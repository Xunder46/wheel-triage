// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wheel_cycle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WheelCycle _$WheelCycleFromJson(Map<String, dynamic> json) => _WheelCycle(
  id: json['id'] as String,
  underlyingId: json['underlyingId'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
  status: $enumDecode(_$WheelCycleStatusEnumMap, json['status']),
  outcome: $enumDecodeNullable(_$WheelCycleOutcomeEnumMap, json['outcome']),
);

Map<String, dynamic> _$WheelCycleToJson(_WheelCycle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'underlyingId': instance.underlyingId,
      'startedAt': instance.startedAt.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'status': _$WheelCycleStatusEnumMap[instance.status]!,
      'outcome': _$WheelCycleOutcomeEnumMap[instance.outcome],
    };

const _$WheelCycleStatusEnumMap = {
  WheelCycleStatus.sellingPuts: 'sellingPuts',
  WheelCycleStatus.holdingShares: 'holdingShares',
  WheelCycleStatus.closed: 'closed',
};

const _$WheelCycleOutcomeEnumMap = {
  WheelCycleOutcome.expiredWorthless: 'expiredWorthless',
  WheelCycleOutcome.closedEarly: 'closedEarly',
  WheelCycleOutcome.calledAway: 'calledAway',
  WheelCycleOutcome.abandoned: 'abandoned',
};
