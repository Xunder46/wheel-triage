import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Serializes [Decimal] as its exact decimal string representation (never a
/// [num]/[double]) so round-tripping through JSON never loses precision.
///
/// Every money-denominated model field uses this converter. Conversion
/// to/from the integer storage units (cents / ten-thousandths) happens only
/// at the persistence boundary inside `lib/data/`, per
/// docs/conventions.md §1 — models themselves always carry `Decimal`.
class DecimalJsonConverter implements JsonConverter<Decimal, String> {
  const DecimalJsonConverter();

  @override
  Decimal fromJson(String json) => Decimal.parse(json);

  @override
  String toJson(Decimal object) => object.toString();
}

/// Same as [DecimalJsonConverter] but for nullable `Decimal?` fields.
class NullableDecimalJsonConverter implements JsonConverter<Decimal?, String?> {
  const NullableDecimalJsonConverter();

  @override
  Decimal? fromJson(String? json) => json == null ? null : Decimal.parse(json);

  @override
  String? toJson(Decimal? object) => object?.toString();
}
