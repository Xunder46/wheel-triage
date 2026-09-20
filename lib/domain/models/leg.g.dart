// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leg.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Leg _$LegFromJson(Map<String, dynamic> json) => _Leg(
  id: json['id'] as String,
  cycleId: json['cycleId'] as String,
  sequence: (json['sequence'] as num).toInt(),
  optionType: $enumDecode(_$OptionTypeEnumMap, json['optionType']),
  strike: const DecimalJsonConverter().fromJson(json['strike'] as String),
  expiration: DateTime.parse(json['expiration'] as String),
  contracts: (json['contracts'] as num).toInt(),
  openedAt: DateTime.parse(json['openedAt'] as String),
  openCreditPerShare: const DecimalJsonConverter().fromJson(
    json['openCreditPerShare'] as String,
  ),
  closedAt: json['closedAt'] == null
      ? null
      : DateTime.parse(json['closedAt'] as String),
  closeDebitPerShare: const NullableDecimalJsonConverter().fromJson(
    json['closeDebitPerShare'] as String?,
  ),
  closeReason: $enumDecodeNullable(_$CloseReasonEnumMap, json['closeReason']),
  rolledFromLegId: json['rolledFromLegId'] as String?,
  ruleProfileVersionId: json['ruleProfileVersionId'] as String,
  ivAtOpen: (json['ivAtOpen'] as num?)?.toDouble(),
  ivRankAtOpen: (json['ivRankAtOpen'] as num?)?.toDouble(),
  deltaAtOpen: (json['deltaAtOpen'] as num?)?.toDouble(),
  underlyingPriceAtOpen: const NullableDecimalJsonConverter().fromJson(
    json['underlyingPriceAtOpen'] as String?,
  ),
  openFee: const NullableDecimalJsonConverter().fromJson(
    json['openFee'] as String?,
  ),
  closeFee: const NullableDecimalJsonConverter().fromJson(
    json['closeFee'] as String?,
  ),
  acceptsAssignment: json['acceptsAssignment'] as bool? ?? true,
);

Map<String, dynamic> _$LegToJson(_Leg instance) => <String, dynamic>{
  'id': instance.id,
  'cycleId': instance.cycleId,
  'sequence': instance.sequence,
  'optionType': _$OptionTypeEnumMap[instance.optionType]!,
  'strike': const DecimalJsonConverter().toJson(instance.strike),
  'expiration': instance.expiration.toIso8601String(),
  'contracts': instance.contracts,
  'openedAt': instance.openedAt.toIso8601String(),
  'openCreditPerShare': const DecimalJsonConverter().toJson(
    instance.openCreditPerShare,
  ),
  'closedAt': instance.closedAt?.toIso8601String(),
  'closeDebitPerShare': const NullableDecimalJsonConverter().toJson(
    instance.closeDebitPerShare,
  ),
  'closeReason': _$CloseReasonEnumMap[instance.closeReason],
  'rolledFromLegId': instance.rolledFromLegId,
  'ruleProfileVersionId': instance.ruleProfileVersionId,
  'ivAtOpen': instance.ivAtOpen,
  'ivRankAtOpen': instance.ivRankAtOpen,
  'deltaAtOpen': instance.deltaAtOpen,
  'underlyingPriceAtOpen': const NullableDecimalJsonConverter().toJson(
    instance.underlyingPriceAtOpen,
  ),
  'openFee': const NullableDecimalJsonConverter().toJson(instance.openFee),
  'closeFee': const NullableDecimalJsonConverter().toJson(instance.closeFee),
  'acceptsAssignment': instance.acceptsAssignment,
};

const _$OptionTypeEnumMap = {OptionType.put: 'put', OptionType.call: 'call'};

const _$CloseReasonEnumMap = {
  CloseReason.rolled: 'rolled',
  CloseReason.closedEarly: 'closedEarly',
  CloseReason.expiredWorthless: 'expiredWorthless',
  CloseReason.assigned: 'assigned',
};
