import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/total_per_contract.dart';
import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/share_lot.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/basis.dart';
import '../../domain/rules/credit_bound.dart';
import '../notifications/notification_providers.dart';
import '../preferences/preferences_provider.dart';
import '../repository_providers.dart';

/// §5.4's assignment flow. Dispatches on the leg's `optionType`
/// (Feature Invariant 14): a **put** leg walks the four §5.4 steps
/// (confirm shares/strike -> create `ShareLot` + show both basis numbers ->
/// cycle transitions to `holdingShares` -> offer a covered call); a
/// **call** leg is "called away" (S-029) — the cycle closes instead.
class AssignmentFlowState {
  final bool isLoading;
  final String? error;
  final Leg? leg;
  final WheelCycle? cycle;
  final bool isSubmitting;
  final bool completed;
  final ShareLot? createdShareLot;
  final Decimal? wheelBasisValue;
  final Decimal? taxBasisValue;
  final bool coveredCallOpened;

  /// A non-blocking credit-bound warning from the covered-call credit field
  /// (Feature Invariant 20's soft-warn tier) — distinct from [error].
  final String? coveredCallWarning;

  const AssignmentFlowState({
    this.isLoading = true,
    this.error,
    this.leg,
    this.cycle,
    this.isSubmitting = false,
    this.completed = false,
    this.createdShareLot,
    this.wheelBasisValue,
    this.taxBasisValue,
    this.coveredCallOpened = false,
    this.coveredCallWarning,
  });

  bool get isPutSide => leg?.optionType == OptionType.put;

  AssignmentFlowState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    Leg? leg,
    WheelCycle? cycle,
    bool? isSubmitting,
    bool? completed,
    ShareLot? createdShareLot,
    Decimal? wheelBasisValue,
    Decimal? taxBasisValue,
    bool? coveredCallOpened,
    String? coveredCallWarning,
    bool clearCoveredCallWarning = false,
  }) => AssignmentFlowState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    leg: leg ?? this.leg,
    cycle: cycle ?? this.cycle,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    completed: completed ?? this.completed,
    createdShareLot: createdShareLot ?? this.createdShareLot,
    wheelBasisValue: wheelBasisValue ?? this.wheelBasisValue,
    taxBasisValue: taxBasisValue ?? this.taxBasisValue,
    coveredCallOpened: coveredCallOpened ?? this.coveredCallOpened,
    coveredCallWarning: clearCoveredCallWarning ? null : (coveredCallWarning ?? this.coveredCallWarning),
  );
}

class AssignmentFlowController extends StateNotifier<AssignmentFlowState> {
  AssignmentFlowController(this._ref, this._repo, this._legId) : super(const AssignmentFlowState()) {
    ready = _load();
  }

  final Ref _ref;
  final WheelRepository _repo;
  final String _legId;

  /// Completes once the initial leg/cycle fetch has settled — see
  /// `RollPlannerController.ready` for why this exists.
  late final Future<void> ready;

  Future<void> _load() async {
    final leg = await _repo.getLeg(_legId);
    final cycle = leg == null ? null : await _repo.getCycle(leg.cycleId);
    state = state.copyWith(
      isLoading: false,
      leg: leg,
      cycle: cycle,
      error: leg == null ? 'This position no longer exists.' : null,
    );
  }

  /// Put-side assignment (§5.4 steps 1-3, S-026): confirms shares acquired
  /// (`100 x contracts`) and the strike, creates the `ShareLot`, and the
  /// repository transitions the cycle to `holdingShares`. Computes both
  /// basis figures live for display (step 2) — never persisted
  /// (Feature Invariant 12) — contract-weighted per leg throughout (Feature
  /// Invariant 25): `wheelBasis`/`taxBasis` take the raw put legs plus the
  /// just-created `ShareLot`, never a pre-summed per-share total.
  Future<bool> confirmPutAssignment({
    required Decimal assignmentStrike,
    required int contracts,
    Decimal? closeFee,
    DateTime? assignedAt,
  }) async {
    final leg = state.leg;
    if (leg == null || leg.optionType != OptionType.put) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final effectiveNow = assignedAt ?? DateTime.now();
      final result = await _repo.recordAssignment(
        legId: leg.id,
        closeFee: closeFee,
        shareLot: NewShareLotInput(
          assignedAt: effectiveNow,
          assignmentStrike: assignmentStrike,
          contracts: contracts,
        ),
      );

      // Phase 21/S-171: the assigned put leg is closed -- its notifications
      // cancel. (The covered call this cycle opens next is scheduled
      // separately, from openCoveredCall, since it isn't created here.)
      await _ref.read(notificationSchedulerProvider).cancelForLeg(leg.id);

      final cycleLegs = await _repo.getLegsForCycle(leg.cycleId);
      final putLegs = cycleLegs.where((l) => l.optionType == OptionType.put).toList();
      final wheel = wheelBasis(
        putLegs: putLegs,
        shareLot: result.shareLot,
        callLegsSinceAssignment: const [],
      );
      final tax = taxBasis(putLegs: putLegs, shareLot: result.shareLot);

      state = state.copyWith(
        isSubmitting: false,
        completed: true,
        cycle: result.cycle,
        createdShareLot: result.shareLot,
        wheelBasisValue: wheel,
        taxBasisValue: tax,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'Could not record assignment: $e');
      return false;
    }
  }

  /// Call-side assignment / "called away" (S-029, Feature Invariant 14):
  /// closes the call leg, consumes the `ShareLot`, and ends the cycle
  /// (`outcome -> calledAway`).
  Future<bool> confirmCallAway({Decimal? closeFee, DateTime? closedAt}) async {
    final leg = state.leg;
    if (leg == null || leg.optionType != OptionType.call) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final effectiveNow = closedAt ?? DateTime.now();
      final result = await _repo.recordCallAway(
        legId: leg.id,
        closeFee: closeFee,
        closedAt: effectiveNow,
      );
      // Phase 21/S-171: the called-away call leg is closed (and the cycle
      // with it) -- its notifications cancel.
      await _ref.read(notificationSchedulerProvider).cancelForLeg(leg.id);
      state = state.copyWith(isSubmitting: false, completed: true, cycle: result.cycle);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'Could not record call-away: $e');
      return false;
    }
  }

  /// §5.4 step 4: open the covered call right after a put assignment. The
  /// wheel-basis strike floor shown in the UI is advisory only
  /// (Feature Invariant 13) — this method does not enforce it, [strike] is
  /// whatever the caller passes.
  ///
  /// [acceptsAssignment] is asked fresh for this new leg (S-125) — it is
  /// NEVER inherited from the just-closed put leg's own value, unlike a
  /// roll's inheritance (S-102): the put and the covered call are different
  /// positions with potentially different answers to "happy to be assigned
  /// on this one?".
  ///
  /// Applies the "total per contract" preference (Feature Invariant 21) to
  /// [openCreditPerShare] first, then the no-arbitrage bound (Feature
  /// Invariant 20) against the just-assigned put leg's own latest snapshot
  /// (this screen collects no "current stock price" input of its own) —
  /// skipped entirely with no reject/warn when that leg has no snapshot yet
  /// (S-057).
  Future<bool> openCoveredCall({
    required Decimal strike,
    required DateTime expiration,
    required Decimal openCreditPerShare,
    required int contracts,
    Decimal? openFee,
    bool acceptsAssignment = true,
    DateTime? openedAt,
  }) async {
    final leg = state.leg;
    if (leg == null) return false;
    state = state.copyWith(clearError: true, clearCoveredCallWarning: true);
    try {
      final totalPerContract =
          _ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;
      final perShareCredit = perShareValue(openCreditPerShare, totalPerContract: totalPerContract);

      final putSnapshot = await _repo.getLatestSnapshotForLeg(leg.id);
      if (putSnapshot != null) {
        final bound = checkCreditBound(
          value: perShareCredit,
          side: OptionType.call,
          spot: putSnapshot.underlyingPrice,
          strike: strike,
        );
        if (bound.blocks) {
          state = state.copyWith(error: bound.message);
          return false;
        }
        state = state.copyWith(
          coveredCallWarning: bound.level == CreditBoundLevel.softWarn ? bound.message : null,
          clearCoveredCallWarning: bound.level != CreditBoundLevel.softWarn,
        );
      }

      final effectiveOpenedAt = openedAt ?? DateTime.now();
      final newLeg = await _repo.openNextLeg(
        cycleId: leg.cycleId,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: strike,
          expiration: expiration,
          contracts: contracts,
          openedAt: effectiveOpenedAt,
          openCreditPerShare: perShareCredit,
          ruleProfileVersionId: leg.ruleProfileVersionId,
          openFee: openFee,
          acceptsAssignment: acceptsAssignment,
        ),
      );

      // Phase 21/S-170: the covered call is a fresh leg-creation site too --
      // schedule its own notifications from its own expiration.
      final cycle = state.cycle;
      if (cycle != null) {
        final underlying = await _repo.getUnderlying(cycle.underlyingId);
        if (underlying != null) {
          final milestones =
              _ref.read(preferencesControllerProvider).valueOrNull?.notificationMilestones ??
              const [21, 7, 0];
          await _ref
              .read(notificationSchedulerProvider)
              .scheduleForLeg(
                legId: newLeg.id,
                ticker: underlying.ticker,
                optionType: OptionType.call,
                strike: strike,
                expiration: expiration,
                milestones: milestones,
                now: effectiveOpenedAt,
              );
        }
      }

      state = state.copyWith(coveredCallOpened: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Could not open the covered call: $e');
      return false;
    }
  }
}

final assignmentFlowControllerProvider =
    StateNotifierProvider.family
        .autoDispose<AssignmentFlowController, AssignmentFlowState, String>((ref, legId) {
          final repo = ref.watch(wheelRepositoryProvider);
          return AssignmentFlowController(ref, repo, legId);
        });
