import 'package:drift/drift.dart';

import '../type_converters.dart';

@DataClassName('LegRow')
class LegTable extends Table {
  @override
  String get tableName => 'leg';

  TextColumn get id => text()();
  TextColumn get cycleId => text()();
  IntColumn get sequence => integer()();
  TextColumn get optionType => text().map(const OptionTypeConverter())();
  IntColumn get strike => integer().map(const CentsConverter())();
  IntColumn get expirationMs => integer().map(const DateTimeMsConverter())();
  IntColumn get contracts => integer()();
  IntColumn get openedAtMs => integer().map(const DateTimeMsConverter())();
  IntColumn get openCreditPerShare => integer().map(const TenThousandthsConverter())();
  IntColumn get closedAtMs =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const DateTimeMsConverter()))();
  IntColumn get closeDebitPerShare =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const TenThousandthsConverter()))();
  TextColumn get closeReason =>
      text().nullable().map(NullAwareTypeConverter.wrap(const CloseReasonConverter()))();
  TextColumn get rolledFromLegId => text().nullable()();
  TextColumn get ruleProfileVersionId => text()();
  RealColumn get ivAtOpen => real().nullable()();
  RealColumn get ivRankAtOpen => real().nullable()();
  RealColumn get deltaAtOpen => real().nullable()();
  IntColumn get underlyingPriceAtOpen =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const CentsConverter()))();

  // --- Schema v3 (Phase 15) ----------------------------------------------

  /// Integer cents, total for the transaction. Nullable with no SQL
  /// default — a pre-v3 row's `ADD COLUMN` backfills to `NULL`, never `0`
  /// (§4.3: "not recorded" is not "zero").
  IntColumn get openFee => integer().nullable().map(NullAwareTypeConverter.wrap(const CentsConverter()))();
  IntColumn get closeFee => integer().nullable().map(NullAwareTypeConverter.wrap(const CentsConverter()))();

  /// SQL-level default so a pre-v3 row's `ADD COLUMN` backfills existing
  /// legs to `true`, matching `Leg.acceptsAssignment`'s `@Default(true)`.
  BoolColumn get acceptsAssignment => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
