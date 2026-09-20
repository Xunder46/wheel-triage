import 'package:decimal/decimal.dart';

import 'rule_profile.dart';

/// Screening-time annualised yield: always divides by [strike], for both
/// puts and calls, at screening time (Feature Invariant 4, brief §4.1 as
/// written). The journal's wheel-basis version (`journalAnnualisedReturn`,
/// capital committed on the call side per §5.5) is a **reserved name for the
/// M5 iteration, not implemented this run** -- never rename or overload this
/// function to accept a basis parameter.
///
/// A dimensionless ratio, not a stored money figure, so `double` matches
/// `docs/conventions.md` §1's Greeks/IV allowance; no scenario in the plan
/// requires this value hold to `Decimal` boundary exactness.
double screenerAnnualisedYield({
  required Decimal credit,
  required Decimal strike,
  required int dteAtOpen,
}) {
  if (dteAtOpen <= 0 || strike == Decimal.zero) return 0;
  final ratio = credit.toDouble() / strike.toDouble();
  return ratio * (365 / dteAtOpen) * 100;
}

/// The entry screener's two hard gates (brief §4.5). Independent of the
/// soft score, which is still computed and shown regardless -- "the gates
/// decide, the score only sorts" (S-019).
class ScreenerGates {
  final bool ivRankPasses;
  final bool annualisedYieldPasses;

  const ScreenerGates({required this.ivRankPasses, required this.annualisedYieldPasses});

  bool get passesAll => ivRankPasses && annualisedYieldPasses;
}

ScreenerGates screenerHardGates({
  required double ivRank,
  required double annualisedYield,
  required RuleProfile profile,
}) =>
    ScreenerGates(
      ivRankPasses: ivRank >= profile.minIvRank,
      annualisedYieldPasses: annualisedYield >= profile.minAnnualisedYield,
    );

/// One 0-3 component of the 0-9 sorting score. Bands are half-open,
/// lower-inclusive/upper-exclusive (Feature Invariant 2): `< 20 -> 0`,
/// `[20,35) -> 1`, `[35,50) -> 2`, `[50, inf) -> 3`. Cascading from the top
/// threshold down encodes that half-open boundary exactly (S-016).
int screenerYieldScore(double annualisedYield) {
  if (annualisedYield >= 50) return 3;
  if (annualisedYield >= 35) return 2;
  if (annualisedYield >= 20) return 1;
  return 0;
}

/// IV-rank component of the sorting score, same half-open banding rule
/// (Feature Invariant 2), cut points `30`/`50`/`70` (S-017).
int screenerIvRankScore(double ivRank) {
  if (ivRank >= 70) return 3;
  if (ivRank >= 50) return 2;
  if (ivRank >= 30) return 1;
  return 0;
}

/// Cushion (in sigmas) component of the sorting score, same half-open
/// banding rule (Feature Invariant 2), cut points `0.5`/`1.0`/`1.5` (S-018).
int screenerCushionScore(double cushionSigmas) {
  if (cushionSigmas >= 1.5) return 3;
  if (cushionSigmas >= 1.0) return 2;
  if (cushionSigmas >= 0.5) return 1;
  return 0;
}

/// The 0-9 "sorting score" -- a sorting aid, never a verdict (brief §4.5,
/// §1). Callers must label it "Sorting score" in the UI, never "rating" or
/// "grade" (that's a Phase 4 UI concern; this function only computes it).
int screenerSortingScore({
  required double annualisedYield,
  required double ivRank,
  required double cushionSigmas,
}) =>
    screenerYieldScore(annualisedYield) +
    screenerIvRankScore(ivRank) +
    screenerCushionScore(cushionSigmas);
