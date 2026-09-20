import 'package:drift/drift.dart';

import '../type_converters.dart';

@DataClassName('SnapshotRow')
class SnapshotTable extends Table {
  @override
  String get tableName => 'snapshot';

  TextColumn get id => text()();
  TextColumn get legId => text()();
  IntColumn get takenAtMs => integer().map(const DateTimeMsConverter())();
  IntColumn get optionMark => integer().map(const TenThousandthsConverter())();
  IntColumn get underlyingPrice => integer().map(const CentsConverter())();
  RealColumn get deltaAsEntered => real()();
  TextColumn get deltaConvention => text().map(const DeltaConventionConverter())();
  RealColumn get gamma => real().nullable()();
  RealColumn get theta => real().nullable()();
  RealColumn get vega => real().nullable()();
  RealColumn get iv => real().nullable()();
  IntColumn get openInterest => integer().nullable()();
  IntColumn get volume => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
