/// Stable, fixed ids for the three built-in [RuleProfileData] rows seeded
/// at migration time (Feature Invariant 8: "seeded ... with stable, fixed
/// ids"). Since Iteration 5 a profile row is identity only (D-3) — the
/// threshold values live on `rule_profile_version` rows, one per profile at
/// seed time, whose ids come from [RuleProfileVersionIds].
abstract final class RuleProfileIds {
  static const conservative = 'rule-profile-conservative';
  static const standard = 'rule-profile-standard';
  static const aggressive = 'rule-profile-aggressive';
}

/// Deterministic ids for the three seeded v1 version rows, plus the one
/// place the id format itself is expressed (Iteration 5, D-3):
/// `<profileId>-v<version>`. Every writer of a version row uses
/// [forVersion] — the v4 migration's raw-SQL copy, both repository
/// implementations' `appendRuleProfileVersion`, and the format-1 import
/// conversion all derive their ids through this format, so they can never
/// drift apart.
abstract final class RuleProfileVersionIds {
  static const standardV1 = 'rule-profile-standard-v1';
  static const conservativeV1 = 'rule-profile-conservative-v1';
  static const aggressiveV1 = 'rule-profile-aggressive-v1';

  /// The version id for [version] (1-based) of [profileId].
  static String forVersion(String profileId, int version) => '$profileId-v$version';
}
