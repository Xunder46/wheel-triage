import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import 'roll_chain.dart' show legNetCredit;

/// `docs/brief-ledger.md` §4.4's journal aggregates, computed over closed
/// cycles. Every function here is a small, independent pure reducer over
/// exactly the flat list it needs (the caller -- `lib/state/journal/`,
/// Phase 17 -- assembles those lists once per closed cycle via
/// `lib/domain/rules/cycle_pnl.dart`'s `computeCyclePnl`) so each aggregate
/// stays trivially testable on its own literal fixture, with no Flutter, no
/// I/O, and no hidden re-derivation of a cycle's own P&L.

/// Win rate: the fraction (0..1) of [netResults] that are strictly greater
/// than zero. A cycle whose `netResult` is exactly `0` does NOT count as a
/// win (§4.4's literal `> 0`, S-113) -- it is also not a loss, simply
/// excluded from the numerator while still counting in the denominator.
double winRate(List<Decimal> netResults) {
  if (netResults.isEmpty) return 0;
  final wins = netResults.where((r) => r > Decimal.zero).length;
  return wins / netResults.length;
}

/// Bare arithmetic mean of [daysHeldValues] -- unlike average premium
/// capture (below), nothing about "average days in cycle" mixes
/// incommensurable signs the way a debit-roll leg's capture does, so a
/// simple mean is not misleading here and needs no Feature Invariant 29-
/// style distribution treatment.
double averageDaysInCycle(List<int> daysHeldValues) {
  if (daysHeldValues.isEmpty) return 0;
  return daysHeldValues.reduce((a, b) => a + b) / daysHeldValues.length;
}

/// One closed leg's own premium capture: `legNetCredit / openCreditPerShare
/// x 100`. `null` for a still-open leg (no final capture yet) or a leg
/// whose `openCreditPerShare` is exactly zero (nothing to divide by).
Decimal? legPremiumCapturePct(Leg leg) {
  if (leg.closedAt == null) return null;
  if (leg.openCreditPerShare == Decimal.zero) return null;
  final ratio = legNetCredit(leg) / leg.openCreditPerShare; // exact Rational
  return (ratio * Decimal.fromInt(100).toRational()).toDecimal(scaleOnInfinitePrecision: 6);
}

/// Average premium capture (§4.4), shown as a **median**, never a bare mean
/// (Feature Invariant 29) -- the coordinator's own characterization of the
/// bare mean as "the weakest of the six" aggregates, since a single
/// debit-roll leg (e.g. -50%) and a single expired-worthless leg (100%)
/// average to a number ("25%") that describes neither trade. A median is
/// resistant to exactly that distortion while still being a one-line
/// figure, matching the rest of this file's aggregates -- a full
/// histogram/distribution render was considered and is disproportionate to
/// this iteration's Journal-screen scope (Decide-and-Log, logged in the
/// plan's `## Assumption Log`, ratified/reverted by the Phase 23 reviewer).
/// `null` when [closedLegs] contains no leg with a computable capture.
double? medianPremiumCapturePct(List<Leg> closedLegs) {
  final captures = closedLegs
      .map(legPremiumCapturePct)
      .whereType<Decimal>()
      .map((d) => d.toDouble())
      .toList()
    ..sort();
  if (captures.isEmpty) return null;
  final mid = captures.length ~/ 2;
  if (captures.length.isOdd) return captures[mid];
  return (captures[mid - 1] + captures[mid]) / 2;
}

/// Total premium collected across every closed cycle -- the plain sum of
/// each cycle's own already-contract-weighted `CyclePnl.totalPremium`.
Decimal totalPremiumCollected(List<Decimal> totalPremiums) =>
    totalPremiums.fold(Decimal.zero, (sum, p) => sum + p);

/// Total fees paid across every closed cycle -- the plain sum of each
/// cycle's own `CyclePnl.totalFees`.
Decimal totalFeesPaid(List<Decimal> totalFeesList) =>
    totalFeesList.fold(Decimal.zero, (sum, f) => sum + f);

/// One (ticker, netResult) pair -- one per closed cycle -- for
/// [netResultByUnderlying] to group.
typedef UnderlyingNetResult = ({String ticker, Decimal netResult});

/// Net result summed per underlying ticker, no cross-contamination between
/// tickers (S-111).
Map<String, Decimal> netResultByUnderlying(List<UnderlyingNetResult> entries) {
  final result = <String, Decimal>{};
  for (final entry in entries) {
    result[entry.ticker] = (result[entry.ticker] ?? Decimal.zero) + entry.netResult;
  }
  return result;
}

/// Roll-count distribution: how many closed cycles fall into each
/// `rollCount` bucket (S-112).
Map<int, int> rollCountDistribution(List<int> rollCounts) {
  final distribution = <int, int>{};
  for (final count in rollCounts) {
    distribution[count] = (distribution[count] ?? 0) + 1;
  }
  return distribution;
}
