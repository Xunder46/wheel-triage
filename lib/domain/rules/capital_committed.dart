import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import '../models/share_lot.dart';
import '../models/wheel_cycle.dart';
import 'basis.dart';

/// `docs/brief-pro.md` D-P14 / Pro Wave 1 D-9 and D-10: how much capital the
/// book has committed right now, and how concentrated that is per
/// underlying. Pure, zero Flutter imports, zero I/O; `now` is a parameter
/// (`docs/conventions.md` §3).
///
/// This is deliberately **not** `cycle_pnl.dart`'s `peakCapitalCommitted`:
/// that figure is the largest single commitment a cycle ever carried and
/// keeps the Journal's "capital committed" name (D-P14). This one is the
/// live figure and is always labelled **"Committed now"**.

/// One cycle's inputs to [currentCapitalCommitted]. The caller supplies the
/// cycle, its ticker, every leg in it, and its active share lot (if any) —
/// never a pre-summed per-share value, for the same reason `basis.dart`'s
/// `taxBasis`/`wheelBasis` take raw legs (Feature Invariant 25): a roll can
/// change contract count mid-cycle, and only the raw legs carry each leg's
/// own multiplier.
class CycleCapitalInput {
  final WheelCycle cycle;
  final String ticker;
  final List<Leg> legs;

  /// The cycle's **active** lot (`WheelRepository.getShareLotForCycle`),
  /// non-null only while the cycle is `holdingShares`.
  final ShareLot? shareLot;

  const CycleCapitalInput({
    required this.cycle,
    required this.ticker,
    required this.legs,
    this.shareLot,
  });
}

/// One cycle's committed capital (D-9):
///
/// ```
/// putSide   = Σ (strike x 100 x contracts) over its OPEN put legs
/// shareSide = holdingShares ? wheelBasis(put legs, lot, no calls) x 100 x lot.contracts : 0
/// ```
///
/// Legs whose expiration has passed but are still open **are** included —
/// the on-screen definition says so ("includes legs past expiration until
/// recorded"), and a past-expiration leg is still an obligation until it is
/// recorded. A `holdingShares` cycle with no open call still counts: the
/// shares are held. A cycle with neither an open put leg nor a share lot
/// contributes zero.
///
/// The share side uses `wheelBasis` with **no** calls since assignment, so
/// the figure is the shares' wheel-adjusted basis at the moment of
/// assignment — the same basis `peakCapitalCommitted` uses for its own
/// share-side term, and the one the on-screen definition names ("shares at
/// wheel-adjusted basis").
Decimal capitalCommittedForCycle(CycleCapitalInput input) {
  var total = Decimal.zero;
  for (final leg in input.legs) {
    if (leg.optionType != OptionType.put || leg.closedAt != null) continue;
    total += leg.strike * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts);
  }

  final lot = input.shareLot;
  if (input.cycle.status == WheelCycleStatus.holdingShares && lot != null) {
    final basis = wheelBasis(
      putLegs: input.legs.where((leg) => leg.optionType == OptionType.put).toList(),
      shareLot: lot,
      callLegsSinceAssignment: const [],
    );
    total += basis * Decimal.fromInt(100) * Decimal.fromInt(lot.contracts);
  }
  return total;
}

/// The book's total committed capital (D-9). [now] is accepted for
/// signature parity with every other rule in this directory and is
/// deliberately unused: "committed now" is a function of what is open, not
/// of the clock — a past-expiration leg is included precisely because the
/// clock has moved past it.
Decimal currentCapitalCommitted(List<CycleCapitalInput> cycles, {DateTime? now}) =>
    cycles.fold(Decimal.zero, (sum, input) => sum + capitalCommittedForCycle(input));

/// Per-underlying committed capital, keyed by ticker (D-9). Every ticker
/// present in [cycles] appears, including one whose figure is zero — the
/// concentration readout needs the zero to render "0%" rather than nothing.
Map<String, Decimal> capitalCommittedByUnderlying(List<CycleCapitalInput> cycles) {
  final byUnderlying = <String, Decimal>{};
  for (final input in cycles) {
    byUnderlying[input.ticker] = (byUnderlying[input.ticker] ?? Decimal.zero) + capitalCommittedForCycle(input);
  }
  return byUnderlying;
}

/// One underlying over the concentration limit (D-10).
class ConcentrationFlag {
  final String ticker;

  /// The underlying's share of wheel capital, rounded to the nearest whole
  /// percent (D-15).
  final int percent;
  final double limitPct;

  const ConcentrationFlag({required this.ticker, required this.percent, required this.limitPct});
}

/// `capital / wheelCapital x 100`, rounded half-up to the nearest whole
/// percent (D-15) — **display only**. The flag comparison in
/// [concentrationFlags] uses the unrounded ratio, so a book a cent over the
/// limit is flagged even though its rounded percentage equals the limit.
/// Returns 0 when [wheelCapital] is null or zero — the caller must not
/// render a percentage at all in that case (D-10's invite line is what shows
/// instead).
int concentrationPercent({required Decimal capital, required Decimal? wheelCapital}) {
  final exact = concentrationRatio(capital: capital, wheelCapital: wheelCapital);
  if (exact == null) return 0;
  return _roundHalfUp(exact);
}

/// The unrounded `capital / wheelCapital x 100`, or `null` when there is no
/// wheel capital to divide by. Kept exact through `Decimal`'s own `Rational`
/// division and only rounded at the very end, the same pattern
/// `formulas.dart`'s `capturedPct` uses (S-012) — a ratio that lands on
/// `24.999999...` instead of `25` would silently mis-flag a book.
Decimal? concentrationRatio({required Decimal capital, required Decimal? wheelCapital}) {
  if (wheelCapital == null || wheelCapital == Decimal.zero) return null;
  final pct = (capital / wheelCapital) * Decimal.fromInt(100).toRational();
  return pct.toDecimal(scaleOnInfinitePrecision: 6);
}

/// The flags to render, largest first (D-10). Empty when [wheelCapital] is
/// null — with no wheel capital set there is no flag anywhere, and Today
/// shows [kConcentrationInviteLine] instead. The comparison is **strictly**
/// greater on the unrounded ratio, matching `brief.md` §5.6's "exceeds": a
/// book exactly at the limit is not flagged, and one a cent over it is.
List<ConcentrationFlag> concentrationFlags({
  required Map<String, Decimal> capitalByUnderlying,
  required Decimal? wheelCapital,
  required double concentrationLimitPct,
}) {
  if (wheelCapital == null || wheelCapital == Decimal.zero) return const [];
  final limit = Decimal.parse(concentrationLimitPct.toString());
  final flags = <ConcentrationFlag>[];
  for (final entry in capitalByUnderlying.entries) {
    final ratio = concentrationRatio(capital: entry.value, wheelCapital: wheelCapital);
    if (ratio == null || ratio <= limit) continue;
    flags.add(
      ConcentrationFlag(
        ticker: entry.key,
        percent: _roundHalfUp(ratio),
        limitPct: concentrationLimitPct,
      ),
    );
  }
  flags.sort((a, b) {
    final byPercent = b.percent.compareTo(a.percent);
    return byPercent != 0 ? byPercent : a.ticker.compareTo(b.ticker);
  });
  return flags;
}

/// D-10's flag line, worded as a fact in the neutral surface colour:
/// `INTC 27% of wheel capital · limit 25%`.
String concentrationFlagLine(ConcentrationFlag flag) =>
    '${flag.ticker} ${flag.percent}% of wheel capital · limit ${_trimmedPct(flag.limitPct)}%';

/// D-10's one-line invitation, shown when no wheel capital is set. The
/// exact string is pinned by S-222.
const String kConcentrationInviteLine =
    'Concentration per underlying appears once wheel capital is set in Settings.';

/// D-9's on-screen definition of the third tile. The ledger strip renders it
/// as one paragraph with `premium_collected.dart`'s [kPremiumDefinitionLine],
/// joined by a space — the premium half first, because that is the figure the
/// strip leads with.
const String kCommittedNowDefinitionLine =
    'Committed now: open puts at strike, shares at wheel-adjusted basis';

/// The second half of the ledger strip's definition paragraph (D-9):
/// [kCommittedNowDefinitionLine], extended with the book's own share of wheel
/// capital when one is set — `…; 41% of your $30,000 wheel capital.` With no
/// wheel capital there is no percentage to name, so the sentence stops at the
/// basis and [kConcentrationInviteLine] carries the rest.
String committedNowDefinition({required Decimal committedNow, required Decimal? wheelCapital}) {
  final pct = concentrationRatio(capital: committedNow, wheelCapital: wheelCapital);
  if (pct == null) return '$kCommittedNowDefinitionLine.';
  return '$kCommittedNowDefinitionLine; ${_roundHalfUp(pct)}% of your '
      '${_wholeDollars(wheelCapital!)} wheel capital.';
}

/// D-6's range for wheel capital: absent (`null` — "not set", a real state) or
/// strictly positive. A value outside it is **refused at entry**, never
/// clamped to the nearest legal one: the figure feeds a percentage the user
/// reads as a fact about their own book, and a silently rewritten one would be
/// a different fact.
bool wheelCapitalInRange(Decimal? wheelCapital) =>
    wheelCapital == null || wheelCapital > Decimal.zero;

/// D-6's refusal message for a wheel-capital entry outside
/// [wheelCapitalInRange].
const String kWheelCapitalRefusal = 'Enter an amount above 0, or leave it blank.';

/// D-6's range for the concentration limit: `(0, 100]` — a percentage of the
/// user's own wheel capital, inclusive at the top. Refused at entry rather
/// than clamped, for the same reason as [wheelCapitalInRange].
bool concentrationLimitInRange(double limitPct) => limitPct > 0 && limitPct <= 100;

/// D-6's refusal message for a limit outside [concentrationLimitInRange].
const String kConcentrationLimitRefusal = 'Enter a limit above 0 and up to 100.';

/// Half-up rounding on a non-negative [Decimal] — `Decimal.round()` is
/// half-away-from-zero, which agrees with half-up for the non-negative
/// percentages this file produces.
int _roundHalfUp(Decimal value) => value.round().toBigInt().toInt();

/// `$30,000` — whole dollars with thousands separators, matching the ledger
/// tiles. `lib/core/money/whole_dollars.dart` renders the same way and this is
/// a deliberate copy of it: the rules layer may import only
/// `lib/domain/models/`, so it cannot reach `lib/core/` (the same reasoning
/// `obligation.dart`'s own `_dollars` documents).
String _wholeDollars(Decimal value) {
  final whole = value.round().toBigInt().toString();
  final negative = whole.startsWith('-');
  final digits = negative ? whole.substring(1) : whole;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$$buffer';
}

/// Trims trailing zeros the way `iv_resolution.dart`'s `_trimmedPct` does,
/// so a whole-number limit renders as `25%` rather than `25.0%`.
String _trimmedPct(double value) {
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
