import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/domain/rules/credit_bound.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/rule_profiles/rule_profile_providers.dart';
import 'package:wheel_triage/state/screener/screener_controller.dart';

import '../../support/rule_profile_fixtures.dart';

final _fixedNow = DateTime(2026, 1, 1);

void main() {
  group('S-020: "Just calculating" vs. "Track this position"', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = InMemoryWheelRepository();
      container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          screenerControllerProvider.overrideWith(
            (ref) => ScreenerController(ref, now: _fixedNow),
          ),
        ],
      );
      container.listen(screenerControllerProvider, (previous, next) {});
      container.listen(screenerOutputsProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});
    });

    tearDown(() => container.dispose());

    void fillForm() {
      final controller = container.read(screenerControllerProvider.notifier);
      controller
        ..setTicker('xyz')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('45'))
        ..setSpot(Decimal.parse('47'))
        ..setCredit(Decimal.parse('0.60'))
        ..setDteConvenience(35)
        ..setIv(45)
        ..setIvRank(40)
        ..setContracts(2);
    }

    test('Flow A: "Just calculating" persists nothing', () async {
      fillForm();
      container.read(screenerControllerProvider.notifier).justCalculate();

      // Outputs render (non-null) without any persistence side effect.
      final outputs = container.read(screenerOutputsProvider);
      expect(outputs.annualisedYield, isNotNull);

      expect(await repo.getOpenLegs(), isEmpty);
    });

    test('Flow B: "Track this position" creates exactly one Underlying/Cycle/Leg', () async {
      fillForm();
      final ok = await container
          .read(screenerControllerProvider.notifier)
          .trackThisPosition(now: DateTime(2026, 1, 1));
      expect(ok, isTrue);

      final legs = await repo.getOpenLegs();
      expect(legs, hasLength(1));
      final leg = legs.single;
      expect(leg.sequence, 0);
      expect(leg.optionType, OptionType.put);
      expect(leg.strike, Decimal.parse('45'));
      expect(leg.contracts, 2);
      expect(leg.openCreditPerShare, Decimal.parse('0.60'));
      expect(leg.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
      // Expiration is exactly the picker's value (Feature Invariant 22) --
      // moved by the convenience DTE field to today + 35 days, not Friday-
      // snapped.
      expect(leg.expiration, _fixedNow.add(const Duration(days: 35)));

      final cycle = await repo.getCycle(leg.cycleId);
      expect(cycle, isNotNull);
      expect(cycle!.status.name, 'sellingPuts');
      expect(cycle.outcome, isNull);

      final underlying = await repo.getUnderlying(cycle.underlyingId);
      expect(underlying, isNotNull);
      expect(underlying!.ticker, 'XYZ');
    });

    test('S-120: openFee is optional -- blank persists null, a typed value persists exactly', () async {
      fillForm();
      final ok = await container
          .read(screenerControllerProvider.notifier)
          .trackThisPosition(now: DateTime(2026, 1, 1));
      expect(ok, isTrue);
      final blankLeg = (await repo.getOpenLegs()).single;
      expect(blankLeg.openFee, isNull);

      container.read(screenerControllerProvider.notifier).reset();
      fillForm();
      container.read(screenerControllerProvider.notifier).setOpenFee(Decimal.parse('1.30'));
      final ok2 = await container
          .read(screenerControllerProvider.notifier)
          .trackThisPosition(now: DateTime(2026, 1, 2));
      expect(ok2, isTrue);
      final legs = await repo.getOpenLegs();
      final feeLeg = legs.firstWhere((l) => l.openFee != null);
      expect(feeLeg.openFee, Decimal.parse('1.30'));
    });

    test('S-123: acceptsAssignment toggle -- default true, explicit false persists false', () async {
      fillForm();
      final ok = await container
          .read(screenerControllerProvider.notifier)
          .trackThisPosition(now: DateTime(2026, 1, 1));
      expect(ok, isTrue);
      expect((await repo.getOpenLegs()).single.acceptsAssignment, isTrue);

      container.read(screenerControllerProvider.notifier).reset();
      fillForm();
      container.read(screenerControllerProvider.notifier).setAcceptsAssignment(false);
      final ok2 = await container
          .read(screenerControllerProvider.notifier)
          .trackThisPosition(now: DateTime(2026, 1, 2));
      expect(ok2, isTrue);
      final legs = await repo.getOpenLegs();
      expect(legs.where((l) => !l.acceptsAssignment), hasLength(1));
    });

    test('S-198(a): a new cycle pins the version current at open time — v1, then v2 after an edit', () async {
      fillForm();
      final firstOk = await container
          .read(screenerControllerProvider.notifier)
          .trackThisPosition(now: DateTime(2026, 1, 1));
      expect(firstOk, isTrue);
      expect(
        (await repo.getOpenLegs()).single.ruleProfileVersionId,
        RuleProfileVersionIds.standardV1,
      );

      final v2 = await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: DateTime(2026, 1, 2),
        values: standardVersionInput(profitTargetPct: 60.0),
      );
      // The editor's save invalidates the resolved profile (Phase 26); the
      // repository append itself notifies nothing, so stand in for it here.
      container.invalidate(currentRuleProfileProvider);

      fillForm();
      final secondOk = await container
          .read(screenerControllerProvider.notifier)
          .trackThisPosition(now: DateTime(2026, 1, 2));
      expect(secondOk, isTrue);
      expect(
        (await repo.getOpenLegs()).map((l) => l.ruleProfileVersionId),
        contains(v2.id),
      );
    });
  });

  group('S-050/S-053: hard-reject blocks both actions and suppresses outputs', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = InMemoryWheelRepository();
      container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          screenerControllerProvider.overrideWith(
            (ref) => ScreenerController(ref, now: _fixedNow),
          ),
        ],
      );
      container.listen(screenerControllerProvider, (previous, next) {});
      container.listen(screenerOutputsProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});
    });

    tearDown(() => container.dispose());

    void fillHardRejectForm() {
      final controller = container.read(screenerControllerProvider.notifier);
      // S-050 row 1: strike=$50, spot=$45, credit=$46 (call, > spot).
      controller
        ..setTicker('xyz')
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('50'))
        ..setSpot(Decimal.parse('45'))
        ..setCredit(Decimal.parse('46'))
        ..setDteConvenience(35);
    }

    test('outcome A: "Just calculating" renders the blocked state, no real yield', () {
      fillHardRejectForm();
      container.read(screenerControllerProvider.notifier).justCalculate();

      final outputs = container.read(screenerOutputsProvider);
      expect(outputs.isBlocked, isTrue);
      expect(outputs.creditBound!.level, CreditBoundLevel.hardReject);
      expect(outputs.annualisedYield, isNull);
      expect(outputs.sortingScore, isNull);
    });

    test('outcome B: "Track this position" returns false, creates zero rows', () async {
      fillHardRejectForm();
      final ok = await container.read(screenerControllerProvider.notifier).trackThisPosition();
      expect(ok, isFalse);
      expect(await repo.getOpenLegs(), isEmpty);

      final state = container.read(screenerControllerProvider);
      expect(state.error, contains("can't exceed the share price"));
    });
  });

  group('S-091: put-side hard reject fires with no stock price entered', () {
    test(
      'put, strike \$40, credit \$41, spot unset -> outputs.isBlocked == true '
      '(the put-side bound only needs strike, never spot -- a missing stock price '
      'must not suppress it the way it correctly suppresses the call-side check)',
      () {
        final repo = InMemoryWheelRepository();
        final container = ProviderContainer(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            screenerControllerProvider.overrideWith(
              (ref) => ScreenerController(ref, now: _fixedNow),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(screenerControllerProvider, (previous, next) {});
        container.listen(screenerOutputsProvider, (previous, next) {});
        container.listen(preferencesControllerProvider, (previous, next) {});

        final controller = container.read(screenerControllerProvider.notifier);
        controller
          ..setTicker('xyz')
          ..setSide(OptionType.put)
          ..setStrike(Decimal.parse('40'))
          ..setCredit(Decimal.parse('41')) // > strike, no spot entered at all
          ..setDteConvenience(35);

        final outputs = container.read(screenerOutputsProvider);
        expect(outputs.isBlocked, isTrue);
        expect(outputs.creditBound!.level, CreditBoundLevel.hardReject);
        expect(outputs.creditBound!.message, contains('strike price'));
        expect(outputs.annualisedYield, isNull);
        expect(outputs.sortingScore, isNull);
      },
    );
  });

  group('S-051: soft-warn never blocks', () {
    test('screener credit soft-warn renders the outputs, no block', () async {
      final repo = InMemoryWheelRepository();
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          screenerControllerProvider.overrideWith(
            (ref) => ScreenerController(ref, now: _fixedNow),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(screenerControllerProvider, (previous, next) {});
      container.listen(screenerOutputsProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});

      final controller = container.read(screenerControllerProvider.notifier);
      // S-051 row 1's shape, put-side: strike=$50, credit=$30 (between 0.5x
      // and 1x the strike, so a soft warn). Put-side since D-12 — a call with
      // no shares on record is refused before the save, which would make this
      // scenario assert a refusal rather than a soft warn.
      controller
        ..setTicker('xyz')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('50'))
        ..setSpot(Decimal.parse('45'))
        ..setCredit(Decimal.parse('30'))
        ..setDteConvenience(35);

      final outputs = container.read(screenerOutputsProvider);
      expect(outputs.isBlocked, isFalse);
      expect(outputs.creditBound!.level, CreditBoundLevel.softWarn);
      expect(outputs.annualisedYield, isNotNull); // never blocked

      final ok = await controller.trackThisPosition();
      expect(ok, isTrue);
      expect(await repo.getOpenLegs(), hasLength(1));
    });
  });

  group('S-052: "total per contract" toggle', () {
    test('typing 31 with the toggle on stores Decimal.parse("0.31")', () async {
      final repo = InMemoryWheelRepository();
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          screenerControllerProvider.overrideWith(
            (ref) => ScreenerController(ref, now: _fixedNow),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(screenerControllerProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});

      final prefsController = container.read(preferencesControllerProvider.notifier);
      await prefsController.ready;
      await prefsController.update((p) => p.copyWith(totalPerContractToggle: true));

      container.read(screenerControllerProvider.notifier).setCredit(Decimal.parse('31'));
      final state = container.read(screenerControllerProvider);
      expect(state.credit, Decimal.parse('0.31'));
    });

    test(
      'one global preference: toggled from a different field entirely, a fresh screener '
      'instance against the same repository still reflects it (not per-field)',
      () async {
        final repo = InMemoryWheelRepository();
        // Simulate the toggle having been set from the snapshot sheet
        // instead of the screener, directly through the repository -- the
        // same persistence path `PreferencesController` writes through.
        final defaults = await repo.getPreferences();
        await repo.updatePreferences(defaults.copyWith(totalPerContractToggle: true));

        // A fresh container/controller instance, simulating a relaunch,
        // against the same underlying repository.
        final container = ProviderContainer(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            screenerControllerProvider.overrideWith(
              (ref) => ScreenerController(ref, now: _fixedNow),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(screenerControllerProvider, (previous, next) {});
        container.listen(preferencesControllerProvider, (previous, next) {});
        await container.read(preferencesControllerProvider.notifier).ready;

        container.read(screenerControllerProvider.notifier).setCredit(Decimal.parse('31'));
        expect(container.read(screenerControllerProvider).credit, Decimal.parse('0.31'));
      },
    );
  });

  group('S-054: screener expiration date picker', () {
    test('defaults to the Friday nearest today+37, inside [30,45]', () {
      final repo = InMemoryWheelRepository();
      final wednesday = DateTime(2026, 1, 7);
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          screenerControllerProvider.overrideWith(
            (ref) => ScreenerController(ref, now: wednesday),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(screenerControllerProvider, (previous, next) {});

      final state = container.read(screenerControllerProvider);
      expect(state.expiration, isNotNull);
      expect(state.expiration!.weekday, DateTime.friday);
      expect(state.nonFridayWarning, isFalse);
      final daysOut = state.expiration!.difference(wednesday).inDays;
      expect(daysOut, inInclusiveRange(30, 45));
    });

    test('picking a non-Friday date warns without blocking; DTE field moves the picker', () {
      final repo = InMemoryWheelRepository();
      final wednesday = DateTime(2026, 1, 7);
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          screenerControllerProvider.overrideWith(
            (ref) => ScreenerController(ref, now: wednesday),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(screenerControllerProvider, (previous, next) {});

      final controller = container.read(screenerControllerProvider.notifier);
      controller.setDteConvenience(32); // today (a Wednesday) + 32 days -> a Sunday.
      final state = container.read(screenerControllerProvider);
      expect(state.expiration, wednesday.add(const Duration(days: 32)));
      expect(state.dte, 32);
      // The picker moved to exactly today+32 -- the nearest actual calendar
      // date, un-snapped to Friday -- and a non-Friday warns without
      // blocking (`hasEnoughToTrack` is unaffected by the warning).
      expect(state.nonFridayWarning, isTrue);
    });
  });

  group('S-236: the screener\'s save path follows D-12 through the shared service', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = InMemoryWheelRepository();
      container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          screenerControllerProvider.overrideWith(
            (ref) => ScreenerController(ref, now: _fixedNow),
          ),
        ],
      );
      container.listen(screenerControllerProvider, (previous, next) {});
      container.listen(screenerOutputsProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});
    });

    tearDown(() => container.dispose());

    ScreenerController controller() => container.read(screenerControllerProvider.notifier);

    /// T's holdingShares cycle: one put, assigned, one share lot, no open call.
    Future<String> seedHoldingCycle() async {
      final underlying = await repo.getOrCreateUnderlying('T');
      final put = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('30'),
          expiration: DateTime(2026, 2, 20),
          contracts: 1,
          openedAt: _fixedNow.subtract(const Duration(days: 40)),
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final assigned = await repo.recordAssignment(
        legId: put.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: _fixedNow.subtract(const Duration(days: 5)),
          assignmentStrike: Decimal.parse('30'),
          contracts: 1,
        ),
      );
      return assigned.cycle.id;
    }

    void fillCall(String ticker) {
      controller()
        ..setTicker(ticker)
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('28'))
        ..setSpot(Decimal.parse('28'))
        ..setCredit(Decimal.parse('0.30'))
        ..setDteConvenience(35)
        ..setContracts(1);
    }

    test('(a) a call on T appends one leg to the existing cycle', () async {
      final cycleId = await seedHoldingCycle();
      final cyclesBefore = await repo.countCyclesForReplace();

      fillCall('T');
      expect(await controller().trackThisPosition(), isTrue);

      expect(await repo.countCyclesForReplace(), cyclesBefore);
      final legs = await repo.getLegsForCycle(cycleId);
      expect(legs, hasLength(2));
      expect(legs.last.optionType, OptionType.call);
      expect(legs.last.sequence, 1);
      expect(container.read(screenerControllerProvider).tracked, isTrue);
    });

    test('(b) a call on CCL with no shares on record is refused, nothing written', () async {
      final underlying = await repo.getOrCreateUnderlying('CCL');
      await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('19'),
          expiration: DateTime(2026, 2, 20),
          contracts: 1,
          openedAt: _fixedNow,
          openCreditPerShare: Decimal.parse('0.34'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final cyclesBefore = await repo.countCyclesForReplace();

      fillCall('CCL');
      expect(await controller().trackThisPosition(), isFalse);

      expect(
        container.read(screenerControllerProvider).error,
        'Calls are recorded against shares held from an assignment, and there '
        'are no CCL shares on record.',
      );
      expect(await repo.countCyclesForReplace(), cyclesBefore);
      expect(await repo.getOpenLegs(), hasLength(1));
      expect(container.read(screenerControllerProvider).tracked, isFalse);
    });

    test('(c) the put side persists exactly as before: one cycle, one leg, sequence 0', () async {
      final form = controller();
      form
        ..setTicker('ccl')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setSpot(Decimal.parse('18.20'))
        ..setCredit(Decimal.parse('0.34'))
        ..setIv(21)
        ..setIvRank(30)
        ..setOpenFee(Decimal.parse('0.65'))
        ..setAcceptsAssignment(false)
        ..setDteConvenience(18)
        ..setContracts(2);

      expect(await form.trackThisPosition(), isTrue);

      expect(await repo.countCyclesForReplace(), 1);
      final leg = (await repo.getOpenLegs()).single;
      expect(leg.sequence, 0);
      expect(leg.optionType, OptionType.put);
      expect(leg.strike, Decimal.parse('19'));
      expect(leg.contracts, 2);
      expect(leg.openCreditPerShare, Decimal.parse('0.34'));
      expect(leg.ivAtOpen, 21);
      expect(leg.ivRankAtOpen, 30);
      expect(leg.underlyingPriceAtOpen, Decimal.parse('18.20'));
      expect(leg.openFee, Decimal.parse('0.65'));
      expect(leg.acceptsAssignment, isFalse);
      expect(leg.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
      expect((await repo.getCycle(leg.cycleId))!.status, WheelCycleStatus.sellingPuts);
      // The ticker is uppercased by the form, as it always was.
      expect((await repo.getUnderlying((await repo.getCycle(leg.cycleId))!.underlyingId))!.ticker,
          'CCL');
    });
  });
}
