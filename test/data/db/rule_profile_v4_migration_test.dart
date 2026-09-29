// S-190: migration v3 -> v4 (and the v1 -> v4 jump) moves every profile's
// 14 threshold values into an immutable v1 version row, re-points every
// leg's pin to `<profileId>-v1`, and removes the moved columns from
// `rule_profile` — preserving every prior value exactly (Iteration 5,
// D-3/D-6, phase 24).
//
// Follows the same `SchemaVerifier.schemaAt` pattern as the other migration
// tests: build a real versioned database through the schema-specific
// generated helpers, run the real `AppDatabase` migration path, then
// re-read through the target version's helpers. The third test pins the
// `to >= 4` half of the v4 step's gate: targeting v3 must never run it.
//
// `migrateAndValidate(db, N)` migrates the database *to* N — drift is told
// the database's version is N, so `onUpgrade` receives `to == N` — and then
// validates the result against the schema snapshot for N. N therefore has to
// be the version the `DatabaseAtV*` helper below reads through, not the
// app's current `schemaVersion` (6 since Pro Wave 2's Phase 1). That is
// exactly what lets the third test target v3 and prove the v4 step never ran.
//
// The one exception is the v1-start case below: the v2 step creates
// `user_preferences` from the *live* table definition, so a database that
// starts at v1 ends up with the current column set whatever N is. That test
// therefore targets the current version and reads through `DatabaseAtV6`.
//
// Values inserted through the generated helpers are RAW SQL values (the
// helpers do not apply the app's type converters — see
// `leg_v3_migration_test.dart`'s `tailExtrinsicThreshold: 500`), so
// ten-thousandths integers are compared directly, which is also what makes
// "integer-exact" preservation provable here.

import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/user_preferences_defaults.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v6.dart' as v6;

/// `StandardProfileDefaults.tailExtrinsicThreshold` ($0.05) as the raw
/// integer ten-thousandths the schema helpers see.
const _defaultTailExtrinsicRaw = 500;

void main() {
  test('S-190: v3 -> v4 copies every profile value into a shared-timestamp v1 row, '
      're-points every leg, and leaves every other table intact', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);

    final oldDb = v3.DatabaseAtV3(schema.newConnection());

    // Three profile rows at the v3 shape. Standard and Aggressive at the
    // §4.4 defaults; Conservative deliberately non-default on two fields —
    // one double and the one money-denominated (ten-thousandths) column —
    // so "preserved exactly" is falsifiable for both encodings.
    Future<void> insertProfile(
      String id,
      String name, {
      double profitTargetPct = StandardProfileDefaults.profitTargetPct,
      int tailExtrinsicThreshold = _defaultTailExtrinsicRaw,
    }) =>
        oldDb.into(oldDb.ruleProfile).insert(
              v3.RuleProfileCompanion.insert(
                id: id,
                name: name,
                profitTargetPct: profitTargetPct,
                assignThreshold: StandardProfileDefaults.assignThreshold,
                baseRollBand: StandardProfileDefaults.baseRollBand,
                midIvRollBand: StandardProfileDefaults.midIvRollBand,
                highIvRollBand: StandardProfileDefaults.highIvRollBand,
                midIvCutoff: StandardProfileDefaults.midIvCutoff,
                highIvCutoff: StandardProfileDefaults.highIvCutoff,
                tailDteDays: StandardProfileDefaults.tailDteDays,
                tailExtrinsicThreshold: tailExtrinsicThreshold,
                minIvRank: StandardProfileDefaults.minIvRank,
                minAnnualisedYield: StandardProfileDefaults.minAnnualisedYield,
                targetDteMin: StandardProfileDefaults.targetDteMin,
                targetDteMax: StandardProfileDefaults.targetDteMax,
                targetDelta: StandardProfileDefaults.targetDelta,
              ),
            );

    await insertProfile(RuleProfileIds.standard, 'Standard');
    await insertProfile(
      RuleProfileIds.conservative,
      'Conservative',
      profitTargetPct: 55.0,
      tailExtrinsicThreshold: 1234,
    );
    await insertProfile(RuleProfileIds.aggressive, 'Aggressive');

    await oldDb.into(oldDb.underlying).insert(
          v3.UnderlyingCompanion.insert(id: 'u1', ticker: 'AAPL'),
        );
    await oldDb.into(oldDb.underlying).insert(
          v3.UnderlyingCompanion.insert(id: 'u2', ticker: 'MSFT'),
        );
    await oldDb.into(oldDb.wheelCycle).insert(
          v3.WheelCycleCompanion.insert(
            id: 'c1',
            underlyingId: 'u1',
            startedAtMs: 1700000000000,
            status: 'sellingPuts',
          ),
        );
    await oldDb.into(oldDb.wheelCycle).insert(
          v3.WheelCycleCompanion.insert(
            id: 'c2',
            underlyingId: 'u2',
            startedAtMs: 1700100000000,
            status: 'holdingShares',
          ),
        );
    await oldDb.into(oldDb.leg).insert(
          v3.LegCompanion.insert(
            id: 'l1',
            cycleId: 'c1',
            sequence: 0,
            optionType: 'put',
            strike: 4500,
            expirationMs: 1710000000000,
            contracts: 1,
            openedAtMs: 1700000000000,
            openCreditPerShare: 6000,
            ruleProfileId: RuleProfileIds.standard,
          ),
        );
    await oldDb.into(oldDb.leg).insert(
          v3.LegCompanion.insert(
            id: 'l2',
            cycleId: 'c1',
            sequence: 1,
            optionType: 'put',
            strike: 4400,
            expirationMs: 1715000000000,
            contracts: 1,
            openedAtMs: 1710000000000,
            openCreditPerShare: 6500,
            closedAtMs: const Value(1712000000000),
            closeDebitPerShare: const Value(2000),
            closeReason: const Value('rolled'),
            rolledFromLegId: const Value('l1'),
            ruleProfileId: RuleProfileIds.conservative,
          ),
        );
    await oldDb.into(oldDb.leg).insert(
          v3.LegCompanion.insert(
            id: 'l3',
            cycleId: 'c2',
            sequence: 0,
            optionType: 'call',
            strike: 5200,
            expirationMs: 1717000000000,
            contracts: 2,
            openedAtMs: 1700200000000,
            openCreditPerShare: 5500,
            ruleProfileId: RuleProfileIds.standard,
          ),
        );
    await oldDb.into(oldDb.snapshot).insert(
          v3.SnapshotCompanion.insert(
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
          v3.ShareLotCompanion.insert(
            id: 'sl1',
            cycleId: 'c2',
            assignedAtMs: 1700150000000,
            assignmentStrike: 5000,
            contracts: 2,
          ),
        );
    await oldDb.into(oldDb.userPreferences).insert(
          v3.UserPreferencesCompanion.insert(
            id: UserPreferencesDefaults.rowId,
            totalPerContractToggle: true,
            deltaConventionDefault: 'option',
            firstRunExplainerShown: true,
            ivResolutionNoticeDismissed: true,
            exportReminderDismissed: const Value(true),
            lastExportAtMs: const Value(1680000000000),
            notificationMilestones: const Value('14,3'),
          ),
        );
    await oldDb.close();

    final migrationStartedAt = DateTime.now();
    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 4);
    await dbForMigration.close();
    final migrationEndedAt = DateTime.now();

    final checkDb = v4.DatabaseAtV4(schema.newConnection());
    addTearDown(checkDb.close);

    // `rule_profile` is identity-only now.
    final profiles = await checkDb.select(checkDb.ruleProfile).get();
    expect(profiles, hasLength(3));
    expect(
      profiles.map((p) => p.id).toSet(),
      {RuleProfileIds.standard, RuleProfileIds.conservative, RuleProfileIds.aggressive},
    );
    expect(
      profiles.singleWhere((p) => p.id == RuleProfileIds.standard).name,
      'Standard',
    );

    // Exactly one v1 version per profile, id derived from the profile id,
    // all sharing one migration timestamp inside the migrate() window.
    final versions = await checkDb.select(checkDb.ruleProfileVersion).get();
    expect(versions, hasLength(3));
    for (final version in versions) {
      expect(version.version, 1);
      expect(version.id, RuleProfileVersionIds.forVersion(version.profileId, 1));
    }
    final timestamp =
        versions.map((v) => v.effectiveAtMs).toSet().single;
    expect(
      timestamp,
      inInclusiveRange(
        migrationStartedAt.millisecondsSinceEpoch,
        migrationEndedAt.millisecondsSinceEpoch,
      ),
      reason: 'one shared timestamp for every v1 row this migration run created',
    );

    // Values preserved integer-exact, including the money column.
    final standard =
        versions.singleWhere((v) => v.profileId == RuleProfileIds.standard);
    expect(standard.profitTargetPct, StandardProfileDefaults.profitTargetPct);
    expect(standard.assignThreshold, StandardProfileDefaults.assignThreshold);
    expect(standard.baseRollBand, StandardProfileDefaults.baseRollBand);
    expect(standard.midIvRollBand, StandardProfileDefaults.midIvRollBand);
    expect(standard.highIvRollBand, StandardProfileDefaults.highIvRollBand);
    expect(standard.midIvCutoff, StandardProfileDefaults.midIvCutoff);
    expect(standard.highIvCutoff, StandardProfileDefaults.highIvCutoff);
    expect(standard.tailDteDays, StandardProfileDefaults.tailDteDays);
    expect(standard.tailExtrinsicThreshold, _defaultTailExtrinsicRaw);
    expect(standard.minIvRank, StandardProfileDefaults.minIvRank);
    expect(standard.minAnnualisedYield, StandardProfileDefaults.minAnnualisedYield);
    expect(standard.targetDteMin, StandardProfileDefaults.targetDteMin);
    expect(standard.targetDteMax, StandardProfileDefaults.targetDteMax);
    expect(standard.targetDelta, StandardProfileDefaults.targetDelta);

    final conservative =
        versions.singleWhere((v) => v.profileId == RuleProfileIds.conservative);
    expect(conservative.profitTargetPct, 55.0);
    expect(conservative.tailExtrinsicThreshold, 1234);

    // Every leg re-pointed to its profile's v1 — a pure string append.
    final legs = await checkDb.select(checkDb.leg).get();
    expect(legs, hasLength(3));
    expect(
      legs.singleWhere((l) => l.id == 'l1').ruleProfileVersionId,
      RuleProfileVersionIds.standardV1,
    );
    expect(
      legs.singleWhere((l) => l.id == 'l2').ruleProfileVersionId,
      RuleProfileVersionIds.conservativeV1,
    );
    expect(
      legs.singleWhere((l) => l.id == 'l3').ruleProfileVersionId,
      RuleProfileVersionIds.standardV1,
    );

    // Every other table's rows survived untouched.
    expect((await checkDb.select(checkDb.underlying).get()), hasLength(2));
    expect((await checkDb.select(checkDb.wheelCycle).get()), hasLength(2));
    final snapshot = (await checkDb.select(checkDb.snapshot).get()).single;
    expect(snapshot.optionMark, 3000);
    expect(snapshot.legId, 'l1');
    final lot = (await checkDb.select(checkDb.shareLot).get()).single;
    expect(lot.assignmentStrike, 5000);
    expect(lot.contracts, 2);
    final prefs = (await checkDb.select(checkDb.userPreferences).get()).single;
    expect(prefs.totalPerContractToggle, isTrue);
    expect(prefs.notificationMilestones, '14,3');
    expect(prefs.lastExportAtMs, 1680000000000);
    // The leg's other columns are untouched by the rename.
    final l2 = legs.singleWhere((l) => l.id == 'l2');
    expect(l2.closeDebitPerShare, 2000);
    expect(l2.closeReason, 'rolled');
    expect(l2.rolledFromLegId, 'l1');
  });

  test('S-190 (v1 -> v6 jump): the v4 step runs after the earlier steps and still '
      're-points the leg', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);

    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.into(oldDb.ruleProfile).insert(
          v1.RuleProfileCompanion.insert(
            id: RuleProfileIds.standard,
            name: 'Standard',
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
            ruleProfileId: RuleProfileIds.standard,
          ),
        );
    await oldDb.close();

    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 6);
    await dbForMigration.close();

    final checkDb = v6.DatabaseAtV6(schema.newConnection());
    addTearDown(checkDb.close);

    final version = (await checkDb.select(checkDb.ruleProfileVersion).get()).single;
    expect(version.id, RuleProfileVersionIds.standardV1);
    expect(version.profileId, RuleProfileIds.standard);
    expect(
      (await checkDb.select(checkDb.leg).get()).single.ruleProfileVersionId,
      RuleProfileVersionIds.standardV1,
    );
    // The v2 step also ran on this jump — proves step sequencing, not just
    // the v4 step in isolation.
    expect(await checkDb.select(checkDb.userPreferences).get(), hasLength(1));
  });

  test('S-190 (gate): targeting v3 never runs the v4 step', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    // v2, not v1: a v1 start would create `user_preferences` from the live
    // (v5) definition inside the v2 step and could not validate against the
    // v3 snapshot. Starting at v2 still exercises the v3 step on the way.
    final schema = await verifier.schemaAt(2);

    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    await oldDb.into(oldDb.ruleProfile).insert(
          v2.RuleProfileCompanion.insert(
            id: RuleProfileIds.standard,
            name: 'Standard',
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
    await oldDb.close();

    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 3);
    await dbForMigration.close();

    final checkDb = v3.DatabaseAtV3(schema.newConnection());
    addTearDown(checkDb.close);

    // The v3 shape is intact: the threshold column is still there...
    final profile = (await checkDb.select(checkDb.ruleProfile).get()).single;
    expect(profile.profitTargetPct, StandardProfileDefaults.profitTargetPct);

    // ...and the v4 table was never created.
    final v4Table = await checkDb
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rule_profile_version'",
        )
        .get();
    expect(v4Table, isEmpty);
  });
}
