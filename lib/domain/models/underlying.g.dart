// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'underlying.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Underlying _$UnderlyingFromJson(Map<String, dynamic> json) => _Underlying(
  id: json['id'] as String,
  ticker: json['ticker'] as String,
  displayName: json['displayName'] as String?,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$UnderlyingToJson(_Underlying instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticker': instance.ticker,
      'displayName': instance.displayName,
      'notes': instance.notes,
    };
