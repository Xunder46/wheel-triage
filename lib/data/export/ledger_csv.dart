import 'package:decimal/decimal.dart';

import '../../domain/models/leg.dart';
import '../../domain/models/share_lot.dart';
import '../../domain/models/wheel_cycle.dart';
import '../wheel_repository.dart';

/// CSV export of every closed cycle (`docs/brief-ledger.md` §5), one row
/// per cycle, newest-`endedAt`-first (matching
/// `WheelRepository.getClosedCycles`'s own order). Column set matches the
/// Journal screen's own row (`lib/widgets/journal_row.dart`,
/// `docs/brief-ledger.md` §4.4, S-154): ticker, duration in days, leg
/// count, total premium, outcome, net result, return on capital. Money
/// columns render as decimal dollars (e.g. `"646.10"`), never integer
/// cents, and carry no `$` prefix so a spreadsheet reads them as numbers.
///
/// Deliberately does NOT import `lib/domain/rules/cycle_pnl.dart` (or
/// `basis.dart`/`roll_chain.dart`/`formulas.dart`) even though the figures
/// below are the same ones that module computes -- Feature Invariant 11
/// ("nothing in `lib/data/` imports `lib/domain/rules/`") forbids that
/// import from this layer. The private helpers below are this file's own,
/// self-contained implementation of the same contract-weighted formulas
/// (Feature Invariant 25 / docs/conventions.md §1: every dollar figure
/// sums each leg's own `openCreditPerShare`/`closeDebitPerShare` times 100
/// times that leg's own `contracts`, never a pre-summed per-share value).
/// This is a deliberate, logged duplication -- see the Phase 19 entry in
/// `## Assumption Log` of docs/plans/wheel-triage-plan.md.
Future<String> buildClosedCyclesCsv(WheelRepository repository) async {
  final cycles = await repository.getClosedCycles();
  final buffer = StringBuffer()
    ..writeln(
      'ticker,duration_days,leg_count,total_premium,outcome,net_result,return_on_capital_pct',
    );

  for (final cycle in cycles) {
    final legs = await repository.getLegsForCycle(cycle.id);
    final underlying = await repository.getUnderlying(cycle.underlyingId);
    final ticker = underlying?.ticker ?? '?';

    final assignedPut = _assignedPutLeg(legs);
    final calledAwayCall = _calledAwayCallLeg(legs);
    final totalPremium = _cycleTotalPremium(legs);
    final fees = _totalFees(legs);
    final assignment = await repository.getAssignmentForCycle(cycle.id);
    final stockPnL = _stockPnL(
      assignedPutLeg: assignedPut,
      calledAwayCallLeg: calledAwayCall,
      shareLot: assignment,
    );
    final netResult = totalPremium - fees + stockPnL;
    final days = _daysBetween(cycle.startedAt, cycle.endedAt ?? cycle.startedAt);
    final peak = _peakCapitalCommitted(legs, assignment);
    final returnOnCapitalPct = peak <= Decimal.zero
        ? 0.0
        : netResult.toDouble() / peak.toDouble() * 100;

    buffer.writeln(
      [
        _csvField(ticker),
        days.toString(),
        legs.length.toString(),
        totalPremium.toStringAsFixed(2),
        _csvField(_outcomeLabel(cycle.outcome)),
        netResult.toStringAsFixed(2),
        returnOnCapitalPct.toStringAsFixed(1),
      ].join(','),
    );
  }

  return buffer.toString();
}

// --- Self-contained formula helpers (see file doc comment for why) -------

Decimal _legNetCredit(Leg leg) => leg.openCreditPerShare - (leg.closeDebitPerShare ?? Decimal.zero);

Decimal _cycleTotalPremium(List<Leg> legs) => legs.fold(
  Decimal.zero,
  (sum, leg) => sum + _legNetCredit(leg) * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts),
);

Decimal _totalFees(List<Leg> legs) => legs.fold(
  Decimal.zero,
  (sum, leg) => sum + (leg.openFee ?? Decimal.zero) + (leg.closeFee ?? Decimal.zero),
);

Leg? _assignedPutLeg(List<Leg> legs) {
  for (final leg in legs) {
    if (leg.optionType == OptionType.put && leg.closeReason == CloseReason.assigned) return leg;
  }
  return null;
}

Leg? _calledAwayCallLeg(List<Leg> legs) {
  for (final leg in legs) {
    if (leg.optionType == OptionType.call && leg.closeReason == CloseReason.assigned) return leg;
  }
  return null;
}

/// Mirrors `cycle_pnl.dart#stockPnL` (Feature Invariant 36): the put-side
/// strike is [shareLot]'s retained `assignmentStrike` when present, else
/// [assignedPutLeg]'s own strike (the legacy fallback for a cycle closed
/// before that record was retained). `required` (Phase 23.4 ruling 2a) so
/// no caller can omit it by accident.
Decimal _stockPnL({
  required Leg? assignedPutLeg,
  required Leg? calledAwayCallLeg,
  required ShareLot? shareLot,
}) {
  if (assignedPutLeg == null || calledAwayCallLeg == null) return Decimal.zero;
  final putStrike = shareLot?.assignmentStrike ?? assignedPutLeg.strike;
  return (calledAwayCallLeg.strike - putStrike) *
      Decimal.fromInt(100) *
      Decimal.fromInt(calledAwayCallLeg.contracts);
}

/// UTC-normalized whole-day span, matching
/// `lib/domain/rules/formulas.dart#daysBetween`'s own DST-safe
/// implementation (duplicated here for the same Feature Invariant 11
/// reason as the rest of this file).
int _daysBetween(DateTime from, DateTime to) {
  final f = DateTime.utc(from.year, from.month, from.day);
  final t = DateTime.utc(to.year, to.month, to.day);
  return t.difference(f).inDays;
}

/// Mirrors `cycle_pnl.dart#peakCapitalCommitted`: the maximum of every
/// put-side leg's `strike x 100 x contracts` and, when the cycle reached an
/// assignment, the wheel basis immediately after that assignment (before
/// any covered-call credit, since wheel basis only ever decreases from
/// there) times shares.
///
/// The assignment's own `assignmentStrike`/`contracts` come from
/// [assignment] — the cycle's retained record of what was actually entered
/// at assignment ([WheelRepository.getAssignmentForCycle], CR-1). Rebuilding
/// them from the assigned put leg instead is only a fallback for a cycle
/// closed before that record was retained (or a hand-built import): the
/// leg's own `strike`/`contracts` are not necessarily the assignment's, so
/// the fallback is an approximation, not an equivalent.
Decimal _peakCapitalCommitted(List<Leg> legs, ShareLot? assignment) {
  final putLegs = legs.where((l) => l.optionType == OptionType.put).toList();
  var peak = Decimal.zero;
  for (final leg in putLegs) {
    final committed = leg.strike * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts);
    if (committed > peak) peak = committed;
  }

  final terms = _assignmentTerms(legs, assignment);
  if (terms == null) return peak;
  final totalShares = terms.contracts * 100;
  if (totalShares <= 0) return peak;

  final putPremium = _cycleTotalPremium(putLegs);
  final perShareCredit = (putPremium / Decimal.fromInt(totalShares)).toDecimal(
    scaleOnInfinitePrecision: 6,
  );
  final basisAtAssignment = terms.strike - perShareCredit;
  final committed = basisAtAssignment * Decimal.fromInt(100) * Decimal.fromInt(terms.contracts);
  return committed > peak ? committed : peak;
}

/// The assignment's recorded strike and contract count: the retained
/// [assignment] when the cycle has one, else the assigned put leg's own
/// values (the legacy fallback described on [_peakCapitalCommitted]).
/// `null` when the cycle never reached a put-side assignment.
({Decimal strike, int contracts})? _assignmentTerms(List<Leg> legs, ShareLot? assignment) {
  if (assignment != null) {
    return (strike: assignment.assignmentStrike, contracts: assignment.contracts);
  }
  final assignedPutLeg = _assignedPutLeg(legs);
  if (assignedPutLeg == null) return null;
  return (strike: assignedPutLeg.strike, contracts: assignedPutLeg.contracts);
}

/// Duplicated from `lib/widgets/journal_row.dart`'s private
/// `_outcomeLabel` -- `lib/data/` cannot import `lib/widgets/` (UI layer,
/// downstream), and this is pure vocabulary text, not a formula, so the
/// duplication risk here is negligible compared to the dollar-figure
/// helpers above.
String _outcomeLabel(WheelCycleOutcome? outcome) => switch (outcome) {
  WheelCycleOutcome.expiredWorthless => 'Expired worthless',
  WheelCycleOutcome.closedEarly => 'Closed early',
  WheelCycleOutcome.calledAway => 'Called away',
  WheelCycleOutcome.abandoned => 'Abandoned',
  null => 'Open',
};

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
