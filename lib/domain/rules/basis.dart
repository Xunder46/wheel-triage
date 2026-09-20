import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import '../models/share_lot.dart';
import 'roll_chain.dart';

/// Tax-reporting cost basis (brief §3.6): assignment strike minus the
/// put-side premium actually received by the time of assignment, per share.
/// Never reduced by covered-call premiums -- those are their own taxable
/// events.
///
/// Takes the raw [putLegs] (every put-side leg in the cycle, in whatever
/// order) plus the [shareLot] the assignment created, rather than a
/// pre-summed per-share `Decimal` (S-014's original signature) -- Feature
/// Invariant 25, the coordinator's named fourth formula error. A pre-summed
/// per-share total loses each leg's own `contracts` the instant a roll
/// changes contract count mid-cycle (a roll from 1 contract to 3 is
/// ordinary trading, Feature Invariant 26, not something the schema
/// rejects); this signature keeps every leg's `contracts` in scope long
/// enough to weight it correctly (`cycleTotalPremium`) before ever dividing
/// by the lot's own total shares.
Decimal taxBasis({required List<Leg> putLegs, required ShareLot shareLot}) {
  final totalShares = shareLot.contracts * 100;
  if (totalShares == 0) return shareLot.assignmentStrike;
  final perShareCredit = _perShareDollars(cycleTotalPremium(putLegs), totalShares);
  return shareLot.assignmentStrike - perShareCredit;
}

/// Wheel-adjusted (management) basis (brief §3.6): [taxBasis] further
/// reduced by every covered-call credit collected since assignment, per
/// share of the same [shareLot]. This genuinely changes as more calls are
/// sold, so it is computed live every time it is displayed and never
/// persisted (Feature Invariant 12) -- `ShareLot` stores only
/// `assignmentStrike`/`contracts` and the raw facts; both basis figures are
/// derived from that plus the cycle's leg history on demand.
///
/// [callLegsSinceAssignment] takes the raw call legs (contract-weighted
/// internally via `cycleTotalPremium`, Feature Invariant 25) rather than
/// S-014's original pre-summed `List<Decimal>` of per-share credits, for the
/// same reason [taxBasis] does: a covered-call contract count is free to
/// vary from the assignment's own `shareLot.contracts` (e.g. a partial
/// covered call), and only the raw legs carry that multiplier.
Decimal wheelBasis({
  required List<Leg> putLegs,
  required ShareLot shareLot,
  required List<Leg> callLegsSinceAssignment,
}) {
  final totalShares = shareLot.contracts * 100;
  final tax = taxBasis(putLegs: putLegs, shareLot: shareLot);
  if (totalShares == 0) return tax;
  final perShareCallCredit = _perShareDollars(
    cycleTotalPremium(callLegsSinceAssignment),
    totalShares,
  );
  return tax - perShareCallCredit;
}

/// `totalDollars / shares`, kept exact via `Decimal`'s own `Rational`
/// division and only rounded to a fixed number of fractional digits at the
/// very end (never mid-calculation) -- the same pattern
/// `lib/domain/rules/formulas.dart`'s `capturedPct` uses for the identical
/// reason (S-012). Six fractional digits keeps a repeating-decimal result
/// (e.g. `145/300 = 0.4833...`) exact enough that rounding for on-screen
/// display (two decimals) never itself introduces error.
Decimal _perShareDollars(Decimal totalDollars, int shares) {
  final ratio = totalDollars / Decimal.fromInt(shares); // exact Rational
  return ratio.toDecimal(scaleOnInfinitePrecision: 6);
}
