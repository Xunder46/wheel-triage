import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import '../models/share_lot.dart';
import 'basis.dart';
import 'formulas.dart' show daysBetween;
import 'roll_chain.dart';

/// `docs/brief-ledger.md` §4.1/§4.2's cycle-level P&L figures, every dollar
/// total contract-weighted per leg (Feature Invariant 25) -- never a
/// per-share sum multiplied by a single leg's contract count. Pure, zero
/// Flutter imports, zero I/O; `now` is always a parameter, never read from
/// the wall clock in here (`docs/conventions.md` §3).

/// Sum of every recorded fee across [legs] -- `openFee`/`closeFee`, null
/// treated as "not yet paid" (0) for the purpose of this sum, never coerced
/// to zero anywhere it would be persisted (Feature Invariant 28 governs the
/// separate "is this cycle fee-complete" question; this function only
/// totals whatever *is* recorded).
Decimal totalFees(List<Leg> legs) => legs.fold(
  Decimal.zero,
  (sum, leg) => sum + (leg.openFee ?? Decimal.zero) + (leg.closeFee ?? Decimal.zero),
);

/// True iff at least one CLOSED leg is missing its `closeFee` (Feature
/// Invariant 28: an open leg's null `closeFee` is expected, not a gap, since
/// it hasn't closed yet -- only a leg that has actually closed without a
/// recorded fee counts).
bool hasFeeGap(List<Leg> legs) => legs.any((leg) => leg.closedAt != null && leg.closeFee == null);

/// Count of closed legs missing a `closeFee` -- feeds the "Before fees"
/// banner's "N leg(s) missing fee data" wording (S-121).
int feeGapCount(List<Leg> legs) =>
    legs.where((leg) => leg.closedAt != null && leg.closeFee == null).length;

/// The put leg whose own assignment started this cycle's share ownership
/// (`closeReason == assigned`, `optionType == put`) -- at most one per
/// cycle, since a cycle can only be assigned once before it starts holding
/// shares. `null` if this cycle never reached a put-side assignment.
Leg? assignedPutLeg(List<Leg> legs) {
  for (final leg in legs) {
    if (leg.optionType == OptionType.put && leg.closeReason == CloseReason.assigned) return leg;
  }
  return null;
}

/// The call leg whose own assignment ("called away") ended this cycle
/// (`closeReason == assigned`, `optionType == call`) -- at most one per
/// cycle, since a call-side assignment always ends the cycle (Feature
/// Invariant 14). `null` if this cycle never reached a call-away (still
/// holding shares, or never assigned at all).
Leg? calledAwayCallLeg(List<Leg> legs) {
  for (final leg in legs) {
    if (leg.optionType == OptionType.call && leg.closeReason == CloseReason.assigned) return leg;
  }
  return null;
}

/// Realised stock P&L: the called-away leg's own strike minus the
/// put-assignment leg's own strike, times 100, times the CALLED-AWAY leg's
/// own `contracts` (Feature Invariant 25 -- deliberately never
/// `ShareLot.contracts`, since Feature Invariant 26 allows a covered call's
/// contract count to differ from the shares actually held). Zero when the
/// cycle never reached a call-away (no shares ever sold back yet).
Decimal stockPnL({required Leg? assignedPutLeg, required Leg? calledAwayCallLeg}) {
  if (assignedPutLeg == null || calledAwayCallLeg == null) return Decimal.zero;
  return (calledAwayCallLeg.strike - assignedPutLeg.strike) *
      Decimal.fromInt(100) *
      Decimal.fromInt(calledAwayCallLeg.contracts);
}

/// `totalPremium (cycleTotalPremium) - totalFees + stockPnL` -- the
/// coordinator's named fourth-formula-error fix, Q1's `netResult`
/// (`docs/brief-ledger.md` §4.1), now contract-weighted throughout.
Decimal netResult({
  required List<Leg> legs,
  required Leg? assignedPutLeg,
  required Leg? calledAwayCallLeg,
}) =>
    cycleTotalPremium(legs) -
    totalFees(legs) +
    stockPnL(assignedPutLeg: assignedPutLeg, calledAwayCallLeg: calledAwayCallLeg);

/// Number of rolls in the chain -- one per leg that was itself created by a
/// roll (`rolledFromLegId != null`), never counting the first leg.
int rollCount(List<Leg> legs) => legs.where((leg) => leg.rolledFromLegId != null).length;

/// "Peak capital committed" (Feature Invariant 27, on-screen label,
/// deliberately never a bare "Capital committed"): the maximum, across the
/// whole cycle, of every put-side leg's `strike x 100 x contracts` and every
/// holding-phase `wheelBasis x 100 x shares`. `wheelBasis` only ever
/// decreases (or holds steady) as more covered-call credit is collected
/// (`lib/domain/rules/basis.dart`), so its own peak during the holding
/// phase is always its value immediately after assignment, before any
/// covered call -- computing it with an empty `callLegsSinceAssignment` here
/// is therefore sufficient, not an approximation.
Decimal peakCapitalCommitted({required List<Leg> putLegs, ShareLot? shareLot}) {
  var peak = Decimal.zero;
  for (final leg in putLegs) {
    final committed = leg.strike * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts);
    if (committed > peak) peak = committed;
  }
  if (shareLot != null) {
    final basisAtAssignment = wheelBasis(
      putLegs: putLegs,
      shareLot: shareLot,
      callLegsSinceAssignment: const [],
    );
    final committed = basisAtAssignment * Decimal.fromInt(100) * Decimal.fromInt(shareLot.contracts);
    if (committed > peak) peak = committed;
  }
  return peak;
}

/// `netResult / peakCapitalCommitted`, as a percentage. Guarded against a
/// zero (or negative -- never expected, but never trusted either)
/// [peakCapitalCommitted]: returns `0`, never a thrown exception or `NaN`
/// (`docs/conventions.md` §1).
double returnOnCapital({required Decimal netResult, required Decimal peakCapitalCommitted}) {
  if (peakCapitalCommitted <= Decimal.zero) return 0;
  return netResult.toDouble() / peakCapitalCommitted.toDouble() * 100;
}

/// [journalAnnualisedReturn]'s result: the un-annualised
/// [returnOnCapitalPct] always present, [annualisedReturnPct] present only
/// when [daysHeld] > 0 (S-107) -- a same-day close carries [note] instead of
/// a divide-by-zero annualised figure.
class JournalAnnualisedReturnResult {
  final double returnOnCapitalPct;
  final double? annualisedReturnPct;
  final String? note;

  const JournalAnnualisedReturnResult({
    required this.returnOnCapitalPct,
    this.annualisedReturnPct,
    this.note,
  });
}

/// Feature Invariant 4's reserved name, implemented now: the journal's
/// wheel-basis-anchored annualised return (`netResult / peakCapitalCommitted`,
/// annualised over [daysHeld]) -- distinctly denominated from
/// `screener.dart`'s strike-denominated `screenerAnnualisedYield`, which
/// stays exactly as built (never renamed, never overloaded to accept a
/// basis parameter). Guards `daysHeld == 0` (S-107): a same-day close
/// returns the un-annualised return on capital with [JournalAnnualisedReturnResult.note]
/// set, never a division by zero.
JournalAnnualisedReturnResult journalAnnualisedReturn({
  required Decimal netResult,
  required Decimal peakCapitalCommitted,
  required int daysHeld,
}) {
  final ror = returnOnCapital(netResult: netResult, peakCapitalCommitted: peakCapitalCommitted);
  if (daysHeld == 0) {
    return JournalAnnualisedReturnResult(
      returnOnCapitalPct: ror,
      note: 'Same-day close -- return not annualised',
    );
  }
  return JournalAnnualisedReturnResult(
    returnOnCapitalPct: ror,
    annualisedReturnPct: ror * (365 / daysHeld),
  );
}

/// Every §4.1/§4.2 cycle figure, computed once from a cycle's own legs (in
/// `sequence` order) plus its share lot (if any) -- the single place the
/// state layer (`lib/state/journal/`, `lib/state/positions/`) calls into,
/// so business logic stays here and not duplicated at each call site.
class CyclePnl {
  final Decimal totalPremium;
  final Decimal totalFees;
  final Decimal stockPnL;
  final Decimal netResult;
  final int daysHeld;
  final int rollCount;
  final Decimal peakCapitalCommitted;
  final double returnOnCapitalPct;
  final double? annualisedReturnPct;
  final String? annualisedReturnNote;
  final bool hasFeeGap;
  final int feeGapCount;

  const CyclePnl({
    required this.totalPremium,
    required this.totalFees,
    required this.stockPnL,
    required this.netResult,
    required this.daysHeld,
    required this.rollCount,
    required this.peakCapitalCommitted,
    required this.returnOnCapitalPct,
    this.annualisedReturnPct,
    this.annualisedReturnNote,
    required this.hasFeeGap,
    required this.feeGapCount,
  });
}

/// Computes [CyclePnl] for one cycle. [endedAt] `null` means the cycle is
/// still open -- [now] stands in for it when computing [CyclePnl.daysHeld]
/// (an "as of today" unrealised figure); for a closed cycle [endedAt] is
/// used and [now] is ignored, matching the "now always passed in" rule even
/// where a closed cycle happens not to need it.
CyclePnl computeCyclePnl({
  required List<Leg> legs,
  required ShareLot? shareLot,
  required DateTime startedAt,
  DateTime? endedAt,
  required DateTime now,
}) {
  final putLegs = legs.where((leg) => leg.optionType == OptionType.put).toList();
  final assignedPut = assignedPutLeg(legs);
  final calledAwayCall = calledAwayCallLeg(legs);
  final net = netResult(legs: legs, assignedPutLeg: assignedPut, calledAwayCallLeg: calledAwayCall);
  final days = daysBetween(startedAt, endedAt ?? now);
  final peak = peakCapitalCommitted(putLegs: putLegs, shareLot: shareLot);
  final annualised = journalAnnualisedReturn(netResult: net, peakCapitalCommitted: peak, daysHeld: days);

  return CyclePnl(
    totalPremium: cycleTotalPremium(legs),
    totalFees: totalFees(legs),
    stockPnL: stockPnL(assignedPutLeg: assignedPut, calledAwayCallLeg: calledAwayCall),
    netResult: net,
    daysHeld: days,
    rollCount: rollCount(legs),
    peakCapitalCommitted: peak,
    returnOnCapitalPct: annualised.returnOnCapitalPct,
    annualisedReturnPct: annualised.annualisedReturnPct,
    annualisedReturnNote: annualised.note,
    hasFeeGap: hasFeeGap(legs),
    feeGapCount: feeGapCount(legs),
  );
}
