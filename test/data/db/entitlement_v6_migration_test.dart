// S-255: schema v6 adds exactly one table, `entitlement_cache` — the
// store-derived entitlement cache (Pro Wave 2, D-25). A fresh install and a
// v5 -> v6 migration must agree: both report the free tier's "never checked"
// state (`isActive == false`, `planKind == ProPlanKind.none`,
// `expiresAt == null`, `willRenew == false`, `billingIssue == false`,
// `purchasedAt == null`, `checkedAt == null`) while every pre-existing row
// survives byte-identical.
//
// Follows the same `SchemaVerifier.schemaAt` pattern as the other migration
// tests: build a real versioned database through the schema-specific
// generated helpers, run the real `AppDatabase` migration path, then
// re-read through the target version's helpers. Values inserted through the
// generated helpers are RAW SQL values (the helpers do not apply the app's
// type converters — see `leg_v3_migration_test.dart`), so
// `wheel_capital_cents` is compared as an integer and `plan_kind` as its
// stored text.
//
// The migration half additionally reads through the real repository, because
// the row's *shape* is not the whole contract: `getEntitlementCache()` must
// resolve the seeded row rather than fall back to its defensive insert, and
// `EntitlementCacheData`'s defaults must agree with the raw column values.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/data/db/drift_wheel_repository.dart';
import 'package:wheel_triage/domain/models/entitlement_cache.dart';
import 'package:wheel_triage/domain/models/entitlement_cache_defaults.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/user_preferences_defaults.dart';

import 'generated/schema.dart';
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;

/// `StandardProfileDefaults.tailExtrinsicThreshold` ($0.05) as the raw
/// integer ten-thousandths the schema helpers see.
const _defaultTailExtrinsicRaw = 500;

/// S-255's fixture: one `user_preferences` row with every v5 field set to a
/// non-default value, plus one of every other pre-v6 table so "nothing else
/// moved" is falsifiable. Built through the generated v5 helpers, so every
/// value below is a RAW SQL value.
Future<void> _insertV5Fixture(v5.DatabaseAtV5 db) async {
  await db.into(db.userPreferences).insert(
        v5.UserPreferencesCompanion.insert(
          id: UserPreferencesDefaults.rowId,
          totalPerContractToggle: true,
          deltaConventionDefault: 'option',
          firstRunExplainerShown: true,
          ivResolutionNoticeDismissed: true,
          exportReminderDismissed: const Value(true),
          lastExportAtMs: const Value(1680000000000),
          notificationMilestones: const Value('7,0'),
          // $30,000.00 in the storage unit for equity prices: cents.
          wheelCapitalCents: const Value(3000000),
          concentrationLimitPct: const Value(20.0),
        ),
      );

  // The three seeded profiles with their v1 versions, at the post-v4 shape.
  for (final id in [
    RuleProfileIds.conservative,
    RuleProfileIds.standard,
    RuleProfileIds.aggressive,
  ]) {
    await db.into(db.ruleProfile).insert(
          v5.RuleProfileCompanion.insert(
            id: id,
            name: id.replaceAll('rule-profile-', ''),
          ),
        );
    await db.into(db.ruleProfileVersion).insert(
          v5.RuleProfileVersionCompanion.insert(
            id: RuleProfileVersionIds.forVersion(id, 1),
            profileId: id,
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
  }

  await db.into(db.underlying).insert(
        v5.UnderlyingCompanion.insert(id: 'u1', ticker: 'AAPL'),
      );

  // One OPEN cycle carrying two legs: `l1` backdated (closed), `l2` still
  // open and carrying both fees plus `acceptsAssignment = false` — the two
  // v3/v4 column families a v6 migration must not disturb.
  await db.into(db.wheelCycle).insert(
        v5.WheelCycleCompanion.insert(
          id: 'c1',
          underlyingId: 'u1',
          startedAtMs: 1700000000000,
          status: 'sellingPuts',
        ),
      );
  await db.into(db.leg).insert(
        v5.LegCompanion.insert(
          id: 'l1',
          cycleId: 'c1',
          sequence: 0,
          optionType: 'put',
          strike: 4500,
          expirationMs: 1710000000000,
          contracts: 1,
          openedAtMs: 1699000000000,
          openCreditPerShare: 6000,
          closedAtMs: const Value(1705000000000),
          closeDebitPerShare: const Value(2000),
          closeReason: const Value('expiredWorthless'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          openFee: const Value(65),
          closeFee: const Value(65),
        ),
      );
  await db.into(db.leg).insert(
        v5.LegCompanion.insert(
          id: 'l2',
          cycleId: 'c1',
          sequence: 1,
          optionType: 'call',
          strike: 5500,
          expirationMs: 1720000000000,
          contracts: 1,
          openedAtMs: 1706000000000,
          openCreditPerShare: 8000,
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          openFee: const Value(65),
          closeFee: const Value(70),
          acceptsAssignment: const Value(false),
        ),
      );

  // One CLOSED cycle, so both cycle statuses are represented.
  await db.into(db.wheelCycle).insert(
        v5.WheelCycleCompanion.insert(
          id: 'c2',
          underlyingId: 'u1',
          startedAtMs: 1680000000000,
          status: 'closed',
          endedAtMs: const Value(1690000000000),
          outcome: const Value('expiredWorthless'),
        ),
      );

  await db.into(db.snapshot).insert(
        v5.SnapshotCompanion.insert(
          id: 's1',
          legId: 'l1',
          takenAtMs: 1701000000000,
          optionMark: 3000,
          underlyingPrice: 460000,
          deltaAsEntered: -0.25,
          deltaConvention: 'position',
          iv: const Value(42.5),
        ),
      );
  await db.into(db.shareLot).insert(
        v5.ShareLotCompanion.insert(
          id: 'sl1',
          cycleId: 'c1',
          assignedAtMs: 1700150000000,
          assignmentStrike: 5000,
          contracts: 1,
        ),
      );
}

/// Every assertion both halves of S-255 share: the cache row's raw shape,
/// exactly-one-row, and the repository's resolved value.
Future<void> _expectDefaultCacheRow(v6.DatabaseAtV6 checkDb) async {
  final rows = await checkDb.select(checkDb.entitlementCache).get();
  expect(rows, hasLength(1));
  final row = rows.single;
  expect(row.id, EntitlementCacheDefaults.rowId);
  expect(row.isActive, EntitlementCacheDefaults.isActive);
  expect(row.planKind, EntitlementCacheDefaults.planKindName);
  expect(row.expiresAtMs, isNull);
  expect(row.willRenew, EntitlementCacheDefaults.willRenew);
  expect(row.billingIssue, EntitlementCacheDefaults.billingIssue);
  expect(row.purchasedAtMs, isNull);
  expect(row.checkedAtMs, isNull);
}

void main() {
  test('S-255: v5 -> v6 creates entitlement_cache, seeds the free tier, and leaves '
      'every other row byte-identical', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);

    final oldDb = v5.DatabaseAtV5(schema.newConnection());
    await _insertV5Fixture(oldDb);
    await oldDb.close();

    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 6);
    await dbForMigration.close();

    final checkDb = v6.DatabaseAtV6(schema.newConnection());
    addTearDown(checkDb.close);

    // Read the RAW row *before* touching the repository: the repository's
    // defensive fallback seeds this row when it is missing, so a repository
    // read first would mask a migration step that failed to seed.
    await _expectDefaultCacheRow(checkDb);

    // The repository then resolves that same seeded row rather than falling
    // back — and resolves it to the Dart-side default value, so the raw
    // column shape and `EntitlementCacheData`'s defaults agree.
    final repoDb = AppDatabase(schema.newConnection());
    addTearDown(repoDb.close);
    final resolved = await DriftWheelRepository(repoDb).getEntitlementCache();
    expect(resolved, const EntitlementCacheData());
    expect(resolved.planKind, ProPlanKind.none);
    expect((await repoDb.select(repoDb.entitlementCacheTable).get()), hasLength(1));

    // Every pre-existing preference field survived exactly.
    final prefs = (await checkDb.select(checkDb.userPreferences).get()).single;
    expect(prefs.totalPerContractToggle, isTrue);
    expect(prefs.deltaConventionDefault, 'option');
    expect(prefs.firstRunExplainerShown, isTrue);
    expect(prefs.ivResolutionNoticeDismissed, isTrue);
    expect(prefs.exportReminderDismissed, isTrue);
    expect(prefs.lastExportAtMs, 1680000000000);
    expect(prefs.notificationMilestones, '7,0');
    expect(prefs.wheelCapitalCents, 3000000);
    expect(prefs.concentrationLimitPct, 20.0);

    // Every other table's rows are untouched, including the two leg column
    // families added after v1.
    expect((await checkDb.select(checkDb.underlying).get()), hasLength(1));
    expect((await checkDb.select(checkDb.ruleProfile).get()), hasLength(3));
    expect((await checkDb.select(checkDb.ruleProfileVersion).get()), hasLength(3));

    final cycles = await checkDb.select(checkDb.wheelCycle).get();
    expect(cycles, hasLength(2));
    expect(cycles.map((c) => c.status).toSet(), {'sellingPuts', 'closed'});

    final legs = await checkDb.select(checkDb.leg).get();
    expect(legs, hasLength(2));
    final closedLeg = legs.singleWhere((l) => l.id == 'l1');
    expect(closedLeg.openCreditPerShare, 6000);
    expect(closedLeg.closeDebitPerShare, 2000);
    expect(closedLeg.closeReason, 'expiredWorthless');
    expect(closedLeg.openFee, 65);
    expect(closedLeg.closeFee, 65);
    expect(closedLeg.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
    final openLeg = legs.singleWhere((l) => l.id == 'l2');
    expect(openLeg.openFee, 65);
    expect(openLeg.closeFee, 70);
    expect(openLeg.acceptsAssignment, isFalse);
    expect(openLeg.ivAtOpen, isNull);

    final snapshot = (await checkDb.select(checkDb.snapshot).get()).single;
    expect(snapshot.iv, 42.5);
    expect(snapshot.underlyingPrice, 460000);
    expect((await checkDb.select(checkDb.shareLot).get()), hasLength(1));
  });

  test('S-255: a fresh v6 install reports the same cache row as the migration', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Runs the real migration path (onCreate: createAll + seedRuleProfiles +
    // seedDefaultPreferences + seedEntitlementCache) against a brand-new
    // database, then validates the result against drift_schema_v6.json.
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final resolved = await DriftWheelRepository(db).getEntitlementCache();
    expect(resolved, const EntitlementCacheData());
    expect(resolved.checkedAt, isNull);
    expect(resolved.planKind, ProPlanKind.none);

    // Exactly one row, and it is the one `onCreate` seeded — not a second
    // row appended by the repository's defensive fallback.
    final rows = await db.select(db.entitlementCacheTable).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, EntitlementCacheDefaults.rowId);
    expect(rows.single.planKind, ProPlanKind.none);
    expect(rows.single.checkedAtMs, isNull);
  });

  test('S-255 (gate): targeting v5 never runs the v6 step', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    // Start at v4, not v5: `migrateAndValidate(db, N)` only runs `onUpgrade`
    // when the database's actual version differs from N, so a v5 database
    // "migrated" to v5 is a no-op that would prove nothing about the gate.
    // Starting at v4 makes the v5 step genuinely run while the v6 step must
    // stay gated out.
    final schema = await verifier.schemaAt(4);

    final oldDb = v4.DatabaseAtV4(schema.newConnection());
    await oldDb.into(oldDb.userPreferences).insert(
          v4.UserPreferencesCompanion.insert(
            id: UserPreferencesDefaults.rowId,
            totalPerContractToggle: false,
            deltaConventionDefault: 'position',
            firstRunExplainerShown: false,
            ivResolutionNoticeDismissed: false,
          ),
        );
    await oldDb.close();

    final dbForMigration = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 5);
    await dbForMigration.close();

    final checkDb = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(checkDb.close);

    // The v5 step really ran (so this test cannot pass by doing nothing)...
    final columns = await checkDb
        .customSelect("SELECT name FROM pragma_table_info('user_preferences')")
        .get();
    final columnNames = columns.map((row) => row.read<String>('name')).toSet();
    expect(columnNames, contains('wheel_capital_cents'));
    expect(columnNames, contains('concentration_limit_pct'));

    // ...and the v6 step did not.
    final tables = await checkDb
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = tables.map((row) => row.read<String>('name')).toSet();
    expect(tableNames, isNot(contains('entitlement_cache')));
  });
}
