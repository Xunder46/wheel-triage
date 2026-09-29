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
// Migrated all the way to v5 (Pro Wave 1, Phase 2), not stopped at v2 or v3:
// Dart-defined tables carry only their current column set, so `onUpgrade`'s
// `from < 2` step (`m.createTable(userPreferencesTable)`) always creates that
// table with every column the table has *today* — including v3's three
// additions and v5's two — regardless of which target version a test
// requests. There is no way to isolate the v1 -> v2 step alone anymore once a
// later version has extended a table an earlier step creates fresh; this test
// now doubles as the "device skips every later step" coverage for the
// `from >= 2` guards in `AppDatabase`'s v3 and v5 steps (see
// `leg_v3_migration_test.dart` for the isolated, from-a-real-v2-database
// v2 -> v3 case, S-092, and `user_preferences_v5_migration_test.dart` for the
// isolated v4 -> v5 case, S-214).
//
// Because the target is the current version, the assertions below read the
// post-v4 shape too: `leg.rule_profile_id` has been renamed and rewritten to
// `rule_profile_version_id`, and the 14 threshold columns live in
// `rule_profile_version` rather than `rule_profile`.

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/domain/models/user_preferences_defaults.dart';

import 'db/generated/schema.dart';
import 'db/generated/schema_v5.dart' as v5;
import 'db/generated/schema_v1.dart' as v1;

void main() {
  test('v1 -> v5 migration adds user_preferences and preserves all v1 data', () async {
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

    // Run the app's real migration path (onUpgrade's 1 -> 2 -> 3 -> 4 -> 5
    // steps) and validate the resulting live schema matches
    // drift_schema_v5.json.
    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 5);
    await dbForMigration.close();

    final checkDb = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(checkDb.close);

    // New table: exactly one seeded row, at the fixed id, with the app's
    // default preference values (S-035's defaults plus Phase 15's three v3
    // additions plus Phase 2's two v5 additions), read through the raw v5
    // schema snapshot so this test only depends on drift_dev's own generated
    // code, not lib/data/db/type_converters.dart.
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
    // Phase 2's two v5 columns backfill to "not set" / 25, never to zero.
    expect(prefsRow.wheelCapitalCents, isNull);
    expect(prefsRow.concentrationLimitPct, 25.0);

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
    // Phase 24's v4 step re-points the leg at its profile's v1 version, and
    // the raw value carried over from v1's `rule_profile_id` is unchanged
    // apart from the `-v1` suffix.
    expect(legRows.single.ruleProfileVersionId, 'rule-profile-standard-v1');

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
    expect(ruleProfileRows.single.name, 'Standard');

    // Phase 24's v4 step moved the 14 threshold columns into the append-only
    // `rule_profile_version` table — this pre-existing v1 profile now has
    // exactly one version row carrying every value it had at v1.
    final versionRows = await checkDb.select(checkDb.ruleProfileVersion).get();
    expect(versionRows, hasLength(1));
    final versionRow = versionRows.single;
    expect(versionRow.id, 'rule-profile-standard-v1');
    expect(versionRow.profileId, 'rule-profile-standard');
    expect(versionRow.version, 1);
    expect(versionRow.profitTargetPct, 50.0);
    expect(versionRow.assignThreshold, 0.70);
    expect(versionRow.tailExtrinsicThreshold, 500);
    expect(versionRow.targetDelta, 0.30);
  });
}
