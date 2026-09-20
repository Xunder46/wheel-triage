import 'package:drift/drift.dart';

import '../type_converters.dart';

/// Raw facts only (Feature Invariant 12) — no `wheelBasis`/`taxBasis`
/// columns exist here or anywhere; both are computed live.
@DataClassName('ShareLotRow')
class ShareLotTable extends Table {
  @override
  String get tableName => 'share_lot';

  TextColumn get id => text()();
  TextColumn get cycleId => text()();
  IntColumn get assignedAtMs => integer().map(const DateTimeMsConverter())();
  IntColumn get assignmentStrike => integer().map(const CentsConverter())();
  IntColumn get contracts => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
