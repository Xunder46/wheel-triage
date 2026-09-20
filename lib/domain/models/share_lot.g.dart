// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_lot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ShareLot _$ShareLotFromJson(Map<String, dynamic> json) => _ShareLot(
  id: json['id'] as String,
  cycleId: json['cycleId'] as String,
  assignedAt: DateTime.parse(json['assignedAt'] as String),
  assignmentStrike: const DecimalJsonConverter().fromJson(
    json['assignmentStrike'] as String,
  ),
  contracts: (json['contracts'] as num).toInt(),
);

Map<String, dynamic> _$ShareLotToJson(_ShareLot instance) => <String, dynamic>{
  'id': instance.id,
  'cycleId': instance.cycleId,
  'assignedAt': instance.assignedAt.toIso8601String(),
  'assignmentStrike': const DecimalJsonConverter().toJson(
    instance.assignmentStrike,
  ),
  'contracts': instance.contracts,
};
