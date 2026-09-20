import 'package:drift/drift.dart';

/// Identity only (`id`, `name`) since Iteration 5 (D-3) — mirrors
/// `lib/domain/models/rule_profile_data.dart`. The 14 threshold columns and
/// the money encoding that lived here moved to `rule_profile_version_table`
/// (Feature Invariant 9's `tailExtrinsicThreshold` split applies there).
@DataClassName('RuleProfileRow')
class RuleProfileTable extends Table {
  @override
  String get tableName => 'rule_profile';

  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}
