import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/journal/journal_controller.dart';
import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/state/entitlements/pro_feature_gate.dart';
import 'package:wheel_triage/state/notifications/notification_providers.dart';
import 'package:wheel_triage/state/portfolio/portfolio_controller.dart';
import 'package:wheel_triage/state/positions/position_detail_controller.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/record/record_save_service.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/rule_profiles/rule_profile_providers.dart';
import 'package:wheel_triage/state/today/today_controller.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/fake_purchase_gateway.dart';
import '../../support/rule_profile_fixtures.dart';

final _now = DateTime(2026, 3, 2, 10);

/// The ids S-267's flow reaches back into. Deliberately *not* the whole
/// fixture — everything observed is looked up from the repository again, so
/// the two runs are compared through the same interface a screen uses.
class _Fixture {
  const _Fixture({
    required this.putLegId,
    required this.pastExpirationLegId,
    required this.holdingCycleId,
    required this.callLegId,
    required this.closedCycleId,
  });

  final String putLegId;
  final String pastExpirationLegId;
  final String holdingCycleId;
  final String callLegId;
  final String closedCycleId;
}

/// S-267's fixture: three open cycles — one `sellingPuts` with two
/// snapshots, one `holdingShares` with a share lot and an open call, one
/// past expiration — plus one closed cycle.
Future<_Fixture> _seed(InMemoryWheelRepository repo) async {
  Future<({WheelCycle cycle, Leg leg})> openPut(
    String ticker, {
    required DateTime expiration,
    Decimal? strike,
  }) async {
    final underlying = await repo.getOrCreateUnderlying(ticker);
    return repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: strike ?? Decimal.parse('30'),
        expiration: expiration,
        contracts: 1,
        openedAt: _now.subtract(const Duration(days: 40)),
        openCreditPerShare: Decimal.parse('1.20'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
  }

  // (a) sellingPuts, two snapshots.
  final put = await openPut('AAA', expiration: _now.add(const Duration(days: 20)));
  for (final (days, mark, delta) in [(20, '1.40', 0.28), (5, '1.05', 0.31)]) {
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: put.leg.id,
        takenAt: _now.subtract(Duration(days: days)),
        optionMark: Decimal.parse(mark),
        underlyingPrice: Decimal.parse('29'),
        deltaAsEntered: delta,
        deltaConvention: DeltaConvention.position,
        iv: 42,
      ),
    );
  }

  // (b) holdingShares with a share lot and an open call on it.
  final assigned = await openPut(
    'BBB',
    expiration: _now.add(const Duration(days: 30)),
    strike: Decimal.parse('25'),
  );
  final holding = await repo.recordAssignment(
    legId: assigned.leg.id,
    shareLot: NewShareLotInput(
      assignedAt: _now.subtract(const Duration(days: 10)),
      assignmentStrike: Decimal.parse('25'),
      contracts: 1,
    ),
  );
  final call = await repo.openNextLeg(
    cycleId: holding.cycle.id,
    leg: NewLegInput(
      optionType: OptionType.call,
      strike: Decimal.parse('27'),
      expiration: _now.add(const Duration(days: 25)),
      contracts: 1,
      openedAt: _now.subtract(const Duration(days: 8)),
      openCreditPerShare: Decimal.parse('0.45'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );

  // (c) a leg whose expiration has passed and is still open.
  final expired = await openPut(
    'CCC',
    expiration: _now.subtract(const Duration(days: 3)),
    strike: Decimal.parse('35'),
  );

  // (d) one closed cycle, so the journal has a row.
  final closed = await openPut('DDD', expiration: _now.subtract(const Duration(days: 12)));
  await repo.closeLeg(
    legId: closed.leg.id,
    reason: CloseReason.expiredWorthless,
    closeDebitPerShare: Decimal.zero,
    closedAt: _now.subtract(const Duration(days: 12)),
  );

  return _Fixture(
    putLegId: put.leg.id,
    pastExpirationLegId: expired.leg.id,
    holdingCycleId: holding.cycle.id,
    callLegId: call.id,
    closedCycleId: closed.cycle.id,
  );
}

final _uuid = RegExp(
  r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
);

/// The three seeded rule-profile versions carry `DateTime.now()` as their
/// `effectiveAt`, so the export's copy of it differs between two runs for
/// reasons that have nothing to do with the entitlement. Normalised with the
/// ids, for the same reason.
final _seededEffectiveAt = RegExp(r'"effectiveAt":"[^"]*"');

/// Replaces the run's generated ids with placeholders in order of first
/// appearance. Ids are random per run and are not part of what "identical
/// across entitlement states" means, but their creation order is the same
/// every time, so the placeholders are comparable where the raw ids are not.
List<String> _deIdentified(List<String> lines) {
  final seen = <String, String>{};
  return [
    for (final line in lines)
      line
          .replaceAllMapped(
            _uuid,
            (m) => seen.putIfAbsent(m.group(0)!, () => 'id#${seen.length + 1}'),
          )
          .replaceAll(_seededEffectiveAt, '"effectiveAt":"seeded"'),
  ];
}

/// One run of S-267's flow, as the labelled lines a comparison can diff.
class _Run {
  _Run({required this.shared, required this.newCycleLine});

  final List<String> shared;

  /// The outcome of the *one* action S-267 says may differ — a new put cycle
  /// attempted while the book is at the free limit. Kept out of [shared] so
  /// the rest is compared strictly.
  final String newCycleLine;
}

/// Runs S-267's flow under [entitlement] against a fresh book.
Future<_Run> _exercise(
  EntitlementSnapshot entitlement, {
  bool attemptNewCycle = false,
}) async {
  final repo = InMemoryWheelRepository();
  final store = FakePurchaseGateway()..snapshot = entitlement;
  final container = ProviderContainer(
    overrides: [
      wheelRepositoryProvider.overrideWithValue(repo),
      purchaseGatewayProvider.overrideWithValue(store),
      notificationGatewayProvider.overrideWithValue(FakeNotificationGateway()),
    ],
  );
  container.listen(entitlementControllerProvider, (previous, next) {});
  container.listen(preferencesControllerProvider, (previous, next) {});
  container.listen(todayControllerProvider, (previous, next) {});
  try {
    await container.read(entitlementControllerProvider.notifier).initialize();
    final fixture = await _seed(repo);
    final lines = <String>[];

    Future<void> observeToday(String label) async {
      await container.read(todayControllerProvider.notifier).load(now: _now);
      final state = container.read(todayControllerProvider);
      lines.add('$label today: loading=${state.isLoading} error=${state.error}');
      for (final item in state.items) {
        lines.add(
          '$label today item: ${item.underlying.ticker} '
          '${item.bucket.runtimeType} reason=${item.bucket.reason} '
          'dte=${item.dte} needsReading=${item.needsReading} '
          'aging=${item.olderThanAging} batchEligible=${item.batchEligible} '
          'snapshot=${item.latestSnapshot?.optionMark}',
        );
      }
      lines.add(
        '$label today past expiration: '
        '${state.pastExpiration.map((i) => i.underlying.ticker).toList()}',
      );
      lines.add(
        '$label today expiring: '
        '${state.expiringThisWeek.map((g) => '${g.date.toIso8601String()}x${g.legs.length}').toList()}',
      );
      lines.add(
        '$label today aging: count=${state.agingCount} line=${state.agingLine}',
      );
      lines.add(
        '$label today ledger: month=${state.netPremiumMonth} '
        'ytd=${state.netPremiumYearToDate} committed=${state.committedNow} '
        'label=${state.ledgerMonthLabel} capital=${state.wheelCapital} '
        'flags=${state.concentrationFlags.length}',
      );
    }

    Future<void> observeDetail(String label, String legId) async {
      final provider = positionDetailControllerProvider(legId);
      container.listen(provider, (previous, next) {});
      await container.read(provider.notifier).load(now: _now);
      final state = container.read(provider);
      lines.add(
        '$label detail $legId: loading=${state.isLoading} error=${state.error} '
        'bucket=${state.bucket.runtimeType} reason=${state.bucket?.reason} '
        'captured=${state.capturedPct} delta=${state.deltaMagnitude} '
        'band=${state.rollBand} iv=${state.resolvedIv?.value} '
        'cumulative=${state.cycleCumulativeCredit} extrinsic=${state.extrinsic} '
        'oneSigma=${state.oneSigmaMove} cushion=${state.cushionSigmas} '
        'cycleLegs=${state.cycleLegs.length} snapshots=${state.snapshots.length} '
        'shareLot=${state.shareLot != null} pnl=${state.cyclePnl != null} '
        'profile=${state.profile.versionId}',
      );
    }

    Future<void> observeJournal(String label) async {
      await container.read(journalControllerProvider.notifier).load(now: _now);
      final state = container.read(journalControllerProvider);
      lines.add('$label journal: loading=${state.isLoading} error=${state.error}');
      for (final row in state.rows) {
        lines.add(
          '$label journal row: ${row.ticker} legs=${row.legs.length} '
          'premium=${row.pnl.totalPremium} fees=${row.pnl.totalFees} '
          'net=${row.pnl.netResult} rolls=${row.pnl.rollCount} '
          'daysHeld=${row.pnl.daysHeld} stock=${row.pnl.stockPnL} '
          'roc=${row.pnl.returnOnCapitalPct} peak=${row.pnl.peakCapitalCommitted}',
        );
      }
      final a = state.aggregates;
      lines.add(
        '$label journal aggregates: winRate=${a.winRate} '
        'averageDays=${a.averageDaysInCycle} median=${a.medianPremiumCapturePct} '
        'premium=${a.totalPremiumCollected} fees=${a.totalFeesPaid} '
        'byUnderlying=${a.netResultByUnderlying} rolls=${a.rollCountDistribution}',
      );
    }

    // --- view Today, and both detail sheets -----------------------------
    await observeToday('1.');
    await observeDetail('1.', fixture.putLegId);
    await observeDetail('1.', fixture.callLegId);

    // --- read a snapshot, append a snapshot -----------------------------
    lines.add(
      '2. snapshots: ${(await repo.getSnapshotsForLeg(fixture.putLegId)).map((s) => '${s.takenAt.toIso8601String()}/${s.optionMark}').toList()}',
    );
    final detail = container.read(positionDetailControllerProvider(fixture.putLegId).notifier);
    final appended = await detail.updateSnapshot(
      optionMark: Decimal.parse('0.85'),
      underlyingPrice: Decimal.parse('28'),
      deltaAsEntered: 0.36,
      deltaConvention: DeltaConvention.position,
      iv: 48,
      takenAt: _now.subtract(const Duration(days: 2)),
    );
    final afterAppend = container.read(positionDetailControllerProvider(fixture.putLegId));
    lines.add(
      '2. append: ok=$appended error=${afterAppend.snapshotError} '
      'warning=${afterAppend.snapshotWarning} '
      'snapshots=${(await repo.getSnapshotsForLeg(fixture.putLegId)).length}',
    );
    await observeToday('2.');
    await observeDetail('2.', fixture.putLegId);

    // --- roll ------------------------------------------------------------
    final rolled = await repo.recordRoll(
      closingLegId: fixture.putLegId,
      closeDebitPerShare: Decimal.parse('0.40'),
      closedAt: _now,
      newLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('28'),
        expiration: _now.add(const Duration(days: 35)),
        contracts: 1,
        openedAt: _now,
        openCreditPerShare: Decimal.parse('1.10'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    lines.add(
      '3. roll: closed=${rolled.closedLeg.closeReason} '
      'newSequence=${rolled.newLeg.sequence} '
      'rolledFrom=${rolled.newLeg.rolledFromLegId == fixture.putLegId} '
      'cycleStatus=${(await repo.getCycle(rolled.newLeg.cycleId))!.status}',
    );

    // --- close (a call leg, so the cycle it sits on stays open) ---------
    final closedCall = await repo.closeLeg(
      legId: fixture.callLegId,
      reason: CloseReason.closedEarly,
      closeDebitPerShare: Decimal.parse('0.20'),
      closedAt: _now,
    );
    lines.add(
      '4. close: reason=${closedCall.leg.closeReason} '
      'cycleStatus=${closedCall.cycle.status}',
    );

    // --- assign, then called away ---------------------------------------
    final assigned = await repo.recordAssignment(
      legId: fixture.pastExpirationLegId,
      shareLot: NewShareLotInput(
        assignedAt: _now,
        assignmentStrike: Decimal.parse('35'),
        contracts: 1,
      ),
    );
    lines.add(
      '5. assign: status=${assigned.cycle.status} '
      'shareLot=${(await repo.getShareLotForCycle(assigned.cycle.id)) != null}',
    );
    final newCall = await repo.openNextLeg(
      cycleId: assigned.cycle.id,
      leg: NewLegInput(
        optionType: OptionType.call,
        strike: Decimal.parse('36'),
        expiration: _now.add(const Duration(days: 30)),
        contracts: 1,
        openedAt: _now,
        openCreditPerShare: Decimal.parse('0.40'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    final calledAway = await repo.recordCallAway(legId: newCall.id, closedAt: _now);
    lines.add(
      '6. calledAway: leg=${calledAway.leg.closeReason} '
      'status=${calledAway.cycle.status} outcome=${calledAway.cycle.outcome} '
      'retained=${(await repo.getAssignmentForCycle(calledAway.cycle.id)) != null} '
      'live=${(await repo.getShareLotForCycle(calledAway.cycle.id)) != null}',
    );

    // --- the journal, export, restore -----------------------------------
    await observeJournal('7.');
    final exported = await repo.exportToJson();
    lines.add('8. export: $exported');
    await repo.restoreFromJson(exported, now: _now);
    lines.add('8. restore: cycles=${await repo.countCyclesForReplace()}');
    await observeToday('8.');
    await observeJournal('8.');

    // --- edit the rule profile, and re-read everything it feeds ---------
    final version = await repo.appendRuleProfileVersion(
      profileId: RuleProfileIds.standard,
      effectiveAt: _now,
      values: standardVersionInput(profitTargetPct: 60.0),
    );
    container.invalidate(currentRuleProfileProvider);
    lines.add(
      '9. profile: versions=${(await repo.getRuleProfileVersions(RuleProfileIds.standard)).length} '
      'current=${version.id}',
    );
    await observeToday('9.');
    await observeDetail('9.', rolled.newLeg.id);

    var newCycleLine = 'not attempted';
    if (attemptNewCycle) {
      // The flow above legitimately closes a cycle (CCC is called away at
      // step 6), so the book is topped back up to the limit first: this
      // assertion is about the limit, not about a particular cycle count. The
      // top-up is a raw repository write, so it is identical in all three
      // entitlement states and cannot itself differ.
      final topUp = await repo.getOrCreateUnderlying('EEE');
      await repo.createCycle(
        underlyingId: topUp.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('20'),
          expiration: _now.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      expect(await repo.getOpenCycles(), hasLength(kFreeTierOpenCycles));

      final result = await container.read(recordSaveServiceProvider).save(
        ticker: 'ZZZ',
        side: OptionType.put,
        strike: Decimal.parse('12'),
        expiration: _now.add(const Duration(days: 30)),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.50'),
        now: _now,
      );
      newCycleLine = result.isPaywallRequired
          ? 'refused: ${result.trigger}'
          : 'created: ${result.outcome} cycles=${(await repo.getOpenCycles()).length}';
    }

    return _Run(shared: _deIdentified(lines), newCycleLine: newCycleLine);
  } finally {
    container.dispose();
  }
}

const _active = EntitlementSnapshot.active(
  planKind: ProPlanKind.annual,
  willRenew: true,
);

void main() {
  group('S-267: every existing action works in every entitlement state', () {
    test('the whole flow is identical under active, inactive and unknown', () async {
      final active = await _exercise(_active);
      final inactive = await _exercise(const EntitlementSnapshot.inactive());
      final unknown = await _exercise(const EntitlementSnapshot.unknown());

      // A strict, ordered comparison: the diff names the first line that
      // moved, so "nothing is hidden, mutated or disabled" is one assertion
      // per state rather than a hand-picked subset.
      expect(inactive.shared, active.shared);
      expect(unknown.shared, active.shared);
      expect(active.shared, isNotEmpty);
    });

    test('the only difference is a new put cycle at the limit', () async {
      final active = await _exercise(_active, attemptNewCycle: true);
      final inactive = await _exercise(
        const EntitlementSnapshot.inactive(),
        attemptNewCycle: true,
      );
      final unknown = await _exercise(
        const EntitlementSnapshot.unknown(),
        attemptNewCycle: true,
      );

      expect(active.newCycleLine, 'created: RecordSaveOutcome.created cycles=4');
      // The book ends at three open cycles: the fixture's own three.
      expect(
        inactive.newCycleLine,
        'refused: You have 3 open cycles, the free plan\'s limit, so recording '
        'a fourth needs Pro. Everything you\'ve already recorded stays '
        'available on every plan.',
      );
      expect(unknown.newCycleLine, inactive.newCycleLine);
    });
  });

  group('S-268: a lapse from Pro with five open cycles loses nothing', () {
    /// Five cycles created while Pro was active, one per distinct ticker.
    Future<List<Leg>> fiveCycles(InMemoryWheelRepository repo) async {
      final legs = <Leg>[];
      for (var i = 0; i < 5; i++) {
        final underlying = await repo.getOrCreateUnderlying('T$i');
        final result = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('${20 + i}'),
            expiration: _now.add(Duration(days: 20 + i)),
            contracts: 1,
            openedAt: _now.subtract(const Duration(days: 10)),
            openCreditPerShare: Decimal.parse('1.00'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );
        legs.add(result.leg);
      }
      return legs;
    }

    test('all five stay listed and actionable, the export is byte-identical, '
        'and the sixth is refused with the past-the-limit line', () async {
      final repo = InMemoryWheelRepository();
      final store = FakePurchaseGateway()..snapshot = _active;
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          purchaseGatewayProvider.overrideWithValue(store),
          notificationGatewayProvider.overrideWithValue(FakeNotificationGateway()),
        ],
      );
      container.listen(entitlementControllerProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});
      container.listen(todayControllerProvider, (previous, next) {});
      addTearDown(container.dispose);

      await container.read(entitlementControllerProvider.notifier).initialize();
      final legs = await fiveCycles(repo);

      Future<List<String>> observe() async {
        await container.read(todayControllerProvider.notifier).load(now: _now);
        final today = container.read(todayControllerProvider);
        await container.read(journalControllerProvider.notifier).load(now: _now);
        return [
          'items=${today.items.map((i) => '${i.underlying.ticker}/${i.bucket.runtimeType}/${i.dte}').toList()}',
          'past=${today.pastExpiration.length} aging=${today.agingCount}',
          'committed=${today.committedNow} capital=${today.wheelCapital}',
          'journalRows=${container.read(journalControllerProvider).rows.length}',
          'cycles=${(await repo.getOpenCycles()).length}',
        ];
      }

      final before = await observe();
      final exportBefore = await repo.exportToJson();
      expect(before.first, contains('T0/'));

      // The entitlement lapses: the store now answers "no entitlement".
      store.snapshot = const EntitlementSnapshot.inactive();
      await container.read(entitlementControllerProvider.notifier).refresh();

      expect(await observe(), before);
      expect(await repo.exportToJson(), exportBefore);

      // The sixth is refused while all five are still open — the refusal is
      // about the count, so it is asserted before the actions below change it.
      final sixth = await container.read(recordSaveServiceProvider).save(
        ticker: 'ZZZ',
        side: OptionType.put,
        strike: Decimal.parse('12'),
        expiration: _now.add(const Duration(days: 30)),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.50'),
        now: _now,
      );
      expect(sixth.isPaywallRequired, isTrue);
      expect(
        sixth.trigger,
        'You have 5 open cycles, past the free plan\'s limit of 3, so recording '
        'another needs Pro. Everything you\'ve already recorded stays available '
        'on every plan.',
      );
      expect(await repo.getOpenCycles(), hasLength(5));

      // Every action on the five still succeeds.
      final detail = container.read(positionDetailControllerProvider(legs.first.id).notifier);
      container.listen(positionDetailControllerProvider(legs.first.id), (previous, next) {});
      await detail.load(now: _now);
      expect(
        await detail.updateSnapshot(
          optionMark: Decimal.parse('0.90'),
          underlyingPrice: Decimal.parse('20'),
          deltaAsEntered: 0.30,
          deltaConvention: DeltaConvention.position,
          takenAt: _now,
        ),
        isTrue,
      );
      expect(
        await detail.closeDirect(
          reason: CloseReason.closedEarly,
          closeDebitPerShare: Decimal.parse('0.10'),
          closedAt: _now,
        ),
        isTrue,
      );
      final rolled = await repo.recordRoll(
        closingLegId: legs[1].id,
        closeDebitPerShare: Decimal.parse('0.50'),
        closedAt: _now,
        newLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('20'),
          expiration: _now.add(const Duration(days: 40)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      expect(rolled.newLeg.rolledFromLegId, legs[1].id);
      final assigned = await repo.recordAssignment(
        legId: legs[2].id,
        shareLot: NewShareLotInput(
          assignedAt: _now,
          assignmentStrike: Decimal.parse('22'),
          contracts: 1,
        ),
      );
      expect(assigned.cycle.status, WheelCycleStatus.holdingShares);
      final call = await repo.openNextLeg(
        cycleId: assigned.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('23'),
          expiration: _now.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('0.40'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final calledAway = await repo.recordCallAway(legId: call.id, closedAt: _now);
      expect(calledAway.cycle.outcome, WheelCycleOutcome.calledAway);
      expect(
        await repo.closeLeg(
          legId: legs[3].id,
          reason: CloseReason.expiredWorthless,
          closeDebitPerShare: Decimal.zero,
          closedAt: _now,
        ),
        isNotNull,
      );

      // Two of the five are still open (legs[1]'s rolled cycle and legs[4]'s),
      // which is what the closed, called-away and rolled-away legs leave.
      expect(await repo.getOpenCycles(), hasLength(2));
    });

    test('the sixth cycle is refused with the past-the-limit line while all '
        'five are untouched', () async {
      final repo = InMemoryWheelRepository();
      final store = FakePurchaseGateway()..snapshot = _active;
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          purchaseGatewayProvider.overrideWithValue(store),
          notificationGatewayProvider.overrideWithValue(FakeNotificationGateway()),
        ],
      );
      container.listen(entitlementControllerProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});
      addTearDown(container.dispose);

      await container.read(entitlementControllerProvider.notifier).initialize();
      await fiveCycles(repo);
      final exportBefore = await repo.exportToJson();

      store.snapshot = const EntitlementSnapshot.inactive();
      await container.read(entitlementControllerProvider.notifier).refresh();

      final result = await container.read(recordSaveServiceProvider).save(
        ticker: 'ZZZ',
        side: OptionType.put,
        strike: Decimal.parse('12'),
        expiration: _now.add(const Duration(days: 30)),
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.50'),
        now: _now,
      );

      expect(result.isPaywallRequired, isTrue);
      expect(
        result.trigger,
        'You have 5 open cycles, past the free plan\'s limit of 3, so recording '
        'another needs Pro. Everything you\'ve already recorded stays available '
        'on every plan.',
      );
      expect(await repo.getOpenCycles(), hasLength(5));
      expect(await repo.exportToJson(), exportBefore);
    });
  });

  group('S-292: a lapse from Pro leaves the book and Portfolio intact', () {
    /// The `nothing_locks_test.dart` book, with wheel capital and the limit
    /// set so Portfolio has percentages and a flag line to render.
    Future<InMemoryWheelRepository> seeded() async {
      final repo = InMemoryWheelRepository();
      await _seed(repo);
      await repo.updatePreferences(
        (await repo.getPreferences()).copyWith(
          wheelCapital: Decimal.parse('30000'),
          concentrationLimitPct: 25,
        ),
      );
      return repo;
    }

    /// Every read S-292 names, as comparable lines. Deliberately the *whole*
    /// read rather than one field: a lapse that quietly dropped a row would
    /// still pass a spot check.
    Future<List<String>> fullRead(
      ProviderContainer container,
      InMemoryWheelRepository repo,
    ) async {
      final legs = await repo.getAllLegs();
      final closed = await repo.getClosedCycles();
      final snapshots = <String>[];
      for (final leg in legs) {
        snapshots.add('${leg.id}:${(await repo.getSnapshotsForLeg(leg.id)).length}');
      }
      await container.read(todayControllerProvider.notifier).load(now: _now);
      final today = container.read(todayControllerProvider);
      await container.read(portfolioControllerProvider.notifier).load(now: _now);
      final portfolio = container.read(portfolioControllerProvider);
      return [
        'legs=${legs.map((l) => '${l.id}/${l.optionType}/${l.strike}/${l.closeReason}').toList()}',
        'closed=${closed.map((c) => '${c.id}/${c.status}/${c.outcome}').toList()}',
        'snapshots=$snapshots',
        'today committed=${today.committedNow} capital=${today.wheelCapital} '
            'flags=${today.concentrationFlags.length}',
        'portfolio committed=${portfolio.committedNow} '
            'percent=${portfolio.percentOfWheelCapital} '
            'flags=${portfolio.flagLines} key=${portfolio.keyLine} '
            'bars=${portfolio.bars.map((b) => '${b.ticker}:${b.percent}').toList()}',
      ];
    }

    test('(a) the full read is identical across the lapse, and Today is '
        'unchanged; (b) Portfolio comes back with the same figures', () async {
      final repo = await seeded();
      final store = FakePurchaseGateway()..snapshot = _active;
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          purchaseGatewayProvider.overrideWithValue(store),
          notificationGatewayProvider.overrideWithValue(FakeNotificationGateway()),
        ],
      );
      container.listen(entitlementControllerProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});
      container.listen(todayControllerProvider, (previous, next) {});
      container.listen(portfolioControllerProvider, (previous, next) {});
      addTearDown(container.dispose);

      await container.read(entitlementControllerProvider.notifier).initialize();
      expect(container.read(entitlementControllerProvider).isActive, isTrue);

      final before = await fullRead(container, repo);
      expect(before.first, contains('legs=['));

      // (a) The entitlement lapses. Portfolio is no longer reachable without
      // the paywall -- the gate is the only thing that changed.
      store.snapshot = const EntitlementSnapshot.inactive();
      await container.read(entitlementControllerProvider.notifier).refresh();
      expect(container.read(entitlementControllerProvider).isActive, isFalse);
      expect(
        container.read(proFeatureGateProvider).evaluate(kPortfolioFeatureName),
        isA<ProFeatureLocked>(),
      );

      // The book itself is untouched: the same full read, line for line.
      expect(await fullRead(container, repo), before);

      // (b) It comes back with no reinstall, no reload call and no
      // navigation -- only the store's answer changed.
      store.snapshot = _active;
      await container.read(entitlementControllerProvider.notifier).refresh();
      expect(container.read(entitlementControllerProvider).isActive, isTrue);
      expect(
        container.read(proFeatureGateProvider).evaluate(kPortfolioFeatureName),
        isA<ProFeatureOpen>(),
      );
      expect(await fullRead(container, repo), before);
    });

    test('(c) changing wheel capital in Settings invalidates Portfolio, so '
        'the next build reflects it with no manual refresh', () async {
      final repo = await seeded();
      final store = FakePurchaseGateway()..snapshot = _active;
      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          purchaseGatewayProvider.overrideWithValue(store),
          notificationGatewayProvider.overrideWithValue(FakeNotificationGateway()),
        ],
      );
      container.listen(entitlementControllerProvider, (previous, next) {});
      container.listen(preferencesControllerProvider, (previous, next) {});
      container.listen(portfolioControllerProvider, (previous, next) {});
      addTearDown(container.dispose);

      await container.read(entitlementControllerProvider.notifier).initialize();
      // The controller reads preferences through the repository, so the
      // fixture's own write is what the first load sees.
      await container.read(portfolioControllerProvider.notifier).load(now: _now);
      final atThirty = container.read(portfolioControllerProvider);
      expect(atThirty.percentOfWheelCapital, isNotNull);
      expect(atThirty.keyLine, isNotNull);

      // The Settings save path: write the preference, then invalidate.
      await container
          .read(preferencesControllerProvider.notifier)
          .setWheelCapital(Decimal.parse('40000'));
      container.invalidate(portfolioControllerProvider);
      await container.read(portfolioControllerProvider.notifier).load(now: _now);
      final atForty = container.read(portfolioControllerProvider);

      expect(atForty.committedNow, atThirty.committedNow);
      expect(atForty.percentOfWheelCapital, lessThan(atThirty.percentOfWheelCapital!));
      expect(atForty.bars, isNot(atThirty.bars));
    });
  });
}
