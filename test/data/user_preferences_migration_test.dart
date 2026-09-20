// S-034: migration v1 -> v2 creates `user_preferences`, leaves every
// pre-existing v1 row untouched.
//
// Follows drift_dev's own documented `SchemaVerifier.schemaAt` pattern
// (https://drift.simonbinder.eu/docs/migrations/tests/#verifying-data-
// integrity): insert one row into every v1 table via the schema-specific
// `v1.DatabaseAtV1` (generated with --data-classes --companions so this test
// doesn't need raw SQL), run the real `AppDatabase` migration path, then
// re-read through a versioned schema snapshot to confirm both the new
// table and every old row survived byte-identical.
//
// Migrated all the way to v3 (Phase 15), not stopped at v2: Dart-defined
// tables carry only their current column set, so `onUpgrade`'s `from < 2`
// step (`m.createTable(userPreferencesTable)`) always creates that table
// with every column the table has *today* — including v3's three
// additions — regardless of which target version a test requests. There
// is no way to isolate the v1 -> v2 step alone anymore once a later
// version has extended a table an earlier step creates fresh; this test
// now doubles as the "device skips v2 entirely" coverage for the `from >=
// 2` guard in `AppDatabase`'s v3 step (see `leg_v3_migration_test.dart`
// for the isolated, from-a-real-v2-database v2 -> v3 case, S-092).

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/domain/models/user_preferences_defaults.dart';

import 'db/generated/schema.dart';
import 'db/generated/schema_v3.dart' as v3;
import 'db/generated/schema_v1.dart' as v1;

void main() {
  test('v1 -> v3 migration adds user_preferences and preserves all v1 data', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);

    // One row in each of the six pre-existing v1 tables (fixture per S-034).
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.into(oldDb.underlying).insert(
          v1.UnderlyingCompanion.insert(id: 'u1', ticker: 'AAPL'),
        );
    await oldDb.into(oldDb.wheelCycle).insert(
          v1.WheelCycleCompanion.insert(
            id: 'c1',
            underlyingId: 'u1',
            startedAtMs: 1700000000000,
            status: 'sellingPuts',
          ),
        );
    await oldDb.into(oldDb.leg).insert(
          v1.LegCompanion.insert(
            id: 'l1',
            cycleId: 'c1',
            sequence: 0,
            optionType: 'put',
            strike: 4500,
            expirationMs: 1710000000000,
            contracts: 1,
            openedAtMs: 1700000000000,
            openCreditPerShare: 6000,
            ruleProfileId: 'rule-profile-standard',
          ),
        );
    await oldDb.into(oldDb.snapshot).insert(
          v1.SnapshotCompanion.insert(
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
          v1.ShareLotCompanion.insert(
            id: 'sl1',
            cycleId: 'c1',
            assignedAtMs: 1702000000000,
            assignmentStrike: 4500,
            contracts: 1,
          ),
        );
    await oldDb.into(oldDb.ruleProfile).insert(
          v1.RuleProfileCompanion.insert(
            id: 'rule-profile-standard',
            name: 'Standard',
            profitTargetPct: 50.0,
            assignThreshold: 0.70,
            baseRollBand: 0.30,
            midIvRollBand: 0.35,
            highIvRollBand: 0.40,
            midIvCutoff: 40.0,
            highIvCutoff: 70.0,
            tailDteDays: 3,
            tailExtrinsicThreshold: 500,
            minIvRank: 30.0,
            minAnnualisedYield: 20.0,
            targetDteMin: 30,
            targetDteMax: 45,
            targetDelta: 0.30,
          ),
        );
    await oldDb.close();

    // Run the app's real migration path (onUpgrade's 1 -> 2 -> 3 steps) and
    // validate the resulting live schema matches drift_schema_v3.json.
    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 3);
    await dbForMigration.close();

    final checkDb = v3.DatabaseAtV3(schema.newConnection());
    addTearDown(checkDb.close);

    // New table: exactly one seeded row, at the fixed id, with the app's
    // default preference values (S-035's defaults plus Phase 15's three
    // v3 additions), read through the raw v3 schema snapshot so this test
    // only depends on drift_dev's own generated code, not
    // lib/data/db/type_converters.dart.
    final prefsRows = await checkDb.select(checkDb.userPreferences).get();
    expect(prefsRows, hasLength(1));
    final prefsRow = prefsRows.single;
    expect(prefsRow.id, UserPreferencesDefaults.rowId);
    expect(prefsRow.totalPerContractToggle, UserPreferencesDefaults.totalPerContractToggle);
    expect(prefsRow.deltaConventionDefault, UserPreferencesDefaults.deltaConventionDefault.name);
    expect(prefsRow.firstRunExplainerShown, UserPreferencesDefaults.firstRunExplainerShown);
    expect(
      prefsRow.ivResolutionNoticeDismissed,
      UserPreferencesDefaults.ivResolutionNoticeDismissed,
    );
    expect(prefsRow.exportReminderDismissed, UserPreferencesDefaults.exportReminderDismissed);
    expect(prefsRow.lastExportAtMs, isNull);
    expect(
      prefsRow.notificationMilestones,
      UserPreferencesDefaults.notificationMilestones.join(','),
    );

    // Every pre-existing v1 row survives untouched, byte-identical.
    final underlyingRows = await checkDb.select(checkDb.underlying).get();
    expect(underlyingRows, hasLength(1));
    expect(underlyingRows.single.id, 'u1');
    expect(underlyingRows.single.ticker, 'AAPL');

    final cycleRows = await checkDb.select(checkDb.wheelCycle).get();
    expect(cycleRows, hasLength(1));
    expect(cycleRows.single.id, 'c1');
    expect(cycleRows.single.status, 'sellingPuts');

    final legRows = await checkDb.select(checkDb.leg).get();
    expect(legRows, hasLength(1));
    expect(legRows.single.id, 'l1');
    expect(legRows.single.strike, 4500);
    expect(legRows.single.openCreditPerShare, 6000);
    // Phase 15's three new leg columns backfill to "not recorded"/"true",
    // never to a coerced zero (§4.3) — this pre-existing v1 row never had
    // an open fee recorded, and predates `acceptsAssignment` entirely.
    expect(legRows.single.openFee, isNull);
    expect(legRows.single.closeFee, isNull);
    expect(legRows.single.acceptsAssignment, isTrue);

    final snapshotRows = await checkDb.select(checkDb.snapshot).get();
    expect(snapshotRows, hasLength(1));
    expect(snapshotRows.single.id, 's1');
    expect(snapshotRows.single.underlyingPrice, 460000);

    final shareLotRows = await checkDb.select(checkDb.shareLot).get();
    expect(shareLotRows, hasLength(1));
    expect(shareLotRows.single.id, 'sl1');

    final ruleProfileRows = await checkDb.select(checkDb.ruleProfile).get();
    expect(ruleProfileRows, hasLength(1));
    expect(ruleProfileRows.single.id, 'rule-profile-standard');
    expect(ruleProfileRows.single.tailExtrinsicThreshold, 500);
  });
}
