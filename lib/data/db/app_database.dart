import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/leg.dart';
import '../../domain/models/rule_profile_defaults.dart';
import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/models/user_preferences_defaults.dart';
import '../../domain/models/wheel_cycle.dart';
import 'tables/leg_table.dart';
import 'tables/rule_profile_table.dart';
import 'tables/rule_profile_version_table.dart';
import 'tables/share_lot_table.dart';
import 'tables/snapshot_table.dart';
import 'tables/underlying_table.dart';
import 'tables/user_preferences_table.dart';
import 'tables/wheel_cycle_table.dart';
import 'type_converters.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  UnderlyingTable,
  WheelCycleTable,
  LegTable,
  SnapshotTable,
  ShareLotTable,
  RuleProfileTable,
  RuleProfileVersionTable,
  UserPreferencesTable,
])
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'wheel_triage'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await seedRuleProfiles();
          await seedDefaultPreferences();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Schema v2 (Iteration 3, Phase 8): adds `user_preferences` only —
          // every v1 table/row is untouched by this step (S-034). Gated on
          // `to` as well as `from` so this step (and the v3 step below) run
          // in isolation when a migration test targets an intermediate
          // version via `SchemaVerifier.migrateAndValidate(db, N)`, not just
          // during a real device's from-v1-to-v3 upgrade.
          if (from < 2 && to >= 2) {
            await m.createTable(userPreferencesTable);
            await seedDefaultPreferences();
          }
          // Schema v3 (Iteration 4, Phase 15): three new nullable/defaulted
          // columns on `leg`, three on `user_preferences` — no other table
          // changes (S-092). Every column's own `withDefault`/nullability
          // (declared on the table getters) backfills pre-existing rows:
          // `open_fee`/`close_fee` -> null, `accepts_assignment` -> true,
          // `export_reminder_dismissed` -> false, `last_export_at_ms` ->
          // null, `notification_milestones` -> '21,7,0'.
          if (from < 3 && to >= 3) {
            await m.addColumn(legTable, legTable.openFee);
            await m.addColumn(legTable, legTable.closeFee);
            await m.addColumn(legTable, legTable.acceptsAssignment);
            // `user_preferences` only needs these three ALTERed in when the
            // table already existed pre-upgrade (from >= 2). A direct
            // v1 -> v3 jump instead creates the table fresh via the `from <
            // 2` step above, using `userPreferencesTable`'s current (v3)
            // Dart definition — which already carries these columns, so
            // adding them again here would be a duplicate-column error.
            if (from >= 2) {
              await m.addColumn(
                userPreferencesTable,
                userPreferencesTable.exportReminderDismissed,
              );
              await m.addColumn(userPreferencesTable, userPreferencesTable.lastExportAtMs);
              await m.addColumn(
                userPreferencesTable,
                userPreferencesTable.notificationMilestones,
              );
            }
          }
          // Schema v4 (Iteration 5, Phase 24): `rule_profile` keeps identity
          // only; its 14 threshold columns move to the new append-only
          // `rule_profile_version` table, and every existing leg's
          // `rule_profile_id` value is rewritten to `<profileId>-v1` so legs
          // pin a version from the moment this migration lands (D-3…D-7).
          // Order is load-bearing: the version rows must be copied out
          // *before* `alterTable` re-creates `rule_profile` without those
          // columns. Gated on `to` as well as `from`, like the v2/v3 steps,
          // so a migration test targeting an intermediate version
          // (`SchemaVerifier.migrateAndValidate(db, 3)`) never runs it.
          if (from < 4 && to >= 4) {
            await m.createTable(ruleProfileVersionTable);

            // One timestamp shared by every v1 row this run creates. Raw
            // SQL because the threshold columns no longer exist in
            // `ruleProfileTable`'s Dart definition and are dropped below.
            final migratedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
            await customStatement(
              'INSERT INTO rule_profile_version ('
              'id, profile_id, version, effective_at_ms, '
              'profit_target_pct, assign_threshold, base_roll_band, mid_iv_roll_band, '
              'high_iv_roll_band, mid_iv_cutoff, high_iv_cutoff, tail_dte_days, '
              'tail_extrinsic_threshold, min_iv_rank, min_annualised_yield, '
              'target_dte_min, target_dte_max, target_delta'
              ') SELECT '
              "id || '-v1', id, 1, ?, "
              'profit_target_pct, assign_threshold, base_roll_band, mid_iv_roll_band, '
              'high_iv_roll_band, mid_iv_cutoff, high_iv_cutoff, tail_dte_days, '
              'tail_extrinsic_threshold, min_iv_rank, min_annualised_yield, '
              'target_dte_min, target_dte_max, target_delta '
              'FROM rule_profile',
              [migratedAt],
            );

            // Every existing leg now pins its profile's v1 version id:
            // rename the column first, then rewrite the value — a rename
            // alone would leave every legacy pin pointing at a value that
            // no `rule_profile_version` row carries (D-4/D-6). The append
            // is unconditional and unvalidated (D-7): a dangling legacy id
            // simply stays dangling, exactly as it behaved before.
            await m.renameColumn(legTable, 'rule_profile_id', legTable.ruleProfileVersionId);
            await customStatement(
              "UPDATE leg SET rule_profile_version_id = rule_profile_version_id || '-v1'",
            );

            // Drop the 14 columns that moved to `rule_profile_version`.
            for (final column in _ruleProfileV3OnlyColumns) {
              await m.dropColumn(ruleProfileTable, column);
            }
          }
          // Schema v5 (Pro Wave 1, Phase 2): two new columns on
          // `user_preferences` — `wheel_capital_cents` (nullable, "not set"
          // backfills to null) and `concentration_limit_pct` (real, SQL
          // default 25) — and nothing else (S-214). Gated on `to` as well as
          // `from`, like every step above, so a migration test targeting an
          // intermediate version never runs it.
          //
          // The `from >= 2` guard mirrors the v3 step: a direct v1 -> v5
          // jump creates the table fresh from its current Dart definition,
          // which already carries both columns.
          if (from < 5 && to >= 5) {
            if (from >= 2) {
              await m.addColumn(userPreferencesTable, userPreferencesTable.wheelCapitalCents);
              await m.addColumn(
                userPreferencesTable,
                userPreferencesTable.concentrationLimitPct,
              );
            }
          }
        },
      );

  /// The `rule_profile` columns that exist at v3 and not at v4 — the ones
  /// the v4 upgrade step drops after copying them into v1 version rows.
  /// Listed as SQL names (snake_case) because the Dart getters no longer
  /// exist on the shrunk `RuleProfileTable`.
  static const _ruleProfileV3OnlyColumns = [
    'profit_target_pct',
    'assign_threshold',
    'base_roll_band',
    'mid_iv_roll_band',
    'high_iv_roll_band',
    'mid_iv_cutoff',
    'high_iv_cutoff',
    'tail_dte_days',
    'tail_extrinsic_threshold',
    'min_iv_rank',
    'min_annualised_yield',
    'target_dte_min',
    'target_dte_max',
    'target_delta',
  ];

  /// Inserts the three built-in rule profiles (Feature Invariant 8) with
  /// stable, fixed ids (`lib/domain/models/rule_profile_ids.dart`) plus each
  /// profile's v1 threshold version (Iteration 5, D-3/D-6) — the same
  /// values the v4 migration copies into v1 rows, from the same
  /// `StandardProfileDefaults` constants, so a fresh install and an
  /// upgraded install observe identical data. One install-time timestamp
  /// is shared by all three version rows. Public (not just called from
  /// `onCreate`) so `InMemoryWheelRepository` and tests can reuse the exact
  /// same default values without duplicating the numbers.
  Future<void> seedRuleProfiles() async {
    final seededAt = DateTime.now();
    for (final (id, name) in [
      (RuleProfileIds.conservative, 'Conservative'),
      (RuleProfileIds.standard, 'Standard'),
      (RuleProfileIds.aggressive, 'Aggressive'),
    ]) {
      await into(ruleProfileTable).insert(
        RuleProfileTableCompanion.insert(id: id, name: name),
      );
      await into(ruleProfileVersionTable).insert(
        _standardVersionCompanion(
          id: RuleProfileVersionIds.forVersion(id, 1),
          profileId: id,
          effectiveAt: seededAt,
        ),
      );
    }
  }

  RuleProfileVersionTableCompanion _standardVersionCompanion({
    required String id,
    required String profileId,
    required DateTime effectiveAt,
  }) =>
      RuleProfileVersionTableCompanion.insert(
        id: id,
        profileId: profileId,
        version: 1,
        effectiveAtMs: effectiveAt,
        profitTargetPct: StandardProfileDefaults.profitTargetPct,
        assignThreshold: StandardProfileDefaults.assignThreshold,
        baseRollBand: StandardProfileDefaults.baseRollBand,
        midIvRollBand: StandardProfileDefaults.midIvRollBand,
        highIvRollBand: StandardProfileDefaults.highIvRollBand,
        midIvCutoff: StandardProfileDefaults.midIvCutoff,
        highIvCutoff: StandardProfileDefaults.highIvCutoff,
        tailDteDays: StandardProfileDefaults.tailDteDays,
        tailExtrinsicThreshold: StandardProfileDefaults.tailExtrinsicThreshold,
        minIvRank: StandardProfileDefaults.minIvRank,
        minAnnualisedYield: StandardProfileDefaults.minAnnualisedYield,
        targetDteMin: StandardProfileDefaults.targetDteMin,
        targetDteMax: StandardProfileDefaults.targetDteMax,
        targetDelta: StandardProfileDefaults.targetDelta,
      );

  /// Inserts the single fixed-id `user_preferences` row (schema v2) with
  /// the app's default preference values
  /// (`lib/domain/models/user_preferences_defaults.dart`). Public — same
  /// visibility rationale as `seedRuleProfiles` — so both `onCreate` and
  /// the `1 -> 2` `onUpgrade` step share this one insert path, and tests
  /// can reuse it without duplicating the default values.
  Future<void> seedDefaultPreferences() async {
    await into(userPreferencesTable).insert(
      UserPreferencesTableCompanion.insert(
        id: UserPreferencesDefaults.rowId,
        totalPerContractToggle: UserPreferencesDefaults.totalPerContractToggle,
        deltaConventionDefault: UserPreferencesDefaults.deltaConventionDefault,
        firstRunExplainerShown: UserPreferencesDefaults.firstRunExplainerShown,
        ivResolutionNoticeDismissed: UserPreferencesDefaults.ivResolutionNoticeDismissed,
        // These three columns carry a SQL-level `withDefault` (so a v2 -> v3
        // migration backfills them without a second hand-duplicated
        // literal — see `tables/user_preferences_table.dart`), which makes
        // them optional, `Value`-wrapped fields in the generated
        // `.insert()` constructor rather than raw values.
        exportReminderDismissed: const Value(UserPreferencesDefaults.exportReminderDismissed),
        lastExportAtMs: const Value(UserPreferencesDefaults.lastExportAt),
        notificationMilestones: const Value(UserPreferencesDefaults.notificationMilestones),
        // Schema v5 (Pro Wave 1, D-6). `concentrationLimitPct` carries a
        // SQL-level `withDefault` for the same reason as the v3 columns
        // above; `wheelCapitalCents` is nullable with no default, so it is
        // simply omitted — "not set" is the absence of a value.
        concentrationLimitPct: const Value(UserPreferencesDefaults.concentrationLimitPct),
      ),
    );
  }
}
