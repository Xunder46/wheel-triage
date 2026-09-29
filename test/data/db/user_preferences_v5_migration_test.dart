// S-214: schema v5 adds `wheel_capital_cents` (nullable) and
// `concentration_limit_pct` (defaulted to 25) to `user_preferences`, and
// nothing else. A fresh install and a v4 -> v5 migration must agree: both
// report `wheelCapital == null` / `concentrationLimitPct == 25.0` while
// every pre-existing field and every other table's rows survive untouched
// (Pro Wave 1, D-6).
//
// Follows the same `SchemaVerifier.schemaAt` pattern as the other migration
// tests: build a real versioned database through the schema-specific
// generated helpers, run the real `AppDatabase` migration path, then
// re-read through the target version's helpers. Values inserted through the
// generated helpers are RAW SQL values (the helpers do not apply the app's
// type converters), so `wheel_capital_cents` is compared as an integer.

import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/user_preferences_defaults.dart';

import 'generated/schema.dart';
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

/// `StandardProfileDefaults.tailExtrinsicThreshold` ($0.05) as the raw
/// integer ten-thousandths the schema helpers see.
const _defaultTailExtrinsicRaw = 500;

void main() {
  test('S-214: v4 -> v5 adds the two preference columns and leaves every other '
      'row byte-identical', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);

    final oldDb = v4.DatabaseAtV4(schema.newConnection());

    // The v4 fixture: one preferences row with every field set away from
    // its default, plus one of every other table so "nothing else moved"
    // is falsifiable.
    await oldDb.into(oldDb.userPreferences).insert(
          v4.UserPreferencesCompanion.insert(
            id: UserPreferencesDefaults.rowId,
            totalPerContractToggle: true,
            deltaConventionDefault: 'option',
            firstRunExplainerShown: true,
            ivResolutionNoticeDismissed: true,
            exportReminderDismissed: const Value(true),
            lastExportAtMs: const Value(1680000000000),
            notificationMilestones: const Value('7,0'),
          ),
        );
    await oldDb.into(oldDb.ruleProfile).insert(
          v4.RuleProfileCompanion.insert(
            id: RuleProfileIds.standard,
            name: 'Standard',
          ),
        );
    await oldDb.into(oldDb.ruleProfileVersion).insert(
          v4.RuleProfileVersionCompanion.insert(
            id: RuleProfileVersionIds.standardV1,
            profileId: RuleProfileIds.standard,
            version: 1,
            effectiveAtMs: 1700000000000,
            profitTargetPct: StandardProfileDefaults.profitTargetPct,
            assignThreshold: StandardProfileDefaults.assignThreshold,
            baseRollBand: StandardProfileDefaults.baseRollBand,
            midIvRollBand: StandardProfileDefaults.midIvRollBand,
            highIvRollBand: StandardProfileDefaults.highIvRollBand,
            midIvCutoff: StandardProfileDefaults.midIvCutoff,
            highIvCutoff: StandardProfileDefaults.highIvCutoff,
            tailDteDays: StandardProfileDefaults.tailDteDays,
            tailExtrinsicThreshold: _defaultTailExtrinsicRaw,
            minIvRank: StandardProfileDefaults.minIvRank,
            minAnnualisedYield: StandardProfileDefaults.minAnnualisedYield,
            targetDteMin: StandardProfileDefaults.targetDteMin,
            targetDteMax: StandardProfileDefaults.targetDteMax,
            targetDelta: StandardProfileDefaults.targetDelta,
          ),
        );
    await oldDb.into(oldDb.underlying).insert(
          v4.UnderlyingCompanion.insert(id: 'u1', ticker: 'AAPL'),
        );
    await oldDb.into(oldDb.wheelCycle).insert(
          v4.WheelCycleCompanion.insert(
            id: 'c1',
            underlyingId: 'u1',
            startedAtMs: 1700000000000,
            status: 'sellingPuts',
          ),
        );
    await oldDb.into(oldDb.leg).insert(
          v4.LegCompanion.insert(
            id: 'l1',
            cycleId: 'c1',
            sequence: 0,
            optionType: 'put',
            strike: 4500,
            expirationMs: 1710000000000,
            contracts: 1,
            openedAtMs: 1700000000000,
            openCreditPerShare: 6000,
            closedAtMs: const Value(1705000000000),
            closeDebitPerShare: const Value(2000),
            closeReason: const Value('expiredWorthless'),
            openFee: const Value(65),
            closeFee: const Value(65),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );
    await oldDb.into(oldDb.snapshot).insert(
          v4.SnapshotCompanion.insert(
            id: 's1',
            legId: 'l1',
            takenAtMs: 1701000000000,
            optionMark: 3000,
            underlyingPrice: 460000,
            deltaAsEntered: -0.25,
            deltaConvention: 'position',
          ),
        );
    await oldDb.into(oldDb.shareLot).insert(
          v4.ShareLotCompanion.insert(
            id: 'sl1',
            cycleId: 'c1',
            assignedAtMs: 1700150000000,
            assignmentStrike: 5000,
            contracts: 1,
          ),
        );
    await oldDb.close();

    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 5);
    await dbForMigration.close();

    final checkDb = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(checkDb.close);

    // The two new columns backfill to "not set" / 25.
    final prefs = (await checkDb.select(checkDb.userPreferences).get()).single;
    expect(prefs.wheelCapitalCents, isNull);
    expect(prefs.concentrationLimitPct, 25.0);

    // Every pre-existing preference field survived exactly.
    expect(prefs.totalPerContractToggle, isTrue);
    expect(prefs.deltaConventionDefault, 'option');
    expect(prefs.firstRunExplainerShown, isTrue);
    expect(prefs.ivResolutionNoticeDismissed, isTrue);
    expect(prefs.exportReminderDismissed, isTrue);
    expect(prefs.lastExportAtMs, 1680000000000);
    expect(prefs.notificationMilestones, '7,0');

    // Every other table's rows are untouched.
    expect((await checkDb.select(checkDb.underlying).get()), hasLength(1));
    expect((await checkDb.select(checkDb.wheelCycle).get()), hasLength(1));
    expect((await checkDb.select(checkDb.ruleProfile).get()), hasLength(1));
    expect((await checkDb.select(checkDb.ruleProfileVersion).get()), hasLength(1));
    final leg = (await checkDb.select(checkDb.leg).get()).single;
    expect(leg.openCreditPerShare, 6000);
    expect(leg.closeDebitPerShare, 2000);
    expect(leg.closeReason, 'expiredWorthless');
    expect(leg.openFee, 65);
    expect(leg.closeFee, 65);
    expect(leg.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
    expect((await checkDb.select(checkDb.snapshot).get()), hasLength(1));
    expect((await checkDb.select(checkDb.shareLot).get()), hasLength(1));
  });

  test('S-214: a fresh v5 install reports the same two values as the migration', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await db.seedDefaultPreferences();

    final checkDb = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(checkDb.close);

    final prefs = (await checkDb.select(checkDb.userPreferences).get()).single;
    expect(prefs.wheelCapitalCents, isNull);
    expect(prefs.concentrationLimitPct, 25.0);
    expect(prefs.totalPerContractToggle, UserPreferencesDefaults.totalPerContractToggle);
    expect(prefs.notificationMilestones, '21,7,0');
  });

  test('S-214 (gate): targeting v4 never runs the v5 step', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    // Start below v4 so the 3 -> 4 upgrade really runs (a v4 database
    // migrated "to v4" would be a no-op) while the v5 step stays gated out.
    final schema = await verifier.schemaAt(3);

    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    await oldDb.into(oldDb.userPreferences).insert(
          v3.UserPreferencesCompanion.insert(
            id: UserPreferencesDefaults.rowId,
            totalPerContractToggle: false,
            deltaConventionDefault: 'position',
            firstRunExplainerShown: false,
            ivResolutionNoticeDismissed: false,
          ),
        );
    await oldDb.close();

    // `migrateAndValidate(db, N)` migrates *to* N — drift is told the
    // database's version is N, so `onUpgrade` receives `to == N` — and then
    // validates the result against N's schema snapshot. N is therefore the
    // version `DatabaseAtV4` below reads through, not the app's current
    // `schemaVersion` (5).
    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 4);
    await dbForMigration.close();

    final checkDb = v4.DatabaseAtV4(schema.newConnection());
    addTearDown(checkDb.close);

    // The v4 shape is intact: neither v5 column exists.
    final columns = await checkDb
        .customSelect("SELECT name FROM pragma_table_info('user_preferences')")
        .get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    expect(names, isNot(contains('wheel_capital_cents')));
    expect(names, isNot(contains('concentration_limit_pct')));
  });
}
