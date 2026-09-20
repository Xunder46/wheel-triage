import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/total_per_contract.dart';
import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/models/underlying.dart';
import '../../domain/rules/credit_bound.dart';
import '../../domain/rules/formulas.dart' as formulas;
import '../../domain/rules/screener.dart';
import '../notifications/notification_providers.dart';
import '../preferences/preferences_provider.dart';
import '../repository_providers.dart';

/// One candidate replacement the user types in (§5.3): a new expiry, a new
/// strike, and the two prices they can see (the repurchase debit on the
/// current leg, the credit on the new leg). Both prices are already the
/// resolved per-share values by the time a [RollCandidate] exists — see
/// `RollPlannerController.addCandidate`, which applies the "total per
/// contract" preference before constructing one.
class RollCandidate {
  final String id;
  final DateTime newExpiry;
  final Decimal newStrike;
  final Decimal buybackDebit;
  final Decimal newCredit;

  const RollCandidate({
    required this.id,
    required this.newExpiry,
    required this.newStrike,
    required this.buybackDebit,
    required this.newCredit,
  });

  /// `netCredit = newCredit - buybackDebit` (brief §5.3's formula, verbatim).
  Decimal get netCredit => newCredit - buybackDebit;

  /// `netCredit <= 0` -> a debit roll. Never presented as income
  /// (`docs/conventions.md`, S-025).
  bool get isDebit => netCredit <= Decimal.zero;
}

/// A candidate plus everything derived from it for display, computed
/// against the leg being rolled and "now".
class RollCandidateResult {
  final RollCandidate candidate;
  final Decimal netCredit;
  final bool isDebit;
  final Decimal strikeDelta;
  final double annualisedYield;

  const RollCandidateResult({
    required this.candidate,
    required this.netCredit,
    required this.isDebit,
    required this.strikeDelta,
    required this.annualisedYield,
  });
}

class RollPlannerState {
  final bool isLoading;
  final String? error;
  final Leg? leg;

  /// The leg's own latest snapshot (if any), fetched once at load time —
  /// the "current stock price" source for the no-arbitrage bound check
  /// (Feature Invariant 20), since this screen collects no stock-price
  /// input of its own. `null` means the bound check is skipped entirely
  /// (S-057), not blocked on an unknown price.
  final Snapshot? latestSnapshot;

  /// The leg's own underlying (ticker source for the new leg's expiration
  /// notifications, Phase 21) -- fetched once at load time alongside
  /// [latestSnapshot], `null` only before the first load settles or if the
  /// leg's cycle/underlying can't be resolved.
  final Underlying? underlying;
  final List<RollCandidate> candidates;

  /// A non-blocking soft-warn message from the most recently *added*
  /// candidate (Feature Invariant 20's soft-warn tier) — distinct from
  /// [error], which is reserved for a hard-reject block.
  final String? candidateWarning;
  final bool isSubmitting;
  final bool rolled;

  const RollPlannerState({
    this.isLoading = true,
    this.error,
    this.leg,
    this.latestSnapshot,
    this.underlying,
    this.candidates = const [],
    this.candidateWarning,
    this.isSubmitting = false,
    this.rolled = false,
  });

  RollPlannerState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    Leg? leg,
    Snapshot? latestSnapshot,
    Underlying? underlying,
    List<RollCandidate>? candidates,
    String? candidateWarning,
    bool clearCandidateWarning = false,
    bool? isSubmitting,
    bool? rolled,
  }) => RollPlannerState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    leg: leg ?? this.leg,
    latestSnapshot: latestSnapshot ?? this.latestSnapshot,
    underlying: underlying ?? this.underlying,
    candidates: candidates ?? this.candidates,
    candidateWarning: clearCandidateWarning ? null : (candidateWarning ?? this.candidateWarning),
    isSubmitting: isSubmitting ?? this.isSubmitting,
    rolled: rolled ?? this.rolled,
  );
}

class RollPlannerController extends StateNotifier<RollPlannerState> {
  RollPlannerController(this._ref, this._repo, this._legId) : super(const RollPlannerState()) {
    ready = _load();
  }

  final Ref _ref;
  final WheelRepository _repo;
  final String _legId;

  /// Completes once the initial leg fetch has settled. Tests (and any
  /// future caller that needs to know the first load has finished, not
  /// just watch `state`) can await this instead of racing the
  /// constructor's fire-and-forget load.
  late final Future<void> ready;

  Future<void> _load() async {
    final leg = await _repo.getLeg(_legId);
    final snapshot = leg == null ? null : await _repo.getLatestSnapshotForLeg(leg.id);
    final cycle = leg == null ? null : await _repo.getCycle(leg.cycleId);
    final underlying = cycle == null ? null : await _repo.getUnderlying(cycle.underlyingId);
    state = state.copyWith(
      isLoading: false,
      leg: leg,
      latestSnapshot: snapshot,
      underlying: underlying,
      error: leg == null ? 'This position no longer exists.' : null,
    );
  }

  /// Adds [candidate] to the comparison list. Applies the "total per
  /// contract" preference (Feature Invariant 21) to `buybackDebit`/
  /// `newCredit` first, then runs the no-arbitrage bound (Feature Invariant
  /// 20) on both against the current leg's own strike (buyback) and the
  /// candidate's new strike (new credit), sourcing "stock price" from
  /// [RollPlannerState.latestSnapshot] — skipped entirely with no
  /// reject/warn when there is none yet (S-057). A hard reject on either
  /// field blocks the add (returns `false`, no candidate stored); a soft
  /// warn on either still adds it and surfaces
  /// [RollPlannerState.candidateWarning].
  bool addCandidate(RollCandidate candidate) {
    if (state.candidates.length >= 3) return false; // "two or three candidates" (§5.3)
    final leg = state.leg;
    if (leg == null) return false;

    final totalPerContract =
        _ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;
    final adjusted = RollCandidate(
      id: candidate.id,
      newExpiry: candidate.newExpiry,
      newStrike: candidate.newStrike,
      buybackDebit: perShareValue(candidate.buybackDebit, totalPerContract: totalPerContract),
      newCredit: perShareValue(candidate.newCredit, totalPerContract: totalPerContract),
    );

    final bound = _worstBound(adjusted, leg, state.latestSnapshot);
    if (bound != null && bound.blocks) {
      state = state.copyWith(error: bound.message);
      return false;
    }

    state = state.copyWith(
      candidates: [...state.candidates, adjusted],
      clearError: true,
      candidateWarning: bound?.level == CreditBoundLevel.softWarn ? bound!.message : null,
      clearCandidateWarning: bound?.level != CreditBoundLevel.softWarn,
    );
    return true;
  }

  void removeCandidate(String id) =>
      state = state.copyWith(candidates: state.candidates.where((c) => c.id != id).toList());

  /// Every candidate compared side by side (§5.3), on the extended duration
  /// for each candidate's own new expiry.
  List<RollCandidateResult> results({DateTime? now}) {
    final leg = state.leg;
    if (leg == null) return const [];
    final effectiveNow = now ?? DateTime.now();
    return state.candidates.map((candidate) {
      final extendedDte = formulas.dte(candidate.newExpiry, effectiveNow);
      final yieldValue = screenerAnnualisedYield(
        credit: candidate.newCredit,
        strike: candidate.newStrike,
        dteAtOpen: extendedDte,
      );
      return RollCandidateResult(
        candidate: candidate,
        netCredit: candidate.netCredit,
        isDebit: candidate.isDebit,
        strikeDelta: candidate.newStrike - leg.strike,
        annualisedYield: yieldValue,
      );
    }).toList();
  }

  /// Confirms [candidate] as the roll (S-024): one atomic two-write
  /// transaction via `WheelRepository.recordRoll`. The new leg inherits the
  /// closing leg's `ruleProfileVersionId` (Feature Invariant 8; D-5 keeps
  /// the pin on the predecessor's version, so a mid-cycle edit never
  /// changes an open trade's rules) and its
  /// `acceptsAssignment` (Feature Invariant 8's own precedent, S-102) — no
  /// profile picker and no re-ask exists for a roll, contrast with the
  /// assignment flow's covered-call step, which asks fresh (S-125).
  /// [closeFee]/[openFee] are both optional (S-120) and land on the closing
  /// leg and the new leg respectively.
  Future<bool> confirmRoll(RollCandidate candidate, {Decimal? closeFee, Decimal? openFee, DateTime? now}) async {
    final leg = state.leg;
    if (leg == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final effectiveNow = now ?? DateTime.now();
      final result = await _repo.recordRoll(
        closingLegId: leg.id,
        closeDebitPerShare: candidate.buybackDebit,
        closeFee: closeFee,
        closedAt: effectiveNow,
        newLeg: NewLegInput(
          optionType: leg.optionType,
          strike: candidate.newStrike,
          expiration: candidate.newExpiry,
          contracts: leg.contracts,
          openedAt: effectiveNow,
          openCreditPerShare: candidate.newCredit,
          ruleProfileVersionId: leg.ruleProfileVersionId,
          openFee: openFee,
          acceptsAssignment: leg.acceptsAssignment,
        ),
      );

      // Phase 21/S-172: the closing leg's notifications cancel; the new
      // leg's schedule fresh from its own expiration.
      final scheduler = _ref.read(notificationSchedulerProvider);
      await scheduler.cancelForLeg(leg.id);
      final ticker = state.underlying?.ticker;
      if (ticker != null) {
        final milestones =
            _ref.read(preferencesControllerProvider).valueOrNull?.notificationMilestones ??
            const [21, 7, 0];
        await scheduler.scheduleForLeg(
          legId: result.newLeg.id,
          ticker: ticker,
          optionType: leg.optionType,
          strike: candidate.newStrike,
          expiration: candidate.newExpiry,
          milestones: milestones,
          now: effectiveNow,
        );
      }

      state = state.copyWith(isSubmitting: false, rolled: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'Could not record this roll: $e');
      return false;
    }
  }
}

/// The worse of the two bound checks on [candidate] (`hardReject` >
/// `softWarn` > `ok`) — `buybackDebit` against [leg]'s own strike, `newCredit`
/// against the candidate's new strike, both against [snapshot]'s stock price.
/// `null` (skip) when there is no [snapshot] yet.
CreditBoundResult? _worstBound(RollCandidate candidate, Leg leg, Snapshot? snapshot) {
  if (snapshot == null) return null;
  final debitCheck = checkCreditBound(
    value: candidate.buybackDebit,
    side: leg.optionType,
    spot: snapshot.underlyingPrice,
    strike: leg.strike,
  );
  final creditCheck = checkCreditBound(
    value: candidate.newCredit,
    side: leg.optionType,
    spot: snapshot.underlyingPrice,
    strike: candidate.newStrike,
  );
  if (debitCheck.level == CreditBoundLevel.hardReject) return debitCheck;
  if (creditCheck.level == CreditBoundLevel.hardReject) return creditCheck;
  if (debitCheck.level == CreditBoundLevel.softWarn) return debitCheck;
  if (creditCheck.level == CreditBoundLevel.softWarn) return creditCheck;
  return CreditBoundResult.ok;
}

final rollPlannerControllerProvider =
    StateNotifierProvider.family.autoDispose<RollPlannerController, RollPlannerState, String>((
      ref,
      legId,
    ) {
      final repo = ref.watch(wheelRepositoryProvider);
      return RollPlannerController(ref, repo, legId);
    });
