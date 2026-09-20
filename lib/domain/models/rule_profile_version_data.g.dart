// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_profile_version_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RuleProfileVersionData _$RuleProfileVersionDataFromJson(
  Map<String, dynamic> json,
) => _RuleProfileVersionData(
  id: json['id'] as String,
  profileId: json['profileId'] as String,
  version: (json['version'] as num).toInt(),
  effectiveAt: DateTime.parse(json['effectiveAt'] as String),
  profitTargetPct: (json['profitTargetPct'] as num).toDouble(),
  assignThreshold: (json['assignThreshold'] as num).toDouble(),
  baseRollBand: (json['baseRollBand'] as num).toDouble(),
  midIvRollBand: (json['midIvRollBand'] as num).toDouble(),
  highIvRollBand: (json['highIvRollBand'] as num).toDouble(),
  midIvCutoff: (json['midIvCutoff'] as num).toDouble(),
  highIvCutoff: (json['highIvCutoff'] as num).toDouble(),
  tailDteDays: (json['tailDteDays'] as num).toInt(),
  tailExtrinsicThreshold: const DecimalJsonConverter().fromJson(
    json['tailExtrinsicThreshold'] as String,
  ),
  minIvRank: (json['minIvRank'] as num).toDouble(),
  minAnnualisedYield: (json['minAnnualisedYield'] as num).toDouble(),
  targetDteMin: (json['targetDteMin'] as num).toInt(),
  targetDteMax: (json['targetDteMax'] as num).toInt(),
  targetDelta: (json['targetDelta'] as num).toDouble(),
);

Map<String, dynamic> _$RuleProfileVersionDataToJson(
  _RuleProfileVersionData instance,
) => <String, dynamic>{
  'id': instance.id,
  'profileId': instance.profileId,
  'version': instance.version,
  'effectiveAt': instance.effectiveAt.toIso8601String(),
  'profitTargetPct': instance.profitTargetPct,
  'assignThreshold': instance.assignThreshold,
  'baseRollBand': instance.baseRollBand,
  'midIvRollBand': instance.midIvRollBand,
  'highIvRollBand': instance.highIvRollBand,
  'midIvCutoff': instance.midIvCutoff,
  'highIvCutoff': instance.highIvCutoff,
  'tailDteDays': instance.tailDteDays,
  'tailExtrinsicThreshold': const DecimalJsonConverter().toJson(
    instance.tailExtrinsicThreshold,
  ),
  'minIvRank': instance.minIvRank,
  'minAnnualisedYield': instance.minAnnualisedYield,
  'targetDteMin': instance.targetDteMin,
  'targetDteMax': instance.targetDteMax,
  'targetDelta': instance.targetDelta,
};
