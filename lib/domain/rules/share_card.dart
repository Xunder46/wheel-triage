import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import '../models/wheel_cycle.dart';
import 'cycle_pnl.dart' show CyclePnl, returnOnCapital;
import 'journal_aggregates.dart' show averageDaysInCycle, medianPremiumCapturePct;
import 'premium_collected.dart' show inPeriod, monthPeriodContaining;

/// `docs/brief-pro.md` D-P15 / Pro Wave 3 D-47…D-52: the month the share card
/// covers, its five figures, and the copy it renders. Pure, zero Flutter
/// imports, zero I/O; `now` is a parameter (`docs/conventions.md` §3).
///
/// The card is a *descriptive* summary of cycles the user already closed. It
/// names no security as a suggestion, pairs no action verb with anything and
/// carries no praise, streak or badge (conventions §4) — the figures are
/// facts about a month that has already happened.

/// One cycle as the card reads it: the cycle, its ticker, its legs, and its
/// already-computed P&L. The caller assembles these from
/// `cycle_pnl.computeCyclePnl` (`lib/state/journal/`), so this file never
/// re-derives a cycle's own P&L and cannot disagree with the Journal about it.
typedef ShareCardCycle = ({WheelCycle cycle, String ticker, List<Leg> legs, CyclePnl pnl});

/// The month the card covers (D-47): the calendar month containing [now],
/// which is the same period Today's "Net premium · month" tile uses, so the
/// strip and the card cannot disagree about which month "this month" is.
({DateTime start, DateTime end}) cardMonthPeriod(DateTime now) => monthPeriodContaining(now);

/// Whether [cycle] belongs to the month containing [now] (D-47).
///
/// A cycle belongs by its **end date**, inclusive on both ends, through the
/// same [inPeriod] the premium sum uses — so a cycle closed on the 1st and one
/// closed on the month's last day are both in, and one closed the day before
/// is out. The cycle, not the leg, is the unit: a roll spanning the boundary
/// lands in the month its final leg closed.
///
/// A `closed` cycle with a null `endedAt` is in **no** month. The month is
/// defined by the end date and there is no second date to fall back to;
/// guessing `startedAt` would put a cycle on a card for a month in which
/// nothing was closed. A cycle that is not `closed` is out even when it
/// carries an end date.
bool inCardMonth({required WheelCycle cycle, required DateTime now}) {
  if (cycle.status != WheelCycleStatus.closed) return false;
  final endedAt = cycle.endedAt;
  if (endedAt == null) return false;
  final period = cardMonthPeriod(now);
  return inPeriod(endedAt, period.start, period.end);
}

/// The month's cycles (D-47), in the order supplied — the card lists figures,
/// not cycles, so it never needs an order of its own.
List<ShareCardCycle> cyclesInCardMonth({required List<ShareCardCycle> cycles, required DateTime now}) =>
    cycles.where((entry) => inCardMonth(cycle: entry.cycle, now: now)).toList();

/// The card's five figures (D-49), over one month's cycles.
class ShareCardFigures {
  /// D-48: `returnOnCapital` called **once on the two sums** — `Σ net result
  /// ÷ Σ peak capital committed`, before fees. An average of per-cycle
  /// percentages would weight a small cycle equally with a large one.
  final double returnOnCapitalPct;

  /// How many cycles closed in the month.
  final int cyclesClosed;

  /// How many of them closed with `netResult > 0`, **strictly** — the same
  /// rule `journal_aggregates.winRate` uses, so the card cannot report
  /// `4 of 5` while the Journal's win rate disagrees for the same set. A
  /// cycle that closed at exactly zero is not positive.
  final int closedPositive;

  /// Whole days, half-up. `null` when the month has no cycles: there is no
  /// average of nothing, and `0` would be a claim about a month that has not
  /// happened.
  final int? averageDaysInCycle;

  /// The **median**, never a mean (Feature Invariant 29), over every leg of
  /// the month's cycles — the same population the Journal's own figure uses,
  /// so the two agree. `null` when no leg has a computable capture; the card
  /// renders `--` rather than a `0%` it did not measure.
  final double? medianPremiumCapturePct;

  const ShareCardFigures({
    required this.returnOnCapitalPct,
    required this.cyclesClosed,
    required this.closedPositive,
    required this.averageDaysInCycle,
    required this.medianPremiumCapturePct,
  });

  /// `4 of 5` — the count is never rendered without its denominator, since a
  /// bare `4` on a card with no month context says nothing.
  String get closedPositiveText => '$closedPositive of $cyclesClosed';
}

/// The month's five figures (D-48, D-49).
ShareCardFigures shareCardFigures(List<ShareCardCycle> cycles) {
  var netResultSum = Decimal.zero;
  var peakCapitalSum = Decimal.zero;
  var closedPositive = 0;
  final daysHeld = <int>[];
  final legs = <Leg>[];

  for (final entry in cycles) {
    netResultSum += entry.pnl.netResult;
    peakCapitalSum += entry.pnl.peakCapitalCommitted;
    if (entry.pnl.netResult > Decimal.zero) closedPositive++;
    daysHeld.add(entry.pnl.daysHeld);
    legs.addAll(entry.legs);
  }

  return ShareCardFigures(
    returnOnCapitalPct: returnOnCapital(netResult: netResultSum, peakCapitalCommitted: peakCapitalSum),
    cyclesClosed: cycles.length,
    closedPositive: closedPositive,
    averageDaysInCycle: cycles.isEmpty ? null : averageDaysInCycle(daysHeld).round(),
    medianPremiumCapturePct: medianPremiumCapturePct(legs),
  );
}

/// The month's fee gap (D-50): the summed per-cycle [CyclePnl.feeGapCount] and
/// whether any cycle in the month has one.
///
/// `hasFeeGap` is true iff a **closed** leg lacks its `closeFee`; both halves
/// come from `cycle_pnl.dart` and are unchanged. The sum is of the per-cycle
/// counts rather than of the month's legs, so the card cannot double-count a
/// leg through a cycle it is already counted in.
({bool hasFeeGap, int feeGapCount}) monthFeeGap(List<ShareCardCycle> cycles) => (
  hasFeeGap: cycles.any((entry) => entry.pnl.hasFeeGap),
  feeGapCount: cycles.fold(0, (sum, entry) => sum + entry.pnl.feeGapCount),
);

/// D-50's clause, with its leading space so it can be appended to a sentence
/// that already ends in a full stop: ` Before fees: 3 closed legs have no fee
/// recorded.`
///
/// With no gap the clause is **absent** — not "Fees included", which would be
/// a claim the app has not verified for every leg in the month. The count
/// decides singular/plural, so `1 closed leg has no fee recorded`.
String beforeFeesClause({required bool hasFeeGap, required int feeGapCount}) {
  if (!hasFeeGap) return '';
  final noun = feeGapCount == 1 ? 'closed leg has' : 'closed legs have';
  return ' Before fees: $feeGapCount $noun no fee recorded.';
}

/// D-51's definition paragraph: the definition **on the card**, naming the
/// month so a shared image is unambiguous a year later.
///
/// [monthYear] is a rendered string (`format.monthYearText`) rather than a
/// `DateTime`: the rules layer may import only `lib/domain/models/`
/// (`docs/conventions.md` §2), so the one full-month formatter lives in
/// `lib/core/format.dart` and its output is passed in. A caller that already
/// has the calendar header's own `monthYearText` therefore cannot render two
/// spellings of the same month.
String shareCardDefinitionLine({required String monthYear, required List<ShareCardCycle> cycles}) {
  final gap = monthFeeGap(cycles);
  return 'Return on capital: net result ÷ peak capital committed, over cycles closed in '
      '$monthYear.${beforeFeesClause(hasFeeGap: gap.hasFeeGap, feeGapCount: gap.feeGapCount)}';
}

/// D-52's optional ticker line: the month's tickers, **deduplicated and
/// A–Z**, joined by ` · `. Empty when the month has no cycles, so the caller
/// renders no line rather than a bare separator.
String cardTickerLine(List<ShareCardCycle> cycles) {
  final tickers = cycles.map((entry) => entry.ticker).toSet().toList()..sort();
  return tickers.join(' · ');
}

/// D-52's optional net-result line: the month's summed net result to two
/// decimals, then D-50's clause when there is a gap.
///
/// `before fees` is stated unconditionally because the figure genuinely is the
/// pre-fee sum; the clause is what says the app could not check every leg.
/// Two decimals because this is a row, not a tile.
String netResultLine({required List<ShareCardCycle> cycles}) {
  final sum = cycles.fold(Decimal.zero, (total, entry) => total + entry.pnl.netResult);
  final gap = monthFeeGap(cycles);
  return 'Net result ${_money(sum)} before fees'
      '${beforeFeesClause(hasFeeGap: gap.hasFeeGap, feeGapCount: gap.feeGapCount)}';
}

/// `$357.00` — a deliberate copy of `format.moneyText`, for the same reason
/// `obligation.dart`'s `_dollars` and `capital_committed.dart`'s
/// `_wholeDollars` are: the rules layer may import only
/// `lib/domain/models/`, so it cannot reach `lib/core/`.
String _money(Decimal value) => '\$${value.toStringAsFixed(2)}';
