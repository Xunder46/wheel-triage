import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates/nearest_friday.dart';
import '../../core/money/total_per_contract.dart';
import '../../core/notifications/notification_scheduler.dart';
import '../../domain/models/leg.dart';
import '../../domain/rules/credit_bound.dart';
import '../../domain/rules/formulas.dart';
import '../../domain/rules/screener.dart';
import '../preferences/preferences_provider.dart';
import '../repository_providers.dart';
import 'record_save_service.dart';

/// `[21, 7, 0]` → `"21, 7 and 0"` — the Record screen's reminder line.
String humanList(List<int> values) {
  if (values.isEmpty) return '';
  if (values.length == 1) return '${values.first}';
  return '${values.sublist(0, values.length - 1).join(', ')} and ${values.last}';
}

/// The next four Fridays strictly after [now] — the four chips D-16 offers.
/// "Strictly after" is why a Friday today is never offered.
List<DateTime> nextFourFridays(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var first = today.add(const Duration(days: 1));
  while (!isFriday(first)) {
    first = first.add(const Duration(days: 1));
  }
  return [for (var i = 0; i < 4; i++) first.add(Duration(days: 7 * i))];
}

/// D-16's form. Every field starts unset; an incomplete form is a normal
/// state, not an error. The four Fridays are pure (`now` plus a calendar
/// walk), so they are derived in the constructor; the recent-ticker chips
/// need a repository read and arrive with [RecordController.load].
class RecordFormState {
  final String ticker;
  final OptionType side;
  final Decimal? strike;
  final DateTime? expiration;
  final Decimal? credit;
  final int contracts;

  /// Derived from [expiration] against the controller's own `now`, never
  /// `DateTime.now()` — the form's DTE must be deterministic under test.
  final int? dte;

  /// Optional, behind the disclosure. Blank persists as `null`, never zero.
  final Decimal? spot;
  final double? iv;
  final double? ivRank;
  final Decimal? openFee;

  final bool acceptsAssignment;
  final bool showOptional;
  final bool isSaving;
  final String? error;

  /// Set together with [error] when the save was blocked by the free tier's
  /// open-cycle limit (D-23/D-24). The screen shows [error] either way and
  /// opens the paywall from this, then clears it — the trigger is an event,
  /// not a status, so it must not survive a rebuild.
  final String? paywallTrigger;
  final bool saved;
  final String? confirmation;
  final List<String> recentTickers;
  final List<DateTime> fridayOptions;

  const RecordFormState({
    this.ticker = '',
    this.side = OptionType.put,
    this.strike,
    this.expiration,
    this.credit,
    this.contracts = 1,
    this.dte,
    this.spot,
    this.iv,
    this.ivRank,
    this.openFee,
    this.acceptsAssignment = true,
    this.showOptional = false,
    this.isSaving = false,
    this.error,
    this.paywallTrigger,
    this.saved = false,
    this.confirmation,
    this.recentTickers = const [],
    this.fridayOptions = const [],
  });

  /// Non-blocking warning surface, the same one the screener keeps: a
  /// non-Friday date is legitimate but worth flagging.
  bool get nonFridayWarning => expiration != null && !isFriday(expiration!);

  /// Required at save: ticker, strike, credit, expiration, contracts. A put
  /// needs no stock price (its bound is the strike).
  bool get hasEnoughToSave =>
      ticker.trim().isNotEmpty &&
      strike != null &&
      credit != null &&
      expiration != null &&
      contracts > 0;

  bool get hasEnoughForYield => strike != null && credit != null && expiration != null;

  RecordFormState copyWith({
    String? ticker,
    OptionType? side,
    Decimal? strike,
    bool clearStrike = false,
    DateTime? expiration,
    int? dte,
    Decimal? credit,
    bool clearCredit = false,
    int? contracts,
    Decimal? spot,
    bool clearSpot = false,
    double? iv,
    bool clearIv = false,
    double? ivRank,
    bool clearIvRank = false,
    Decimal? openFee,
    bool clearOpenFee = false,
    bool? acceptsAssignment,
    bool? showOptional,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? paywallTrigger,
    bool clearPaywallTrigger = false,
    bool? saved,
    String? confirmation,
    List<String>? recentTickers,
    List<DateTime>? fridayOptions,
  }) => RecordFormState(
    ticker: ticker ?? this.ticker,
    side: side ?? this.side,
    strike: clearStrike ? null : (strike ?? this.strike),
    expiration: expiration ?? this.expiration,
    dte: dte ?? this.dte,
    credit: clearCredit ? null : (credit ?? this.credit),
    contracts: contracts ?? this.contracts,
    spot: clearSpot ? null : (spot ?? this.spot),
    iv: clearIv ? null : (iv ?? this.iv),
    ivRank: clearIvRank ? null : (ivRank ?? this.ivRank),
    openFee: clearOpenFee ? null : (openFee ?? this.openFee),
    acceptsAssignment: acceptsAssignment ?? this.acceptsAssignment,
    showOptional: showOptional ?? this.showOptional,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
    paywallTrigger: (clearError || clearPaywallTrigger)
        ? null
        : (paywallTrigger ?? this.paywallTrigger),
    saved: saved ?? this.saved,
    confirmation: confirmation ?? this.confirmation,
    recentTickers: recentTickers ?? this.recentTickers,
    fridayOptions: fridayOptions ?? this.fridayOptions,
  );
}

/// D-16's form state. The credit bound, the yield and the capital figure are
/// derived here rather than in the screen (no rule logic in a widget); the
/// D-12 host line is a separate provider because it needs a repository read
/// keyed on (ticker, side) — see [callHostProvider].
class RecordController extends StateNotifier<RecordFormState> {
  RecordController(this._ref, {DateTime? now})
    : _now = now ?? DateTime.now(),
      super(RecordFormState(fridayOptions: nextFourFridays(now ?? DateTime.now())));

  final Ref _ref;
  final DateTime _now;

  /// Loads the recent-ticker chips and pre-selects the farthest of the four
  /// Fridays — the closest of them to the existing 30–45-day default window.
  Future<void> load() async {
    final repo = _ref.read(wheelRepositoryProvider);
    final legs = await repo.getAllLegs();

    final tickers = <String>[];
    for (final leg in legs.reversed) {
      final cycle = await repo.getCycle(leg.cycleId);
      if (cycle == null) continue;
      final underlying = await repo.getUnderlying(cycle.underlyingId);
      final ticker = underlying?.ticker;
      if (ticker == null || ticker.isEmpty || tickers.contains(ticker)) continue;
      tickers.add(ticker);
      if (tickers.length == 6) break;
    }

    final farthest = state.fridayOptions.isEmpty ? null : state.fridayOptions.last;
    state = state.copyWith(
      recentTickers: tickers,
      expiration: state.expiration ?? farthest,
      dte: state.dte ?? (farthest == null ? null : daysBetween(_now, farthest)),
    );
  }

  void setTicker(String value) => state = state.copyWith(ticker: value.toUpperCase());

  void setSide(OptionType value) => state = state.copyWith(side: value);

  void selectRecentTicker(String ticker) => setTicker(ticker);

  void setStrike(Decimal? value) =>
      state = value == null ? state.copyWith(clearStrike: true) : state.copyWith(strike: value);

  /// Stores the per-share value regardless of how the user thinks about it
  /// (Feature Invariant 21) — identical to the screener's own conversion.
  void setCredit(Decimal? value) {
    if (value == null) {
      state = state.copyWith(clearCredit: true);
      return;
    }
    final totalPerContract =
        _ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;
    state = state.copyWith(credit: perShareValue(value, totalPerContract: totalPerContract));
  }

  void setExpiration(DateTime value) =>
      state = state.copyWith(expiration: value, dte: daysBetween(_now, value));

  void setContracts(int value) => state = state.copyWith(contracts: value);

  void setSpot(Decimal? value) =>
      state = value == null ? state.copyWith(clearSpot: true) : state.copyWith(spot: value);

  void setIv(double? value) =>
      state = value == null ? state.copyWith(clearIv: true) : state.copyWith(iv: value);

  void setIvRank(double? value) =>
      state = value == null ? state.copyWith(clearIvRank: true) : state.copyWith(ivRank: value);

  void setOpenFee(Decimal? value) =>
      state = value == null ? state.copyWith(clearOpenFee: true) : state.copyWith(openFee: value);

  void setAcceptsAssignment(bool value) => state = state.copyWith(acceptsAssignment: value);

  void setShowOptional(bool value) => state = state.copyWith(showOptional: value);

  /// Feature Invariant 20's no-arbitrage bound. A put is checked against its
  /// strike with no stock price needed; a call's bound is the stock price, so
  /// with no stock price the check is **skipped** rather than guessing the
  /// strike — `null` here means "not checked", never "passed".
  CreditBoundResult? get creditBound {
    final form = state;
    if (form.strike == null || form.credit == null) return null;
    if (form.side == OptionType.call && form.spot == null) return null;
    return checkCreditBound(
      value: form.credit!,
      side: form.side,
      spot: form.spot ?? Decimal.zero, // unread by checkCreditBound when side is put
      strike: form.strike!,
    );
  }

  double? get annualisedYield {
    final form = state;
    if (!form.hasEnoughForYield || (creditBound?.blocks ?? false)) return null;
    final days = form.dte;
    if (days == null || days <= 0) return null;
    return screenerAnnualisedYield(credit: form.credit!, strike: form.strike!, dteAtOpen: days);
  }

  /// `strike × 100 × contracts` (D-16) — the cash the position ties up.
  Decimal? get capitalCommitted {
    final form = state;
    if (form.strike == null) return null;
    return form.strike! * Decimal.fromInt(100) * Decimal.fromInt(form.contracts);
  }

  /// The milestones that will actually fire for this leg — the same
  /// "already passed" predicate `NotificationScheduler.scheduleForLeg` uses,
  /// so the line names reality rather than the preference's full set.
  List<int> get firingMilestones {
    final form = state;
    if (form.expiration == null) return const [];
    final milestones =
        _ref.read(preferencesControllerProvider).valueOrNull?.notificationMilestones ??
        const [21, 7, 0];
    return milestones
        .where(
          (m) =>
              scheduledDateTimeFor(expiration: form.expiration!, milestoneDte: m).isAfter(_now),
        )
        .toList();
  }

  String get reminderLine {
    final firing = firingMilestones;
    if (firing.isEmpty) return 'No reminders will fire for this expiration.';
    return 'Reminders: ${humanList(firing)} days before expiration.';
  }

  /// D-19's one save path. On a refusal the form keeps every value (S-234).
  Future<bool> save() async {
    final form = state;
    if (!form.hasEnoughToSave) {
      state = form.copyWith(
        error: 'Enter ticker, strike, credit, expiration, and contracts first.',
        // Defence in depth (D-30/R12): only the gate's own refusal may leave a
        // trigger behind, so no other exit path can reopen the paywall.
        clearPaywallTrigger: true,
      );
      return false;
    }
    final bound = creditBound;
    if (bound != null && bound.blocks) {
      state = form.copyWith(error: bound.message, clearPaywallTrigger: true);
      return false;
    }

    state = form.copyWith(isSaving: true, clearError: true);
    try {
      final result = await _ref
          .read(recordSaveServiceProvider)
          .save(
            ticker: form.ticker,
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
            now: _now,
          );

      if (result.isRefused) {
        state = state.copyWith(
          isSaving: false,
          error: result.refusalReason,
          clearPaywallTrigger: true,
        );
        return false;
      }

      if (result.isPaywallRequired) {
        state = state.copyWith(
          isSaving: false,
          error: result.trigger,
          paywallTrigger: result.trigger,
        );
        return false;
      }

      final side = form.side == OptionType.call ? 'call' : 'put';
      state = state.copyWith(
        isSaving: false,
        saved: true,
        confirmation:
            'Recorded \$${form.strike!.toStringAsFixed(2)} ${result.ticker} $side '
            'expiring ${_shortDate(form.expiration!)}.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Could not record this trade: $e',
        clearPaywallTrigger: true,
      );
      return false;
    }
  }

  /// The D-24 refusal line the gate produced on the last save, if the save
  /// was refused for the free tier's limit (D-30). `null` in every other
  /// case, including a save that failed for another reason.
  String? get paywallTrigger => state.paywallTrigger;

  /// Consumes the paywall trigger once the screen has opened the paywall, so
  /// a later failure that is not the gate's cannot reopen it (D-30, R12).
  void clearPaywallTrigger() => state = state.copyWith(clearPaywallTrigger: true);

  void reset() {
    state = RecordFormState(fridayOptions: nextFourFridays(_now));
  }

  static String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

final recordControllerProvider =
    StateNotifierProvider.autoDispose<RecordController, RecordFormState>(
      (ref) => RecordController(ref),
    );

/// D-12's host-cycle line for the form's current ticker and side. A
/// repository read, so it lives here rather than in the form state; the
/// screen watches it and renders either the explanation (S-233) or the
/// refusal (S-234/S-235) — never a bare verdict.
final callHostProvider = FutureProvider.autoDispose<CallHostResolution?>((ref) async {
  final form = ref.watch(recordControllerProvider);
  if (form.side != OptionType.call) return null;
  final ticker = form.ticker.trim();
  if (ticker.isEmpty) return null;
  return ref.watch(recordSaveServiceProvider).resolveCallHost(ticker);
});
