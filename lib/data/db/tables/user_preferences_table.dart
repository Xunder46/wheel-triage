import 'package:drift/drift.dart';

import '../../../domain/models/user_preferences_defaults.dart';
import '../type_converters.dart';

/// Single fixed-id row (schema v2, Phase 8 step 3) — this table only ever
/// holds one row, at id `UserPreferencesDefaults.rowId` ('default'). Mirrors
/// `lib/domain/models/user_preferences.dart` 1:1 plus this table-only `id`
/// primary key, which `DriftWheelRepository` never surfaces through
/// `WheelRepository`. Reuses the existing `DeltaConventionConverter`
/// (`lib/data/db/type_converters.dart`, built in Phase 2 for
/// `SnapshotTable`) rather than declaring a second converter for the same
/// enum.
@DataClassName('UserPreferencesRow')
class UserPreferencesTable extends Table {
  @override
  String get tableName => 'user_preferences';

  TextColumn get id => text()();
  BoolColumn get totalPerContractToggle => boolean()();
  TextColumn get deltaConventionDefault => text().map(const DeltaConventionConverter())();
  BoolColumn get firstRunExplainerShown => boolean()();
  BoolColumn get ivResolutionNoticeDismissed => boolean()();

  // --- Schema v3 (Phase 15) ----------------------------------------------
  //
  // SQL-level defaults on the boolean/text columns so the one pre-existing
  // v2 row's `ADD COLUMN` backfills to the same values
  // `UserPreferencesDefaults` already defines, rather than a second,
  // hand-duplicated literal. `lastExportAtMs` is nullable with no default —
  // "never exported" backfills to `null`.

  BoolColumn get exportReminderDismissed =>
      boolean().withDefault(const Constant(UserPreferencesDefaults.exportReminderDismissed))();
  IntColumn get lastExportAtMs =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const DateTimeMsConverter()))();
  TextColumn get notificationMilestones => text()
      .map(const IntListConverter())
      .withDefault(Constant(UserPreferencesDefaults.notificationMilestones.join(',')))();

  // --- Schema v5 (Pro Wave 1, D-6) ---------------------------------------
  //
  // `wheelCapitalCents` is nullable with no default: "not set" backfills to
  // `null`, never to zero. Money is integer **cents** here — equity, not
  // option prices — so `CentsConverter`, not `TenThousandthsConverter`.
  // `concentrationLimitPct` is a dimensionless percentage, so a plain real
  // with the brief's 25 as its SQL-level default, matching the v3 pattern
  // above.

  IntColumn get wheelCapitalCents =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const CentsConverter()))();
  RealColumn get concentrationLimitPct =>
      real().withDefault(const Constant(UserPreferencesDefaults.concentrationLimitPct))();

  @override
  Set<Column> get primaryKey => {id};
}
