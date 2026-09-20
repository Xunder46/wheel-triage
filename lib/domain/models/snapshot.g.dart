// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Snapshot _$SnapshotFromJson(Map<String, dynamic> json) => _Snapshot(
  id: json['id'] as String,
  legId: json['legId'] as String,
  takenAt: DateTime.parse(json['takenAt'] as String),
  optionMark: const DecimalJsonConverter().fromJson(
    json['optionMark'] as String,
  ),
  underlyingPrice: const DecimalJsonConverter().fromJson(
    json['underlyingPrice'] as String,
  ),
  deltaAsEntered: (json['deltaAsEntered'] as num).toDouble(),
  deltaConvention: $enumDecode(
    _$DeltaConventionEnumMap,
    json['deltaConvention'],
  ),
  gamma: (json['gamma'] as num?)?.toDouble(),
  theta: (json['theta'] as num?)?.toDouble(),
  vega: (json['vega'] as num?)?.toDouble(),
  iv: (json['iv'] as num?)?.toDouble(),
  openInterest: (json['openInterest'] as num?)?.toInt(),
  volume: (json['volume'] as num?)?.toInt(),
);

Map<String, dynamic> _$SnapshotToJson(_Snapshot instance) => <String, dynamic>{
  'id': instance.id,
  'legId': instance.legId,
  'takenAt': instance.takenAt.toIso8601String(),
  'optionMark': const DecimalJsonConverter().toJson(instance.optionMark),
  'underlyingPrice': const DecimalJsonConverter().toJson(
    instance.underlyingPrice,
  ),
  'deltaAsEntered': instance.deltaAsEntered,
  'deltaConvention': _$DeltaConventionEnumMap[instance.deltaConvention]!,
  'gamma': instance.gamma,
  'theta': instance.theta,
  'vega': instance.vega,
  'iv': instance.iv,
  'openInterest': instance.openInterest,
  'volume': instance.volume,
};

const _$DeltaConventionEnumMap = {
  DeltaConvention.position: 'position',
  DeltaConvention.option: 'option',
};
