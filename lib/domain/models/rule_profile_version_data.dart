import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_converters.dart';

part 'rule_profile_version_data.freezed.dart';
part 'rule_profile_version_data.g.dart';

/// One immutable, append-only snapshot of a rule profile's 14 threshold
/// values (Iteration 5, D-3) — the domain mirror of the
/// `rule_profile_version` table, 1:1. Once written, a version row is never
/// updated or deleted through [WheelRepository]; an edit appends the next
/// version instead.
///
/// [id] is deterministic: `<profileId>-v<version>`
/// (`RuleProfileVersionIds.forVersion`). [version] is 1-based and unique
/// per profile. Every leg pins one of these ids
/// (`Leg.ruleProfileVersionId`), never a `rule_profile` id, so editing a
/// profile can never silently reclassify history.
///
/// Field types follow the profile/version split the schema has always
/// used: all thresholds are dimensionless `double` except
/// [tailExtrinsicThreshold], the one money-denominated field (Feature
/// Invariant 9), stored as integer ten-thousandths at the persistence
/// boundary.
@freezed
abstract class RuleProfileVersionData with _$RuleProfileVersionData {
  const factory RuleProfileVersionData({
    required String id,
    required String profileId,
    required int version,
    required DateTime effectiveAt,
    required double profitTargetPct,
    required double assignThreshold,
    required double baseRollBand,
    required double midIvRollBand,
    required double highIvRollBand,
    required double midIvCutoff,
    required double highIvCutoff,
    required int tailDteDays,
    @DecimalJsonConverter() required Decimal tailExtrinsicThreshold,
    required double minIvRank,
    required double minAnnualisedYield,
    required int targetDteMin,
    required int targetDteMax,
    required double targetDelta,
  }) = _RuleProfileVersionData;

  factory RuleProfileVersionData.fromJson(Map<String, Object?> json) =>
      _$RuleProfileVersionDataFromJson(json);
}
