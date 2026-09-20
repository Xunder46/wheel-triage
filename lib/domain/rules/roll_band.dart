/// The IV-adjusted roll band (brief §4.2, Feature Invariant 3). Delta is a
/// probability estimate under the market's own volatility assumption; on a
/// high-IV underlying a fixed delta threshold fires long before the strike
/// is actually threatened, so the band widens as IV rises.
///
/// The asymmetry is literal and intentional, not a bug to "fix":
/// `iv > highCutoff` is **strict** (so `iv == highCutoff` does NOT get the
/// high band), `iv >= midCutoff` is **inclusive**. A `null` IV (no snapshot
/// yet) falls back to [baseBand]. Standalone so `RuleProfile.rollBandFor`
/// (`lib/domain/rules/rule_profile.dart`) can delegate to it with its own
/// fields, without a second copy of this comparison chain existing anywhere.
double rollBandFor({
  required double? iv,
  required double baseBand,
  required double midBand,
  required double highBand,
  required double midCutoff,
  required double highCutoff,
}) {
  if (iv == null) return baseBand;
  if (iv > highCutoff) return highBand;
  if (iv >= midCutoff) return midBand;
  return baseBand;
}
