import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/notifications/notification_scheduler.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/state/assignment/assignment_flow_controller.dart';
import 'package:wheel_triage/state/notifications/notification_providers.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/rule_profile_fixtures.dart';

final _now = DateTime(2026, 1, 1);

void main() {
  test('S-026: assignment flow -- put side', () async {
    final repo = InMemoryWheelRepository();
    final underlying = await repo.getOrCreateUnderlying('PUT');
    final result = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        expiration: _now.add(const Duration(days: 10)),
        contracts: 1,
        openedAt: _now.subtract(const Duration(days: 20)),
        openCreditPerShare: Decimal.parse('1.20'), // put-side cumulative credit at assignment
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    // Pin the `.family.autoDispose` provider alive and wait for its
    // constructor-fired load to settle (see roll_planner_controller_test.dart
    // for why a bare `read()` isn't enough).
    container.listen(assignmentFlowControllerProvider(result.leg.id), (previous, next) {});
    final controller = container.read(assignmentFlowControllerProvider(result.leg.id).notifier);
    await controller.ready;
    final ok = await controller.confirmPutAssignment(
      assignmentStrike: Decimal.parse('50'),
      contracts: 1,
      assignedAt: _now,
    );
    expect(ok, isTrue);

    final state = container.read(assignmentFlowControllerProvider(result.leg.id));
    expect(state.completed, isTrue);
    expect(state.createdShareLot, isNotNull);
    expect(state.createdShareLot!.contracts, 1); // 100 shares acquired (100 x contracts)
    expect(state.createdShareLot!.assignmentStrike, Decimal.parse('50'));

    // wheelBasis == taxBasis == 50.00 - 1.20 = 48.80 (no calls sold yet).
    expect(state.wheelBasisValue, Decimal.parse('48.80'));
    expect(state.taxBasisValue, Decimal.parse('48.80'));

    expect(state.cycle!.status, WheelCycleStatus.holdingShares);

    final shareLot = await repo.getShareLotForCycle(result.cycle.id);
    expect(shareLot, isNotNull);
  });

  test('S-120: put assignment closeFee persists on the closed put leg', () async {
    final repo = InMemoryWheelRepository();
    final underlying = await repo.getOrCreateUnderlying('FEE');
    final result = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        expiration: _now.add(const Duration(days: 10)),
        contracts: 1,
        openedAt: _now.subtract(const Duration(days: 20)),
        openCreditPerShare: Decimal.parse('1.20'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.listen(assignmentFlowControllerProvider(result.leg.id), (previous, next) {});
    final controller = container.read(assignmentFlowControllerProvider(result.leg.id).notifier);
    await controller.ready;
    await controller.confirmPutAssignment(
      assignmentStrike: Decimal.parse('50'),
      contracts: 1,
      closeFee: Decimal.parse('1.30'),
      assignedAt: _now,
    );

    final closedLeg = (await repo.getLeg(result.leg.id))!;
    expect(closedLeg.closeFee, Decimal.parse('1.30'));
  });

  test(
    'S-120/S-125: covered-call step -- openFee persists, acceptsAssignment asked fresh '
    '(never inherited from the put leg\'s own true value)',
    () async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('FRESH');
      final putResult = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now,
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 40)),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          acceptsAssignment: true, // the put's own value -- must not leak
        ),
      );
      await repo.recordAssignment(
        legId: putResult.leg.id,
        shareLot: NewShareLotInput(assignedAt: _now, assignmentStrike: Decimal.parse('50'), contracts: 1),
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(assignmentFlowControllerProvider(putResult.leg.id), (previous, next) {});
      final controller = container.read(assignmentFlowControllerProvider(putResult.leg.id).notifier);
      await controller.ready;

      final ok = await controller.openCoveredCall(
        strike: Decimal.parse('55'),
        expiration: _now.add(const Duration(days: 30)),
        openCreditPerShare: Decimal.parse('0.50'),
        contracts: 1,
        openFee: Decimal.parse('1.25'),
        acceptsAssignment: false, // answered "no" fresh for this new leg
      );
      expect(ok, isTrue);

      final legs = await repo.getLegsForCycle(putResult.cycle.id);
      final callLeg = legs.firstWhere((l) => l.optionType == OptionType.call);
      expect(callLeg.openFee, Decimal.parse('1.25'));
      expect(callLeg.acceptsAssignment, isFalse);
    },
  );

  test(
    'S-198(c/d): a covered call inherits the put leg\'s pin — v1 before and after an edit',
    () async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('PINNED');
      final putResult = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now,
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 40)),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: putResult.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: _now,
          assignmentStrike: Decimal.parse('50'),
          contracts: 1,
        ),
      );

      // The edit lands *after* the cycle opened: v2 exists from here on.
      final v2 = await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: _now,
        values: standardVersionInput(profitTargetPct: 60.0),
      );

      final container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(assignmentFlowControllerProvider(putResult.leg.id), (previous, next) {});
      final controller =
          container.read(assignmentFlowControllerProvider(putResult.leg.id).notifier);
      await controller.ready;

      Future<Leg> sellCoveredCall() async {
        final ok = await controller.openCoveredCall(
          strike: Decimal.parse('55'),
          expiration: _now.add(const Duration(days: 30)),
          openCreditPerShare: Decimal.parse('0.50'),
          contracts: 1,
        );
        expect(ok, isTrue);
        final callLegs = (await repo.getLegsForCycle(putResult.cycle.id))
            .where((l) => l.optionType == OptionType.call)
            .toList();
        return callLegs.reduce((a, b) => a.sequence > b.sequence ? a : b);
      }

      // (c) Assignment ends the put leg but continues the trade: the covered
      // call keeps the exit rule the cycle was opened under, not the newest.
      final firstCall = await sellCoveredCall();
      expect(firstCall.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
      expect(firstCall.ruleProfileVersionId, isNot(v2.id));

      // (d) Closing the call early and selling another changes nothing — the
      // assignment path is not a new-cycle site.
      await repo.closeLeg(
        legId: firstCall.id,
        reason: CloseReason.closedEarly,
        closeDebitPerShare: Decimal.parse('0.20'),
        closedAt: _now,
      );
      final secondCall = await sellCoveredCall();
      expect(secondCall.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
      expect(secondCall.ruleProfileVersionId, isNot(v2.id));
    },
  );

  test('S-029: call-away flow -- covered call assigned, cycle closes', () async {
    final repo = InMemoryWheelRepository();
    final underlying = await repo.getOrCreateUnderlying('CALL');
    final putResult = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        expiration: _now,
        contracts: 1,
        openedAt: _now.subtract(const Duration(days: 40)),
        openCreditPerShare: Decimal.parse('1.20'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    await repo.recordAssignment(
      legId: putResult.leg.id,
      shareLot: NewShareLotInput(assignedAt: _now, assignmentStrike: Decimal.parse('50'), contracts: 1),
    );
    final callLeg = await repo.openNextLeg(
      cycleId: putResult.cycle.id,
      leg: NewLegInput(
        optionType: OptionType.call,
        strike: Decimal.parse('52'),
        expiration: _now.add(const Duration(days: 20)),
        contracts: 1,
        openedAt: _now,
        openCreditPerShare: Decimal.parse('0.50'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.listen(assignmentFlowControllerProvider(callLeg.id), (previous, next) {});
    final controller = container.read(assignmentFlowControllerProvider(callLeg.id).notifier);
    await controller.ready;
    final ok = await controller.confirmCallAway(closedAt: _now);
    expect(ok, isTrue);

    final closedCallLeg = (await repo.getLeg(callLeg.id))!;
    expect(closedCallLeg.closedAt, _now);
    expect(closedCallLeg.closeReason, CloseReason.assigned);

    final shareLot = await repo.getShareLotForCycle(putResult.cycle.id);
    expect(shareLot, isNull); // consumed/removed

    final cycle = (await repo.getCycle(putResult.cycle.id))!;
    expect(cycle.status, WheelCycleStatus.closed);
    expect(cycle.outcome, WheelCycleOutcome.calledAway);
    expect(cycle.endedAt, _now);
  });

  test('S-120: call-away closeFee persists on the closed call leg', () async {
    final repo = InMemoryWheelRepository();
    final underlying = await repo.getOrCreateUnderlying('CAF');
    final putResult = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        expiration: _now,
        contracts: 1,
        openedAt: _now.subtract(const Duration(days: 40)),
        openCreditPerShare: Decimal.parse('1.20'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    await repo.recordAssignment(
      legId: putResult.leg.id,
      shareLot: NewShareLotInput(assignedAt: _now, assignmentStrike: Decimal.parse('50'), contracts: 1),
    );
    final callLeg = await repo.openNextLeg(
      cycleId: putResult.cycle.id,
      leg: NewLegInput(
        optionType: OptionType.call,
        strike: Decimal.parse('52'),
        expiration: _now.add(const Duration(days: 20)),
        contracts: 1,
        openedAt: _now,
        openCreditPerShare: Decimal.parse('0.50'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.listen(assignmentFlowControllerProvider(callLeg.id), (previous, next) {});
    final controller = container.read(assignmentFlowControllerProvider(callLeg.id).notifier);
    await controller.ready;
    await controller.confirmCallAway(closeFee: Decimal.parse('0.65'), closedAt: _now);

    final closedCallLeg = (await repo.getLeg(callLeg.id))!;
    expect(closedCallLeg.closeFee, Decimal.parse('0.65'));
  });

  group('S-050/S-051/S-057: no-arbitrage bound on the covered-call credit field', () {
    Future<({InMemoryWheelRepository repo, ProviderContainer container, String putLegId})> setup({
      bool withSnapshot = true,
    }) async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('COV');
      final putResult = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now,
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 40)),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: putResult.leg.id,
        shareLot: NewShareLotInput(assignedAt: _now, assignmentStrike: Decimal.parse('50'), contracts: 1),
      );
      if (withSnapshot) {
        // S-050 row 4 / S-051 row 4's "the just-assigned put leg's latest
        // snapshot spot=$54".
        await repo.appendSnapshot(
          NewSnapshotInput(
            legId: putResult.leg.id,
            takenAt: _now,
            optionMark: Decimal.parse('0.05'),
            underlyingPrice: Decimal.parse('54'),
            deltaAsEntered: -0.02,
            deltaConvention: DeltaConvention.position,
          ),
        );
      }

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      container.listen(assignmentFlowControllerProvider(putResult.leg.id), (previous, next) {});
      await container.read(assignmentFlowControllerProvider(putResult.leg.id).notifier).ready;
      await container
          .read(assignmentFlowControllerProvider(putResult.leg.id).notifier)
          .confirmPutAssignment(assignmentStrike: Decimal.parse('50'), contracts: 1, assignedAt: _now);
      return (repo: repo, container: container, putLegId: putResult.leg.id);
    }

    test('S-050 row 4: credit \$55 > spot \$54 (call) -- hard-rejects, no leg opened', () async {
      final ctx = await setup();
      addTearDown(ctx.container.dispose);
      final controller = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId).notifier);

      final ok = await controller.openCoveredCall(
        strike: Decimal.parse('55'),
        expiration: _now.add(const Duration(days: 30)),
        openCreditPerShare: Decimal.parse('55'),
        contracts: 1,
      );
      expect(ok, isFalse);
      final state = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId));
      expect(state.error, contains("can't exceed the share price"));
      expect(state.coveredCallOpened, isFalse);
    });

    test('S-051 row 4: credit \$30 (between 0.5x and 1x spot) -- soft-warns, still opens', () async {
      final ctx = await setup();
      addTearDown(ctx.container.dispose);
      final controller = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId).notifier);

      final ok = await controller.openCoveredCall(
        strike: Decimal.parse('55'),
        expiration: _now.add(const Duration(days: 30)),
        openCreditPerShare: Decimal.parse('30'),
        contracts: 1,
      );
      expect(ok, isTrue);
      final state = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId));
      expect(state.coveredCallWarning, isNotNull);
      expect(state.coveredCallOpened, isTrue);
    });

    test('S-057: put leg has no snapshot yet -- bound check skipped, no false block', () async {
      final ctx = await setup(withSnapshot: false);
      addTearDown(ctx.container.dispose);
      final controller = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId).notifier);

      final ok = await controller.openCoveredCall(
        strike: Decimal.parse('55'),
        expiration: _now.add(const Duration(days: 30)),
        openCreditPerShare: Decimal.parse('999'), // would hard-reject against any real spot
        contracts: 1,
      );
      expect(ok, isTrue);
      final state = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId));
      expect(state.error, isNull);
      expect(state.coveredCallOpened, isTrue);
    });

    test('"total per contract" applies to the covered-call credit field too', () async {
      final ctx = await setup();
      addTearDown(ctx.container.dispose);
      final prefsController = ctx.container.read(preferencesControllerProvider.notifier);
      await prefsController.ready;
      await prefsController.update((p) => p.copyWith(totalPerContractToggle: true));

      final controller = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId).notifier);
      final ok = await controller.openCoveredCall(
        strike: Decimal.parse('55'),
        expiration: _now.add(const Duration(days: 30)),
        openCreditPerShare: Decimal.parse('30'), // -> 0.30 per share, well under bound
        contracts: 1,
      );
      expect(ok, isTrue);

      final cycle = ctx.container.read(assignmentFlowControllerProvider(ctx.putLegId)).cycle!;
      final legs = await ctx.repo.getLegsForCycle(cycle.id);
      final callLeg = legs.firstWhere((l) => l.optionType == OptionType.call);
      expect(callLeg.openCreditPerShare, Decimal.parse('0.30'));
    });
  });

  group('Phase 21 notifications', () {
    test('S-171: put assignment cancels the assigned put leg\'s notifications', () async {
      final repo = InMemoryWheelRepository();
      final gateway = FakeNotificationGateway();
      final underlying = await repo.getOrCreateUnderlying('NPUT');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now.add(const Duration(days: 10)),
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 20)),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          notificationGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      container.listen(assignmentFlowControllerProvider(result.leg.id), (previous, next) {});
      final controller = container.read(assignmentFlowControllerProvider(result.leg.id).notifier);
      await controller.ready;
      await controller.confirmPutAssignment(assignmentStrike: Decimal.parse('50'), contracts: 1, assignedAt: _now);

      for (final milestone in kSupportedNotificationMilestones) {
        expect(gateway.cancelledIds, contains(notificationIdFor(legId: result.leg.id, milestoneDte: milestone)));
      }
    });

    test('S-170: opening the covered call schedules its own notifications, from its own expiration', () async {
      final repo = InMemoryWheelRepository();
      final gateway = FakeNotificationGateway();
      final underlying = await repo.getOrCreateUnderlying('NCALL');
      final putResult = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now,
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 40)),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: putResult.leg.id,
        shareLot: NewShareLotInput(assignedAt: _now, assignmentStrike: Decimal.parse('50'), contracts: 1),
      );

      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          notificationGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      container.listen(assignmentFlowControllerProvider(putResult.leg.id), (previous, next) {});
      final controller = container.read(assignmentFlowControllerProvider(putResult.leg.id).notifier);
      await controller.ready;

      final callExpiration = _now.add(const Duration(days: 30));
      final ok = await controller.openCoveredCall(
        strike: Decimal.parse('55'),
        expiration: callExpiration,
        openCreditPerShare: Decimal.parse('0.50'),
        contracts: 1,
        openedAt: _now,
      );
      expect(ok, isTrue);

      final legs = await repo.getLegsForCycle(putResult.cycle.id);
      final callLeg = legs.firstWhere((l) => l.optionType == OptionType.call);
      expect(gateway.scheduled.keys, hasLength(3));
      for (final milestone in [21, 7, 0]) {
        expect(
          gateway.scheduled.containsKey(notificationIdFor(legId: callLeg.id, milestoneDte: milestone)),
          isTrue,
          reason: 'milestone $milestone',
        );
      }
    });

    test('S-171: call-away cancels the called-away call leg\'s notifications', () async {
      final repo = InMemoryWheelRepository();
      final gateway = FakeNotificationGateway();
      final underlying = await repo.getOrCreateUnderlying('NCAF');
      final putResult = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now,
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 40)),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: putResult.leg.id,
        shareLot: NewShareLotInput(assignedAt: _now, assignmentStrike: Decimal.parse('50'), contracts: 1),
      );
      final callLeg = await repo.openNextLeg(
        cycleId: putResult.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('52'),
          expiration: _now.add(const Duration(days: 20)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('0.50'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          notificationGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      container.listen(assignmentFlowControllerProvider(callLeg.id), (previous, next) {});
      final controller = container.read(assignmentFlowControllerProvider(callLeg.id).notifier);
      await controller.ready;
      await controller.confirmCallAway(closedAt: _now);

      for (final milestone in kSupportedNotificationMilestones) {
        expect(gateway.cancelledIds, contains(notificationIdFor(legId: callLeg.id, milestoneDte: milestone)));
      }
    });
  });
}
