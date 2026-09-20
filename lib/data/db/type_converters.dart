import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../domain/models/leg.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/models/wheel_cycle.dart';

/// Storage-specific concerns (integer money encodings, enum-to-text mapping)
/// live here, inside the Drift layer, and never surface through
/// `WheelRepository`'s signatures (docs/conventions.md §6).

// --- Money -------------------------------------------------------------
//
// Integer cents for underlying/equity-price fields, integer ten-thousandths
// for option-price fields (Feature Invariant 9). Both conversions are exact
// for any value with <=2 (cents) or <=4 (ten-thousandths) decimal digits —
// dividing by a power of ten always has finite decimal precision.

Decimal centsToDecimal(int cents) => (Decimal.fromInt(cents) / Decimal.fromInt(100)).toDecimal();

int decimalToCents(Decimal value) =>
    (value * Decimal.fromInt(100)).round().toBigInt().toInt();

Decimal tenThousandthsToDecimal(int value) =>
    (Decimal.fromInt(value) / Decimal.fromInt(10000)).toDecimal();

int decimalToTenThousandths(Decimal value) =>
    (value * Decimal.fromInt(10000)).round().toBigInt().toInt();

/// [Decimal] column storing integer cents on disk.
class CentsConverter extends TypeConverter<Decimal, int> {
  const CentsConverter();

  @override
  Decimal fromSql(int fromDb) => centsToDecimal(fromDb);

  @override
  int toSql(Decimal value) => decimalToCents(value);
}

/// [Decimal] column storing integer ten-thousandths on disk.
class TenThousandthsConverter extends TypeConverter<Decimal, int> {
  const TenThousandthsConverter();

  @override
  Decimal fromSql(int fromDb) => tenThousandthsToDecimal(fromDb);

  @override
  int toSql(Decimal value) => decimalToTenThousandths(value);
}

// --- Timestamps ----------------------------------------------------------
//
// Integer epoch milliseconds, one unit/suffix everywhere (docs/conventions.md
// naming table: `_ms`).

class DateTimeMsConverter extends TypeConverter<DateTime, int> {
  const DateTimeMsConverter();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

// --- Enums -----------------------------------------------------------
//
// Stored as their `.name` text, never an integer index, so reordering or
// inserting an enum value later never silently reinterprets old rows.

class OptionTypeConverter extends TypeConverter<OptionType, String> {
  const OptionTypeConverter();

  @override
  OptionType fromSql(String fromDb) => OptionType.values.byName(fromDb);

  @override
  String toSql(OptionType value) => value.name;
}

class CloseReasonConverter extends TypeConverter<CloseReason, String> {
  const CloseReasonConverter();

  @override
  CloseReason fromSql(String fromDb) => CloseReason.values.byName(fromDb);

  @override
  String toSql(CloseReason value) => value.name;
}

class WheelCycleStatusConverter extends TypeConverter<WheelCycleStatus, String> {
  const WheelCycleStatusConverter();

  @override
  WheelCycleStatus fromSql(String fromDb) => WheelCycleStatus.values.byName(fromDb);

  @override
  String toSql(WheelCycleStatus value) => value.name;
}

class WheelCycleOutcomeConverter extends TypeConverter<WheelCycleOutcome, String> {
  const WheelCycleOutcomeConverter();

  @override
  WheelCycleOutcome fromSql(String fromDb) => WheelCycleOutcome.values.byName(fromDb);

  @override
  String toSql(WheelCycleOutcome value) => value.name;
}

class DeltaConventionConverter extends TypeConverter<DeltaConvention, String> {
  const DeltaConventionConverter();

  @override
  DeltaConvention fromSql(String fromDb) => DeltaConvention.values.byName(fromDb);

  @override
  String toSql(DeltaConvention value) => value.name;
}

// --- Lists ---------------------------------------------------------------

/// `List<int>` column storing a comma-joined `TEXT` value on disk (schema
/// v3, Phase 15) — used for `user_preferences.notification_milestones`. An
/// empty list round-trips as an empty string, never a stray leading/trailing
/// comma.
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) =>
      fromDb.isEmpty ? const [] : fromDb.split(',').map(int.parse).toList();

  @override
  String toSql(List<int> value) => value.join(',');
}
