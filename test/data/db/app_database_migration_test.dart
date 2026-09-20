// S-031: migration / schema v1, seeded profiles.
//
// Uses drift_dev's generated schema-verification helpers
// (test/data/db/generated/, produced by `dart run drift_dev schema dump`
// + `dart run drift_dev schema generate` against
// lib/data/db/schema/drift_schema_v1.json) so schema drift between the
// live table definitions and the exported schema contract fails this test
// instead of surfacing in production.
//
// `migrateAndValidate` is called against `AppDatabase.schemaVersion` itself
// (not a hardcoded literal) because a fresh install always runs `onCreate`
// -> `createAll()`, which builds every table from its current, single Dart
// definition regardless of which version is requested — Dart-defined
// tables carry only their latest column set, not one per historical
// schema version. So this check can only ever validate "fresh install
// matches the *current* exported schema," and must track schemaVersion as
// it rises across iterations (v1 at Phase 2, v4 as of Iteration 5) rather
// than staying pinned to the version this test was first written against.

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'generated/schema.dart';

void main() {
  test('fresh migration creates all tables and seeds exactly 3 rule profiles', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Runs the real migration path (onCreate: createAll + seedRuleProfiles)
    // against a brand-new database, then verifies the resulting sqlite
    // schema matches lib/data/db/schema/drift_schema_v4.json exactly.
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final tableNames = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final names = tableNames.map((row) => row.data['name'] as String).toSet();
    expect(
      names,
      containsAll({
        'underlying',
        'wheel_cycle',
        'leg',
        'snapshot',
        'share_lot',
        'rule_profile',
        'rule_profile_version',
      }),
    );

    // Identity rows (Iteration 5, D-3): id + name only.
    final profiles = await db.select(db.ruleProfileTable).get();
    expect(profiles, hasLength(3));
    expect(
      profiles.map((p) => p.id).toSet(),
      {RuleProfileIds.conservative, RuleProfileIds.standard, RuleProfileIds.aggressive},
    );
    expect(profiles.map((p) => p.name).toSet(), {'Conservative', 'Standard', 'Aggressive'});

    // Each profile's seeded v1 version row carries the §4.4 defaults
    // (Feature Invariant 8: Conservative and Aggressive are exact
    // placeholder copies of Standard's numbers this run), all sharing one
    // install-time timestamp.
    final versions = await db.select(db.ruleProfileVersionTable).get();
    expect(versions, hasLength(3));
    expect(versions.map((v) => v.effectiveAtMs).toSet(), hasLength(1));
    for (final v in versions) {
      expect(v.version, 1);
      expect(v.id, RuleProfileVersionIds.forVersion(v.profileId, 1));
      expect(v.profitTargetPct, StandardProfileDefaults.profitTargetPct);
      expect(v.assignThreshold, StandardProfileDefaults.assignThreshold);
      expect(v.baseRollBand, StandardProfileDefaults.baseRollBand);
      expect(v.midIvRollBand, StandardProfileDefaults.midIvRollBand);
      expect(v.highIvRollBand, StandardProfileDefaults.highIvRollBand);
      expect(v.midIvCutoff, StandardProfileDefaults.midIvCutoff);
      expect(v.highIvCutoff, StandardProfileDefaults.highIvCutoff);
      expect(v.tailDteDays, StandardProfileDefaults.tailDteDays);
      expect(v.tailExtrinsicThreshold, StandardProfileDefaults.tailExtrinsicThreshold);
      expect(v.minIvRank, StandardProfileDefaults.minIvRank);
      expect(v.minAnnualisedYield, StandardProfileDefaults.minAnnualisedYield);
      expect(v.targetDteMin, StandardProfileDefaults.targetDteMin);
      expect(v.targetDteMax, StandardProfileDefaults.targetDteMax);
      expect(v.targetDelta, StandardProfileDefaults.targetDelta);
    }
  });
}
