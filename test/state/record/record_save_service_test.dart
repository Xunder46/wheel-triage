import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/state/notifications/notification_providers.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/record/record_save_service.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/rule_profiles/rule_profile_providers.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/rule_profile_fixtures.dart';

final _now = DateTime(2026, 9, 28, 10);

/// One put-side cycle, opened 40 days before [_now] so its `startedAt` is a
/// distinguishable date for S-233's explanation line.
Future<({WheelCycle cycle, Leg leg})> _openPutCycle(
  InMemoryWheelRepository repo, {
  required String ticker,
  Decimal? strike,
  Decimal? credit,
  int contracts = 1,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  return repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: strike ?? Decimal.parse('30'),
      expiration: _now.add(const Duration(days: 20)),
      contracts: contracts,
      openedAt: _now.subtract(const Duration(days: 40)),
      openCreditPerShare: credit ?? Decimal.parse('1.00'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
}

/// S-233's fixture: [ticker] holding 100 shares from an assignment, with no
/// open call on them.
Future<void> _assignShares(
  InMemoryWheelRepository repo, {
  required String ticker,
  required Decimal strike,
}) async {
  final put = await _openPutCycle(repo, ticker: ticker, strike: strike);
  await repo.recordAssignment(
    legId: put.leg.id,
    shareLot: NewShareLotInput(
      assignedAt: _now.subtract(const Duration(days: 5)),
      assignmentStrike: strike,
      contracts: 1,
    ),
  );
}

/// Distinct underlying ids across every cycle in the repository — the only
/// way to count underlyings through the storage-agnostic interface.
Future<Set<String>> _underlyingIds(InMemoryWheelRepository repo) async {
  final ids = <String>{};
  for (final leg in await repo.getAllLegs()) {
    final cycle = await repo.getCycle(leg.cycleId);
    if (cycle != null) ids.add(cycle.underlyingId);
  }
  return ids;
}

void main() {
  late InMemoryWheelRepository repo;
  late ProviderContainer container;
  late FakeNotificationGateway gateway;

  setUp(() {
    repo = InMemoryWheelRepository();
    gateway = FakeNotificationGateway();
    container = ProviderContainer(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        notificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
    container.listen(preferencesControllerProvider, (previous, next) {});
  });

  tearDown(() => container.dispose());

  RecordSaveService service() => container.read(recordSaveServiceProvider);

  group('S-228: Record a trade — the minimum path', () {
    test(
      'a put opens exactly one underlying, one cycle and one leg with the '
      'optionals left null, and schedules this leg\'s reminders',
      () async {
        final result = await service().save(
          ticker: 'CCL',
          side: OptionType.put,
          strike: Decimal.parse('19'),
          expiration: DateTime(2026, 10, 16),
          contracts: 2,
          openCreditPerShare: Decimal.parse('0.34'),
          now: _now,
        );

        expect(result.outcome, RecordSaveOutcome.created);
        expect(result.ticker, 'CCL');

        expect(await _underlyingIds(repo), hasLength(1));

        final legs = await repo.getOpenLegs();
        expect(legs, hasLength(1));
        final leg = legs.single;
        expect(leg.sequence, 0);
        expect(leg.optionType, OptionType.put);
        expect(leg.strike, Decimal.parse('19'));
        expect(leg.contracts, 2);
        expect(leg.openCreditPerShare, Decimal.parse('0.34'));
        expect(leg.openFee, isNull);
        expect(leg.ivAtOpen, isNull);
        expect(leg.ivRankAtOpen, isNull);
        expect(leg.underlyingPriceAtOpen, isNull);
        expect(leg.acceptsAssignment, isTrue);
        expect(leg.ruleProfileVersionId, RuleProfileVersionIds.standardV1);

        final cycle = await repo.getCycle(leg.cycleId);
        expect(cycle!.status, WheelCycleStatus.sellingPuts);

        // The reminder line's milestones are the ones that actually fire.
        expect(gateway.scheduled, isNotEmpty);
        for (final entry in gateway.scheduled.values) {
          expect(entry.when.isAfter(_now), isTrue);
        }
      },
    );
  });

  group('S-233: a call attaches to a waiting share-holding cycle', () {
    test(
      'no new cycle or underlying is created; one leg is appended to T\'s '
      'existing cycle with the standard version and the toggle\'s '
      'acceptsAssignment',
      () async {
        await _assignShares(repo, ticker: 'T', strike: Decimal.parse('30'));
        await _openPutCycle(repo, ticker: 'CCL');
        final cyclesBefore = await repo.countCyclesForReplace();
        final underlyingsBefore = await _underlyingIds(repo);

        final resolution = await service().resolveCallHost('T');
        expect(resolution.isRefused, isFalse);
        expect(resolution.cycle, isNotNull);
        expect(resolution.explanation, isNotNull);
        expect(resolution.explanation, contains('100 shares'));
        expect(resolution.explanation, contains('29.00'));

        final result = await service().save(
          ticker: 'T',
          side: OptionType.call,
          strike: Decimal.parse('28'),
          expiration: DateTime(2026, 10, 16),
          contracts: 1,
          openCreditPerShare: Decimal.parse('0.30'),
          acceptsAssignment: false,
          now: _now,
        );

        expect(result.outcome, RecordSaveOutcome.attached);
        expect(await repo.countCyclesForReplace(), cyclesBefore);
        expect(await _underlyingIds(repo), underlyingsBefore);

        final tLegs = await repo.getLegsForCycle(resolution.cycle!.id);
        expect(tLegs, hasLength(2));
        final attached = tLegs.last;
        expect(attached.rolledFromLegId, isNull);
        expect(attached.sequence, 1);
        expect(attached.optionType, OptionType.call);
        expect(attached.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
        expect(attached.acceptsAssignment, isFalse);
        expect(attached.openCreditPerShare, Decimal.parse('0.30'));

        expect(gateway.scheduled, isNotEmpty);
      },
    );
  });

  group('S-234: a call with no shares on record is refused', () {
    test('writes nothing and returns the D-12 line', () async {
      await _openPutCycle(repo, ticker: 'CCL');

      final result = await service().save(
        ticker: 'CCL',
        side: OptionType.call,
        strike: Decimal.parse('28'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.30'),
        now: _now,
      );

      expect(result.outcome, RecordSaveOutcome.refused);
      expect(
        result.refusalReason,
        'Calls are recorded against shares held from an assignment, and there '
        'are no CCL shares on record.',
      );

      final legs = await repo.getOpenLegs();
      expect(legs, hasLength(1)); // the pre-existing put only
      expect(legs.single.optionType, OptionType.put);
      expect(gateway.scheduled, isEmpty);
    });

    test('a ticker with no history at all creates no underlying row', () async {
      final result = await service().save(
        ticker: 'ZZZ',
        side: OptionType.call,
        strike: Decimal.parse('28'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.30'),
        now: _now,
      );

      expect(result.outcome, RecordSaveOutcome.refused);
      expect(await repo.getAllLegs(), isEmpty);
    });
  });

  group('S-235: a call on shares with an open call is refused', () {
    test('returns the D-12 line and writes nothing', () async {
      await _assignShares(repo, ticker: 'F', strike: Decimal.parse('20'));
      final first = await service().save(
        ticker: 'F',
        side: OptionType.call,
        strike: Decimal.parse('21'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.40'),
        now: _now,
      );
      expect(first.outcome, RecordSaveOutcome.attached);
      final openBefore = await repo.getOpenLegs();

      final second = await service().save(
        ticker: 'F',
        side: OptionType.call,
        strike: Decimal.parse('22'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.45'),
        now: _now,
      );

      expect(second.outcome, RecordSaveOutcome.refused);
      expect(second.refusalReason, 'F already has an open call; close or roll it first.');
      expect(await repo.getOpenLegs(), hasLength(openBefore.length));
    });
  });

  group('S-236 (a, b): the screener\'s call path follows D-P12', () {
    test('(a) attaches to the existing holding cycle', () async {
      await _assignShares(repo, ticker: 'T', strike: Decimal.parse('30'));
      final before = await repo.countCyclesForReplace();

      final result = await service().save(
        ticker: 'T',
        side: OptionType.call,
        strike: Decimal.parse('28'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.30'),
        underlyingPriceAtOpen: Decimal.parse('28'),
        now: _now,
      );

      expect(result.outcome, RecordSaveOutcome.attached);
      expect(await repo.countCyclesForReplace(), before);
    });

    test('(b) CCL with no shares on record is refused and writes nothing', () async {
      await _openPutCycle(repo, ticker: 'CCL');
      final before = await repo.countCyclesForReplace();

      final result = await service().save(
        ticker: 'CCL',
        side: OptionType.call,
        strike: Decimal.parse('28'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.30'),
        underlyingPriceAtOpen: Decimal.parse('28'),
        now: _now,
      );

      expect(result.isRefused, isTrue);
      expect(result.refusalReason, contains('there are no CCL shares on record'));
      expect(await repo.countCyclesForReplace(), before);
      expect(await repo.getOpenLegs(), hasLength(1));
    });
  });

  group('S-228 (version pin): the leg pins the standard profile\'s current version', () {
    test('after an edit, a new leg pins v2 while the old leg keeps v1', () async {
      final first = await service().save(
        ticker: 'CCL',
        side: OptionType.put,
        strike: Decimal.parse('19'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.34'),
        now: _now,
      );
      expect(first.outcome, RecordSaveOutcome.created);

      await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        values: standardVersionInput(profitTargetPct: 0.6),
        effectiveAt: _now,
      );
      // The editor invalidates this after an append; the test stands in for
      // that one line so the save path resolves the newest version.
      container.invalidate(currentRuleProfileProvider);

      final second = await service().save(
        ticker: 'INTC',
        side: OptionType.put,
        strike: Decimal.parse('30'),
        expiration: DateTime(2026, 10, 16),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.40'),
        now: _now,
      );
      expect(second.outcome, RecordSaveOutcome.created);

      final legs = await repo.getOpenLegs();
      final ccl = legs.firstWhere((l) => l.openCreditPerShare == Decimal.parse('0.34'));
      final intc = legs.firstWhere((l) => l.openCreditPerShare == Decimal.parse('0.40'));
      expect(ccl.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
      expect(intc.ruleProfileVersionId, RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 2));
    });
  });
}
