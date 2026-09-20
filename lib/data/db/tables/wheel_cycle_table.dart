import 'package:drift/drift.dart';

import '../type_converters.dart';

@DataClassName('WheelCycleRow')
class WheelCycleTable extends Table {
  @override
  String get tableName => 'wheel_cycle';

  TextColumn get id => text()();
  TextColumn get underlyingId => text()();
  IntColumn get startedAtMs => integer().map(const DateTimeMsConverter())();
  IntColumn get endedAtMs =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const DateTimeMsConverter()))();
  TextColumn get status => text().map(const WheelCycleStatusConverter())();
  TextColumn get outcome =>
      text().nullable().map(NullAwareTypeConverter.wrap(const WheelCycleOutcomeConverter()))();

  @override
  Set<Column> get primaryKey => {id};
}
