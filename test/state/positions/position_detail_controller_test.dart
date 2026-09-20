import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/domain/rules/iv_resolution.dart';
import 'package:wheel_triage/state/positions/position_detail_controller.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/rule_profile_fixtures.dart';

void main() {
  group('S-022: update snapshot -- append-only, re-triage', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;
    late String legId;
    final openedAt = DateTime(2025, 12, 12); // "opened 20 days ago" relative to `today` below
    final today = DateTime(2026, 1, 1);

    setUp(() async {
      repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('ZZZ');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: today.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: openedAt,
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      legId = result.leg.id;

      container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      container.listen(positionDetailControllerProvider(legId), (previous, next) {});
      await container.read(positionDetailControllerProvider(legId).notifier).load(now: today);
    });

    tearDown(() => container.dispose());

    test(
      'zero snapshots yet -> unknown, "No snapshot yet" (brief-followup A4 -- '
      'not leave, see S-042)',
      () {
        final state = container.read(positionDetailControllerProvider(legId));
        expect(state.bucket, isA<BucketUnknown>());
        expect((state.bucket as BucketUnknown).reason, 'No snapshot yet');
        expect(state.snapshots, isEmpty);
      },
    );

    test(
      'submitting a snapshot appends exactly one row, stores deltaConvention, and '
      're-triages to close at exactly 50% captured',
      () async {
        final controller = container.read(positionDetailControllerProvider(legId).notifier);

        final ok = await controller.updateSnapshot(
          optionMark: Decimal.parse('0.30'),
          underlyingPrice: Decimal.parse('46'),
          deltaAsEntered: -0.25,
          deltaConvention: DeltaConvention.position,
          iv: 40,
          takenAt: today,
        );
        expect(ok, isTrue);

        final snapshots = await repo.getSnapshotsForLeg(legId);
        expect(snapshots, hasLength(1));
        expect(snapshots.single.deltaConvention, DeltaConvention.position);
        expect(snapshots.single.deltaAsEntered, -0.25);

        final state = container.read(positionDetailControllerProvider(legId));
        expect(state.capturedPct, Decimal.parse('50.0'));
        expect(state.bucket, isA<BucketClose>());
        expect((state.bucket as BucketClose).reason, '50% of credit captured');

        // Prior zero-snapshot history is preserved (append-only) -- nothing
        // overwritten, just one more row than before.
        expect(state.snapshots, hasLength(1));
      },
    );
  });

  group('S-043-S-046: IV resolution feeds Gate 3, not just the label', () {
    test(
      'S-046 wired end-to-end: snapshot IV null, leg.ivAtOpen=83 -> resolved band 0.40, '
      'delta 0.35 falls through to leave (not roll, which the pre-fix snapshot?.iv path '
      'would have produced)',
      () async {
        final repo = InMemoryWheelRepository();
        final today = DateTime(2026, 1, 1);
        final underlying = await repo.getOrCreateUnderlying('IVX');
        final result = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.call,
            strike: Decimal.parse('11'),
            expiration: today.add(const Duration(days: 30)),
            contracts: 1,
            openedAt: today,
            openCreditPerShare: Decimal.parse('1.00'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
            ivAtOpen: 83.0,
          ),
        );
        await repo.appendSnapshot(
          NewSnapshotInput(
            legId: result.leg.id,
            takenAt: today,
            optionMark: Decimal.parse('0.80'), // capturedPct 20%, below 50% target
            underlyingPrice: Decimal.parse('10'),
            deltaAsEntered: -0.35,
            deltaConvention: DeltaConvention.position,
            iv: null, // snapshot's own IV is blank
          ),
        );

        final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
        await container.read(positionDetailControllerProvider(result.leg.id).notifier).load(now: today);

        final state = container.read(positionDetailControllerProvider(result.leg.id));
        expect(state.resolvedIv?.source, IvSource.legIvAtOpen);
        expect(state.rollBand, 0.40);
        expect(state.rollBandLabelText, '0.40 — from IV at open (83%)');
        // The pre-fix path (feeding snapshot?.iv == null directly) would
        // have produced band 0.30 and therefore Bucket.roll (0.35 >= 0.30).
        // The wired fix produces Bucket.leave instead (0.35 < 0.40).
        expect(state.bucket, isA<BucketLeave>());
      },
    );
  });

  group('S-050/S-051: no-arbitrage bound wired into the snapshot-sheet option mark', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;
    late String legId;
    final today = DateTime(2026, 1, 1);

    setUp(() async {
      repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('BND');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('40'),
          expiration: today.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: today,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      legId = result.leg.id;

      container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      container.listen(positionDetailControllerProvider(legId), (previous, next) {});
      await container.read(positionDetailControllerProvider(legId).notifier).load(now: today);
    });

    tearDown(() => container.dispose());

    test('S-050 row 2: mark \$41 > strike \$40 (put) -- hard-rejects, no row persisted', () async {
      final controller = container.read(positionDetailControllerProvider(legId).notifier);
      final ok = await controller.updateSnapshot(
        optionMark: Decimal.parse('41'),
        underlyingPrice: Decimal.parse('39'),
        deltaAsEntered: -0.30,
        deltaConvention: DeltaConvention.position,
        takenAt: today,
      );
      expect(ok, isFalse);

      final state = container.read(positionDetailControllerProvider(legId));
      expect(state.snapshotError, contains("can't exceed the strike price"));
      expect(await repo.getSnapshotsForLeg(legId), isEmpty);
    });

    test('S-051 row 2: mark \$22 (between 0.5x and 1x strike) -- soft-warns, still persists', () async {
      final controller = container.read(positionDetailControllerProvider(legId).notifier);
      final ok = await controller.updateSnapshot(
        optionMark: Decimal.parse('22'),
        underlyingPrice: Decimal.parse('39'),
        deltaAsEntered: -0.30,
        deltaConvention: DeltaConvention.position,
        takenAt: today,
      );
      expect(ok, isTrue);

      final state = container.read(positionDetailControllerProvider(legId));
      expect(state.snapshotWarning, isNotNull);
      expect(state.snapshotError, isNull);
      expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
    });
  });

  group('S-052: "total per contract" applies to the snapshot option-mark field too', () {
    test('toggle on -> typing 31 persists optionMark 0.31', () async {
      final repo = InMemoryWheelRepository();
      final today = DateTime(2026, 1, 1);
      final underlying = await repo.getOrCreateUnderlying('TPC');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: today.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: today,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
      await container.read(positionDetailControllerProvider(result.leg.id).notifier).load(now: today);

      final prefsController = container.read(preferencesControllerProvider.notifier);
      await prefsController.ready;
      await prefsController.update((p) => p.copyWith(totalPerContractToggle: true));

      final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
      final ok = await controller.updateSnapshot(
        optionMark: Decimal.parse('31'),
        underlyingPrice: Decimal.parse('44'),
        deltaAsEntered: -0.20,
        deltaConvention: DeltaConvention.position,
        takenAt: today,
      );
      expect(ok, isTrue);

      final snapshots = await repo.getSnapshotsForLeg(result.leg.id);
      expect(snapshots.single.optionMark, Decimal.parse('0.31'));
    });
  });

  test(
    'S-126: an open holdingShares cycle computes a live cyclePnl, with no fee gap from its '
    'still-open leg\'s own null closeFee (Feature Invariant 28)',
    () async {
      final repo = InMemoryWheelRepository();
      final today = DateTime(2026, 1, 1);
      final underlying = await repo.getOrCreateUnderlying('HOLD');
      final putResult = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: today,
          contracts: 1,
          openedAt: today.subtract(const Duration(days: 30)),
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: putResult.leg.id,
        closeFee: Decimal.zero, // the put itself is fee-complete -- isolates the open call leg's case
        shareLot: NewShareLotInput(assignedAt: today, assignmentStrike: Decimal.parse('50'), contracts: 1),
      );
      // The covered call is still open -- its own null closeFee is expected,
      // never a gap on its own (Feature Invariant 28) -- but it DOES have a
      // recorded openFee.
      final callLeg = await repo.openNextLeg(
        cycleId: putResult.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('52'),
          expiration: today.add(const Duration(days: 20)),
          contracts: 1,
          openedAt: today,
          openCreditPerShare: Decimal.parse('0.50'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          openFee: Decimal.parse('1.30'),
        ),
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionDetailControllerProvider(callLeg.id), (previous, next) {});
      await container.read(positionDetailControllerProvider(callLeg.id).notifier).load(now: today);

      final state = container.read(positionDetailControllerProvider(callLeg.id));
      expect(state.cyclePnl, isNotNull);
      expect(state.cyclePnl!.hasFeeGap, isFalse); // the open call leg's null closeFee is not a gap
      expect(state.shareLot, isNotNull);
    },
  );

  test('S-120: direct Close/Mark-expired -- closeFee persists on the closed leg', () async {
    final repo = InMemoryWheelRepository();
    final today = DateTime(2026, 1, 1);
    final underlying = await repo.getOrCreateUnderlying('DIRECT');
    final result = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('45'),
        expiration: today.add(const Duration(days: 30)),
        contracts: 1,
        openedAt: today,
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
    await container.read(positionDetailControllerProvider(result.leg.id).notifier).load(now: today);

    final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
    await controller.closeDirect(
      reason: CloseReason.closedEarly,
      closeDebitPerShare: Decimal.parse('0.20'),
      closeFee: Decimal.parse('1.30'),
      closedAt: today,
    );

    final closedLeg = (await repo.getLeg(result.leg.id))!;
    expect(closedLeg.closeFee, Decimal.parse('1.30'));
  });

  test(
    'S-124: acceptsAssignment editable from the position detail sheet, re-triages '
    'without a new snapshot',
    () async {
      final repo = InMemoryWheelRepository();
      final today = DateTime(2026, 1, 1);
      final underlying = await repo.getOrCreateUnderlying('FLIP');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: today.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: today,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.appendSnapshot(
        NewSnapshotInput(
          legId: result.leg.id,
          takenAt: today,
          optionMark: Decimal.parse('0.80'), // capturedPct 20%, below target
          underlyingPrice: Decimal.parse('44'),
          deltaAsEntered: -0.85, // >= assignThreshold 0.70
          deltaConvention: DeltaConvention.position,
        ),
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
      await container.read(positionDetailControllerProvider(result.leg.id).notifier).load(now: today);

      expect(
        container.read(positionDetailControllerProvider(result.leg.id)).bucket,
        isA<BucketAssign>(),
      );

      final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
      final ok = await controller.setAcceptsAssignment(false);
      expect(ok, isTrue);

      final updatedLeg = (await repo.getLeg(result.leg.id))!;
      expect(updatedLeg.acceptsAssignment, isFalse); // persisted

      final state = container.read(positionDetailControllerProvider(result.leg.id));
      expect(state.bucket, isA<BucketRoll>());
      expect((state.bucket as BucketRoll).reason, "Delta 0.85 at or above 0.70, and assignment isn't wanted here");
    },
  );

  test(
    'S-124 edge case: setting acceptsAssignment to its current value is a no-op, '
    'never forwarded as a contradictory call',
    () async {
      final repo = InMemoryWheelRepository();
      final today = DateTime(2026, 1, 1);
      final underlying = await repo.getOrCreateUnderlying('NOOP');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: today.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: today,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
      await container.read(positionDetailControllerProvider(result.leg.id).notifier).load(now: today);

      final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
      final ok = await controller.setAcceptsAssignment(true); // already true by default
      expect(ok, isTrue);
      expect(container.read(positionDetailControllerProvider(result.leg.id)).actionError, isNull);
    },
  );

  test('S-122: edit-fees affordance fills the gap -- fills both fee fields, cycle recomputes', () async {
    final repo = InMemoryWheelRepository();
    final today = DateTime(2026, 1, 1);
    final underlying = await repo.getOrCreateUnderlying('GAP');
    final result = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('45'),
        expiration: today.add(const Duration(days: 30)),
        contracts: 1,
        openedAt: today,
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    await repo.closeLeg(
      legId: result.leg.id,
      reason: CloseReason.expiredWorthless,
      closeDebitPerShare: Decimal.zero,
      closedAt: today,
      // closeFee left null -- the gap.
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
    await container.read(positionDetailControllerProvider(result.leg.id).notifier).load(now: today);

    expect(container.read(positionDetailControllerProvider(result.leg.id)).cyclePnl!.hasFeeGap, isTrue);

    final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
    final ok = await controller.updateLegFees(legId: result.leg.id, closeFee: Decimal.parse('0.65'));
    expect(ok, isTrue);

    final updatedLeg = (await repo.getLeg(result.leg.id))!;
    expect(updatedLeg.closeFee, Decimal.parse('0.65'));

    final state = container.read(positionDetailControllerProvider(result.leg.id));
    expect(state.cyclePnl!.hasFeeGap, isFalse); // recomputed, gap closed
  });

  test(
    'S-103: fees excluded from capturedPct and every gate -- a leg with a recorded fee '
    'classifies identically to one without',
    () async {
      final today = DateTime(2026, 1, 1);

      Future<String> setUpLeg(InMemoryWheelRepository repo, {Decimal? openFee, Decimal? closeFee}) async {
        final underlying = await repo.getOrCreateUnderlying('FEE');
        final result = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45'),
            expiration: today.add(const Duration(days: 30)),
            contracts: 1,
            openedAt: today,
            openCreditPerShare: Decimal.parse('1.00'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
            openFee: openFee,
          ),
        );
        await repo.appendSnapshot(
          NewSnapshotInput(
            legId: result.leg.id,
            takenAt: today,
            optionMark: Decimal.parse('0.45'), // capturedPct 55% -> Gate 1 fires
            underlyingPrice: Decimal.parse('46'),
            deltaAsEntered: -0.10,
            deltaConvention: DeltaConvention.position,
          ),
        );
        return result.leg.id;
      }

      final repoA = InMemoryWheelRepository(); // no fee recorded
      final legIdA = await setUpLeg(repoA);
      final containerA = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repoA)]);
      addTearDown(containerA.dispose);
      containerA.listen(positionDetailControllerProvider(legIdA), (previous, next) {});
      await containerA.read(positionDetailControllerProvider(legIdA).notifier).load(now: today);

      final repoB = InMemoryWheelRepository(); // a $10 fee recorded
      final legIdB = await setUpLeg(repoB, openFee: Decimal.fromInt(1000));
      final containerB = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repoB)]);
      addTearDown(containerB.dispose);
      containerB.listen(positionDetailControllerProvider(legIdB), (previous, next) {});
      await containerB.read(positionDetailControllerProvider(legIdB).notifier).load(now: today);

      final stateA = containerA.read(positionDetailControllerProvider(legIdA));
      final stateB = containerB.read(positionDetailControllerProvider(legIdB));

      expect(stateA.capturedPct, stateB.capturedPct); // fee never nets into currentMark
      expect(stateA.bucket, isA<BucketClose>());
      expect(stateB.bucket, isA<BucketClose>());
      expect((stateA.bucket as BucketClose).reason, (stateB.bucket as BucketClose).reason);
    },
  );

  group('S-140: classification-date fix -- post-save read matches the reopened read, both '
      'against real now', () {
    test(
      'pre-fix would diverge on a dte-driven Gate 4 flip between takenAt (10d ago) and real now',
      () async {
        final repo = InMemoryWheelRepository();
        final wallNow = DateTime.now();
        final openedAt = wallNow.subtract(const Duration(days: 40)); // fixture: "opened 40 days ago"
        final takenAt = wallNow.subtract(const Duration(days: 10)); // fixture: "backdated to 10 days ago"
        // dte-as-of-real-now ~= 2 (<= tailDteDays 3); dte-as-of-takenAt ~= 12
        // (past the tail window) -- the two reference times disagree on
        // whether Gate 4 fires, which is what exposes the defect.
        final expiration = wallNow.add(const Duration(days: 2));

        final underlying = await repo.getOrCreateUnderlying('BACKD');
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

        final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        container.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
        final controller = container.read(positionDetailControllerProvider(result.leg.id).notifier);
        await controller.load();

        final ok = await controller.updateSnapshot(
          // Deep ITM put: intrinsic 10, extrinsic 0.03 (<= tailExtrinsicThreshold
          // 0.05) -- and openCredit 1.00 vs. mark 10.03 keeps capturedPct deep
          // negative, so Gate 1 never preempts Gate 4.
          optionMark: Decimal.parse('10.03'),
          underlyingPrice: Decimal.parse('40'),
          deltaAsEntered: -0.10, // below assignThreshold and the roll band -- Gates 2/3 don't fire
          deltaConvention: DeltaConvention.position,
          takenAt: takenAt,
        );
        expect(ok, isTrue);

        final postSaveBucket = container.read(positionDetailControllerProvider(result.leg.id)).bucket;

        // Reopen: a fresh load() with no new snapshot (S-140's second trigger).
        await controller.load();
        final reopenedBucket = container.read(positionDetailControllerProvider(result.leg.id)).bucket;

        expect(postSaveBucket, isNotNull);
        expect(postSaveBucket, reopenedBucket); // same bucket type AND same reason
        expect(postSaveBucket, isA<BucketClose>());
        expect(postSaveBucket!.reason, contains('time value left'));
      },
    );
  });

  group('S-142: backdated snapshot entry -- range-validated against [leg.openedAt, leg.expiration]', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;
    late String legId;
    late DateTime openedAt;
    late DateTime expiration;

    setUp(() async {
      repo = InMemoryWheelRepository();
      openedAt = DateTime(2026, 1, 1);
      expiration = DateTime(2026, 1, 31);
      final underlying = await repo.getOrCreateUnderlying('BACK');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: expiration,
          contracts: 1,
          openedAt: openedAt,
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      legId = result.leg.id;

      container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionDetailControllerProvider(legId), (previous, next) {});
      await container.read(positionDetailControllerProvider(legId).notifier).load(now: openedAt);
    });

    test('trigger A: takenAt before openedAt is rejected, submit blocked, range named', () async {
      final controller = container.read(positionDetailControllerProvider(legId).notifier);
      final ok = await controller.updateSnapshot(
        optionMark: Decimal.parse('0.50'),
        underlyingPrice: Decimal.parse('46'),
        deltaAsEntered: -0.20,
        deltaConvention: DeltaConvention.position,
        takenAt: openedAt.subtract(const Duration(days: 1)),
      );
      expect(ok, isFalse);

      final state = container.read(positionDetailControllerProvider(legId));
      expect(state.snapshotError, isNotNull);
      expect(state.snapshotError, contains('2026-01-01'));
      expect(state.snapshotError, contains('2026-01-31'));
      expect(await repo.getSnapshotsForLeg(legId), isEmpty);
    });

    test('trigger B: takenAt after expiration is rejected, submit blocked, range named', () async {
      final controller = container.read(positionDetailControllerProvider(legId).notifier);
      final ok = await controller.updateSnapshot(
        optionMark: Decimal.parse('0.50'),
        underlyingPrice: Decimal.parse('46'),
        deltaAsEntered: -0.20,
        deltaConvention: DeltaConvention.position,
        takenAt: expiration.add(const Duration(days: 1)),
      );
      expect(ok, isFalse);

      final state = container.read(positionDetailControllerProvider(legId));
      expect(state.snapshotError, isNotNull);
      expect(state.snapshotError, contains('2026-01-01'));
      expect(state.snapshotError, contains('2026-01-31'));
      expect(await repo.getSnapshotsForLeg(legId), isEmpty);
    });

    test('trigger C: takenAt inside [openedAt, expiration] persists normally', () async {
      final controller = container.read(positionDetailControllerProvider(legId).notifier);
      final ok = await controller.updateSnapshot(
        optionMark: Decimal.parse('0.50'),
        underlyingPrice: Decimal.parse('46'),
        deltaAsEntered: -0.20,
        deltaConvention: DeltaConvention.position,
        takenAt: openedAt.add(const Duration(days: 5)),
      );
      expect(ok, isTrue);
      expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
    });

    test(
      'C, continued: leaving the date field untouched defaults takenAt to now, and a leg whose '
      'range straddles real now (the ordinary case) accepts the default',
      () async {
        final liveRepo = InMemoryWheelRepository();
        final wallNow = DateTime.now();
        final underlying = await liveRepo.getOrCreateUnderlying('LIVE');
        final result = await liveRepo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45'),
            expiration: wallNow.add(const Duration(days: 30)),
            contracts: 1,
            openedAt: wallNow.subtract(const Duration(days: 1)),
            openCreditPerShare: Decimal.parse('0.60'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );

        final liveContainer = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(liveRepo)]);
        addTearDown(liveContainer.dispose);
        liveContainer.listen(positionDetailControllerProvider(result.leg.id), (previous, next) {});
        final controller = liveContainer.read(positionDetailControllerProvider(result.leg.id).notifier);
        await controller.load();
        // No `takenAt` passed at all -- must default to `DateTime.now()`.
        final ok = await controller.updateSnapshot(
          optionMark: Decimal.parse('0.50'),
          underlyingPrice: Decimal.parse('46'),
          deltaAsEntered: -0.20,
          deltaConvention: DeltaConvention.position,
        );
        expect(ok, isTrue);
        expect(await liveRepo.getSnapshotsForLeg(result.leg.id), hasLength(1));
      },
    );
  });

  group('S-196: the audit pin on position detail', () {
    test('leg A still classifies under its pinned v1 after v2 exists', () async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('PIN');
      final now = DateTime(2026, 1, 1);

      Future<Leg> openLeg(String versionId) async {
        final result = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('50'),
            expiration: now.add(const Duration(days: 30)),
            contracts: 1,
            openedAt: now,
            openCreditPerShare: Decimal.parse('1.00'),
            ruleProfileVersionId: versionId,
          ),
        );
        await repo.appendSnapshot(
          NewSnapshotInput(
            legId: result.leg.id,
            takenAt: now,
            optionMark: Decimal.parse('0.45'),
            underlyingPrice: Decimal.parse('50'),
            deltaAsEntered: -0.20,
            deltaConvention: DeltaConvention.position,
          ),
        );
        return result.leg;
      }

      // Leg A opens under v1; the edit lands after; leg B opens under v2.
      final legA = await openLeg(RuleProfileVersionIds.standardV1);
      final v2 = await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: now,
        values: standardVersionInput(profitTargetPct: 60.0),
      );
      final legB = await openLeg(v2.id);

      final container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      Future<PositionDetailState> stateFor(Leg leg) async {
        container.listen(positionDetailControllerProvider(leg.id), (previous, next) {});
        await container
            .read(positionDetailControllerProvider(leg.id).notifier)
            .load(now: now);
        return container.read(positionDetailControllerProvider(leg.id));
      }

      // Identical snapshots, different pins: 55% captured clears v1's 50%
      // target and misses v2's 60%, so the bucket difference *is* the pin.
      final stateA = await stateFor(legA);
      expect(stateA.profile.versionId, RuleProfileVersionIds.standardV1);
      expect(stateA.bucket, isA<BucketClose>());

      final stateB = await stateFor(legB);
      expect(stateB.profile.versionId, v2.id);
      expect(stateB.bucket, isA<BucketLeave>());
    });
  });
}
