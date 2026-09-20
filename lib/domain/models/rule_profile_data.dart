import 'package:freezed_annotation/freezed_annotation.dart';

part 'rule_profile_data.freezed.dart';
part 'rule_profile_data.g.dart';

/// A rule profile's identity only (`id`, `name`), mirroring the
/// `rule_profile` table's two columns 1:1. The 14 threshold values live on
/// immutable `rule_profile_version` rows (`RuleProfileVersionData`) since
/// Iteration 5 — a profile row is a container, never a value holder, so an
/// edit can never rewrite what a historical leg resolved against (D-3).
///
/// No methods beyond serialization — the pure value type `classify()`
/// actually uses (`lib/domain/rules/rule_profile.dart`) is reconciled from
/// a *version* via the single factory `RuleProfile.fromVersion(...)`.
/// Nothing in `lib/data/` imports `lib/domain/rules/`.
@freezed
abstract class RuleProfileData with _$RuleProfileData {
  const factory RuleProfileData({
    required String id,
    required String name,
  }) = _RuleProfileData;

  factory RuleProfileData.fromJson(Map<String, Object?> json) =>
      _$RuleProfileDataFromJson(json);
}
