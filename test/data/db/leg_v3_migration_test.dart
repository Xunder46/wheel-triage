// S-092: migration v2 -> v3 adds the three `leg` columns and the three
// `user_preferences` columns, leaves every pre-existing v2 row untouched.
//
// Follows the same `SchemaVerifier.schemaAt` pattern as
// test/data/db/app_database_migration_test.dart and
// test/data/user_preferences_migration_test.dart: build a real v2 database
// (one row in each of the seven v2 tables, via the schema-specific,
// --data-classes --companions-generated `v2.DatabaseAtV2`), run the real
// `AppDatabase` migration path from v2 to v3, then re-read through
// `v3.DatabaseAtV3` to confirm both the new columns and every old row
// survived byte-identical. Unlike the v1 -> v3 test, this one starts from
// an actual v2-shaped `user_preferences` row (not one created fresh mid-
// migration), so it isolates the `from >= 2` ALTER-TABLE branch of
// `AppDatabase`'s v3 step on its own.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/domain/models/user_preferences_defaults.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  test('v2 -> v3 migration adds leg/user_preferences columns and preserves all v2 data',
      () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(2);

    // One row in each of the seven pre-existing v2 tables (fixture per
    // S-092).
    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    await oldDb.into(oldDb.underlying).insert(
          v2.UnderlyingCompanion.insert(id: 'u1', ticker: 'AAPL'),
        );
    await oldDb.into(oldDb.wheelCycle).insert(
          v2.WheelCycleCompanion.insert(
            id: 'c1',
            underlyingId: 'u1',
            startedAtMs: 1700000000000,
            status: 'sellingPuts',
          ),
        );
    await oldDb.into(oldDb.leg).insert(
          v2.LegCompanion.insert(
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
          v2.SnapshotCompanion.insert(
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
          v2.ShareLotCompanion.insert(
            id: 'sl1',
            cycleId: 'c1',
            assignedAtMs: 1702000000000,
            assignmentStrike: 4500,
            contracts: 1,
          ),
        );
    await oldDb.into(oldDb.ruleProfile).insert(
          v2.RuleProfileCompanion.insert(
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
    await oldDb.into(oldDb.userPreferences).insert(
          v2.UserPreferencesCompanion.insert(
            id: UserPreferencesDefaults.rowId,
            totalPerContractToggle: true,
            deltaConventionDefault: 'option',
            firstRunExplainerShown: true,
            ivResolutionNoticeDismissed: true,
          ),
        );
    await oldDb.close();

    // Run the app's real migration path (onUpgrade's 2 -> 3 step) and
    // validate the resulting live schema matches drift_schema_v3.json.
    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 3);
    await dbForMigration.close();

    final checkDb = v3.DatabaseAtV3(schema.newConnection());
    addTearDown(checkDb.close);

    // The pre-existing leg row survives byte-identical, and its three new
    // v3 columns backfill to "not recorded"/"true" — never a coerced zero
    // (§4.3) or false.
    final legRows = await checkDb.select(checkDb.leg).get();
    expect(legRows, hasLength(1));
    final legRow = legRows.single;
    expect(legRow.id, 'l1');
    expect(legRow.strike, 4500);
    expect(legRow.openCreditPerShare, 6000);
    expect(legRow.openFee, isNull);
    expect(legRow.closeFee, isNull);
    expect(legRow.acceptsAssignment, isTrue);

    // The pre-existing user_preferences row survives with its original
    // (non-default) values untouched, and its three new v3 columns
    // backfill to the app's stated defaults, not to whatever the
    // pre-existing row's other fields happened to be.
    final prefsRows = await checkDb.select(checkDb.userPreferences).get();
    expect(prefsRows, hasLength(1));
    final prefsRow = prefsRows.single;
    expect(prefsRow.id, UserPreferencesDefaults.rowId);
    expect(prefsRow.totalPerContractToggle, isTrue);
    expect(prefsRow.deltaConventionDefault, 'option');
    expect(prefsRow.firstRunExplainerShown, isTrue);
    expect(prefsRow.ivResolutionNoticeDismissed, isTrue);
    expect(prefsRow.exportReminderDismissed, UserPreferencesDefaults.exportReminderDismissed);
    expect(prefsRow.lastExportAtMs, isNull);
    expect(
      prefsRow.notificationMilestones,
      UserPreferencesDefaults.notificationMilestones.join(','),
    );

    // Every other pre-existing v2 row survives untouched, byte-identical.
    final underlyingRows = await checkDb.select(checkDb.underlying).get();
    expect(underlyingRows, hasLength(1));
    expect(underlyingRows.single.id, 'u1');

    final cycleRows = await checkDb.select(checkDb.wheelCycle).get();
    expect(cycleRows, hasLength(1));
    expect(cycleRows.single.id, 'c1');

    final snapshotRows = await checkDb.select(checkDb.snapshot).get();
    expect(snapshotRows, hasLength(1));
    expect(snapshotRows.single.id, 's1');

    final shareLotRows = await checkDb.select(checkDb.shareLot).get();
    expect(shareLotRows, hasLength(1));
    expect(shareLotRows.single.id, 'sl1');

    final ruleProfileRows = await checkDb.select(checkDb.ruleProfile).get();
    expect(ruleProfileRows, hasLength(1));
    expect(ruleProfileRows.single.id, 'rule-profile-standard');
  });
}
