// S-151 (restore is replace-all, confirmation names the destroyed count)
// and S-152 (malformed JSON import leaves the database untouched). Both
// new methods are exercised against BOTH DriftWheelRepository and
// InMemoryWheelRepository (docs/conventions.md §6 parity requirement).

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/data/db/drift_wheel_repository.dart';
import 'package:wheel_triage/data/export/ledger_export.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('DriftWheelRepository', () {
    _runTests(() => DriftWheelRepository(AppDatabase(NativeDatabase.memory())));
  });

  group('InMemoryWheelRepository', () {
    _runTests(InMemoryWheelRepository.new);
  });
}

Future<String> _closedPutCycle(
  WheelRepository repo, {
  required String ticker,
  required DateTime openedAt,
  required DateTime closedAt,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final created = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('50.00'),
      expiration: closedAt,
      contracts: 1,
      openedAt: openedAt,
      openCreditPerShare: Decimal.parse('0.50'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.closeLeg(
    legId: created.leg.id,
    reason: CloseReason.expiredWorthless,
    closeDebitPerShare: Decimal.zero,
    closedAt: closedAt,
  );
  return created.cycle.id;
}

void _runTests(WheelRepository Function() createRepository) {
  test('S-151: countCyclesForReplace names the existing count; restore replaces '
      'them entirely, none survive merged alongside the import', () async {
    final repo = createRepository();

    for (var i = 0; i < 5; i++) {
      await _closedPutCycle(
        repo,
        ticker: 'OLD$i',
        openedAt: DateTime.utc(2026, 1, 1),
        closedAt: DateTime.utc(2026, 1, 20 + i),
      );
    }
    final oldCycleIds = (await repo.getClosedCycles()).map((c) => c.id).toSet();
    expect(await repo.countCyclesForReplace(), 5);

    // An import file containing exactly 2 different cycles, built from a
    // second, independent repository instance.
    final importSource = createRepository();
    await _closedPutCycle(
      importSource,
      ticker: 'NEW0',
      openedAt: DateTime.utc(2026, 3, 1),
      closedAt: DateTime.utc(2026, 3, 10),
    );
    await _closedPutCycle(
      importSource,
      ticker: 'NEW1',
      openedAt: DateTime.utc(2026, 3, 5),
      closedAt: DateTime.utc(2026, 3, 15),
    );
    final importJson = await importSource.exportToJson();

    await repo.restoreFromJson(importJson);

    final afterCycles = await repo.getClosedCycles();
    expect(afterCycles, hasLength(2));
    expect(afterCycles.map((c) => c.id).toSet().intersection(oldCycleIds), isEmpty);
    for (final oldId in oldCycleIds) {
      expect(await repo.getCycle(oldId), isNull);
    }
    expect(await repo.countCyclesForReplace(), 2);
  });

  test('S-152: a malformed import (missing required field) is refused wholesale '
      'and leaves the database byte-for-byte unchanged', () async {
    final repo = createRepository();

    await _closedPutCycle(
      repo,
      ticker: 'AAA',
      openedAt: DateTime.utc(2026, 1, 1),
      closedAt: DateTime.utc(2026, 1, 20),
    );
    await repo.updatePreferences(
      (await repo.getPreferences()).copyWith(totalPerContractToggle: true),
    );

    final beforeJson = await repo.exportToJson();

    // Corrupt one leg's JSON by dropping a required field ('strike').
    final decoded = jsonDecode(beforeJson) as Map<String, dynamic>;
    final legs = (decoded['legs'] as List).cast<Map<String, dynamic>>();
    expect(legs, isNotEmpty);
    legs[0].remove('strike');
    final malformedJson = jsonEncode(decoded);

    await expectLater(
      () => repo.restoreFromJson(malformedJson),
      throwsA(isA<LedgerImportFormatException>()),
    );

    final afterJson = await repo.exportToJson();
    final before = LedgerExport.fromJsonString(beforeJson);
    final after = LedgerExport.fromJsonString(afterJson);

    expect(after.underlyings, unorderedEquals(before.underlyings));
    expect(after.cycles, unorderedEquals(before.cycles));
    expect(after.legs, unorderedEquals(before.legs));
    expect(after.snapshots, unorderedEquals(before.snapshots));
    expect(after.shareLots, unorderedEquals(before.shareLots));
    expect(after.ruleProfiles, unorderedEquals(before.ruleProfiles));
    expect(after.preferences, before.preferences);
  });

  test('S-152 (structural variant): top-level JSON that is not an object is refused, '
      'never partially applied', () async {
    final repo = createRepository();
    await _closedPutCycle(
      repo,
      ticker: 'AAA',
      openedAt: DateTime.utc(2026, 1, 1),
      closedAt: DateTime.utc(2026, 1, 20),
    );
    final beforeJson = await repo.exportToJson();

    await expectLater(
      () => repo.restoreFromJson('[1, 2, 3]'),
      throwsA(isA<LedgerImportFormatException>()),
    );
    await expectLater(
      () => repo.restoreFromJson('not even json'),
      throwsA(isA<LedgerImportFormatException>()),
    );

    expect(await repo.exportToJson(), beforeJson);
  });

  test('S-193: a format-1 file is converted on import, values preserved, converted file '
      're-imports idempotently', () async {
    final repo = createRepository();

    // Build the format-1 envelope by downgrading a real export: fold each
    // profile's v1 values back inline, drop the version list, and rename
    // the leg field back to `ruleProfileId`. This is exactly the shape the
    // app wrote before Iteration 5 — critically, the conservative v1 is
    // given a NON-default profit target so "the file's own values survive"
    // is falsifiable.
    final source = createRepository();
    final underlying = await source.getOrCreateUnderlying('S193');
    await source.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('45.00'),
        expiration: DateTime.utc(2026, 4, 15),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 1),
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: RuleProfileVersionIds.conservativeV1,
      ),
    );

    final decoded = jsonDecode(await source.exportToJson()) as Map<String, dynamic>;
    final versions = (decoded.remove('ruleProfileVersions') as List).cast<Map<String, dynamic>>();
    final profiles = (decoded['ruleProfiles'] as List).cast<Map<String, dynamic>>();
    for (final profile in profiles) {
      final v1 = versions.singleWhere((v) => v['profileId'] == profile['id']);
      for (final entry in v1.entries) {
        if (entry.key == 'id' || entry.key == 'profileId' || entry.key == 'version' ||
            entry.key == 'effectiveAt') {
          continue;
        }
        profile[entry.key] = entry.value;
      }
    }
    // Distinguishable, non-default value on the pinned profile.
    profiles.singleWhere((p) => p['id'] == RuleProfileIds.conservative)['profitTargetPct'] = 55.0;
    final legs = (decoded['legs'] as List).cast<Map<String, dynamic>>();
    for (final leg in legs) {
      leg['ruleProfileId'] = leg.remove('ruleProfileVersionId').toString().replaceAll('-v1', '');
    }
    decoded['formatVersion'] = 1;
    final v1Json = jsonEncode(decoded);

    final restoredAt = DateTime.utc(2026, 9, 19, 10);
    await repo.restoreFromJson(v1Json, now: restoredAt);

    // 3 synthesized v1 rows, ids derived, all at the pinned import instant...
    final converted = await repo.getRuleProfileVersions(RuleProfileIds.conservative);
    expect(converted, hasLength(1));
    expect(converted.single.id, RuleProfileVersionIds.conservativeV1);
    expect(converted.single.version, 1);
    expect(converted.single.effectiveAt, restoredAt);
    // ...carrying the FILE's own values, not this app's defaults.
    expect(converted.single.profitTargetPct, 55.0);

    // Every leg re-pins to the synthesized version id.
    final openLegs = await repo.getOpenLegs();
    expect(openLegs.single.ruleProfileVersionId, RuleProfileVersionIds.conservativeV1);

    // Re-export is already format 2, and importing THAT file again is an
    // exact round trip (conversion is idempotent).
    final reExported = await repo.exportToJson();
    expect(
      (jsonDecode(reExported) as Map<String, dynamic>)['formatVersion'],
      LedgerExport.currentFormatVersion,
    );
    await repo.restoreFromJson(reExported);
    expect(await repo.exportToJson(), reExported);
  });

  test('S-194: format-2 validation matrix — unknown pin, duplicate '
      '(profileId, version), profile with no versions, unsupported format, '
      'orphan version profileId, v1 leg naming an absent profile', () async {
    final repo = createRepository();
    await _closedPutCycle(
      repo,
      ticker: 'AAA',
      openedAt: DateTime.utc(2026, 1, 1),
      closedAt: DateTime.utc(2026, 1, 20),
    );
    final beforeJson = await repo.exportToJson();

    Map<String, dynamic> decoded() =>
        jsonDecode(beforeJson) as Map<String, dynamic>;

    Future<void> expectRefused(Map<String, dynamic> mutated) async {
      await expectLater(
        () => repo.restoreFromJson(jsonEncode(mutated)),
        throwsA(isA<LedgerImportFormatException>()),
      );
      expect(await repo.exportToJson(), beforeJson);
    }

    // (a) a leg pinning a version id that exists nowhere in the file.
    final unknownPin = decoded();
    ((unknownPin['legs'] as List).first as Map<String, dynamic>)['ruleProfileVersionId'] =
        'rule-profile-standard-v99';
    await expectRefused(unknownPin);

    // (b) two versions sharing (profileId, version).
    final duplicateVersion = decoded();
    final versionList = (duplicateVersion['ruleProfileVersions'] as List)
        .cast<Map<String, dynamic>>();
    versionList.add({...versionList.first, 'id': 'rule-profile-standard-v1-copy'});
    await expectRefused(duplicateVersion);

    // (c) a profile with zero versions.
    final bareProfile = decoded();
    (bareProfile['ruleProfileVersions'] as List).removeWhere(
      (v) => (v as Map<String, dynamic>)['profileId'] == RuleProfileIds.conservative,
    );
    await expectRefused(bareProfile);

    // (d) an unsupported format version.
    final futureFormat = decoded()..['formatVersion'] = 3;
    await expectRefused(futureFormat);

    // (e) a version whose profileId is listed nowhere as a profile.
    final orphanVersionProfile = decoded();
    ((orphanVersionProfile['ruleProfileVersions'] as List).cast<Map<String, dynamic>>()
            .first)['profileId'] =
        'no-such-profile';
    await expectRefused(orphanVersionProfile);

    // (f) the format-1 equivalent of (a): the file lists neither the profile
    // nor therefore any synthetic version for it. This is the check that
    // must survive the conversion -- a v1 file is downgraded from a real
    // export, exactly as S-193 builds it.
    final v1 = jsonDecode(beforeJson) as Map<String, dynamic>;
    final v1Versions =
        (v1.remove('ruleProfileVersions') as List).cast<Map<String, dynamic>>();
    for (final profile in (v1['ruleProfiles'] as List).cast<Map<String, dynamic>>()) {
      final seeded = v1Versions.singleWhere((v) => v['profileId'] == profile['id']);
      for (final entry in seeded.entries) {
        if (entry.key == 'id' ||
            entry.key == 'profileId' ||
            entry.key == 'version' ||
            entry.key == 'effectiveAt') {
          continue;
        }
        profile[entry.key] = entry.value;
      }
    }
    v1['formatVersion'] = 1;
    final v1Legs = (v1['legs'] as List).cast<Map<String, dynamic>>();
    for (final leg in v1Legs) {
      leg['ruleProfileId'] = _legacyProfileIdFor(leg);
    }
    v1Legs.first['ruleProfileId'] = 'rule-profile-nope';
    await expectLater(
      () => repo.restoreFromJson(jsonEncode(v1)),
      throwsA(isA<LedgerImportFormatException>()),
    );
    expect(await repo.exportToJson(), beforeJson);
  });

  test('S-215(b): a format-2 file written before schema v5 imports with both new '
      'preference fields at their defaults', () async {
    final repo = createRepository();
    await _closedPutCycle(
      repo,
      ticker: 'S215',
      openedAt: DateTime.utc(2026, 1, 1),
      closedAt: DateTime.utc(2026, 1, 20),
    );
    await repo.updatePreferences(
      (await repo.getPreferences()).copyWith(
        totalPerContractToggle: true,
        notificationMilestones: const [7, 0],
      ),
    );

    // Downgrade a real export to the pre-v5 shape: the format version is
    // still 2 (D-7), only the two new keys are absent.
    final decoded = jsonDecode(await repo.exportToJson()) as Map<String, dynamic>;
    final prefs = decoded['preferences'] as Map<String, dynamic>;
    prefs.remove('wheelCapital');
    prefs.remove('concentrationLimitPct');
    expect(decoded['formatVersion'], 2);

    await repo.restoreFromJson(jsonEncode(decoded));

    final restored = await repo.getPreferences();
    expect(restored.wheelCapital, isNull);
    expect(restored.concentrationLimitPct, 25.0);
    // The file's own values still win over this app's defaults.
    expect(restored.totalPerContractToggle, isTrue);
    expect(restored.notificationMilestones, [7, 0]);
  });
}

/// The legacy field name for a leg's pinned profile, derived from the v2
/// field so the downgrade can never drift from the real export shape.
String _legacyProfileIdFor(Map<String, dynamic> leg) =>
    leg['ruleProfileVersionId'].toString().replaceAll('-v1', '');

