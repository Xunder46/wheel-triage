import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../domain/models/entitlement_cache.dart';
import '../../domain/models/entitlement_cache_defaults.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/rule_profile_data.dart';
import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/rule_profile_version_data.dart';
import '../../domain/models/share_lot.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/models/underlying.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/models/user_preferences_defaults.dart';
import '../../domain/models/wheel_cycle.dart';
import '../export/ledger_export.dart';
import '../id_generator.dart';
import '../wheel_repository.dart';
import 'app_database.dart';

/// Drift/SQLite-backed [WheelRepository]. Every write method that touches
/// more than one row runs inside a single `transaction()` block — see
/// `recordRoll`, `closeLeg`, `recordAssignment`, `recordCallAway`.
class DriftWheelRepository implements WheelRepository {
  DriftWheelRepository(this._db);

  final AppDatabase _db;

  // --- Underlying ---------------------------------------------------

  @override
  Future<Underlying> getOrCreateUnderlying(String ticker) async {
    final existing =
        await (_db.select(_db.underlyingTable)..where((t) => t.ticker.equals(ticker)))
            .getSingleOrNull();
    if (existing != null) return _underlyingFromRow(existing);

    final created = Underlying(id: generateId(), ticker: ticker);
    await _db.into(_db.underlyingTable).insert(_underlyingToCompanion(created));
    return created;
  }

  @override
  Future<Underlying?> getUnderlying(String id) async {
    final row =
        await (_db.select(_db.underlyingTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _underlyingFromRow(row);
  }

  // --- RuleProfile ----------------------------------------------------

  @override
  Future<List<RuleProfileData>> getRuleProfiles() async {
    final rows = await _db.select(_db.ruleProfileTable).get();
    return rows.map(_ruleProfileFromRow).toList();
  }

  @override
  Future<RuleProfileData?> getRuleProfile(String id) async {
    final row =
        await (_db.select(_db.ruleProfileTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _ruleProfileFromRow(row);
  }

  @override
  Future<List<RuleProfileVersionData>> getRuleProfileVersions(String profileId) async {
    final rows = await (_db.select(_db.ruleProfileVersionTable)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.asc(t.version)]))
        .get();
    return rows.map(_ruleProfileVersionFromRow).toList();
  }

  @override
  Future<RuleProfileVersionData?> getRuleProfileVersion(String versionId) async {
    final row = await (_db.select(_db.ruleProfileVersionTable)
          ..where((t) => t.id.equals(versionId)))
        .getSingleOrNull();
    return row == null ? null : _ruleProfileVersionFromRow(row);
  }

  @override
  Future<RuleProfileVersionData> appendRuleProfileVersion({
    required String profileId,
    required DateTime effectiveAt,
    required NewRuleProfileVersionInput values,
  }) {
    return _db.transaction(() async {
      final profile = await (_db.select(_db.ruleProfileTable)
            ..where((t) => t.id.equals(profileId)))
          .getSingleOrNull();
      if (profile == null) {
        throw ArgumentError.value(profileId, 'profileId', 'No rule profile with this id exists');
      }

      final existing = await getRuleProfileVersions(profileId);
      final nextVersion = existing.isEmpty ? 1 : existing.last.version + 1;
      final created = RuleProfileVersionData(
        id: RuleProfileVersionIds.forVersion(profileId, nextVersion),
        profileId: profileId,
        version: nextVersion,
        effectiveAt: effectiveAt,
        profitTargetPct: values.profitTargetPct,
        assignThreshold: values.assignThreshold,
        baseRollBand: values.baseRollBand,
        midIvRollBand: values.midIvRollBand,
        highIvRollBand: values.highIvRollBand,
        midIvCutoff: values.midIvCutoff,
        highIvCutoff: values.highIvCutoff,
        tailDteDays: values.tailDteDays,
        tailExtrinsicThreshold: values.tailExtrinsicThreshold,
        minIvRank: values.minIvRank,
        minAnnualisedYield: values.minAnnualisedYield,
        targetDteMin: values.targetDteMin,
        targetDteMax: values.targetDteMax,
        targetDelta: values.targetDelta,
      );
      await _db
          .into(_db.ruleProfileVersionTable)
          .insert(_ruleProfileVersionToCompanion(created));
      return created;
    });
  }

  // --- WheelCycle / Leg lifecycle --------------------------------------

  @override
  Future<({WheelCycle cycle, Leg leg})> createCycle({
    required String underlyingId,
    required NewLegInput firstLeg,
  }) {
    return _db.transaction(() async {
      final cycle = WheelCycle(
        id: generateId(),
        underlyingId: underlyingId,
        startedAt: firstLeg.openedAt,
        status: WheelCycleStatus.sellingPuts,
      );
      await _db.into(_db.wheelCycleTable).insert(_cycleToCompanion(cycle));

      final leg = Leg(
        id: generateId(),
        cycleId: cycle.id,
        sequence: 0,
        optionType: firstLeg.optionType,
        strike: firstLeg.strike,
        expiration: firstLeg.expiration,
        contracts: firstLeg.contracts,
        openedAt: firstLeg.openedAt,
        openCreditPerShare: firstLeg.openCreditPerShare,
        ruleProfileVersionId: firstLeg.ruleProfileVersionId,
        ivAtOpen: firstLeg.ivAtOpen,
        ivRankAtOpen: firstLeg.ivRankAtOpen,
        deltaAtOpen: firstLeg.deltaAtOpen,
        underlyingPriceAtOpen: firstLeg.underlyingPriceAtOpen,
        openFee: firstLeg.openFee,
        acceptsAssignment: firstLeg.acceptsAssignment,
      );
      await _db.into(_db.legTable).insert(_legToCompanion(leg));

      return (cycle: cycle, leg: leg);
    });
  }

  @override
  Future<Leg> openNextLeg({required String cycleId, required NewLegInput leg}) {
    return _db.transaction(() async {
      final existing = await getLegsForCycle(cycleId);
      final nextSequence =
          existing.isEmpty ? 0 : existing.map((l) => l.sequence).reduce((a, b) => a > b ? a : b) + 1;

      final created = Leg(
        id: generateId(),
        cycleId: cycleId,
        sequence: nextSequence,
        optionType: leg.optionType,
        strike: leg.strike,
        expiration: leg.expiration,
        contracts: leg.contracts,
        openedAt: leg.openedAt,
        openCreditPerShare: leg.openCreditPerShare,
        ruleProfileVersionId: leg.ruleProfileVersionId,
        ivAtOpen: leg.ivAtOpen,
        ivRankAtOpen: leg.ivRankAtOpen,
        deltaAtOpen: leg.deltaAtOpen,
        underlyingPriceAtOpen: leg.underlyingPriceAtOpen,
        openFee: leg.openFee,
        acceptsAssignment: leg.acceptsAssignment,
      );
      await _db.into(_db.legTable).insert(_legToCompanion(created));
      return created;
    });
  }

  @override
  Future<List<Leg>> getOpenLegs() async {
    final rows = await (_db.select(_db.legTable)..where((t) => t.closedAtMs.isNull())).get();
    return rows.map(_legFromRow).toList();
  }

  @override
  Future<List<Leg>> getAllLegs() async {
    final rows = await (_db.select(_db.legTable)
          ..orderBy([
            (t) => OrderingTerm.asc(t.openedAtMs),
            (t) => OrderingTerm.asc(t.sequence),
          ]))
        .get();
    return rows.map(_legFromRow).toList();
  }

  @override
  Future<Leg?> getLeg(String id) async {
    final row = await (_db.select(_db.legTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _legFromRow(row);
  }

  @override
  Future<List<Leg>> getLegsForCycle(String cycleId) async {
    final rows = await (_db.select(_db.legTable)
          ..where((t) => t.cycleId.equals(cycleId))
          ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
        .get();
    return rows.map(_legFromRow).toList();
  }

  @override
  Future<WheelCycle?> getCycle(String id) async {
    final row =
        await (_db.select(_db.wheelCycleTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _cycleFromRow(row);
  }

  @override
  Future<List<WheelCycle>> getClosedCycles() async {
    final rows = await (_db.select(_db.wheelCycleTable)
          ..where((t) => t.status.equalsValue(WheelCycleStatus.closed))
          ..orderBy([(t) => OrderingTerm.desc(t.endedAtMs)]))
        .get();
    return rows.map(_cycleFromRow).toList();
  }

  @override
  Future<List<WheelCycle>> getOpenCycles() async {
    final rows = await (_db.select(_db.wheelCycleTable)
          ..where((t) => t.status.equalsValue(WheelCycleStatus.closed).not())
          ..orderBy([(t) => OrderingTerm.asc(t.startedAtMs)]))
        .get();
    return rows.map(_cycleFromRow).toList();
  }

  // --- Snapshot ---------------------------------------------------------

  @override
  Future<Snapshot> appendSnapshot(NewSnapshotInput input) async {
    final snapshot = Snapshot(
      id: generateId(),
      legId: input.legId,
      takenAt: input.takenAt,
      optionMark: input.optionMark,
      underlyingPrice: input.underlyingPrice,
      deltaAsEntered: input.deltaAsEntered,
      deltaConvention: input.deltaConvention,
      gamma: input.gamma,
      theta: input.theta,
      vega: input.vega,
      iv: input.iv,
      openInterest: input.openInterest,
      volume: input.volume,
    );
    await _db.into(_db.snapshotTable).insert(_snapshotToCompanion(snapshot));
    return snapshot;
  }

  @override
  Future<List<Snapshot>> getSnapshotsForLeg(String legId) async {
    final rows = await (_db.select(_db.snapshotTable)
          ..where((t) => t.legId.equals(legId))
          ..orderBy([(t) => OrderingTerm.asc(t.takenAtMs)]))
        .get();
    return rows.map(_snapshotFromRow).toList();
  }

  @override
  Future<Snapshot?> getLatestSnapshotForLeg(String legId) async {
    final row = await (_db.select(_db.snapshotTable)
          ..where((t) => t.legId.equals(legId))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAtMs)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _snapshotFromRow(row);
  }

  // --- Roll / close / assignment (atomic, cycle-transitioning) --------

  @override
  Future<({Leg closedLeg, Leg newLeg})> recordRoll({
    required String closingLegId,
    required Decimal closeDebitPerShare,
    Decimal? closeFee,
    required DateTime closedAt,
    required NewLegInput newLeg,
  }) {
    return _db.transaction(() async {
      final closingLeg = await _requireLeg(closingLegId);

      final updatedClosing = closingLeg.copyWith(
        closedAt: closedAt,
        closeDebitPerShare: closeDebitPerShare,
        closeReason: CloseReason.rolled,
        closeFee: closeFee,
      );
      await (_db.update(_db.legTable)..where((t) => t.id.equals(closingLegId)))
          .write(_legToCompanion(updatedClosing));

      final createdLeg = Leg(
        id: generateId(),
        cycleId: closingLeg.cycleId,
        sequence: closingLeg.sequence + 1,
        optionType: newLeg.optionType,
        strike: newLeg.strike,
        expiration: newLeg.expiration,
        contracts: newLeg.contracts,
        openedAt: newLeg.openedAt,
        openCreditPerShare: newLeg.openCreditPerShare,
        rolledFromLegId: closingLegId,
        ruleProfileVersionId: newLeg.ruleProfileVersionId,
        ivAtOpen: newLeg.ivAtOpen,
        ivRankAtOpen: newLeg.ivRankAtOpen,
        deltaAtOpen: newLeg.deltaAtOpen,
        underlyingPriceAtOpen: newLeg.underlyingPriceAtOpen,
        openFee: newLeg.openFee,
        acceptsAssignment: newLeg.acceptsAssignment,
      );
      await _db.into(_db.legTable).insert(_legToCompanion(createdLeg));

      return (closedLeg: updatedClosing, newLeg: createdLeg);
    });
  }

  @override
  Future<({Leg leg, WheelCycle cycle})> closeLeg({
    required String legId,
    required CloseReason reason,
    Decimal? closeDebitPerShare,
    Decimal? closeFee,
    required DateTime closedAt,
  }) {
    if (reason == CloseReason.rolled || reason == CloseReason.assigned) {
      throw ArgumentError.value(
        reason,
        'reason',
        'closeLeg only accepts closedEarly or expiredWorthless — '
            'use recordRoll/recordAssignment/recordCallAway instead',
      );
    }
    return _db.transaction(() async {
      return _closeLegInTransaction(
        legId: legId,
        reason: reason,
        closeDebitPerShare: closeDebitPerShare,
        closeFee: closeFee,
        closedAt: closedAt,
      );
    });
  }

  /// The shared body of [closeLeg] and [markExpired] — one leg closed plus
  /// the put-leg-ends-its-cycle rule (Feature Invariant 16), so the batch
  /// path cannot drift from the single-leg one. Runs inside whatever
  /// transaction its caller already opened.
  Future<({Leg leg, WheelCycle cycle})> _closeLegInTransaction({
    required String legId,
    required CloseReason reason,
    required Decimal? closeDebitPerShare,
    required Decimal? closeFee,
    required DateTime closedAt,
  }) async {
    final leg = await _requireLeg(legId);

    final updatedLeg = leg.copyWith(
      closedAt: closedAt,
      closeReason: reason,
      closeDebitPerShare: closeDebitPerShare,
      closeFee: closeFee,
    );
    await (_db.update(_db.legTable)..where((t) => t.id.equals(legId)))
        .write(_legToCompanion(updatedLeg));

    var cycle = await _requireCycle(leg.cycleId);

    // Feature Invariant 16: a direct put-side close always ends the
    // cycle; a direct call-side close never does (shares are still
    // held while `holdingShares`).
    if (leg.optionType == OptionType.put) {
      final outcome = reason == CloseReason.closedEarly
          ? WheelCycleOutcome.closedEarly
          : WheelCycleOutcome.expiredWorthless;
      cycle = cycle.copyWith(
        status: WheelCycleStatus.closed,
        outcome: outcome,
        endedAt: closedAt,
      );
      await (_db.update(_db.wheelCycleTable)..where((t) => t.id.equals(cycle.id)))
          .write(_cycleToCompanion(cycle));
    }

    return (leg: updatedLeg, cycle: cycle);
  }

  @override
  Future<List<Leg>> markExpired({required List<({String legId, DateTime closedAt})> legs}) {
    _rejectEmptyExpiryBatch(legs);
    return _db.transaction(() async {
      // Validate every leg before writing any of them: an unknown id or an
      // already-closed leg must leave the database untouched (S-217 b/d).
      // The whole batch is one transaction on top of that, so a failure
      // part-way through still rolls back (S-217 a's atomicity).
      for (final entry in legs) {
        _validateMarkExpiredTarget(await _legOrNull(entry.legId), entry.legId);
      }

      final closed = <Leg>[];
      for (final entry in legs) {
        final result = await _closeLegInTransaction(
          legId: entry.legId,
          reason: CloseReason.expiredWorthless,
          closeDebitPerShare: Decimal.zero,
          closeFee: null,
          closedAt: entry.closedAt,
        );
        closed.add(result.leg);
      }
      return closed;
    });
  }

  @override
  Future<({Leg leg, ShareLot shareLot, WheelCycle cycle})> recordAssignment({
    required String legId,
    Decimal? closeFee,
    required NewShareLotInput shareLot,
  }) {
    return _db.transaction(() async {
      final leg = await _requireLeg(legId);

      final updatedLeg = leg.copyWith(
        closedAt: shareLot.assignedAt,
        closeReason: CloseReason.assigned,
        closeFee: closeFee,
      );
      await (_db.update(_db.legTable)..where((t) => t.id.equals(legId)))
          .write(_legToCompanion(updatedLeg));

      final createdLot = ShareLot(
        id: generateId(),
        cycleId: leg.cycleId,
        assignedAt: shareLot.assignedAt,
        assignmentStrike: shareLot.assignmentStrike,
        contracts: shareLot.contracts,
      );
      await _db.into(_db.shareLotTable).insert(_shareLotToCompanion(createdLot));

      final cycle = (await _requireCycle(leg.cycleId))
          .copyWith(status: WheelCycleStatus.holdingShares);
      await (_db.update(_db.wheelCycleTable)..where((t) => t.id.equals(cycle.id)))
          .write(_cycleToCompanion(cycle));

      return (leg: updatedLeg, shareLot: createdLot, cycle: cycle);
    });
  }

  @override
  Future<({Leg leg, WheelCycle cycle})> recordCallAway({
    required String legId,
    Decimal? closeFee,
    required DateTime closedAt,
  }) {
    return _db.transaction(() async {
      final leg = await _requireLeg(legId);

      final updatedLeg = leg.copyWith(
        closedAt: closedAt,
        closeReason: CloseReason.assigned,
        closeFee: closeFee,
      );
      await (_db.update(_db.legTable)..where((t) => t.id.equals(legId)))
          .write(_legToCompanion(updatedLeg));

      // The ShareLot row is RETAINED (CR-1). The share position ends here,
      // so `getShareLotForCycle` stops returning it (the cycle is no longer
      // `holdingShares`), but the assignment's own recorded
      // strike/contracts are what closed-cycle P&L must use --
      // `getAssignmentForCycle` still returns them. Deleting the row threw
      // that history away and forced callers to reconstruct it from the
      // assigned leg, which need not match what was recorded.

      final cycle = (await _requireCycle(leg.cycleId)).copyWith(
        status: WheelCycleStatus.closed,
        outcome: WheelCycleOutcome.calledAway,
        endedAt: closedAt,
      );
      await (_db.update(_db.wheelCycleTable)..where((t) => t.id.equals(cycle.id)))
          .write(_cycleToCompanion(cycle));

      return (leg: updatedLeg, cycle: cycle);
    });
  }

  // --- Leg metadata (non-lifecycle) -------------------------------------

  @override
  Future<Leg> updateLegMetadata({
    required String legId,
    bool? acceptsAssignment,
    Decimal? openFee,
    Decimal? closeFee,
    bool clearOpenFee = false,
    bool clearCloseFee = false,
  }) async {
    _validateLegMetadataUpdate(
      acceptsAssignment: acceptsAssignment,
      openFee: openFee,
      closeFee: closeFee,
      clearOpenFee: clearOpenFee,
      clearCloseFee: clearCloseFee,
    );

    final leg = await _requireLeg(legId);
    final updated = leg.copyWith(
      acceptsAssignment: acceptsAssignment ?? leg.acceptsAssignment,
      openFee: clearOpenFee ? null : (openFee ?? leg.openFee),
      closeFee: clearCloseFee ? null : (closeFee ?? leg.closeFee),
    );
    await (_db.update(_db.legTable)..where((t) => t.id.equals(legId)))
        .write(_legToCompanion(updated));
    return updated;
  }

  // --- ShareLot ---------------------------------------------------------

  @override
  Future<ShareLot?> getShareLotForCycle(String cycleId) async {
    // "Active" is the cycle's status, not the row's existence: the row is
    // now retained past call-away (CR-1), so a holding-shares cycle is what
    // distinguishes a live lot from retained history. Before retention,
    // row-present and `holdingShares` were the same condition.
    final cycle = await getCycle(cycleId);
    if (cycle == null || cycle.status != WheelCycleStatus.holdingShares) return null;
    return getAssignmentForCycle(cycleId);
  }

  @override
  Future<ShareLot?> getAssignmentForCycle(String cycleId) async {
    final row = await (_db.select(_db.shareLotTable)..where((t) => t.cycleId.equals(cycleId)))
        .getSingleOrNull();
    return row == null ? null : _shareLotFromRow(row);
  }

  // --- UserPreferences (Iteration 3, schema v2) --------------------------

  @override
  Future<UserPreferencesData> getPreferences() async {
    final row = await (_db.select(_db.userPreferencesTable)
          ..where((t) => t.id.equals(UserPreferencesDefaults.rowId)))
        .getSingleOrNull();
    if (row != null) return _userPreferencesFromRow(row);

    // Defensive "resilient read" (same spirit as getOrCreateUnderlying) —
    // unreachable in practice, since onCreate/the 1->2 migration always
    // inserts this row, but never leaves a caller looking at a missing
    // preferences row if it somehow is.
    await _db.seedDefaultPreferences();
    return const UserPreferencesData();
  }

  @override
  Future<UserPreferencesData> updatePreferences(UserPreferencesData prefs) async {
    await (_db.update(_db.userPreferencesTable)
          ..where((t) => t.id.equals(UserPreferencesDefaults.rowId)))
        .write(_userPreferencesToCompanion(prefs));
    return prefs;
  }

  // --- Entitlement cache (Pro Wave 2, schema v6, D-25) --------------------

  @override
  Future<EntitlementCacheData> getEntitlementCache() async {
    final row = await (_db.select(_db.entitlementCacheTable)
          ..where((t) => t.id.equals(EntitlementCacheDefaults.rowId)))
        .getSingleOrNull();
    if (row != null) return _entitlementCacheFromRow(row);

    // Defensive "resilient read" — same spirit as getPreferences above and
    // unreachable in practice, since onCreate/the 5->6 migration always
    // inserts this row. The fixed id is what enforces the single-row contract
    // (D-25/S-256): this read and `saveEntitlementCache` both address the row
    // by `EntitlementCacheDefaults.rowId`, so the read can never resolve more
    // than the one row, and a write can never append a second.
    await _db.seedEntitlementCache();
    return const EntitlementCacheData();
  }

  @override
  Future<EntitlementCacheData> saveEntitlementCache(EntitlementCacheData cache) async {
    await (_db.update(_db.entitlementCacheTable)
          ..where((t) => t.id.equals(EntitlementCacheDefaults.rowId)))
        .write(_entitlementCacheToCompanion(cache));
    return cache;
  }

  // --- Export / import (Phase 19) ----------------------------------------

  @override
  Future<String> exportToJson() async {
    final underlyings = (await _db.select(_db.underlyingTable).get()).map(_underlyingFromRow).toList();
    final cycles = (await _db.select(_db.wheelCycleTable).get()).map(_cycleFromRow).toList();
    final legs = (await _db.select(_db.legTable).get()).map(_legFromRow).toList();
    final snapshots = (await _db.select(_db.snapshotTable).get()).map(_snapshotFromRow).toList();
    final shareLots = (await _db.select(_db.shareLotTable).get()).map(_shareLotFromRow).toList();
    final ruleProfiles = await getRuleProfiles();
    final ruleProfileVersions = (await _db.select(_db.ruleProfileVersionTable).get())
        .map(_ruleProfileVersionFromRow)
        .toList();
    final preferences = await getPreferences();

    return LedgerExport(
      formatVersion: LedgerExport.currentFormatVersion,
      underlyings: underlyings,
      cycles: cycles,
      legs: legs,
      snapshots: snapshots,
      shareLots: shareLots,
      ruleProfiles: ruleProfiles,
      ruleProfileVersions: ruleProfileVersions,
      preferences: preferences,
    ).toJsonString();
  }

  @override
  Future<int> countCyclesForReplace() async => (await _db.select(_db.wheelCycleTable).get()).length;

  @override
  Future<void> restoreFromJson(String json, {DateTime? now}) async {
    // Parsed/validated in full BEFORE the transaction below even opens --
    // a malformed file throws here and nothing is ever wiped (S-152).
    // Format-1 files are converted to the v2 shape inside this call (D-8).
    final export = LedgerExport.fromJsonString(json, now: now);

    await _db.transaction(() async {
      // Wipe every table (replace-all, §5) -- order doesn't matter for
      // correctness (none of these tables declare a SQL foreign key), but
      // children-before-parents keeps the intent readable.
      await _db.delete(_db.snapshotTable).go();
      await _db.delete(_db.shareLotTable).go();
      await _db.delete(_db.legTable).go();
      await _db.delete(_db.wheelCycleTable).go();
      await _db.delete(_db.underlyingTable).go();
      await _db.delete(_db.ruleProfileVersionTable).go();
      await _db.delete(_db.ruleProfileTable).go();
      await _db.delete(_db.userPreferencesTable).go();

      for (final u in export.underlyings) {
        await _db.into(_db.underlyingTable).insert(_underlyingToCompanion(u));
      }
      for (final c in export.cycles) {
        await _db.into(_db.wheelCycleTable).insert(_cycleToCompanion(c));
      }
      for (final l in export.legs) {
        await _db.into(_db.legTable).insert(_legToCompanion(l));
      }
      for (final lot in export.shareLots) {
        await _db.into(_db.shareLotTable).insert(_shareLotToCompanion(lot));
      }
      for (final s in export.snapshots) {
        await _db.into(_db.snapshotTable).insert(_snapshotToCompanion(s));
      }
      for (final rp in export.ruleProfiles) {
        await _db.into(_db.ruleProfileTable).insert(_ruleProfileToCompanion(rp));
      }
      for (final rpv in export.ruleProfileVersions) {
        await _db
            .into(_db.ruleProfileVersionTable)
            .insert(_ruleProfileVersionToCompanion(rpv));
      }
      await _db.into(_db.userPreferencesTable).insert(_userPreferencesToCompanion(export.preferences));
    });
  }

  // --- internal helpers --------------------------------------------------

  Future<Leg> _requireLeg(String legId) async {
    final row =
        await (_db.select(_db.legTable)..where((t) => t.id.equals(legId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError.value(legId, 'legId', 'No leg with this id exists');
    }
    return _legFromRow(row);
  }

  /// [_requireLeg]'s lookup without the throw — `markExpired` validates the
  /// whole batch through the shared `_validateMarkExpiredTarget` instead,
  /// which needs to tell "unknown id" from "already closed".
  Future<Leg?> _legOrNull(String legId) async {
    final row =
        await (_db.select(_db.legTable)..where((t) => t.id.equals(legId))).getSingleOrNull();
    return row == null ? null : _legFromRow(row);
  }

  Future<WheelCycle> _requireCycle(String cycleId) async {
    final row = await (_db.select(_db.wheelCycleTable)..where((t) => t.id.equals(cycleId)))
        .getSingleOrNull();
    if (row == null) {
      throw ArgumentError.value(cycleId, 'cycleId', 'No cycle with this id exists');
    }
    return _cycleFromRow(row);
  }
}

/// Shared validation for [WheelRepository.updateLegMetadata], duplicated
/// verbatim in `InMemoryWheelRepository` (parity is proven by the shared
/// contract test, not by sharing this function across implementations —
/// see docs/conventions.md §6).
void _validateLegMetadataUpdate({
  required bool? acceptsAssignment,
  required Decimal? openFee,
  required Decimal? closeFee,
  required bool clearOpenFee,
  required bool clearCloseFee,
}) {
  if (openFee != null && clearOpenFee) {
    throw ArgumentError(
      'updateLegMetadata: openFee and clearOpenFee are contradictory — '
      'pass a value to set openFee, or clearOpenFee: true to reset it to '
      'null, never both.',
    );
  }
  if (closeFee != null && clearCloseFee) {
    throw ArgumentError(
      'updateLegMetadata: closeFee and clearCloseFee are contradictory — '
      'pass a value to set closeFee, or clearCloseFee: true to reset it to '
      'null, never both.',
    );
  }
  if (acceptsAssignment == null &&
      openFee == null &&
      closeFee == null &&
      !clearOpenFee &&
      !clearCloseFee) {
    throw ArgumentError(
      'updateLegMetadata: no field would change — pass at least one of '
      'acceptsAssignment, openFee, closeFee, clearOpenFee, or clearCloseFee.',
    );
  }
}

/// Shared validation for [WheelRepository.markExpired], duplicated verbatim
/// in `InMemoryWheelRepository` (same rationale as
/// `_validateLegMetadataUpdate` above). Each implementation passes the leg
/// it looked up in its own storage, or `null` when the id is unknown — this
/// function is the only place either the "unknown id" or the "already
/// closed" rule is stated, so the two cannot drift apart.
void _rejectEmptyExpiryBatch(List<({String legId, DateTime closedAt})> legs) {
  if (legs.isEmpty) {
    throw ArgumentError.value(
      legs,
      'legs',
      'markExpired requires at least one leg — an empty batch is never a '
          'silent no-op.',
    );
  }
}

void _validateMarkExpiredTarget(Leg? leg, String legId) {
  if (leg == null) {
    throw ArgumentError.value(legId, 'legId', 'No leg with this id exists');
  }
  if (leg.closedAt != null) {
    throw ArgumentError.value(
      legId,
      'legId',
      'This leg is already closed — markExpired never re-closes a leg.',
    );
  }
}

// --- Row <-> domain model mapping --------------------------------------
//
// Storage-specific concerns end here; nothing above this line in the file
// (and nothing at all in `lib/data/wheel_repository.dart`) is Drift-aware.

Underlying _underlyingFromRow(UnderlyingRow row) => Underlying(
      id: row.id,
      ticker: row.ticker,
      displayName: row.displayName,
      notes: row.notes,
    );

UnderlyingTableCompanion _underlyingToCompanion(Underlying u) => UnderlyingTableCompanion(
      id: Value(u.id),
      ticker: Value(u.ticker),
      displayName: Value(u.displayName),
      notes: Value(u.notes),
    );

WheelCycle _cycleFromRow(WheelCycleRow row) => WheelCycle(
      id: row.id,
      underlyingId: row.underlyingId,
      startedAt: row.startedAtMs,
      endedAt: row.endedAtMs,
      status: row.status,
      outcome: row.outcome,
    );

WheelCycleTableCompanion _cycleToCompanion(WheelCycle c) => WheelCycleTableCompanion(
      id: Value(c.id),
      underlyingId: Value(c.underlyingId),
      startedAtMs: Value(c.startedAt),
      endedAtMs: Value(c.endedAt),
      status: Value(c.status),
      outcome: Value(c.outcome),
    );

Leg _legFromRow(LegRow row) => Leg(
      id: row.id,
      cycleId: row.cycleId,
      sequence: row.sequence,
      optionType: row.optionType,
      strike: row.strike,
      expiration: row.expirationMs,
      contracts: row.contracts,
      openedAt: row.openedAtMs,
      openCreditPerShare: row.openCreditPerShare,
      closedAt: row.closedAtMs,
      closeDebitPerShare: row.closeDebitPerShare,
      closeReason: row.closeReason,
      rolledFromLegId: row.rolledFromLegId,
      ruleProfileVersionId: row.ruleProfileVersionId,
      ivAtOpen: row.ivAtOpen,
      ivRankAtOpen: row.ivRankAtOpen,
      deltaAtOpen: row.deltaAtOpen,
      underlyingPriceAtOpen: row.underlyingPriceAtOpen,
      openFee: row.openFee,
      closeFee: row.closeFee,
      acceptsAssignment: row.acceptsAssignment,
    );

LegTableCompanion _legToCompanion(Leg leg) => LegTableCompanion(
      id: Value(leg.id),
      cycleId: Value(leg.cycleId),
      sequence: Value(leg.sequence),
      optionType: Value(leg.optionType),
      strike: Value(leg.strike),
      expirationMs: Value(leg.expiration),
      contracts: Value(leg.contracts),
      openedAtMs: Value(leg.openedAt),
      openCreditPerShare: Value(leg.openCreditPerShare),
      closedAtMs: Value(leg.closedAt),
      closeDebitPerShare: Value(leg.closeDebitPerShare),
      closeReason: Value(leg.closeReason),
      rolledFromLegId: Value(leg.rolledFromLegId),
      ruleProfileVersionId: Value(leg.ruleProfileVersionId),
      ivAtOpen: Value(leg.ivAtOpen),
      ivRankAtOpen: Value(leg.ivRankAtOpen),
      deltaAtOpen: Value(leg.deltaAtOpen),
      underlyingPriceAtOpen: Value(leg.underlyingPriceAtOpen),
      openFee: Value(leg.openFee),
      closeFee: Value(leg.closeFee),
      acceptsAssignment: Value(leg.acceptsAssignment),
    );

Snapshot _snapshotFromRow(SnapshotRow row) => Snapshot(
      id: row.id,
      legId: row.legId,
      takenAt: row.takenAtMs,
      optionMark: row.optionMark,
      underlyingPrice: row.underlyingPrice,
      deltaAsEntered: row.deltaAsEntered,
      deltaConvention: row.deltaConvention,
      gamma: row.gamma,
      theta: row.theta,
      vega: row.vega,
      iv: row.iv,
      openInterest: row.openInterest,
      volume: row.volume,
    );

SnapshotTableCompanion _snapshotToCompanion(Snapshot s) => SnapshotTableCompanion(
      id: Value(s.id),
      legId: Value(s.legId),
      takenAtMs: Value(s.takenAt),
      optionMark: Value(s.optionMark),
      underlyingPrice: Value(s.underlyingPrice),
      deltaAsEntered: Value(s.deltaAsEntered),
      deltaConvention: Value(s.deltaConvention),
      gamma: Value(s.gamma),
      theta: Value(s.theta),
      vega: Value(s.vega),
      iv: Value(s.iv),
      openInterest: Value(s.openInterest),
      volume: Value(s.volume),
    );

ShareLot _shareLotFromRow(ShareLotRow row) => ShareLot(
      id: row.id,
      cycleId: row.cycleId,
      assignedAt: row.assignedAtMs,
      assignmentStrike: row.assignmentStrike,
      contracts: row.contracts,
    );

ShareLotTableCompanion _shareLotToCompanion(ShareLot lot) => ShareLotTableCompanion(
      id: Value(lot.id),
      cycleId: Value(lot.cycleId),
      assignedAtMs: Value(lot.assignedAt),
      assignmentStrike: Value(lot.assignmentStrike),
      contracts: Value(lot.contracts),
    );

RuleProfileData _ruleProfileFromRow(RuleProfileRow row) => RuleProfileData(
      id: row.id,
      name: row.name,
    );

RuleProfileVersionData _ruleProfileVersionFromRow(RuleProfileVersionRow row) =>
    RuleProfileVersionData(
      id: row.id,
      profileId: row.profileId,
      version: row.version,
      effectiveAt: row.effectiveAtMs,
      profitTargetPct: row.profitTargetPct,
      assignThreshold: row.assignThreshold,
      baseRollBand: row.baseRollBand,
      midIvRollBand: row.midIvRollBand,
      highIvRollBand: row.highIvRollBand,
      midIvCutoff: row.midIvCutoff,
      highIvCutoff: row.highIvCutoff,
      tailDteDays: row.tailDteDays,
      tailExtrinsicThreshold: row.tailExtrinsicThreshold,
      minIvRank: row.minIvRank,
      minAnnualisedYield: row.minAnnualisedYield,
      targetDteMin: row.targetDteMin,
      targetDteMax: row.targetDteMax,
      targetDelta: row.targetDelta,
    );

/// Only needed by [DriftWheelRepository.restoreFromJson] -- every other
/// write path to `rule_profile` is `AppDatabase.seedRuleProfiles()`, which
/// builds its own `.insert()` companion directly.
RuleProfileTableCompanion _ruleProfileToCompanion(RuleProfileData p) => RuleProfileTableCompanion(
      id: Value(p.id),
      name: Value(p.name),
    );

/// Only needed by [DriftWheelRepository.restoreFromJson] -- the live write
/// path is `appendRuleProfileVersion`, which builds its own `.insert()`
/// companion directly.
RuleProfileVersionTableCompanion _ruleProfileVersionToCompanion(RuleProfileVersionData v) =>
    RuleProfileVersionTableCompanion(
      id: Value(v.id),
      profileId: Value(v.profileId),
      version: Value(v.version),
      effectiveAtMs: Value(v.effectiveAt),
      profitTargetPct: Value(v.profitTargetPct),
      assignThreshold: Value(v.assignThreshold),
      baseRollBand: Value(v.baseRollBand),
      midIvRollBand: Value(v.midIvRollBand),
      highIvRollBand: Value(v.highIvRollBand),
      midIvCutoff: Value(v.midIvCutoff),
      highIvCutoff: Value(v.highIvCutoff),
      tailDteDays: Value(v.tailDteDays),
      tailExtrinsicThreshold: Value(v.tailExtrinsicThreshold),
      minIvRank: Value(v.minIvRank),
      minAnnualisedYield: Value(v.minAnnualisedYield),
      targetDteMin: Value(v.targetDteMin),
      targetDteMax: Value(v.targetDteMax),
      targetDelta: Value(v.targetDelta),
    );

UserPreferencesData _userPreferencesFromRow(UserPreferencesRow row) => UserPreferencesData(
      totalPerContractToggle: row.totalPerContractToggle,
      deltaConventionDefault: row.deltaConventionDefault,
      firstRunExplainerShown: row.firstRunExplainerShown,
      ivResolutionNoticeDismissed: row.ivResolutionNoticeDismissed,
      exportReminderDismissed: row.exportReminderDismissed,
      lastExportAt: row.lastExportAtMs,
      notificationMilestones: row.notificationMilestones,
      wheelCapital: row.wheelCapitalCents,
      concentrationLimitPct: row.concentrationLimitPct,
    );

UserPreferencesTableCompanion _userPreferencesToCompanion(UserPreferencesData p) =>
    UserPreferencesTableCompanion(
      id: const Value(UserPreferencesDefaults.rowId),
      totalPerContractToggle: Value(p.totalPerContractToggle),
      deltaConventionDefault: Value(p.deltaConventionDefault),
      firstRunExplainerShown: Value(p.firstRunExplainerShown),
      ivResolutionNoticeDismissed: Value(p.ivResolutionNoticeDismissed),
      exportReminderDismissed: Value(p.exportReminderDismissed),
      lastExportAtMs: Value(p.lastExportAt),
      notificationMilestones: Value(p.notificationMilestones),
      wheelCapitalCents: Value(p.wheelCapital),
      concentrationLimitPct: Value(p.concentrationLimitPct),
    );

EntitlementCacheData _entitlementCacheFromRow(EntitlementCacheRow row) => EntitlementCacheData(
      isActive: row.isActive,
      planKind: row.planKind,
      expiresAt: row.expiresAtMs,
      willRenew: row.willRenew,
      billingIssue: row.billingIssue,
      purchasedAt: row.purchasedAtMs,
      checkedAt: row.checkedAtMs,
    );

EntitlementCacheTableCompanion _entitlementCacheToCompanion(EntitlementCacheData c) =>
    EntitlementCacheTableCompanion(
      id: const Value(EntitlementCacheDefaults.rowId),
      isActive: Value(c.isActive),
      planKind: Value(c.planKind),
      expiresAtMs: Value(c.expiresAt),
      willRenew: Value(c.willRenew),
      billingIssue: Value(c.billingIssue),
      purchasedAtMs: Value(c.purchasedAt),
      checkedAtMs: Value(c.checkedAt),
    );
