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
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/state/notifications/notification_providers.dart';
import 'package:wheel_triage/state/positions/position_detail_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_notification_gateway.dart';

final _now = DateTime(2026, 1, 1);

void main() {
  test('S-027: direct close / mark-expired -- put side ends the cycle', () async {
    final repo = InMemoryWheelRepository();
    final underlying = await repo.getOrCreateUnderlying('PUT');
    final result = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        expiration: _now, // dte near/at 0
        contracts: 1,
        openedAt: _now.subtract(const Duration(days: 20)),
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
    await container.read(positionDetailControllerProvider(result.leg.id).notifier).load(now: _now);

    final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
    final ok = await controller.closeDirect(
      reason: CloseReason.expiredWorthless,
      closeDebitPerShare: Decimal.zero,
      closedAt: _now,
    );
    expect(ok, isTrue);

    final closedLeg = (await repo.getLeg(result.leg.id))!;
    expect(closedLeg.closedAt, _now);
    expect(closedLeg.closeReason, CloseReason.expiredWorthless);
    expect(closedLeg.closeDebitPerShare, Decimal.zero);

    final cycle = (await repo.getCycle(result.cycle.id))!;
    expect(cycle.status, WheelCycleStatus.closed);
    expect(cycle.outcome, WheelCycleOutcome.expiredWorthless);
    expect(cycle.endedAt, _now);
  });

  test(
    'S-028: direct close -- call side while still holding shares does NOT end the cycle',
    () async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('CALL');
      // Put through assignment first, so the cycle is holdingShares with an
      // active ShareLot.
      final putResult = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now,
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 20)),
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
          expiration: _now.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('0.50'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionDetailControllerProvider(callLeg.id), (previous, next) {});
      await container.read(positionDetailControllerProvider(callLeg.id).notifier).load(now: _now);

      final controller = container.read(positionDetailControllerProvider(callLeg.id).notifier);
      final ok = await controller.closeDirect(
        reason: CloseReason.closedEarly,
        closeDebitPerShare: Decimal.parse('0.10'),
        closedAt: _now,
      );
      expect(ok, isTrue);

      final closedCallLeg = (await repo.getLeg(callLeg.id))!;
      expect(closedCallLeg.closedAt, _now);
      expect(closedCallLeg.closeReason, CloseReason.closedEarly);

      final cycle = (await repo.getCycle(putResult.cycle.id))!;
      expect(cycle.status, WheelCycleStatus.holdingShares); // still holding shares
      expect(cycle.outcome, isNull);
    },
  );

  test(
    'S-171: closeDirect cancels the closed leg\'s notifications only, an unrelated leg\'s are untouched',
    () async {
      final repo = InMemoryWheelRepository();
      final gateway = FakeNotificationGateway();
      final underlying = await repo.getOrCreateUnderlying('CLOSE');

      final target = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now,
          contracts: 1,
          openedAt: _now.subtract(const Duration(days: 20)),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final unrelated = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('40'),
          expiration: _now.add(const Duration(days: 30)),
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
      container.listen(positionDetailControllerProvider(target.leg.id), (previous, next) {});
      await container.read(positionDetailControllerProvider(target.leg.id).notifier).load(now: _now);

      final controller = container.read(positionDetailControllerProvider(target.leg.id).notifier);
      final ok = await controller.closeDirect(
        reason: CloseReason.expiredWorthless,
        closeDebitPerShare: Decimal.zero,
        closedAt: _now,
      );
      expect(ok, isTrue);

      for (final milestone in kSupportedNotificationMilestones) {
        expect(
          gateway.cancelledIds,
          contains(notificationIdFor(legId: target.leg.id, milestoneDte: milestone)),
        );
        expect(
          gateway.cancelledIds,
          isNot(contains(notificationIdFor(legId: unrelated.leg.id, milestoneDte: milestone))),
        );
      }
    },
  );

  group('CR-3: closeDirect matches the S-140 classification-date rule', () {
    test(
      'a backdated close does not become the classification reference time',
      () async {
        final repo = InMemoryWheelRepository();
        final wallNow = DateTime.now();
        // Same discriminator as S-140 (the twin defect this mirrors):
        // dte-as-of-real-now == 2, inside the tail window (tailDteDays 3),
        // while dte-as-of-the-backdated-close == 12, past it. Only Gate 4
        // reads `dte`, so the two reference times disagree on whether the
        // leg is in its tail -- which is what exposes the defect.
        final openedAt = wallNow.subtract(const Duration(days: 40));
        final closeDate = wallNow.subtract(const Duration(days: 10));
        final expiration = wallNow.add(const Duration(days: 2));

        final underlying = await repo.getOrCreateUnderlying('CR3');
        final result = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('50'),
            expiration: expiration,
            contracts: 1,
            openedAt: openedAt,
            openCreditPerShare: Decimal.parse('1.00'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );
        await repo.appendSnapshot(
          NewSnapshotInput(
            legId: result.leg.id,
            takenAt: closeDate,
            // Deep ITM put: intrinsic 10, extrinsic 0.03 (<= tailExtrinsic
            // Threshold 0.05). The closing debit of 0.90 puts capturedPct at
            // 10%, so Gate 1 cannot preempt Gate 4.
            optionMark: Decimal.parse('10.03'),
            underlyingPrice: Decimal.parse('40'),
            deltaAsEntered: -0.10,
            deltaConvention: DeltaConvention.position,
          ),
        );

        final container =
            ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
        final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
        await controller.load();

        final ok = await controller.closeDirect(
          reason: CloseReason.closedEarly,
          closeDebitPerShare: Decimal.parse('0.90'),
          closedAt: closeDate,
        );
        expect(ok, isTrue);

        // The persisted close is the backdated one -- `closedAt` keeps its
        // job as the recorded date, unchanged by this fix.
        final closedLeg = (await repo.getLeg(result.leg.id))!;
        expect(closedLeg.closedAt, closeDate);
        expect(closedLeg.closeDebitPerShare, Decimal.parse('0.90'));

        // ...and the classification that follows still uses real now, so the
        // post-close read agrees with what a reopened read shows.
        final postCloseBucket = container.read(positionDetailControllerProvider(result.leg.id)).bucket;
        final reopened = ProviderContainer(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(reopened.dispose);
        reopened.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
        await reopened.read(positionDetailControllerProvider(result.leg.id).notifier).load();
        final reopenedBucket = reopened.read(positionDetailControllerProvider(result.leg.id)).bucket;

        expect(postCloseBucket, isNotNull);
        expect(postCloseBucket, isA<BucketClose>());
        expect(postCloseBucket!.reason, contains('time value left'));
        expect(reopenedBucket, postCloseBucket); // same type AND same reason
      },
    );
  });
}
