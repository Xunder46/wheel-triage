import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates/nearest_friday.dart';
import '../../core/money/total_per_contract.dart';
import '../../domain/models/leg.dart';
import '../../domain/rules/credit_bound.dart';
import '../../domain/rules/formulas.dart';
import '../../domain/rules/rule_profile.dart';
import '../../domain/rules/screener.dart';
import '../preferences/preferences_provider.dart';
import '../record/record_save_service.dart';
import '../rule_profiles/rule_profile_providers.dart';

/// §5.1's entry-screener form. Every field is nullable/unset until the user
/// types something — an incomplete form is a normal state, not an error.
///
/// [expiration] is the persisted source of truth (brief-followup A5,
/// Feature Invariant 22) — the date picker's own value, never derived from a
/// typed DTE. [dte] is a read-only, always-derived convenience mirror of
/// [expiration] (recomputed by the controller every time [expiration]
/// changes), so the yield/one-sigma formulas don't each have to re-derive
/// it from a "now" the form itself doesn't otherwise carry.
class ScreenerFormState {
  final String ticker;
  final OptionType side;
  final Decimal? strike;
  final Decimal? spot;
  final Decimal? credit;
  final DateTime? expiration;
  final int? dte;
  final double? iv;
  final double? ivRank;
  final int contracts;

  /// Total fee for "Track this position" (S-120) — optional, `null` means
  /// "not recorded", never coerced to zero (Phase 15).
  final Decimal? openFee;

  /// Whether the user is willing to be assigned rather than roll (Gate 2,
  /// S-123) — defaults on, editable via a toggle on this form.
  final bool acceptsAssignment;
  final bool isSaving;
  final String? error;
  final bool tracked;

  const ScreenerFormState({
    this.ticker = '',
    this.side = OptionType.put,
    this.strike,
    this.spot,
    this.credit,
    this.expiration,
    this.dte,
    this.iv,
    this.ivRank,
    this.contracts = 1,
    this.openFee,
    this.acceptsAssignment = true,
    this.isSaving = false,
    this.error,
    this.tracked = false,
  });

  /// Non-blocking warning surface (Feature Invariant 22) — a picked date
  /// that isn't a Friday is legitimate (index/month-end/weekly products)
  /// but worth flagging.
  bool get nonFridayWarning => expiration != null && !isFriday(expiration!);

  /// Enough to compute the yield/gates/score outputs (§5.1's "Outputs").
  /// Strike distance and cushion also need [spot], checked separately.
  bool get hasEnoughForYield => strike != null && credit != null && expiration != null;

  /// Enough to persist a `WheelCycle` + first `Leg` ("Track this position").
  bool get hasEnoughToTrack =>
      ticker.trim().isNotEmpty &&
      strike != null &&
      spot != null &&
      credit != null &&
      expiration != null;

  ScreenerFormState copyWith({
    String? ticker,
    OptionType? side,
    Decimal? strike,
    bool clearStrike = false,
    Decimal? spot,
    bool clearSpot = false,
    Decimal? credit,
    bool clearCredit = false,
    DateTime? expiration,
    int? dte,
    double? iv,
    bool clearIv = false,
    double? ivRank,
    bool clearIvRank = false,
    int? contracts,
    Decimal? openFee,
    bool clearOpenFee = false,
    bool? acceptsAssignment,
    bool? isSaving,
    String? error,
    bool clearError = false,
    bool? tracked,
  }) => ScreenerFormState(
    ticker: ticker ?? this.ticker,
    side: side ?? this.side,
    strike: clearStrike ? null : (strike ?? this.strike),
    spot: clearSpot ? null : (spot ?? this.spot),
    credit: clearCredit ? null : (credit ?? this.credit),
    expiration: expiration ?? this.expiration,
    dte: dte ?? this.dte,
    iv: clearIv ? null : (iv ?? this.iv),
    ivRank: clearIvRank ? null : (ivRank ?? this.ivRank),
    contracts: contracts ?? this.contracts,
    openFee: clearOpenFee ? null : (openFee ?? this.openFee),
    acceptsAssignment: acceptsAssignment ?? this.acceptsAssignment,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
    tracked: tracked ?? this.tracked,
  );
}

/// The §5.1/§4.5 computed outputs: annualised yield, one-sigma move, strike
/// distance in dollars and sigmas, the two hard gates, and the 0-9 sorting
/// score with its three components. Every field is nullable — a partially
/// filled form produces partial outputs, never a crash or a `NaN`.
///
/// [creditBound] carries the no-arbitrage bound check (brief-followup A2,
/// Feature Invariant 20) on the credit field. When it hard-rejects, every
/// other field here is left null — the outputs section renders blocked, not
/// a number computed from an arithmetically impossible credit (S-053).
class ScreenerOutputs {
  final double? annualisedYield;
  final Decimal? oneSigmaMove;
  final Decimal? strikeDistanceDollars;
  final double? cushionSigmas;
  final ScreenerGates? gates;
  final int? yieldScore;
  final int? ivRankScore;
  final int? cushionScore;
  final int? sortingScore;
  final CreditBoundResult? creditBound;

  const ScreenerOutputs({
    this.annualisedYield,
    this.oneSigmaMove,
    this.strikeDistanceDollars,
    this.cushionSigmas,
    this.gates,
    this.yieldScore,
    this.ivRankScore,
    this.cushionScore,
    this.sortingScore,
    this.creditBound,
  });

  bool get isBlocked => creditBound?.blocks ?? false;

  static const empty = ScreenerOutputs();
}

class ScreenerController extends StateNotifier<ScreenerFormState> {
  ScreenerController(this._ref, {DateTime? now})
    : _now = now ?? DateTime.now(),
      super(const ScreenerFormState()) {
    _applyDefaultExpiration();
  }

  final Ref _ref;
  final DateTime _now;

  void _applyDefaultExpiration() {
    final exp = defaultExpiration(_now);
    state = state.copyWith(expiration: exp, dte: dte(exp, _now));
  }

  void setTicker(String value) => state = state.copyWith(ticker: value.toUpperCase());

  void setSide(OptionType value) => state = state.copyWith(side: value);

  void setStrike(Decimal? value) =>
      state = value == null ? state.copyWith(clearStrike: true) : state.copyWith(strike: value);

  void setSpot(Decimal? value) =>
      state = value == null ? state.copyWith(clearSpot: true) : state.copyWith(spot: value);

  /// Stores the per-share value regardless of how the user thinks about it
  /// (Feature Invariant 21): when the "total per contract" preference is on,
  /// [value] is what the user typed as the *total* for one contract, and
  /// this divides by 100 before it ever lands in [ScreenerFormState.credit]
  /// — never leaving the conversion implicit at display time only (S-052).
  void setCredit(Decimal? value) {
    if (value == null) {
      state = state.copyWith(clearCredit: true);
      return;
    }
    final totalPerContract =
        _ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;
    state = state.copyWith(credit: perShareValue(value, totalPerContract: totalPerContract));
  }

  /// The date picker's own value (Feature Invariant 22) — the persisted
  /// source of truth for `Leg.expiration`.
  void setExpiration(DateTime value) =>
      state = state.copyWith(expiration: value, dte: dte(value, _now));

  /// The screener's convenience DTE field (Feature Invariant 22): typing a
  /// number of days *moves the picker* to `today + N` days — the nearest
  /// actual calendar date, not Friday-snapped — rather than writing a DTE
  /// value anywhere on its own. `null` (unparsed/cleared input) leaves
  /// [ScreenerFormState.expiration] untouched.
  void setDteConvenience(int? days) {
    if (days == null) return;
    setExpiration(_now.add(Duration(days: days)));
  }

  void setIv(double? value) =>
      state = value == null ? state.copyWith(clearIv: true) : state.copyWith(iv: value);

  void setIvRank(double? value) =>
      state = value == null ? state.copyWith(clearIvRank: true) : state.copyWith(ivRank: value);

  void setContracts(int value) => state = state.copyWith(contracts: value);

  /// S-120: optional, blank persists `null`, never `0`.
  void setOpenFee(Decimal? value) =>
      state = value == null ? state.copyWith(clearOpenFee: true) : state.copyWith(openFee: value);

  /// S-123: the screener leg-creation form's toggle, default on.
  void setAcceptsAssignment(bool value) => state = state.copyWith(acceptsAssignment: value);

  /// "Just calculating" (§5.1): explicitly does not persist anything. This
  /// method exists so the button has its own call site, distinct from
  /// [trackThisPosition] — the outputs themselves (including the credit-bound
  /// block) are already computed reactively by `screenerOutputsProvider`
  /// (S-020, S-053).
  void justCalculate() => state = state.copyWith(clearError: true);

  /// "Track this position" (§5.1): creates a `WheelCycle` + first `Leg`.
  /// Returns `true` on success. S-020's persisted shape: one `Underlying`,
  /// one `WheelCycle` (`status = sellingPuts`), one `Leg` (`sequence = 0`,
  /// `ruleProfileVersionId` = the Standard profile's current version). A
  /// hard-reject credit
  /// bound blocks the write entirely — zero rows created (S-050, S-053).
  Future<bool> trackThisPosition({DateTime? now}) async {
    final form = state;
    if (!form.hasEnoughToTrack) {
      state = form.copyWith(error: 'Enter ticker, strike, stock price, credit, and expiration first.');
      return false;
    }

    final bound = checkCreditBound(
      value: form.credit!,
      side: form.side,
      spot: form.spot!,
      strike: form.strike!,
    );
    if (bound.blocks) {
      state = form.copyWith(error: bound.message);
      return false;
    }

    final effectiveNow = now ?? _now;
    state = form.copyWith(isSaving: true, clearError: true);
    try {
      // D-19: the screener's "Track this position" and Record's save are the
      // same entry point, so a call on a ticker with no shares on record is
      // refused here with the D-12 line rather than opening a put-shaped
      // cycle holding a call leg. The put side is unchanged: `save` still
      // creates one underlying, one `sellingPuts` cycle and its first leg,
      // then schedules that leg's reminders (Phase 21/S-170's lazy
      // permission request lives inside `NotificationScheduler`).
      final result = await _ref
          .read(recordSaveServiceProvider)
          .save(
            ticker: form.ticker.trim(),
            side: form.side,
            strike: form.strike!,
            expiration: form.expiration!,
            contracts: form.contracts,
            openCreditPerShare: form.credit!,
            ivAtOpen: form.iv,
            ivRankAtOpen: form.ivRank,
            underlyingPriceAtOpen: form.spot,
            openFee: form.openFee,
            acceptsAssignment: form.acceptsAssignment,
            now: effectiveNow,
          );

      if (result.isRefused) {
        state = state.copyWith(isSaving: false, error: result.refusalReason);
        return false;
      }

      state = state.copyWith(isSaving: false, tracked: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: 'Could not save this position: $e');
      return false;
    }
  }

  void reset() {
    state = const ScreenerFormState();
    _applyDefaultExpiration();
  }
}

final screenerControllerProvider =
    StateNotifierProvider.autoDispose<ScreenerController, ScreenerFormState>(
      (ref) => ScreenerController(ref),
    );

/// Derived, reactive outputs for whatever is currently in the form. A
/// separate provider (rather than a getter on the controller) so widgets
/// that only care about outputs don't have to watch the whole form state to
/// stay up to date.
final screenerOutputsProvider = Provider.autoDispose<ScreenerOutputs>((ref) {
  final form = ref.watch(screenerControllerProvider);
  if (!form.hasEnoughForYield) return ScreenerOutputs.empty;

  // No-arbitrage credit bound (Feature Invariant 20). The call side's bound
  // is `spot`, so it is skipped until a stock price is entered; the put
  // side's bound is `strike`, always non-null here since `hasEnoughForYield`
  // (checked above) already requires it -- `checkCreditBound` never reads
  // `spot` on the put branch, so a missing stock price must not suppress
  // the put-side check the way it correctly suppresses the call-side one.
  // Found in review: a put entered with credit > strike but no stock price
  // yet was rendering a real, arithmetically-impossible yield instead of
  // the required blocked state (no S-050/S-051 fixture row is put-side
  // with spot unset, which is why this escaped Phase 10).
  CreditBoundResult? creditBound;
  final isCall = form.side == OptionType.call;
  if (!isCall || form.spot != null) {
    creditBound = checkCreditBound(
      value: form.credit!,
      side: form.side,
      spot: form.spot ?? Decimal.zero, // unread by checkCreditBound when side is put
      strike: form.strike!,
    );
  }
  if (creditBound != null && creditBound.blocks) {
    // Hard reject suppresses the entire outputs section (S-053) -- an
    // arithmetically impossible credit must never render a real yield/score.
    return ScreenerOutputs(creditBound: creditBound);
  }

  final annualisedYield = screenerAnnualisedYield(
    credit: form.credit!,
    strike: form.strike!,
    dteAtOpen: form.dte!,
  );

  Decimal? oneSigma;
  double? cushion;
  Decimal? distanceDollars;
  if (form.spot != null) {
    oneSigma = oneSigmaMove(spot: form.spot!, iv: form.iv, dte: form.dte!);
    cushion = cushionSigmas(strike: form.strike!, spot: form.spot!, oneSigmaMove: oneSigma);
    distanceDollars = (form.strike! - form.spot!).abs();
  }

  final profile = ref.watch(currentRuleProfileProvider).valueOrNull ?? RuleProfile.standard;
  final gates = form.ivRank == null
      ? null
      : screenerHardGates(ivRank: form.ivRank!, annualisedYield: annualisedYield, profile: profile);

  final yieldScore = screenerYieldScore(annualisedYield);
  final ivRankScore = form.ivRank == null ? null : screenerIvRankScore(form.ivRank!);
  final cushionScore = cushion == null ? null : screenerCushionScore(cushion);
  final sortingScore = (ivRankScore != null && cushionScore != null)
      ? yieldScore + ivRankScore + cushionScore
      : null;

  return ScreenerOutputs(
    annualisedYield: annualisedYield,
    oneSigmaMove: oneSigma,
    strikeDistanceDollars: distanceDollars,
    cushionSigmas: cushion,
    gates: gates,
    yieldScore: yieldScore,
    ivRankScore: ivRankScore,
    cushionScore: cushionScore,
    sortingScore: sortingScore,
    creditBound: creditBound,
  );
});
