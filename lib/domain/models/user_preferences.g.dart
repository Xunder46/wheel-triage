// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserPreferencesData _$UserPreferencesDataFromJson(Map<String, dynamic> json) =>
    _UserPreferencesData(
      totalPerContractToggle: json['totalPerContractToggle'] as bool? ?? false,
      deltaConventionDefault:
          $enumDecodeNullable(
            _$DeltaConventionEnumMap,
            json['deltaConventionDefault'],
          ) ??
          DeltaConvention.position,
      firstRunExplainerShown: json['firstRunExplainerShown'] as bool? ?? false,
      ivResolutionNoticeDismissed:
          json['ivResolutionNoticeDismissed'] as bool? ?? false,
      exportReminderDismissed:
          json['exportReminderDismissed'] as bool? ?? false,
      lastExportAt: json['lastExportAt'] == null
          ? null
          : DateTime.parse(json['lastExportAt'] as String),
      notificationMilestones:
          (json['notificationMilestones'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [21, 7, 0],
      wheelCapital: const NullableDecimalJsonConverter().fromJson(
        json['wheelCapital'] as String?,
      ),
      concentrationLimitPct:
          (json['concentrationLimitPct'] as num?)?.toDouble() ?? 25.0,
    );

Map<String, dynamic> _$UserPreferencesDataToJson(
  _UserPreferencesData instance,
) => <String, dynamic>{
  'totalPerContractToggle': instance.totalPerContractToggle,
  'deltaConventionDefault':
      _$DeltaConventionEnumMap[instance.deltaConventionDefault]!,
  'firstRunExplainerShown': instance.firstRunExplainerShown,
  'ivResolutionNoticeDismissed': instance.ivResolutionNoticeDismissed,
  'exportReminderDismissed': instance.exportReminderDismissed,
  'lastExportAt': instance.lastExportAt?.toIso8601String(),
  'notificationMilestones': instance.notificationMilestones,
  'wheelCapital': const NullableDecimalJsonConverter().toJson(
    instance.wheelCapital,
  ),
  'concentrationLimitPct': instance.concentrationLimitPct,
};

const _$DeltaConventionEnumMap = {
  DeltaConvention.position: 'position',
  DeltaConvention.option: 'option',
};
