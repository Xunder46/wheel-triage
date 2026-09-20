import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/notifications/notification_scheduler.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/state/notifications/notification_providers.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/roll/roll_planner_controller.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/rule_profile_fixtures.dart';

final _now = DateTime(2026, 1, 1);

void main() {
  late InMemoryWheelRepository repo;
  late ProviderContainer container;
  late String legId;
  late DateTime originalExpiration;

  setUp(() async {
    repo = InMemoryWheelRepository();
    originalExpiration = _now.add(const Duration(days: 20));
    final underlying = await repo.getOrCreateUnderlying('ROLL');
    final result = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('45'),
        expiration: originalExpiration,
        contracts: 2,
        openedAt: _now,
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    legId = result.leg.id;

    container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    // `.family.autoDispose` providers get disposed once nothing is
    // listening -- a bare `container.read()` doesn't count as a listener,
    // so a later `.read()` in the test body could otherwise silently
    // construct a brand-new (un-loaded) instance. `listen` pins this one
    // alive for the container's lifetime; `ready` (below) is then a
    // reliable signal that its constructor-fired load has actually settled.
    container.listen(rollPlannerControllerProvider(legId), (previous, next) {});
    await container.read(rollPlannerControllerProvider(legId).notifier).ready;
  });

  tearDown(() => container.dispose());

  test('S-024: confirming a roll is exactly two writes in one transaction', () async {
    final controller = container.read(rollPlannerControllerProvider(legId).notifier);
    final candidate = RollCandidate(
      id: 'c1',
      newExpiry: originalExpiration.add(const Duration(days: 14)),
      newStrike: Decimal.parse('44'),
      buybackDebit: Decimal.parse('0.80'),
      newCredit: Decimal.parse('0.95'),
    );

    final ok = await controller.confirmRoll(candidate, now: _now);
    expect(ok, isTrue);

    final legs = await repo.getLegsForCycle((await repo.getLeg(legId))!.cycleId);
    expect(legs, hasLength(2));

    final closedLeg = legs.firstWhere((l) => l.id == legId);
    expect(closedLeg.closedAt, _now);
    expect(closedLeg.closeDebitPerShare, Decimal.parse('0.80'));
    expect(closedLeg.closeReason, CloseReason.rolled);

    final newLeg = legs.firstWhere((l) => l.id != legId);
    expect(newLeg.sequence, 1);
    expect(newLeg.rolledFromLegId, legId);
    expect(newLeg.openCreditPerShare, Decimal.parse('0.95'));
    expect(newLeg.strike, Decimal.parse('44'));
    expect(newLeg.contracts, 2);
    expect(newLeg.ruleProfileVersionId, RuleProfileVersionIds.standardV1); // inherited, Feature Invariant 8

    // The pair's net is a credit: 0.95 - 0.80 = 0.15.
    expect(candidate.netCredit, Decimal.parse('0.15'));
    expect(candidate.isDebit, isFalse);
  });

  test(
    'S-025: multi-candidate comparison -- a debit candidate is clearly flagged, never as income',
    () async {
      final controller = container.read(rollPlannerControllerProvider(legId).notifier);

      final candidateA = RollCandidate(
        id: 'A',
        newExpiry: originalExpiration.add(const Duration(days: 14)),
        newStrike: Decimal.parse('44'),
        buybackDebit: Decimal.parse('0.80'),
        newCredit: Decimal.parse('0.95'),
      );
      final candidateB = RollCandidate(
        id: 'B',
        newExpiry: originalExpiration.add(const Duration(days: 7)),
        newStrike: Decimal.parse('45'),
        buybackDebit: Decimal.parse('0.80'),
        newCredit: Decimal.parse('0.60'),
      );

      controller.addCandidate(candidateA);
      controller.addCandidate(candidateB);

      final results = controller.results(now: _now);
      expect(results, hasLength(2));

      final resultA = results.firstWhere((r) => r.candidate.id == 'A');
      expect(resultA.netCredit, Decimal.parse('0.15'));
      expect(resultA.isDebit, isFalse);

      final resultB = results.firstWhere((r) => r.candidate.id == 'B');
      expect(resultB.netCredit, Decimal.parse('-0.20'));
      expect(resultB.isDebit, isTrue); // never presented as income
      expect(resultB.annualisedYield, isNotNull);
    },
  );

  test(
    'S-057: no snapshot on the leg -- bound check skipped entirely, no false block',
    () async {
      final controller = container.read(rollPlannerControllerProvider(legId).notifier);
      final candidate = RollCandidate(
        id: 'huge',
        newExpiry: originalExpiration.add(const Duration(days: 14)),
        newStrike: Decimal.parse('44'),
        buybackDebit: Decimal.parse('0.80'),
        newCredit: Decimal.parse('999'), // would hard-reject against any real spot
      );
      final ok = controller.addCandidate(candidate);
      expect(ok, isTrue);
      expect(container.read(rollPlannerControllerProvider(legId)).candidates, hasLength(1));
      expect(container.read(rollPlannerControllerProvider(legId)).error, isNull);
    },
  );

  test(
    'S-120: roll confirm -- closeFee lands on the closing leg, openFee on the new leg, both optional',
    () async {
      final controller = container.read(rollPlannerControllerProvider(legId).notifier);
      final candidate = RollCandidate(
        id: 'fees',
        newExpiry: originalExpiration.add(const Duration(days: 14)),
        newStrike: Decimal.parse('44'),
        buybackDebit: Decimal.parse('0.80'),
        newCredit: Decimal.parse('0.95'),
      );

      final ok = await controller.confirmRoll(
        candidate,
        closeFee: Decimal.parse('1.30'),
        openFee: Decimal.parse('1.25'),
        now: _now,
      );
      expect(ok, isTrue);

      final legs = await repo.getLegsForCycle((await repo.getLeg(legId))!.cycleId);
      final closedLeg = legs.firstWhere((l) => l.id == legId);
      final newLeg = legs.firstWhere((l) => l.id != legId);
      expect(closedLeg.closeFee, Decimal.parse('1.30'));
      expect(newLeg.openFee, Decimal.parse('1.25'));
    },
  );

  test(
    'S-102: roll inherits acceptsAssignment from the leg it rolled from, without re-asking',
    () async {
      // A fresh cycle whose leg explicitly opts OUT of assignment.
      final underlying = await repo.getOrCreateUnderlying('INH');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: originalExpiration,
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          acceptsAssignment: false,
        ),
      );
      final noAssignLegId = result.leg.id;

      container.listen(rollPlannerControllerProvider(noAssignLegId), (previous, next) {});
      await container.read(rollPlannerControllerProvider(noAssignLegId).notifier).ready;
      final controller = container.read(rollPlannerControllerProvider(noAssignLegId).notifier);

      final ok = await controller.confirmRoll(
        RollCandidate(
          id: 'inherit',
          newExpiry: originalExpiration.add(const Duration(days: 14)),
          newStrike: Decimal.parse('44'),
          buybackDebit: Decimal.parse('0.10'),
          newCredit: Decimal.parse('0.50'),
        ),
        now: _now,
      );
      expect(ok, isTrue);

      final legs = await repo.getLegsForCycle(result.cycle.id);
      final newLeg = legs.firstWhere((l) => l.id != noAssignLegId);
      expect(newLeg.acceptsAssignment, isFalse); // inherited, not re-asked
    },
  );

  group('S-050/S-051: no-arbitrage bound wired into the roll planner\'s newCredit/buybackDebit', () {
    late InMemoryWheelRepository boundedRepo;
    late ProviderContainer boundedContainer;
    late String boundedLegId;

    setUp(() async {
      boundedRepo = InMemoryWheelRepository();
      final underlying = await boundedRepo.getOrCreateUnderlying('BND');
      final result = await boundedRepo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('50'),
          expiration: _now.add(const Duration(days: 20)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      boundedLegId = result.leg.id;
      // S-050 row 3 / S-051 row 3's "leg's latest snapshot spot=$48".
      await boundedRepo.appendSnapshot(
        NewSnapshotInput(
          legId: boundedLegId,
          takenAt: _now,
          optionMark: Decimal.parse('0.90'),
          underlyingPrice: Decimal.parse('48'),
          deltaAsEntered: -0.40,
          deltaConvention: DeltaConvention.position,
        ),
      );

      boundedContainer = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(boundedRepo)],
      );
      boundedContainer.listen(rollPlannerControllerProvider(boundedLegId), (previous, next) {});
      await boundedContainer.read(rollPlannerControllerProvider(boundedLegId).notifier).ready;
    });

    tearDown(() => boundedContainer.dispose());

    test('S-050 row 3: newCredit \$49 > spot \$48 (call) -- hard-rejects, candidate not added', () {
      final controller = boundedContainer.read(rollPlannerControllerProvider(boundedLegId).notifier);
      final ok = controller.addCandidate(
        RollCandidate(
          id: 'reject',
          newExpiry: _now.add(const Duration(days: 34)),
          newStrike: Decimal.parse('50'),
          buybackDebit: Decimal.parse('0.10'),
          newCredit: Decimal.parse('49'),
        ),
      );
      expect(ok, isFalse);
      final state = boundedContainer.read(rollPlannerControllerProvider(boundedLegId));
      expect(state.candidates, isEmpty);
      expect(state.error, contains("can't exceed the share price"));
    });

    test('S-051 row 3: newCredit \$26 (between 0.5x and 1x spot) -- soft-warns, still added', () {
      final controller = boundedContainer.read(rollPlannerControllerProvider(boundedLegId).notifier);
      final ok = controller.addCandidate(
        RollCandidate(
          id: 'warn',
          newExpiry: _now.add(const Duration(days: 34)),
          newStrike: Decimal.parse('50'),
          buybackDebit: Decimal.parse('0.10'),
          newCredit: Decimal.parse('26'),
        ),
      );
      expect(ok, isTrue);
      final state = boundedContainer.read(rollPlannerControllerProvider(boundedLegId));
      expect(state.candidates, hasLength(1));
      expect(state.candidateWarning, isNotNull);
      expect(state.error, isNull);
    });

    test('"total per contract" applies to newCredit/buybackDebit before the bound check', () async {
      final prefsController = boundedContainer.read(preferencesControllerProvider.notifier);
      await prefsController.ready;
      await prefsController.update((p) => p.copyWith(totalPerContractToggle: true));

      final controller = boundedContainer.read(rollPlannerControllerProvider(boundedLegId).notifier);
      final ok = controller.addCandidate(
        RollCandidate(
          id: 'toggle',
          newExpiry: _now.add(const Duration(days: 34)),
          newStrike: Decimal.parse('50'),
          buybackDebit: Decimal.parse('10'), // -> 0.10 per share
          newCredit: Decimal.parse('15'), // -> 0.15 per share, well under bound
        ),
      );
      expect(ok, isTrue);
      final stored = boundedContainer.read(rollPlannerControllerProvider(boundedLegId)).candidates.single;
      expect(stored.buybackDebit, Decimal.parse('0.10'));
      expect(stored.newCredit, Decimal.parse('0.15'));
    });
  });

  group('S-172: reschedule on roll', () {
    test('the closing leg\'s notifications cancel; the new leg gets its own, from its own expiration', () async {
      final repo = InMemoryWheelRepository();
      final gateway = FakeNotificationGateway();
      final originalExpiration = _now.add(const Duration(days: 20));
      final underlying = await repo.getOrCreateUnderlying('ROLL2');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: originalExpiration,
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final legId = created.leg.id;

      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          notificationGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      container.listen(rollPlannerControllerProvider(legId), (previous, next) {});
      await container.read(rollPlannerControllerProvider(legId).notifier).ready;

      final newExpiry = originalExpiration.add(const Duration(days: 30));
      final controller = container.read(rollPlannerControllerProvider(legId).notifier);
      final ok = await controller.confirmRoll(
        RollCandidate(
          id: 'r1',
          newExpiry: newExpiry,
          newStrike: Decimal.parse('44'),
          buybackDebit: Decimal.parse('0.80'),
          newCredit: Decimal.parse('0.95'),
        ),
        now: _now,
      );
      expect(ok, isTrue);

      final legs = await repo.getLegsForCycle(created.cycle.id);
      final newLeg = legs.firstWhere((l) => l.id != legId);

      for (final milestone in kSupportedNotificationMilestones) {
        expect(gateway.cancelledIds, contains(notificationIdFor(legId: legId, milestoneDte: milestone)));
      }
      for (final milestone in [21, 7, 0]) {
        expect(
          gateway.scheduled.containsKey(notificationIdFor(legId: newLeg.id, milestoneDte: milestone)),
          isTrue,
          reason: 'milestone $milestone',
        );
        // Scheduled relative to the NEW leg's own expiration, not the old one.
        final when = gateway.scheduled[notificationIdFor(legId: newLeg.id, milestoneDte: milestone)]!.when;
        expect(when.isBefore(newExpiry.add(const Duration(days: 1))), isTrue);
      }
    });
  });

  group('S-198(b): a roll keeps the closing leg\'s pin', () {
    test('a replacement leg opened after an edit still pins the closing leg\'s v1', () async {
      final v2 = await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: _now,
        values: standardVersionInput(profitTargetPct: 60.0),
      );

      final controller = container.read(rollPlannerControllerProvider(legId).notifier);
      final ok = await controller.confirmRoll(
        RollCandidate(
          id: 'pin-1',
          newExpiry: originalExpiration.add(const Duration(days: 30)),
          newStrike: Decimal.parse('44'),
          buybackDebit: Decimal.parse('0.80'),
          newCredit: Decimal.parse('0.95'),
        ),
        now: _now,
      );
      expect(ok, isTrue);

      // The roll is a continuation of the same trade, not a new cycle: the
      // replacement leg inherits the version the closing leg was opened
      // under, even though v2 is now the current one.
      final legs = await repo.getLegsForCycle((await repo.getLeg(legId))!.cycleId);
      final newLeg = legs.firstWhere((l) => l.id != legId);
      expect(newLeg.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
      expect(newLeg.ruleProfileVersionId, isNot(v2.id));
    });
  });
}
