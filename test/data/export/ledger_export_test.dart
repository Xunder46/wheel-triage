// S-150 (export -> wipe -> restore round-trips exactly) and S-153
// (restore-from-JSON with varying per-leg contract counts computes
// correctly). Both new methods are exercised against BOTH
// DriftWheelRepository and InMemoryWheelRepository (docs/conventions.md §6
// parity requirement).

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/data/db/drift_wheel_repository.dart';
import 'package:wheel_triage/data/export/ledger_csv.dart';
import 'package:wheel_triage/data/export/ledger_export.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_data.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/rule_profile_version_data.dart';
import 'package:wheel_triage/domain/models/share_lot.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/models/underlying.dart';
import 'package:wheel_triage/domain/models/user_preferences.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/domain/rules/basis.dart';
import 'package:wheel_triage/domain/rules/roll_chain.dart' show cycleTotalPremium;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('DriftWheelRepository', () {
    _runTests(() => DriftWheelRepository(AppDatabase(NativeDatabase.memory())));
  });

  group('InMemoryWheelRepository', () {
    _runTests(InMemoryWheelRepository.new);
  });
}

void _runTests(WheelRepository Function() createRepository) {
  test('S-150: export -> wipe -> restore round-trips every table exactly, '
      'including a null-fee leg and a rolled-out leg chain', () async {
    final repo = createRepository();

    final aaa = await repo.getOrCreateUnderlying('AAA');
    final bbb = await repo.getOrCreateUnderlying('BBB');

    // --- Cycle 1 (AAA): a 3-leg roll chain with fees both null and
    // populated, closed on the put side. ---------------------------------
    final cycle1 = await repo.createCycle(
      underlyingId: aaa.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('45.00'),
        expiration: DateTime.utc(2026, 4, 15),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 1),
        openCreditPerShare: Decimal.parse('0.50'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        // openFee deliberately omitted -- must round-trip as null, not 0.
      ),
    );
    final leg0 = cycle1.leg;
    expect(leg0.openFee, isNull);

    final roll1 = await repo.recordRoll(
      closingLegId: leg0.id,
      closeDebitPerShare: Decimal.parse('0.20'),
      // closeFee deliberately omitted on this roll -- stays null.
      closedAt: DateTime.utc(2026, 3, 20),
      newLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('44.00'),
        expiration: DateTime.utc(2026, 5, 15),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 20),
        openCreditPerShare: Decimal.parse('0.65'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        openFee: Decimal.parse('1.00'),
      ),
    );
    final leg1 = roll1.newLeg;
    expect(leg1.rolledFromLegId, leg0.id);

    final roll2 = await repo.recordRoll(
      closingLegId: leg1.id,
      closeDebitPerShare: Decimal.parse('0.10'),
      closeFee: Decimal.parse('0.50'),
      closedAt: DateTime.utc(2026, 5, 5),
      newLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('43.00'),
        expiration: DateTime.utc(2026, 6, 12),
        contracts: 2, // contract-count change across a roll (Feature Invariant 26)
        openedAt: DateTime.utc(2026, 5, 5),
        openCreditPerShare: Decimal.parse('0.80'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    final leg2 = roll2.newLeg;
    expect(leg2.rolledFromLegId, leg1.id);

    await repo.closeLeg(
      legId: leg2.id,
      reason: CloseReason.expiredWorthless,
      closeDebitPerShare: Decimal.zero,
      closedAt: DateTime.utc(2026, 6, 12),
    );

    // --- Cycle 2 (BBB): full assignment + an open covered call with two
    // snapshots (one fully populated, one with every optional field null)
    // -- still open, so its ShareLot is live. -----------------------------
    final cycle2Created = await repo.createCycle(
      underlyingId: bbb.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('100.00'),
        expiration: DateTime.utc(2026, 4, 17),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 1),
        openCreditPerShare: Decimal.parse('1.20'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        openFee: Decimal.parse('0.65'),
      ),
    );
    final assignment = await repo.recordAssignment(
      legId: cycle2Created.leg.id,
      closeFee: Decimal.parse('0.65'),
      shareLot: NewShareLotInput(
        assignedAt: DateTime.utc(2026, 4, 17),
        assignmentStrike: Decimal.parse('100.00'),
        contracts: 1,
      ),
    );
    final callLeg = await repo.openNextLeg(
      cycleId: assignment.cycle.id,
      leg: NewLegInput(
        optionType: OptionType.call,
        strike: Decimal.parse('105.00'),
        expiration: DateTime.utc(2026, 5, 15),
        contracts: 1,
        openedAt: DateTime.utc(2026, 4, 18),
        openCreditPerShare: Decimal.parse('0.55'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        acceptsAssignment: false,
      ),
    );
    await repo.appendSnapshot(NewSnapshotInput(
      legId: callLeg.id,
      takenAt: DateTime.utc(2026, 4, 25),
      optionMark: Decimal.parse('0.30'),
      underlyingPrice: Decimal.parse('102.00'),
      deltaAsEntered: -0.25,
      deltaConvention: DeltaConvention.position,
      gamma: 0.02,
      theta: -0.01,
      vega: 0.03,
      iv: 35.0,
      openInterest: 500,
      volume: 120,
    ));
    await repo.appendSnapshot(NewSnapshotInput(
      legId: callLeg.id,
      takenAt: DateTime.utc(2026, 5, 1),
      optionMark: Decimal.parse('0.20'),
      underlyingPrice: Decimal.parse('103.00'),
      deltaAsEntered: -0.15,
      deltaConvention: DeltaConvention.position,
      // Every optional Greek/IV/OI/volume field left null on this reading.
    ));

    await repo.updatePreferences(
      (await repo.getPreferences()).copyWith(
        totalPerContractToggle: true,
        deltaConventionDefault: DeltaConvention.option,
        firstRunExplainerShown: true,
        ivResolutionNoticeDismissed: true,
        exportReminderDismissed: true,
        lastExportAt: DateTime.utc(2026, 3, 1),
        notificationMilestones: const [14, 3],
        // S-215(a): the two schema-v5 fields ride the existing preferences
        // object, so the format version stays 2 (D-7).
        wheelCapital: Decimal.parse('30000.00'),
        concentrationLimitPct: 20.0,
      ),
    );

    // --- The round trip itself: export, then restore from that same
    // export (restoreFromJson's own replace-all IS the "wipe"). ----------
    final beforeJson = await repo.exportToJson();
    await repo.restoreFromJson(beforeJson);
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
    // S-215(a): the two v5 fields survive the round trip, and the format
    // version is unchanged at 2 (D-7).
    expect(before.preferences.wheelCapital, Decimal.parse('30000.00'));
    expect(before.preferences.concentrationLimitPct, 20.0);
    expect(after.preferences.wheelCapital, Decimal.parse('30000.00'));
    expect(after.preferences.concentrationLimitPct, 20.0);
    expect(before.formatVersion, 2);
    expect(after.formatVersion, 2);

    // Explicit spot checks on the two deliberately risky shapes, both
    // before AND after the round trip -- a null fee coerced to zero, or a
    // roll chain silently reindexed/broken, must fail here even if the
    // blanket `unorderedEquals` above somehow didn't catch it.
    for (final export in [before, after]) {
      final chain = export.legs.where((l) => l.cycleId == cycle1.cycle.id).toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      expect(chain, hasLength(3));
      expect(chain[0].openFee, isNull);
      expect(chain[0].closeFee, isNull);
      expect(chain[0].rolledFromLegId, isNull);
      expect(chain[1].openFee, Decimal.parse('1.00'));
      expect(chain[1].closeFee, Decimal.parse('0.50'));
      expect(chain[1].rolledFromLegId, chain[0].id);
      expect(chain[2].rolledFromLegId, chain[1].id);
      expect(chain[2].contracts, 2);
    }
  });

  test('S-153: restoring a hand-built cycle with varying per-leg contract '
      'counts computes the same totalPremium/wheelBasis as S-105', () async {
    final repo = createRepository();

    // Built directly as model objects -> JSON, never via createCycle/
    // recordRoll/recordAssignment ("never passed through the roll
    // planner").
    const underlyingId = 'u-1';
    const cycleId = 'c-1';
    const leg0Id = 'leg-0';
    const leg1Id = 'leg-1';

    final underlying = const Underlying(id: underlyingId, ticker: 'XYZ');
    final cycle = WheelCycle(
      id: cycleId,
      underlyingId: underlyingId,
      startedAt: DateTime.utc(2026, 1, 5),
      status: WheelCycleStatus.holdingShares,
    );
    final leg0 = Leg(
      id: leg0Id,
      cycleId: cycleId,
      sequence: 0,
      optionType: OptionType.put,
      strike: Decimal.parse('50.00'),
      expiration: DateTime.utc(2026, 2, 20),
      contracts: 1,
      openedAt: DateTime.utc(2026, 1, 5),
      openCreditPerShare: Decimal.parse('0.60'),
      closedAt: DateTime.utc(2026, 1, 25),
      closeDebitPerShare: Decimal.zero, // even roll, isolating the contract-count defect
      closeReason: CloseReason.rolled,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    );
    final leg1 = Leg(
      id: leg1Id,
      cycleId: cycleId,
      sequence: 1,
      optionType: OptionType.put,
      strike: Decimal.parse('50.00'),
      expiration: DateTime.utc(2026, 2, 20),
      contracts: 3,
      openedAt: DateTime.utc(2026, 1, 25),
      openCreditPerShare: Decimal.parse('0.40'),
      closedAt: DateTime.utc(2026, 2, 20),
      closeReason: CloseReason.assigned,
      rolledFromLegId: leg0Id,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    );
    final shareLot = ShareLot(
      id: 'lot-1',
      cycleId: cycleId,
      assignedAt: DateTime.utc(2026, 2, 20),
      assignmentStrike: Decimal.parse('50.00'),
      contracts: 3,
    );
    final standardProfile = RuleProfileData(id: RuleProfileIds.standard, name: 'Standard');
    final standardV1 = RuleProfileVersionData(
      id: RuleProfileVersionIds.standardV1,
      profileId: RuleProfileIds.standard,
      version: 1,
      effectiveAt: DateTime.utc(2026, 1, 1),
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

    final export = LedgerExport(
      formatVersion: LedgerExport.currentFormatVersion,
      underlyings: [underlying],
      cycles: [cycle],
      legs: [leg0, leg1],
      snapshots: const [],
      shareLots: [shareLot],
      ruleProfiles: [standardProfile],
      ruleProfileVersions: [standardV1],
      preferences: const UserPreferencesData(),
    );

    await repo.restoreFromJson(export.toJsonString());

    final importedLegs = await repo.getLegsForCycle(cycleId);
    final importedLot = await repo.getShareLotForCycle(cycleId);
    expect(importedLot, isNotNull);

    // The coordinator's own S-105 figures, computed via the SAME shared
    // rules-engine functions the roll planner and journal use -- proving
    // the import path produces a correct figure because the fix lives in
    // the shared formula (Feature Invariant 25), not in any one entry
    // point.
    expect(cycleTotalPremium(importedLegs), Decimal.parse('180.00'));
    final basis = wheelBasis(
      putLegs: importedLegs,
      shareLot: importedLot!,
      callLegsSinceAssignment: const [],
    );
    expect(basis, Decimal.parse('49.40'));
  });

  test('CR-1: a closed cycle\'s retained assignment survives export/restore, '
      'so a restored backup reports the same figures', () async {
    final source = createRepository();
    final underlying = await source.getOrCreateUnderlying('CR1X');
    final putLeg = await source.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('50.00'),
        expiration: DateTime.utc(2026, 3, 20),
        contracts: 1,
        openedAt: DateTime.utc(2026, 2, 1),
        openCreditPerShare: Decimal.parse('1.20'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    final assignment = await source.recordAssignment(
      legId: putLeg.leg.id,
      shareLot: NewShareLotInput(
        assignedAt: DateTime.utc(2026, 3, 20),
        // Recorded at values the assigned leg does not hold (see the same
        // fixture in ledger_csv_test.dart's CR-1 case).
        assignmentStrike: Decimal.parse('49.50'),
        contracts: 2,
      ),
    );
    final callLeg = await source.openNextLeg(
      cycleId: assignment.cycle.id,
      leg: NewLegInput(
        optionType: OptionType.call,
        strike: Decimal.parse('52.00'),
        expiration: DateTime.utc(2026, 4, 17),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 21),
        openCreditPerShare: Decimal.parse('0.55'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    await source.recordCallAway(legId: callLeg.id, closedAt: DateTime.utc(2026, 4, 17));

    final cycleId = assignment.cycle.id;
    final csvBefore = await buildClosedCyclesCsv(source);

    final restored = createRepository();
    await restored.restoreFromJson(await source.exportToJson());

    // The closed cycle's assignment record came across...
    final retained = await restored.getAssignmentForCycle(cycleId);
    expect(retained, isNotNull);
    expect(retained!.assignmentStrike, Decimal.parse('49.50'));
    expect(retained.contracts, 2);
    // ...still recorded against the closed cycle, never "active".
    expect((await restored.getCycle(cycleId))!.status, WheelCycleStatus.closed);
    expect(await restored.getShareLotForCycle(cycleId), isNull);

    // The user-visible consequence: restoring a backup cannot change the
    // reported figures, because the assignment basis crossed the wire.
    expect(await buildClosedCyclesCsv(restored), csvBefore);
  });

  test('S-192: format-2 export carries the version split and round-trips exactly', () async {
    final repo = createRepository();
    final underlying = await repo.getOrCreateUnderlying('S192');

    // Leg A opens under v1 (the seeded version).
    final legA = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('45.00'),
        expiration: DateTime.utc(2026, 4, 15),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 1),
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    // An edit appends v2; leg B opens under it.
    final v2 = await repo.appendRuleProfileVersion(
      profileId: RuleProfileIds.standard,
      effectiveAt: DateTime.utc(2026, 3, 10),
      values: NewRuleProfileVersionInput(
        profitTargetPct: 60.0,
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
      ),
    );
    expect(v2.id, RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 2));

    final legB = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('45.00'),
        expiration: DateTime.utc(2026, 4, 15),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 11),
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: v2.id,
      ),
    );

    final beforeJson = await repo.exportToJson();
    final before = LedgerExport.fromJsonString(beforeJson);
    expect(before.formatVersion, LedgerExport.currentFormatVersion);
    expect(before.ruleProfiles, hasLength(3)); // identity only
    // 3 seeded v1s + the appended v2.
    expect(before.ruleProfileVersions, hasLength(4));
    expect(
      before.ruleProfileVersions.map((v) => v.id),
      containsAll([RuleProfileVersionIds.standardV1, v2.id]),
    );

    await repo.restoreFromJson(beforeJson);
    final afterJson = await repo.exportToJson();
    expect(afterJson, beforeJson);

    // The pins survive: A stays on v1, B on v2, and each resolves to its
    // own values.
    expect(
      (await repo.getLeg(legA.leg.id))!.ruleProfileVersionId,
      RuleProfileVersionIds.standardV1,
    );
    expect((await repo.getLeg(legB.leg.id))!.ruleProfileVersionId, v2.id);
    expect(
      (await repo.getRuleProfileVersion(RuleProfileVersionIds.standardV1))!.profitTargetPct,
      50.0,
    );
    expect((await repo.getRuleProfileVersion(v2.id))!.profitTargetPct, 60.0);

    // And a further append continues the sequence from the restored rows.
    final v3 = await repo.appendRuleProfileVersion(
      profileId: RuleProfileIds.standard,
      effectiveAt: DateTime.utc(2026, 3, 12),
      values: NewRuleProfileVersionInput(
        profitTargetPct: 65.0,
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
      ),
    );
    expect(v3.version, 3);
  });
}
