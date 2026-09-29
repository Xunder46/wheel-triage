import 'package:decimal/decimal.dart';

import '../domain/models/leg.dart';
import '../domain/models/rule_profile_data.dart';
import '../domain/models/rule_profile_defaults.dart';
import '../domain/models/rule_profile_ids.dart';
import '../domain/models/rule_profile_version_data.dart';
import '../domain/models/share_lot.dart';
import '../domain/models/snapshot.dart';
import '../domain/models/underlying.dart';
import '../domain/models/user_preferences.dart';
import '../domain/models/user_preferences_defaults.dart';
import '../domain/models/wheel_cycle.dart';
import 'export/ledger_export.dart';
import 'id_generator.dart';
import 'wheel_repository.dart';

T? _firstOrNull<T>(Iterable<T> iterable) {
  for (final e in iterable) {
    return e;
  }
  return null;
}

/// Pure-Dart, in-memory [WheelRepository] test double. No Drift, no
/// platform/driver dependency of any kind — it runs anywhere `flutter test`
/// runs. Every write method here reproduces the exact same cycle-ending
/// rules (Feature Invariants 14, 16) as `DriftWheelRepository`; see
/// `test/data/wheel_repository_contract_test.dart` for the shared suite
/// that proves the two stay in lockstep.
class InMemoryWheelRepository implements WheelRepository {
  InMemoryWheelRepository({bool seedRuleProfiles = true}) {
    if (seedRuleProfiles) {
      final seededAt = DateTime.now();
      for (final (id, name) in [
        (RuleProfileIds.conservative, 'Conservative'),
        (RuleProfileIds.standard, 'Standard'),
        (RuleProfileIds.aggressive, 'Aggressive'),
      ]) {
        _ruleProfiles[id] = RuleProfileData(id: id, name: name);
        final version = _standardVersion(profileId: id, effectiveAt: seededAt);
        _ruleProfileVersions[version.id] = version;
      }
    }
  }

  final Map<String, Underlying> _underlyings = {};
  final Map<String, WheelCycle> _cycles = {};
  final Map<String, Leg> _legs = {};
  final Map<String, Snapshot> _snapshots = {};
  final Map<String, ShareLot> _shareLots = {};
  final Map<String, RuleProfileData> _ruleProfiles = {};
  final Map<String, RuleProfileVersionData> _ruleProfileVersions = {};

  // Matches AppDatabase.seedDefaultPreferences()'s defaults exactly — both
  // read the same lib/domain/models/user_preferences_defaults.dart
  // constants (S-035 parity).
  UserPreferencesData _preferences = const UserPreferencesData(
    totalPerContractToggle: UserPreferencesDefaults.totalPerContractToggle,
    deltaConventionDefault: UserPreferencesDefaults.deltaConventionDefault,
    firstRunExplainerShown: UserPreferencesDefaults.firstRunExplainerShown,
    ivResolutionNoticeDismissed: UserPreferencesDefaults.ivResolutionNoticeDismissed,
    exportReminderDismissed: UserPreferencesDefaults.exportReminderDismissed,
    lastExportAt: UserPreferencesDefaults.lastExportAt,
    notificationMilestones: UserPreferencesDefaults.notificationMilestones,
    wheelCapital: UserPreferencesDefaults.wheelCapital,
    concentrationLimitPct: UserPreferencesDefaults.concentrationLimitPct,
  );

  /// The seeded v1 threshold version for a built-in profile — the same
  /// values `AppDatabase.seedRuleProfiles()` inserts, read from the same
  /// `StandardProfileDefaults` constants, so fresh installs observe
  /// identical data in both implementations (docs/conventions.md §6
  /// parity). Id format shared via `RuleProfileVersionIds.forVersion`.
  RuleProfileVersionData _standardVersion({
    required String profileId,
    required DateTime effectiveAt,
  }) => RuleProfileVersionData(
        id: RuleProfileVersionIds.forVersion(profileId, 1),
        profileId: profileId,
        version: 1,
        effectiveAt: effectiveAt,
        profitTargetPct: StandardProfileDefaults.profitTargetPct,
        assignThreshold: StandardProfileDefaults.assignThreshold,
        baseRollBand: StandardProfileDefaults.baseRollBand,
        midIvRollBand: StandardProfileDefaults.midIvRollBand,
        highIvRollBand: StandardProfileDefaults.highIvRollBand,
        midIvCutoff: StandardProfileDefaults.midIvCutoff,
        highIvCutoff: StandardProfileDefaults.highIvCutoff,
        tailDteDays: StandardProfileDefaults.tailDteDays,
        tailExtrinsicThreshold: StandardProfileDefaults.tailExtrinsicThreshold,
        minIvRank: StandardProfileDefaults.minIvRank,
        minAnnualisedYield: StandardProfileDefaults.minAnnualisedYield,
        targetDteMin: StandardProfileDefaults.targetDteMin,
        targetDteMax: StandardProfileDefaults.targetDteMax,
        targetDelta: StandardProfileDefaults.targetDelta,
      );

  // --- Underlying ---------------------------------------------------

  @override
  Future<Underlying> getOrCreateUnderlying(String ticker) async {
    final existing = _firstOrNull(_underlyings.values.where((u) => u.ticker == ticker));
    if (existing != null) return existing;
    final created = Underlying(id: generateId(), ticker: ticker);
    _underlyings[created.id] = created;
    return created;
  }

  @override
  Future<Underlying?> getUnderlying(String id) async => _underlyings[id];

  // --- RuleProfile ----------------------------------------------------

  @override
  Future<List<RuleProfileData>> getRuleProfiles() async => _ruleProfiles.values.toList();

  @override
  Future<RuleProfileData?> getRuleProfile(String id) async => _ruleProfiles[id];

  @override
  Future<List<RuleProfileVersionData>> getRuleProfileVersions(String profileId) async {
    final versions = _ruleProfileVersions.values.where((v) => v.profileId == profileId).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    return versions;
  }

  @override
  Future<RuleProfileVersionData?> getRuleProfileVersion(String versionId) async =>
      _ruleProfileVersions[versionId];

  @override
  Future<RuleProfileVersionData> appendRuleProfileVersion({
    required String profileId,
    required DateTime effectiveAt,
    required NewRuleProfileVersionInput values,
  }) async {
    if (!_ruleProfiles.containsKey(profileId)) {
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
    _ruleProfileVersions[created.id] = created;
    return created;
  }

  // --- WheelCycle / Leg lifecycle --------------------------------------

  @override
  Future<({WheelCycle cycle, Leg leg})> createCycle({
    required String underlyingId,
    required NewLegInput firstLeg,
  }) async {
    final cycle = WheelCycle(
      id: generateId(),
      underlyingId: underlyingId,
      startedAt: firstLeg.openedAt,
      status: WheelCycleStatus.sellingPuts,
    );
    _cycles[cycle.id] = cycle;

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
    _legs[leg.id] = leg;

    return (cycle: cycle, leg: leg);
  }

  @override
  Future<Leg> openNextLeg({required String cycleId, required NewLegInput leg}) async {
    final existing = _legs.values.where((l) => l.cycleId == cycleId);
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
    _legs[created.id] = created;
    return created;
  }

  @override
  Future<List<Leg>> getOpenLegs() async =>
      _legs.values.where((l) => l.closedAt == null).toList();

  @override
  Future<List<Leg>> getAllLegs() async {
    final legs = _legs.values.toList()
      ..sort((a, b) {
        final byOpenedAt = a.openedAt.compareTo(b.openedAt);
        return byOpenedAt != 0 ? byOpenedAt : a.sequence.compareTo(b.sequence);
      });
    return legs;
  }

  @override
  Future<Leg?> getLeg(String id) async => _legs[id];

  @override
  Future<List<Leg>> getLegsForCycle(String cycleId) async {
    final legs = _legs.values.where((l) => l.cycleId == cycleId).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return legs;
  }

  @override
  Future<WheelCycle?> getCycle(String id) async => _cycles[id];

  @override
  Future<List<WheelCycle>> getClosedCycles() async {
    final closed = _cycles.values.where((c) => c.status == WheelCycleStatus.closed).toList()
      ..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));
    return closed;
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
    _snapshots[snapshot.id] = snapshot;
    return snapshot;
  }

  @override
  Future<List<Snapshot>> getSnapshotsForLeg(String legId) async {
    final snapshots = _snapshots.values.where((s) => s.legId == legId).toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return snapshots;
  }

  @override
  Future<Snapshot?> getLatestSnapshotForLeg(String legId) async {
    final snapshots = await getSnapshotsForLeg(legId);
    return snapshots.isEmpty ? null : snapshots.last;
  }

  // --- Roll / close / assignment (atomic, cycle-transitioning) --------

  @override
  Future<({Leg closedLeg, Leg newLeg})> recordRoll({
    required String closingLegId,
    required Decimal closeDebitPerShare,
    Decimal? closeFee,
    required DateTime closedAt,
    required NewLegInput newLeg,
  }) async {
    final closingLeg = _requireLeg(closingLegId);

    final updatedClosing = closingLeg.copyWith(
      closedAt: closedAt,
      closeDebitPerShare: closeDebitPerShare,
      closeReason: CloseReason.rolled,
      closeFee: closeFee,
    );
    _legs[closingLegId] = updatedClosing;

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
    _legs[createdLeg.id] = createdLeg;

    return (closedLeg: updatedClosing, newLeg: createdLeg);
  }

  @override
  Future<({Leg leg, WheelCycle cycle})> closeLeg({
    required String legId,
    required CloseReason reason,
    Decimal? closeDebitPerShare,
    Decimal? closeFee,
    required DateTime closedAt,
  }) async {
    if (reason == CloseReason.rolled || reason == CloseReason.assigned) {
      throw ArgumentError.value(
        reason,
        'reason',
        'closeLeg only accepts closedEarly or expiredWorthless — '
            'use recordRoll/recordAssignment/recordCallAway instead',
      );
    }

    return _closeLegInTransaction(
      legId: legId,
      reason: reason,
      closeDebitPerShare: closeDebitPerShare,
      closeFee: closeFee,
      closedAt: closedAt,
    );
  }

  /// The shared body of [closeLeg] and [markExpired] — one leg closed plus
  /// the put-leg-ends-its-cycle rule (Feature Invariant 16), so the batch
  /// path cannot drift from the single-leg one.
  ({Leg leg, WheelCycle cycle}) _closeLegInTransaction({
    required String legId,
    required CloseReason reason,
    required Decimal? closeDebitPerShare,
    required Decimal? closeFee,
    required DateTime closedAt,
  }) {
    final leg = _requireLeg(legId);
    final updatedLeg = leg.copyWith(
      closedAt: closedAt,
      closeReason: reason,
      closeDebitPerShare: closeDebitPerShare,
      closeFee: closeFee,
    );
    _legs[legId] = updatedLeg;

    var cycle = _requireCycle(leg.cycleId);
    if (leg.optionType == OptionType.put) {
      final outcome = reason == CloseReason.closedEarly
          ? WheelCycleOutcome.closedEarly
          : WheelCycleOutcome.expiredWorthless;
      cycle = cycle.copyWith(
        status: WheelCycleStatus.closed,
        outcome: outcome,
        endedAt: closedAt,
      );
      _cycles[cycle.id] = cycle;
    }

    return (leg: updatedLeg, cycle: cycle);
  }

  @override
  Future<List<Leg>> markExpired({
    required List<({String legId, DateTime closedAt})> legs,
  }) async {
    _rejectEmptyExpiryBatch(legs);

    // Validate every leg before writing any of them, so an unknown id or an
    // already-closed leg leaves every leg and cycle untouched (S-217 b/d).
    for (final entry in legs) {
      _validateMarkExpiredTarget(_legs[entry.legId], entry.legId);
    }

    return [
      for (final entry in legs)
        _closeLegInTransaction(
          legId: entry.legId,
          reason: CloseReason.expiredWorthless,
          closeDebitPerShare: Decimal.zero,
          closeFee: null,
          closedAt: entry.closedAt,
        ).leg,
    ];
  }

  @override
  Future<({Leg leg, ShareLot shareLot, WheelCycle cycle})> recordAssignment({
    required String legId,
    Decimal? closeFee,
    required NewShareLotInput shareLot,
  }) async {
    final leg = _requireLeg(legId);
    final updatedLeg = leg.copyWith(
      closedAt: shareLot.assignedAt,
      closeReason: CloseReason.assigned,
      closeFee: closeFee,
    );
    _legs[legId] = updatedLeg;

    final createdLot = ShareLot(
      id: generateId(),
      cycleId: leg.cycleId,
      assignedAt: shareLot.assignedAt,
      assignmentStrike: shareLot.assignmentStrike,
      contracts: shareLot.contracts,
    );
    _shareLots[createdLot.id] = createdLot;

    final cycle = _requireCycle(leg.cycleId).copyWith(status: WheelCycleStatus.holdingShares);
    _cycles[cycle.id] = cycle;

    return (leg: updatedLeg, shareLot: createdLot, cycle: cycle);
  }

  @override
  Future<({Leg leg, WheelCycle cycle})> recordCallAway({
    required String legId,
    Decimal? closeFee,
    required DateTime closedAt,
  }) async {
    final leg = _requireLeg(legId);
    final updatedLeg = leg.copyWith(
      closedAt: closedAt,
      closeReason: CloseReason.assigned,
      closeFee: closeFee,
    );
    _legs[legId] = updatedLeg;

    // The ShareLot is RETAINED (CR-1) -- the share position ends, so
    // `getShareLotForCycle` stops returning it, but the assignment's own
    // recorded strike/contracts survive for `getAssignmentForCycle`.
    // Deleting it threw that history away and forced callers to
    // reconstruct it from the assigned leg, which need not match.

    final cycle = _requireCycle(leg.cycleId).copyWith(
      status: WheelCycleStatus.closed,
      outcome: WheelCycleOutcome.calledAway,
      endedAt: closedAt,
    );
    _cycles[cycle.id] = cycle;

    return (leg: updatedLeg, cycle: cycle);
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

    final leg = _requireLeg(legId);
    final updated = leg.copyWith(
      acceptsAssignment: acceptsAssignment ?? leg.acceptsAssignment,
      openFee: clearOpenFee ? null : (openFee ?? leg.openFee),
      closeFee: clearCloseFee ? null : (closeFee ?? leg.closeFee),
    );
    _legs[legId] = updated;
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
  Future<ShareLot?> getAssignmentForCycle(String cycleId) async =>
      _firstOrNull(_shareLots.values.where((lot) => lot.cycleId == cycleId));

  // --- UserPreferences (Iteration 3, schema v2) --------------------------

  @override
  Future<UserPreferencesData> getPreferences() async => _preferences;

  @override
  Future<UserPreferencesData> updatePreferences(UserPreferencesData prefs) async {
    _preferences = prefs;
    return _preferences;
  }

  // --- Export / import (Phase 19) ----------------------------------------

  @override
  Future<String> exportToJson() async => LedgerExport(
        formatVersion: LedgerExport.currentFormatVersion,
        underlyings: _underlyings.values.toList(),
        cycles: _cycles.values.toList(),
        legs: _legs.values.toList(),
        snapshots: _snapshots.values.toList(),
        shareLots: _shareLots.values.toList(),
        ruleProfiles: _ruleProfiles.values.toList(),
        ruleProfileVersions: _ruleProfileVersions.values.toList(),
        preferences: _preferences,
      ).toJsonString();

  @override
  Future<int> countCyclesForReplace() async => _cycles.length;

  @override
  Future<void> restoreFromJson(String json, {DateTime? now}) async {
    // Parsed/validated in full BEFORE any map below is touched -- a
    // malformed file throws here and nothing is ever cleared (S-152).
    // Format-1 files are converted to the v2 shape inside this call (D-8).
    final export = LedgerExport.fromJsonString(json, now: now);

    // Everything from here on is synchronous Dart (no `await`), so this
    // whole replace-all runs as one uninterrupted step -- the same
    // atomicity guarantee `DriftWheelRepository` gets from a real SQL
    // transaction, without needing one.
    _underlyings
      ..clear()
      ..addEntries(export.underlyings.map((u) => MapEntry(u.id, u)));
    _cycles
      ..clear()
      ..addEntries(export.cycles.map((c) => MapEntry(c.id, c)));
    _legs
      ..clear()
      ..addEntries(export.legs.map((l) => MapEntry(l.id, l)));
    _snapshots
      ..clear()
      ..addEntries(export.snapshots.map((s) => MapEntry(s.id, s)));
    _shareLots
      ..clear()
      ..addEntries(export.shareLots.map((lot) => MapEntry(lot.id, lot)));
    _ruleProfiles
      ..clear()
      ..addEntries(export.ruleProfiles.map((rp) => MapEntry(rp.id, rp)));
    _ruleProfileVersions
      ..clear()
      ..addEntries(export.ruleProfileVersions.map((rpv) => MapEntry(rpv.id, rpv)));
    _preferences = export.preferences;
  }

  // --- internal helpers --------------------------------------------------

  Leg _requireLeg(String legId) {
    final leg = _legs[legId];
    if (leg == null) {
      throw ArgumentError.value(legId, 'legId', 'No leg with this id exists');
    }
    return leg;
  }

  WheelCycle _requireCycle(String cycleId) {
    final cycle = _cycles[cycleId];
    if (cycle == null) {
      throw ArgumentError.value(cycleId, 'cycleId', 'No cycle with this id exists');
    }
    return cycle;
  }
}

/// Shared validation for [WheelRepository.updateLegMetadata], duplicated
/// verbatim in `DriftWheelRepository` (parity is proven by the shared
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
/// in `DriftWheelRepository` (same rationale as
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
