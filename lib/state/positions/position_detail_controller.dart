import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/total_per_contract.dart';
import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/share_lot.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/models/underlying.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/bucket.dart';
import '../../domain/rules/classify.dart';
import '../../domain/rules/credit_bound.dart';
import '../../domain/rules/cycle_pnl.dart';
import '../../domain/rules/expiry.dart';
import '../../domain/rules/formulas.dart' as formulas;
import '../../domain/rules/iv_resolution.dart';
import '../../domain/rules/roll_chain.dart';
import '../../domain/rules/rule_profile.dart';
import '../../domain/rules/triage_input.dart';
import '../notifications/notification_providers.dart';
import '../preferences/preferences_provider.dart';
import '../repository_providers.dart';

/// Position detail state (§5.2): the current verdict with the arithmetic
/// that fired it shown openly, the roll chain (every leg + cumulative
/// credit), and the snapshot history a sparkline draws from.
class PositionDetailState {
  final bool isLoading;
  final String? error;
  final Leg? leg;
  final Underlying? underlying;
  final WheelCycle? cycle;

  /// Every leg in this cycle, ordered by `sequence` — the roll chain.
  final List<Leg> cycleLegs;

  /// Every snapshot for [leg], ordered by `takenAt` — the sparkline's data
  /// source. Append-only; never edited or removed (§3.4).
  final List<Snapshot> snapshots;

  final RuleProfile profile;
  final Bucket? bucket;
  final Decimal? capturedPct;
  final double? deltaMagnitude;
  final double? rollBand;

  /// Where the IV that produced [rollBand] came from (brief-followup A3,
  /// Feature Invariant 18) — feeds the source-aware "Roll band in use"
  /// label, e.g. via `rollBandLabel`.
  final ResolvedIv? resolvedIv;
  final Decimal? oneSigmaMove;
  final double? cushionSigmas;
  final Decimal? extrinsic;

  /// The current leg's own credit only (Feature Invariant 1) — NOT what
  /// Gate 1 evaluates. This cycle-wide total is shown *beside* it, never
  /// substituted in.
  final Decimal cycleCumulativeCredit;

  /// The cycle's active `ShareLot`, if it is currently `holdingShares` —
  /// `null` otherwise. Feeds [cyclePnl]'s `wheelBasis` term.
  final ShareLot? shareLot;

  /// Every §4.1/§4.2 cycle figure for THIS cycle (Feature Invariant 25,
  /// contract-weighted throughout), computed once per [load]. For a still-
  /// open cycle these are unrealised figures — the UI must label them
  /// "Unrealised, excludes closing costs" (Feature Invariant 28, S-126),
  /// never bare, and never "Before fees" (an open leg's own missing
  /// `closeFee` is expected, not a gap).
  final CyclePnl? cyclePnl;

  final bool snapshotSubmitting;
  final String? snapshotError;

  /// A non-blocking credit-bound warning from the *last successful* snapshot
  /// save (Feature Invariant 20's soft-warn tier) — distinct from
  /// [snapshotError], which is reserved for the hard-reject block.
  final String? snapshotWarning;
  final bool actionSubmitting;
  final String? actionError;

  PositionDetailState({
    this.isLoading = true,
    this.error,
    this.leg,
    this.underlying,
    this.cycle,
    this.cycleLegs = const [],
    this.snapshots = const [],
    required this.profile,
    this.bucket,
    this.capturedPct,
    this.deltaMagnitude,
    this.rollBand,
    this.resolvedIv,
    this.oneSigmaMove,
    this.cushionSigmas,
    this.extrinsic,
    required this.cycleCumulativeCredit,
    this.shareLot,
    this.cyclePnl,
    this.snapshotSubmitting = false,
    this.snapshotError,
    this.snapshotWarning,
    this.actionSubmitting = false,
    this.actionError,
  });

  /// True when the current leg was opened by a roll, not fresh — the roll
  /// chain view must say so prominently (brief §5.2).
  bool get cameFromRoll => leg?.rolledFromLegId != null;

  Snapshot? get latestSnapshot => snapshots.isEmpty ? null : snapshots.last;

  /// The full Feature Invariant 18 label, or `null` before the first load
  /// settles (no [rollBand]/[resolvedIv] computed yet).
  String? get rollBandLabelText =>
      (rollBand == null || resolvedIv == null) ? null : rollBandLabel(band: rollBand!, resolvedIv: resolvedIv!);

  PositionDetailState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    Leg? leg,
    Underlying? underlying,
    WheelCycle? cycle,
    List<Leg>? cycleLegs,
    List<Snapshot>? snapshots,
    RuleProfile? profile,
    Bucket? bucket,
    Decimal? capturedPct,
    double? deltaMagnitude,
    double? rollBand,
    ResolvedIv? resolvedIv,
    Decimal? oneSigmaMove,
    double? cushionSigmas,
    Decimal? extrinsic,
    Decimal? cycleCumulativeCredit,
    ShareLot? shareLot,
    CyclePnl? cyclePnl,
    bool? snapshotSubmitting,
    String? snapshotError,
    bool clearSnapshotError = false,
    String? snapshotWarning,
    bool clearSnapshotWarning = false,
    bool? actionSubmitting,
    String? actionError,
    bool clearActionError = false,
  }) => PositionDetailState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    leg: leg ?? this.leg,
    underlying: underlying ?? this.underlying,
    cycle: cycle ?? this.cycle,
    cycleLegs: cycleLegs ?? this.cycleLegs,
    snapshots: snapshots ?? this.snapshots,
    profile: profile ?? this.profile,
    bucket: bucket ?? this.bucket,
    capturedPct: capturedPct ?? this.capturedPct,
    deltaMagnitude: deltaMagnitude ?? this.deltaMagnitude,
    rollBand: rollBand ?? this.rollBand,
    resolvedIv: resolvedIv ?? this.resolvedIv,
    oneSigmaMove: oneSigmaMove ?? this.oneSigmaMove,
    cushionSigmas: cushionSigmas ?? this.cushionSigmas,
    extrinsic: extrinsic ?? this.extrinsic,
    cycleCumulativeCredit: cycleCumulativeCredit ?? this.cycleCumulativeCredit,
    shareLot: shareLot ?? this.shareLot,
    cyclePnl: cyclePnl ?? this.cyclePnl,
    snapshotSubmitting: snapshotSubmitting ?? this.snapshotSubmitting,
    snapshotError: clearSnapshotError ? null : (snapshotError ?? this.snapshotError),
    snapshotWarning: clearSnapshotWarning ? null : (snapshotWarning ?? this.snapshotWarning),
    actionSubmitting: actionSubmitting ?? this.actionSubmitting,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );
}

class PositionDetailController extends StateNotifier<PositionDetailState> {
  PositionDetailController(this._ref, this._repo, this._legId)
    : super(PositionDetailState(profile: RuleProfile.standard, cycleCumulativeCredit: Decimal.zero)) {
    load();
  }

  final Ref _ref;
  final WheelRepository _repo;
  final String _legId;

  Future<void> load({DateTime? now}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final leg = await _repo.getLeg(_legId);
      if (leg == null) {
        state = state.copyWith(isLoading: false, error: 'This position no longer exists.');
        return;
      }
      final cycle = await _repo.getCycle(leg.cycleId);
      final underlying = cycle == null ? null : await _repo.getUnderlying(cycle.underlyingId);
      final cycleLegs = await _repo.getLegsForCycle(leg.cycleId);
      final snapshots = await _repo.getSnapshotsForLeg(_legId);

      // The leg's pinned threshold version — never the profile's current
      // one (Iteration 5 D-5): an edit must not reclassify an open
      // position or its rolled successors. A dangling pin degrades to the
      // built-in defaults (D-7).
      final versionData = await _repo.getRuleProfileVersion(leg.ruleProfileVersionId);
      final RuleProfile profile;
      if (versionData == null) {
        profile = RuleProfile.standard;
      } else {
        final profileData = await _repo.getRuleProfile(versionData.profileId);
        profile = RuleProfile.fromVersion(versionData, profileName: profileData?.name ?? 'Standard');
      }

      // Feature Invariant 7 / S-140: two distinct reference dates through one
      // shared `formulas.dte` implementation -- `dteValue` (classification,
      // Gate 4) is always `expiration - now.toDate()`, real `now`, never a
      // backdated snapshot's own `takenAt`. A snapshot's own historical
      // figures (its `oneSigmaMove`) use `expiration - snapshot.takenAt.date`
      // instead, so they stay pinned to what the reading said at the moment
      // it was taken rather than drifting as real time (or a caller-supplied
      // backdated `now`) moves forward.
      final effectiveNow = now ?? DateTime.now();
      final snapshot = snapshots.isEmpty ? null : snapshots.last;
      final dteValue = formulas.dte(leg.expiration, effectiveNow);

      Decimal? captured;
      double? deltaMag;
      Decimal? extrinsicValue;
      Decimal? oneSigma;
      double? cushion;
      if (snapshot != null) {
        captured = formulas.capturedPct(openCredit: leg.openCreditPerShare, currentMark: snapshot.optionMark);
        deltaMag = formulas.deltaMagnitude(snapshot.deltaAsEntered);
        final intrinsicValue = formulas.intrinsic(
          optionType: leg.optionType,
          strike: leg.strike,
          spot: snapshot.underlyingPrice,
        );
        extrinsicValue = formulas.extrinsic(currentMark: snapshot.optionMark, intrinsic: intrinsicValue);
        // oneSigmaMove's IV source is unchanged by A3/Feature Invariant 18 --
        // it still reads `snapshot.iv` only, never the resolution order
        // below (which is scoped to Gate 3's roll band exclusively). Its
        // `dte` is this snapshot's own historical DTE (Feature Invariant 7),
        // not the live classification `dteValue` above.
        final snapshotDte = formulas.dte(leg.expiration, snapshot.takenAt);
        oneSigma = formulas.oneSigmaMove(spot: snapshot.underlyingPrice, iv: snapshot.iv, dte: snapshotDte);
        cushion = formulas.cushionSigmas(
          strike: leg.strike,
          spot: snapshot.underlyingPrice,
          oneSigmaMove: oneSigma,
        );
      }

      // Feature Invariant 18 (brief-followup A3): resolve snapshot IV -> leg
      // ivAtOpen -> profile default, and feed the *resolved* value into
      // TriageInput.iv -- never `snapshot?.iv` directly. This changes actual
      // Gate 3 classification, not just a display label. The assembly itself
      // is shared with the positions list and Record's preview (D-17, S-227).
      final resolved = resolveIv(snapshot: snapshot, leg: leg);
      final input = triageInputFor(leg: leg, snapshot: snapshot, dte: dteValue);
      final bucket = classify(input, profile);
      final band = profile.rollBandFor(resolved.value);
      final cumulative = cycleCumulativeCredit(cycleLegs);

      // §4.1/§4.2 cycle P&L, contract-weighted throughout (Feature
      // Invariant 25) -- shown "Unrealised, excludes closing costs" while
      // `cycle.status != closed` (Feature Invariant 28, S-126).
      //
      // `shareLot` (state field) stays the ACTIVE lot only
      // (`getShareLotForCycle`, non-null only while `holdingShares`) -- its
      // documented meaning is unchanged, never repurposed. `computeCyclePnl`
      // needs a different question answered: which strike to use for
      // `stockPnL`/`peakCapitalCommitted`, for which the retained assignment
      // record is preferred, matching `journal_controller.dart:113-116`
      // (Feature Invariant 36, Phase 23.4 ruling 2b) -- the assigned put
      // leg's own strike is only a legacy fallback for a cycle closed before
      // that record was retained.
      final shareLot = cycle == null ? null : await _repo.getShareLotForCycle(cycle.id);
      final pnlShareLot = cycle == null
          ? null
          : (await _repo.getAssignmentForCycle(cycle.id)) ?? _reconstructShareLot(cycleLegs);
      final cyclePnl = cycle == null
          ? null
          : computeCyclePnl(
              legs: cycleLegs,
              shareLot: pnlShareLot,
              startedAt: cycle.startedAt,
              endedAt: cycle.endedAt,
              now: effectiveNow,
            );

      state = PositionDetailState(
        isLoading: false,
        leg: leg,
        underlying: underlying,
        cycle: cycle,
        cycleLegs: cycleLegs,
        snapshots: snapshots,
        profile: profile,
        bucket: bucket,
        capturedPct: captured,
        deltaMagnitude: deltaMag,
        rollBand: band,
        resolvedIv: resolved,
        oneSigmaMove: oneSigma,
        cushionSigmas: cushion,
        extrinsic: extrinsicValue,
        cycleCumulativeCredit: cumulative,
        shareLot: shareLot,
        cyclePnl: cyclePnl,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Could not load this position: $e');
    }
  }

  /// "Update snapshot" (§5.2's primary action). Append-only — never
  /// overwrites a prior snapshot (S-022). [optionMark] is bound-checked
  /// against the no-arbitrage rule (Feature Invariant 20) using the leg's
  /// own strike and **this same submission's** [underlyingPrice] — never a
  /// stale stored one. Applies the "total per contract" preference
  /// (Feature Invariant 21) before the bound check and before persisting.
  /// [takenAt] defaults to now; when backdated, it is range-validated
  /// against `[leg.openedAt, leg.expiration]` (S-142) before anything is
  /// persisted.
  Future<bool> updateSnapshot({
    required Decimal optionMark,
    required Decimal underlyingPrice,
    required double deltaAsEntered,
    required DeltaConvention deltaConvention,
    double? iv,
    double? gamma,
    double? theta,
    double? vega,
    int? openInterest,
    int? volume,
    DateTime? takenAt,
  }) async {
    final leg = state.leg;
    if (leg == null) return false;
    state = state.copyWith(snapshotSubmitting: true, clearSnapshotError: true, clearSnapshotWarning: true);
    try {
      final effectiveTakenAt = takenAt ?? DateTime.now();
      final rangeError = _validateTakenAtRange(takenAt: effectiveTakenAt, leg: leg);
      if (rangeError != null) {
        state = state.copyWith(snapshotSubmitting: false, snapshotError: rangeError);
        return false;
      }

      final totalPerContract =
          _ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;
      final perShareMark = perShareValue(optionMark, totalPerContract: totalPerContract);

      final bound = checkCreditBound(
        value: perShareMark,
        side: leg.optionType,
        spot: underlyingPrice,
        strike: leg.strike,
      );
      if (bound.blocks) {
        state = state.copyWith(snapshotSubmitting: false, snapshotError: bound.message);
        return false;
      }

      await _repo.appendSnapshot(
        NewSnapshotInput(
          legId: _legId,
          takenAt: effectiveTakenAt,
          optionMark: perShareMark,
          underlyingPrice: underlyingPrice,
          deltaAsEntered: deltaAsEntered,
          deltaConvention: deltaConvention,
          gamma: gamma,
          theta: theta,
          vega: vega,
          iv: iv,
          openInterest: openInterest,
          volume: volume,
        ),
      );
      // S-140/Feature Invariant 33: classification always uses real `now`,
      // never this submission's (possibly backdated) `takenAt` -- `load()`
      // defaults to `DateTime.now()` internally. The snapshot's own
      // historical figures (its DTE, its one-sigma move) are unaffected --
      // `load()` derives those from the snapshot's own stored `takenAt`
      // (see the split above), never from this `now`.
      await load();
      state = state.copyWith(
        snapshotSubmitting: false,
        snapshotWarning: bound.level == CreditBoundLevel.softWarn ? bound.message : null,
        clearSnapshotWarning: bound.level != CreditBoundLevel.softWarn,
      );
      return true;
    } catch (e) {
      state = state.copyWith(snapshotSubmitting: false, snapshotError: 'Could not save snapshot: $e');
      return false;
    }
  }

  /// "Close" / "Mark expired" (S-027, S-028) — a direct close, not a roll
  /// and not an assignment. [reason] must be `closedEarly` or
  /// `expiredWorthless`; the repository itself also ends the owning cycle
  /// when this is a put leg (Feature Invariant 16).
  Future<bool> closeDirect({
    required CloseReason reason,
    required Decimal closeDebitPerShare,
    Decimal? closeFee,
    DateTime? closedAt,
  }) async {
    final leg = state.leg;
    if (leg == null) return false;
    state = state.copyWith(actionSubmitting: true, clearActionError: true);
    try {
      // Named for its restricted role, deliberately: this is the date to
      // *record* as the close, and it is NOT a classification reference
      // time. Calling it `now` is what made CR-3 look correct — see the
      // bare `load()` below.
      final recordedClosedAt = closedAt ?? DateTime.now();
      await _repo.closeLeg(
        legId: leg.id,
        reason: reason,
        closeDebitPerShare: closeDebitPerShare,
        closeFee: closeFee,
        closedAt: recordedClosedAt,
      );
      // Phase 21/S-171: a direct close (mark expired / closed early) ends
      // this leg's own life regardless of whether it also ends the cycle --
      // its notifications are cancelled either way.
      await _ref.read(notificationSchedulerProvider).cancelForLeg(leg.id);
      // CR-3 (the same defect S-140 fixed in `updateSnapshot`): the
      // recorded close date must NOT become the classification reference
      // time. Classification always uses real `now`, so a backdated close
      // cannot make the figures shown afterwards disagree with a reopened
      // read of the same leg (`load()` defaults to `DateTime.now()`
      // internally).
      await load();
      state = state.copyWith(actionSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(actionSubmitting: false, actionError: 'Could not close this leg: $e');
      return false;
    }
  }

  /// D-13's "Mark expired" (S-253): the same direct close as [closeDirect],
  /// with the recorded date pinned by [recordedCloseDateForExpiry] — on or
  /// after the expiration date the expiration date is recorded, so a leg
  /// marked on the Monday after a Friday expiry lands in the month it
  /// actually expired in. Before the expiration date the tap time is kept.
  Future<bool> markExpired({Decimal? closeFee, DateTime? now}) async {
    final leg = state.leg;
    if (leg == null) return false;
    return closeDirect(
      reason: CloseReason.expiredWorthless,
      closeDebitPerShare: Decimal.zero,
      closeFee: closeFee,
      closedAt: recordedCloseDateForExpiry(leg, now ?? DateTime.now()),
    );
  }

  /// S-124: flips `acceptsAssignment` on the current leg (editable while
  /// still open — the repository's `updateLegMetadata` doesn't actually
  /// gate on lifecycle state, but this is the leg the sheet is showing) and
  /// re-triages via a full [load] — no new snapshot required, matching the
  /// scenario's own wording. A no-op call (the value already matches) is
  /// short-circuited here rather than forwarded, since `updateLegMetadata`
  /// treats "nothing would change" as an error, not a no-op.
  Future<bool> setAcceptsAssignment(bool value) async {
    final leg = state.leg;
    if (leg == null) return false;
    if (leg.acceptsAssignment == value) return true;
    state = state.copyWith(actionSubmitting: true, clearActionError: true);
    try {
      await _repo.updateLegMetadata(legId: leg.id, acceptsAssignment: value);
      await load();
      state = state.copyWith(actionSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(actionSubmitting: false, actionError: 'Could not update this leg: $e');
      return false;
    }
  }

  /// S-122: fills in whichever of [openFee]/[closeFee] is passed on an
  /// already-closed leg identified by [legId] (not necessarily the
  /// currently-shown leg — a fee gap can belong to any earlier leg in the
  /// roll chain). Only ever *fills* a missing fee here, never clears one
  /// back to unknown — clearing isn't part of this affordance. Returns
  /// `false` without calling the repository when both are `null` (avoids
  /// `updateLegMetadata`'s "nothing would change" `ArgumentError`).
  Future<bool> updateLegFees({required String legId, Decimal? openFee, Decimal? closeFee}) async {
    if (openFee == null && closeFee == null) return false;
    state = state.copyWith(actionSubmitting: true, clearActionError: true);
    try {
      await _repo.updateLegMetadata(legId: legId, openFee: openFee, closeFee: closeFee);
      await load();
      state = state.copyWith(actionSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(actionSubmitting: false, actionError: 'Could not update fees: $e');
      return false;
    }
  }
}

final positionDetailControllerProvider =
    StateNotifierProvider.family.autoDispose<PositionDetailController, PositionDetailState, String>((
      ref,
      legId,
    ) {
      final repo = ref.watch(wheelRepositoryProvider);
      return PositionDetailController(ref, repo, legId);
    });

/// S-142: [takenAt] must fall within `[leg.openedAt, leg.expiration]`
/// (inclusive both ends — a snapshot taken the same calendar day the leg
/// opened or the same calendar day it expires is legitimate). Compares
/// calendar dates only via `formulas.daysBetween`, the same UTC-normalized,
/// time-of-day-ignoring day count `dte`/`daysHeld` already share (Feature
/// Invariant 7) — a leg opened at 14:32 and a snapshot backdated to 09:00
/// the same day must not be rejected merely for its earlier time-of-day.
/// Returns the rejection message naming the valid range, or `null` when the
/// date is in range.
String? _validateTakenAtRange({required DateTime takenAt, required Leg leg}) {
  final beforeOpen = formulas.daysBetween(leg.openedAt, takenAt) < 0;
  final afterExpiration = formulas.daysBetween(leg.expiration, takenAt) > 0;
  if (beforeOpen || afterExpiration) {
    return 'Snapshot date must be between ${_dateOnly(leg.openedAt)} and ${_dateOnly(leg.expiration)}.';
  }
  return null;
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Legacy fallback for [PositionDetailController.load]'s `pnlShareLot` --
/// see that call site. Deliberately duplicated from
/// `journal_controller.dart`'s own private `_reconstructShareLot` (same
/// shape, same reasoning) rather than exported and shared across the two
/// state files, to keep this Phase 23.4.1 remediation's diff bounded to
/// this one file (see `docs/plans/iteration-4-closeout-plan.md`'s
/// `## Assumption Log`). Only reached when the cycle has no retained
/// assignment record (CR-1: a cycle closed before the row was retained, or
/// a hand-built import), where the assigned put leg's own
/// `strike`/`contracts` are the only stand-in available. They are *not*
/// necessarily the assignment's, so this is an approximation, not an
/// equivalent -- do not prefer it over the record. `null` when the cycle
/// never reached a put-side assignment (it closed entirely on the put
/// side).
ShareLot? _reconstructShareLot(List<Leg> legs) {
  final assigned = assignedPutLeg(legs);
  if (assigned == null || assigned.closedAt == null) return null;
  return ShareLot(
    id: 'reconstructed-${assigned.id}',
    cycleId: assigned.cycleId,
    assignedAt: assigned.closedAt!,
    assignmentStrike: assigned.strike,
    contracts: assigned.contracts,
  );
}
