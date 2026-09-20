import 'package:drift/drift.dart';

/// SQL table name is `underlying` (S-031); the generated row class is named
/// `UnderlyingRow` (not `Underlying`) to keep it distinct from the domain
/// model `lib/domain/models/underlying.dart` — `DriftWheelRepository` is the
/// only place that maps between the two.
@DataClassName('UnderlyingRow')
class UnderlyingTable extends Table {
  @override
  String get tableName => 'underlying';

  TextColumn get id => text()();
  TextColumn get ticker => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
