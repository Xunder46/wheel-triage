// Shared parity contract suite (docs/conventions.md §6): the exact same
// test bodies run against DriftWheelRepository and InMemoryWheelRepository,
// unmodified per implementation. If one implementation diverges from the
// other in observable behavior, this file is where that shows up.
//
// Per Phase 2 step 8: covers S-013/S-014's persistence shape (arithmetic
// itself is not asserted here — lib/domain/rules/ does not exist yet at
// this point in the pipeline), S-020's persist-vs-not shape, S-024/S-025's
// two-write atomicity, S-026/S-029's cycle transitions, S-030 (write-then-
// read round trip), and S-031 (seeded rule profiles, parity of seeding
// between both implementations). Phase 3 added S-216 (`getAllLegs`'
// ordering) and S-217 (`markExpired`'s atomicity).
//
// CR-7: the three export/import methods (`exportToJson`,
// `countCyclesForReplace`, `restoreFromJson`) are intentionally NOT here —
// their parity coverage lives in the three parameterized files under
// `test/data/export/`, each of which runs the same bodies against both
// implementations. The export surface having no test in this file is a
// decision, not an omission; add export-surface parity there, not here.
// (Deliberately no method count here: a restated count goes stale the next
// time the interface grows, which is how this comment first went wrong.)

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/data/db/drift_wheel_repository.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/entitlement_cache.dart';
import 'package:wheel_triage/domain/models/entitlement_cache_defaults.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/models/underlying.dart';
import 'package:wheel_triage/domain/models/user_preferences.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';

void main() {
  // Every test below intentionally opens its own fresh, independent
  // in-memory AppDatabase — that's the point (test isolation), not a bug.
  // Silence drift's "opened AppDatabase multiple times" debug warning,
  // which assumes shared-executor reuse that never happens here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('DriftWheelRepository', () {
    _runContractTests(() => DriftWheelRepository(AppDatabase(NativeDatabase.memory())));
  });

  group('InMemoryWheelRepository', () {
    _runContractTests(InMemoryWheelRepository.new);
  });
}

/// Runs the full shared contract suite against whatever [createRepository]
/// returns. Called once per implementation, above — the bodies below never
/// differ between the two groups.
void _runContractTests(WheelRepository Function() createRepository) {
  late WheelRepository repo;

  setUp(() {
    repo = createRepository();
  });

  group('Underlying', () {
    test('getOrCreateUnderlying creates once, returns the same row on repeat calls', () async {
      final first = await repo.getOrCreateUnderlying('SBET');
      final second = await repo.getOrCreateUnderlying('SBET');

      expect(second.id, first.id);
      expect(second.ticker, 'SBET');
    });

    test('different tickers create different underlyings', () async {
      final a = await repo.getOrCreateUnderlying('SBET');
      final b = await repo.getOrCreateUnderlying('AAPL');

      expect(a.id, isNot(b.id));
    });

    test('getUnderlying returns null for an unknown id', () async {
      expect(await repo.getUnderlying('does-not-exist'), isNull);
    });

    test('getUnderlying resolves an id created via getOrCreateUnderlying', () async {
      final created = await repo.getOrCreateUnderlying('SBET');
      final fetched = await repo.getUnderlying(created.id);

      expect(fetched, created);
    });
  });

  group('RuleProfile seeding (S-031 parity)', () {
    test('exactly 3 profiles are seeded with the stable fixed ids', () async {
      final profiles = await repo.getRuleProfiles();

      expect(profiles, hasLength(3));
      expect(
        profiles.map((p) => p.id).toSet(),
        {RuleProfileIds.conservative, RuleProfileIds.standard, RuleProfileIds.aggressive},
      );
    });

    test('every seeded profile has exactly its v1 at the §4.4 defaults (S-031 parity)', () async {
      for (final profileId in [
        RuleProfileIds.conservative,
        RuleProfileIds.standard,
        RuleProfileIds.aggressive,
      ]) {
        final versions = await repo.getRuleProfileVersions(profileId);
        expect(versions, hasLength(1));
        final v1 = versions.single;
        expect(v1.id, RuleProfileVersionIds.forVersion(profileId, 1));
        expect(v1.profileId, profileId);
        expect(v1.version, 1);
        expect(v1.profitTargetPct, StandardProfileDefaults.profitTargetPct);
        expect(v1.assignThreshold, StandardProfileDefaults.assignThreshold);
        expect(v1.baseRollBand, StandardProfileDefaults.baseRollBand);
        expect(v1.midIvRollBand, StandardProfileDefaults.midIvRollBand);
        expect(v1.highIvRollBand, StandardProfileDefaults.highIvRollBand);
        expect(v1.midIvCutoff, StandardProfileDefaults.midIvCutoff);
        expect(v1.highIvCutoff, StandardProfileDefaults.highIvCutoff);
        expect(v1.tailDteDays, StandardProfileDefaults.tailDteDays);
        expect(v1.tailExtrinsicThreshold, StandardProfileDefaults.tailExtrinsicThreshold);
        expect(v1.minIvRank, StandardProfileDefaults.minIvRank);
        expect(v1.minAnnualisedYield, StandardProfileDefaults.minAnnualisedYield);
        expect(v1.targetDteMin, StandardProfileDefaults.targetDteMin);
        expect(v1.targetDteMax, StandardProfileDefaults.targetDteMax);
        expect(v1.targetDelta, StandardProfileDefaults.targetDelta);
      }
    });

    test('getRuleProfile returns null for an unknown id', () async {
      expect(await repo.getRuleProfile('does-not-exist'), isNull);
    });

    test('getRuleProfileVersion returns null for an unknown id, bare profile ids included',
        () async {
      expect(await repo.getRuleProfileVersion('does-not-exist'), isNull);
      expect(await repo.getRuleProfileVersion(RuleProfileIds.standard), isNull);
    });

    test('S-191: appendRuleProfileVersion derives id/version; reads order by version',
        () async {
      final sharedInstant = DateTime.utc(2026, 9, 19, 10);

      final v2 = await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: sharedInstant,
        values: _versionInput(profitTargetPct: 60.0),
      );
      expect(v2.id, RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 2));
      expect(v2.version, 2);
      expect(v2.profileId, RuleProfileIds.standard);
      expect(v2.effectiveAt, sharedInstant);

      await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: sharedInstant,
        values: _versionInput(profitTargetPct: 65.0),
      );
      await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: sharedInstant,
        values: _versionInput(profitTargetPct: 70.0),
      );

      final versions = await repo.getRuleProfileVersions(RuleProfileIds.standard);
      // Ordering is by `version`, never `effectiveAt` -- these three edits
      // share one instant and must still order deterministically.
      expect(versions.map((v) => v.version).toList(), [1, 2, 3, 4]);
      expect(
        versions.map((v) => v.id).toList(),
        [
          RuleProfileVersionIds.standardV1,
          RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 2),
          RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 3),
          RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 4),
        ],
      );
      expect(
        (await repo.getRuleProfileVersion(
          RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 3),
        ))!.profitTargetPct,
        65.0,
      );

      // Other profiles are untouched by an append to Standard.
      expect(await repo.getRuleProfileVersions(RuleProfileIds.conservative), hasLength(1));
    });

    test('appendRuleProfileVersion refuses an unknown profile id', () async {
      await expectLater(
        () => repo.appendRuleProfileVersion(
          profileId: 'no-such-profile',
          effectiveAt: DateTime.utc(2026, 9, 19),
          values: _versionInput(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('createCycle (S-020 persist shape)', () {
    test('atomically creates a sellingPuts cycle and its sequence-0 leg', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');

      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 2,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      expect(result.cycle.underlyingId, underlying.id);
      expect(result.cycle.status, WheelCycleStatus.sellingPuts);
      expect(result.cycle.outcome, isNull);

      expect(result.leg.cycleId, result.cycle.id);
      expect(result.leg.sequence, 0);
      expect(result.leg.optionType, OptionType.put);
      expect(result.leg.strike, Decimal.parse('45.00'));
      expect(result.leg.contracts, 2);
      expect(result.leg.openCreditPerShare, Decimal.parse('0.60'));
      expect(result.leg.ruleProfileVersionId, RuleProfileVersionIds.standardV1);
      expect(result.leg.closedAt, isNull);

      // Persisted and independently retrievable (S-030 write-then-read).
      expect(await repo.getCycle(result.cycle.id), result.cycle);
      expect(await repo.getLeg(result.leg.id), result.leg);
      expect(await repo.getOpenLegs(), contains(result.leg));
    });

    test('"just calculating" (never calling createCycle) persists nothing', () async {
      // The screener's "just calculating" path never calls the repository
      // at all (Phase 4's concern) — this asserts the negative half of
      // S-020: an untouched repository has zero legs and zero cycles.
      expect(await repo.getOpenLegs(), isEmpty);
    });
  });

  group('Snapshot (append-only)', () {
    late String legId;

    setUp(() async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      legId = created.leg.id;
    });

    test('getLatestSnapshotForLeg is null before any snapshot exists', () async {
      expect(await repo.getLatestSnapshotForLeg(legId), isNull);
      expect(await repo.getSnapshotsForLeg(legId), isEmpty);
    });

    test('appendSnapshot never overwrites prior history; latest is the most recent', () async {
      final first = await repo.appendSnapshot(NewSnapshotInput(
        legId: legId,
        takenAt: DateTime.utc(2026, 3, 15),
        optionMark: Decimal.parse('0.45'),
        underlyingPrice: Decimal.parse('46.00'),
        deltaAsEntered: -0.20,
        deltaConvention: DeltaConvention.position,
      ));
      final second = await repo.appendSnapshot(NewSnapshotInput(
        legId: legId,
        takenAt: DateTime.utc(2026, 3, 25),
        optionMark: Decimal.parse('0.30'),
        underlyingPrice: Decimal.parse('46.00'),
        deltaAsEntered: -0.25,
        deltaConvention: DeltaConvention.position,
      ));

      final history = await repo.getSnapshotsForLeg(legId);
      expect(history, [first, second]);
      expect(await repo.getLatestSnapshotForLeg(legId), second);
    });
  });

  group('openNextLeg (covered call after assignment)', () {
    test('assigns the next sequence and leaves rolledFromLegId null', () async {
      final underlying = await repo.getOrCreateUnderlying('AAA');
      final putLeg = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50.00'),
          expiration: DateTime.utc(2026, 3, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 2, 1),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final assignment = await repo.recordAssignment(
        legId: putLeg.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 3, 15),
          assignmentStrike: Decimal.parse('50.00'),
          contracts: 1,
        ),
      );

      final callLeg = await repo.openNextLeg(
        cycleId: assignment.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('52.00'),
          expiration: DateTime.utc(2026, 4, 17),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 16),
          openCreditPerShare: Decimal.parse('0.55'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      expect(callLeg.cycleId, assignment.cycle.id);
      expect(callLeg.sequence, putLeg.leg.sequence + 1);
      expect(callLeg.rolledFromLegId, isNull);
      expect(callLeg.closedAt, isNull);

      final chain = await repo.getLegsForCycle(assignment.cycle.id);
      expect(chain, [assignment.leg, callLeg]);
    });
  });

  group('getAllLegs (S-216: every leg, deterministic order)', () {
    // S-216's fixture: two cycles, four legs, one of them backdated a month
    // earlier than the rest. The timestamps are chosen so that
    // `(openedAt, sequence)` is a *total* order over the four legs, and so
    // that insertion order contradicts it exactly once: `A0` (sequence 0) is
    // written after `B1` (sequence 1) but shares its `openedAt`, so an
    // implementation that sorted on `openedAt` alone — or trusted SQLite's
    // rowid / the map's insertion order — returns them the other way round.
    final reference = DateTime.utc(2026, 5, 4, 10, 0);
    final backdated = reference.subtract(const Duration(days: 30));
    final laterSameMinute = reference.add(const Duration(seconds: 30));

    Future<
        ({
          Leg backdatedPut,
          Leg call,
          Leg put,
          Leg rolledCall,
          WheelCycle closedCycle,
          WheelCycle openCycle,
        })> seed() async {
      // The closed cycle first, so its later leg (sequence 1) is written
      // before the open cycle's first leg (sequence 0) at the same instant.
      final closedUnderlying = await repo.getOrCreateUnderlying('BBB');
      final created = await repo.createCycle(
        underlyingId: closedUnderlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: backdated,
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final assigned = await repo.recordAssignment(
        legId: created.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: backdated.add(const Duration(days: 32)),
          assignmentStrike: Decimal.parse('45.00'),
          contracts: 1,
        ),
      );
      final call = await repo.openNextLeg(
        cycleId: assigned.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('47.00'),
          expiration: DateTime.utc(2026, 5, 15),
          contracts: 1,
          openedAt: reference,
          openCreditPerShare: Decimal.parse('0.50'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final calledAway = await repo.recordCallAway(
        legId: call.id,
        closedAt: reference.add(const Duration(days: 12)),
      );

      final openUnderlying = await repo.getOrCreateUnderlying('AAA');
      final rolled = await repo.createCycle(
        underlyingId: openUnderlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('30.00'),
          expiration: DateTime.utc(2026, 6, 19),
          contracts: 1,
          openedAt: reference,
          openCreditPerShare: Decimal.parse('0.45'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final roll = await repo.recordRoll(
        closingLegId: rolled.leg.id,
        closeDebitPerShare: Decimal.parse('0.15'),
        closedAt: reference.add(const Duration(seconds: 20)),
        newLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('28.00'),
          expiration: DateTime.utc(2026, 7, 17),
          contracts: 1,
          openedAt: laterSameMinute,
          openCreditPerShare: Decimal.parse('0.40'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      return (
        backdatedPut: created.leg,
        call: call,
        put: roll.closedLeg,
        rolledCall: roll.newLeg,
        closedCycle: calledAway.cycle,
        openCycle: rolled.cycle,
      );
    }

    test('returns every leg, backdated first, sequence breaking same-instant ties', () async {
      final fixture = await seed();

      final legs = await repo.getAllLegs();

      expect(
        legs.map((l) => l.id).toList(),
        [
          fixture.backdatedPut.id,
          fixture.put.id,
          fixture.call.id,
          fixture.rolledCall.id,
        ],
      );
      expect(legs, hasLength(4));
    });

    test('includes open and closed legs alike, and does not disturb either cycle', () async {
      final fixture = await seed();

      final legs = await repo.getAllLegs();

      expect(legs.where((l) => l.closedAt == null).map((l) => l.id), [fixture.rolledCall.id]);
      expect(
        legs.where((l) => l.closedAt != null).map((l) => l.id),
        [fixture.backdatedPut.id, fixture.put.id, fixture.call.id],
      );

      expect((await repo.getCycle(fixture.openCycle.id))!.status, WheelCycleStatus.sellingPuts);
      expect((await repo.getCycle(fixture.closedCycle.id))!.status, WheelCycleStatus.closed);
    });
  });

  group('recordRoll (S-024/S-025: atomic two-write)', () {
    test('closes leg N as rolled and creates leg N+1 inheriting ruleProfileVersionId', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 2,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final leg0 = created.leg;

      final rollResult = await repo.recordRoll(
        closingLegId: leg0.id,
        closeDebitPerShare: Decimal.parse('0.80'),
        closedAt: DateTime.utc(2026, 4, 1),
        newLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('44.00'),
          expiration: DateTime.utc(2026, 4, 29),
          contracts: 2,
          openedAt: DateTime.utc(2026, 4, 1),
          openCreditPerShare: Decimal.parse('0.95'),
          ruleProfileVersionId: leg0.ruleProfileVersionId,
        ),
      );

      expect(rollResult.closedLeg.id, leg0.id);
      expect(rollResult.closedLeg.closeReason, CloseReason.rolled);
      expect(rollResult.closedLeg.closeDebitPerShare, Decimal.parse('0.80'));
      expect(rollResult.closedLeg.closedAt, DateTime.utc(2026, 4, 1));

      expect(rollResult.newLeg.sequence, 1);
      expect(rollResult.newLeg.rolledFromLegId, leg0.id);
      expect(rollResult.newLeg.cycleId, leg0.cycleId);
      expect(rollResult.newLeg.ruleProfileVersionId, leg0.ruleProfileVersionId);
      expect(rollResult.newLeg.closedAt, isNull);

      // Both writes landed — the roll chain now has exactly two legs, in
      // sequence order (S-013's persistence shape).
      final chain = await repo.getLegsForCycle(leg0.cycleId);
      expect(chain, [rollResult.closedLeg, rollResult.newLeg]);

      // Inline, trivial arithmetic only — the real formulas live in
      // lib/domain/rules/roll_chain.dart (Phase 3).
      final legNetCredit0 =
          rollResult.closedLeg.openCreditPerShare - rollResult.closedLeg.closeDebitPerShare!;
      expect(legNetCredit0, Decimal.parse('-0.20')); // a debit roll, per S-013/S-025

      // The new leg replaces the old one in getOpenLegs.
      final open = await repo.getOpenLegs();
      expect(open.map((l) => l.id), contains(rollResult.newLeg.id));
      expect(open.map((l) => l.id), isNot(contains(rollResult.closedLeg.id)));
    });
  });

  group('Leg fees / acceptsAssignment (Phase 15)', () {
    test('S-093: fee fields round-trip, null and populated', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');

      // Leg A: no fees passed at all -> both fields read back null, never
      // coerced to Decimal.zero (§4.3).
      final legA = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      expect(legA.leg.openFee, isNull);
      expect((await repo.getLeg(legA.leg.id))!.openFee, isNull);

      final closedA = await repo.closeLeg(
        legId: legA.leg.id,
        reason: CloseReason.expiredWorthless,
        closedAt: DateTime.utc(2026, 4, 15),
      );
      expect(closedA.leg.closeFee, isNull);
      expect((await repo.getLeg(legA.leg.id))!.closeFee, isNull);

      // Leg B: an explicit open fee of $1.50 and close fee of $0.65 -> read
      // back as the exact cent values.
      final legB = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          openFee: Decimal.parse('1.50'),
        ),
      );
      expect(legB.leg.openFee, Decimal.parse('1.50'));

      final closedB = await repo.closeLeg(
        legId: legB.leg.id,
        reason: CloseReason.expiredWorthless,
        closeFee: Decimal.parse('0.65'),
        closedAt: DateTime.utc(2026, 4, 15),
      );
      expect(closedB.leg.closeFee, Decimal.parse('0.65'));
      expect((await repo.getLeg(legB.leg.id))!.openFee, Decimal.parse('1.50'));
      expect((await repo.getLeg(legB.leg.id))!.closeFee, Decimal.parse('0.65'));
    });

    test('S-094: acceptsAssignment defaults to true on createCycle and openNextLeg', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');

      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 1),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      expect(created.leg.acceptsAssignment, isTrue);

      final assignment = await repo.recordAssignment(
        legId: created.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 4, 15),
          assignmentStrike: Decimal.parse('50.00'),
          contracts: 1,
        ),
      );
      final callLeg = await repo.openNextLeg(
        cycleId: assignment.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('52.00'),
          expiration: DateTime.utc(2026, 5, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 4, 16),
          openCreditPerShare: Decimal.parse('0.50'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      expect(callLeg.acceptsAssignment, isTrue);
      expect((await repo.getLeg(callLeg.id))!.acceptsAssignment, isTrue);
    });

    test('S-095: recordRoll preserves an explicit acceptsAssignment on the new leg', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          acceptsAssignment: false,
        ),
      );
      final leg0 = created.leg;
      expect(leg0.acceptsAssignment, isFalse);

      final rollResult = await repo.recordRoll(
        closingLegId: leg0.id,
        closeDebitPerShare: Decimal.parse('0.80'),
        closedAt: DateTime.utc(2026, 4, 1),
        newLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('44.00'),
          expiration: DateTime.utc(2026, 4, 29),
          contracts: 1,
          openedAt: DateTime.utc(2026, 4, 1),
          openCreditPerShare: Decimal.parse('0.95'),
          ruleProfileVersionId: leg0.ruleProfileVersionId,
          acceptsAssignment: false,
        ),
      );

      // The repository's own job is only to not clobber whatever value the
      // caller (lib/state/'s inheritance policy, S-102) supplies — never to
      // derive it itself.
      expect(rollResult.newLeg.acceptsAssignment, isFalse);
      expect((await repo.getLeg(rollResult.newLeg.id))!.acceptsAssignment, isFalse);
      // The closed leg's own value is unchanged by the roll.
      expect((await repo.getLeg(leg0.id))!.acceptsAssignment, isFalse);
    });
  });

  group('updateLegMetadata (Phase 17.1: S-122/S-124 non-lifecycle edits)', () {
    test('S-124: flips acceptsAssignment on an open leg, touching nothing else', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 2,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          openFee: Decimal.parse('1.00'),
        ),
      );
      final before = created.leg;
      expect(before.acceptsAssignment, isTrue);
      expect(before.closedAt, isNull);

      final updated = await repo.updateLegMetadata(
        legId: before.id,
        acceptsAssignment: false,
      );

      expect(updated.acceptsAssignment, isFalse);
      // Not just that acceptsAssignment changed — every other field is
      // byte-identical to the pre-update leg (the method's entire value is
      // in what it declines to touch).
      expect(updated, before.copyWith(acceptsAssignment: false));

      final reread = await repo.getLeg(before.id);
      expect(reread, updated);
    });

    test('S-122: fills openFee and closeFee on an already-closed leg, touching nothing else',
        () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final closed = await repo.closeLeg(
        legId: created.leg.id,
        reason: CloseReason.expiredWorthless,
        closedAt: DateTime.utc(2026, 4, 15),
      );
      final before = closed.leg;
      expect(before.openFee, isNull);
      expect(before.closeFee, isNull);

      final updated = await repo.updateLegMetadata(
        legId: before.id,
        openFee: Decimal.parse('1.25'),
        closeFee: Decimal.parse('0.65'),
      );

      expect(updated.openFee, Decimal.parse('1.25'));
      expect(updated.closeFee, Decimal.parse('0.65'));
      // Pin exactly what must NOT move: closedAt, closeReason, sequence,
      // rolledFromLegId, openCreditPerShare, closeDebitPerShare all
      // byte-identical to the leg as it was before this call.
      expect(updated.closedAt, before.closedAt);
      expect(updated.closeReason, before.closeReason);
      expect(updated.sequence, before.sequence);
      expect(updated.rolledFromLegId, before.rolledFromLegId);
      expect(updated.openCreditPerShare, before.openCreditPerShare);
      expect(updated.closeDebitPerShare, before.closeDebitPerShare);
      expect(
        updated,
        before.copyWith(
          openFee: Decimal.parse('1.25'),
          closeFee: Decimal.parse('0.65'),
        ),
      );

      final reread = await repo.getLeg(before.id);
      expect(reread, updated);
    });

    test('clearOpenFee/clearCloseFee reset a fee back to null, touching nothing else', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          openFee: Decimal.parse('1.25'),
        ),
      );
      final closed = await repo.closeLeg(
        legId: created.leg.id,
        reason: CloseReason.expiredWorthless,
        closeFee: Decimal.parse('0.65'),
        closedAt: DateTime.utc(2026, 4, 15),
      );
      final before = closed.leg;
      expect(before.openFee, Decimal.parse('1.25'));
      expect(before.closeFee, Decimal.parse('0.65'));

      final updated = await repo.updateLegMetadata(
        legId: before.id,
        clearOpenFee: true,
        clearCloseFee: true,
      );

      expect(updated.openFee, isNull);
      expect(updated.closeFee, isNull);
      expect(updated, before.copyWith(openFee: null, closeFee: null));

      final reread = await repo.getLeg(before.id);
      expect(reread, updated);
    });

    test('throws ArgumentError on an all-null call that would change nothing', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      expect(
        () => repo.updateLegMetadata(legId: created.leg.id),
        throwsArgumentError,
      );

      // Confirms the no-op call above did not silently write anything.
      expect(await repo.getLeg(created.leg.id), created.leg);
    });

    test('throws ArgumentError when a fee value and its clear flag are both set', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      expect(
        () => repo.updateLegMetadata(
          legId: created.leg.id,
          openFee: Decimal.parse('1.00'),
          clearOpenFee: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.updateLegMetadata(
          legId: created.leg.id,
          closeFee: Decimal.parse('1.00'),
          clearCloseFee: true,
        ),
        throwsArgumentError,
      );

      // Confirms neither rejected call silently wrote anything.
      expect(await repo.getLeg(created.leg.id), created.leg);
    });
  });

  group('closeLeg (Feature Invariant 16)', () {
    Future<({Leg leg, WheelCycle cycle})> openPutLeg(String ticker) async {
      final underlying = await repo.getOrCreateUnderlying(ticker);
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 11),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      return (leg: created.leg, cycle: created.cycle);
    }

    test('rejects reason=rolled', () async {
      final opened = await openPutLeg('AAA');
      expect(
        () => repo.closeLeg(
          legId: opened.leg.id,
          reason: CloseReason.rolled,
          closedAt: DateTime.utc(2026, 4, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects reason=assigned', () async {
      final opened = await openPutLeg('AAA');
      expect(
        () => repo.closeLeg(
          legId: opened.leg.id,
          reason: CloseReason.assigned,
          closedAt: DateTime.utc(2026, 4, 1),
        ),
        throwsArgumentError,
      );
    });

    test('S-027: direct put close (expiredWorthless) ends the cycle', () async {
      final opened = await openPutLeg('AAA');

      final result = await repo.closeLeg(
        legId: opened.leg.id,
        reason: CloseReason.expiredWorthless,
        closeDebitPerShare: Decimal.zero,
        closedAt: DateTime.utc(2026, 4, 15),
      );

      expect(result.leg.closeReason, CloseReason.expiredWorthless);
      expect(result.leg.closeDebitPerShare, Decimal.zero);
      expect(result.cycle.status, WheelCycleStatus.closed);
      expect(result.cycle.outcome, WheelCycleOutcome.expiredWorthless);
      expect(result.cycle.endedAt, DateTime.utc(2026, 4, 15));
    });

    test('direct put close (closedEarly) ends the cycle with outcome closedEarly', () async {
      final opened = await openPutLeg('AAA');

      final result = await repo.closeLeg(
        legId: opened.leg.id,
        reason: CloseReason.closedEarly,
        closeDebitPerShare: Decimal.parse('0.10'),
        closedAt: DateTime.utc(2026, 3, 20),
      );

      expect(result.cycle.status, WheelCycleStatus.closed);
      expect(result.cycle.outcome, WheelCycleOutcome.closedEarly);
    });

    test('S-028: direct call close while holdingShares does NOT end the cycle', () async {
      final opened = await openPutLeg('AAA');
      final assigned = await repo.recordAssignment(
        legId: opened.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 4, 15),
          assignmentStrike: Decimal.parse('45.00'),
          contracts: 1,
        ),
      );
      final callLeg = await repo.openNextLeg(
        cycleId: assigned.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('47.00'),
          expiration: DateTime.utc(2026, 5, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 4, 16),
          openCreditPerShare: Decimal.parse('0.50'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      expect(callLeg.cycleId, assigned.cycle.id);
      expect(callLeg.rolledFromLegId, isNull);

      final result = await repo.closeLeg(
        legId: callLeg.id,
        reason: CloseReason.closedEarly,
        closeDebitPerShare: Decimal.parse('0.20'),
        closedAt: DateTime.utc(2026, 4, 20),
      );

      expect(result.leg.closeReason, CloseReason.closedEarly);
      // The cycle itself is what closeLeg reports back — assert directly
      // on it (still holdingShares: shares are still owned, the user may
      // open another covered call), and re-fetch to confirm the write
      // really landed rather than just trusting the in-memory return value.
      expect(result.cycle.status, WheelCycleStatus.holdingShares);
      final putCycle = await repo.getCycle(assigned.cycle.id);
      expect(putCycle!.status, WheelCycleStatus.holdingShares);
    });
  });

  group('markExpired (S-217: the batch expire is atomic)', () {
    // S-217's fixture: three open legs past expiration across two cycles —
    // two puts, each on its own cycle, and one call on a `holdingShares`
    // cycle — plus one open leg that is deliberately NOT in any batch, so
    // "nothing else moved" is falsifiable.
    final putExpiration = DateTime.utc(2026, 4, 15);
    final callExpiration = DateTime.utc(2026, 4, 22);
    final unselectedExpiration = DateTime.utc(2026, 4, 3);

    Future<
        ({
          Leg holdingSharesCall,
          Leg put,
          Leg secondPut,
          Leg unselectedPut,
          WheelCycle holdingSharesCycle,
          WheelCycle putCycle,
          WheelCycle secondPutCycle,
          WheelCycle unselectedCycle,
        })> seed() async {
      Future<({Leg leg, WheelCycle cycle})> openPut(
        String ticker,
        String strike,
        DateTime expiration,
      ) async {
        final underlying = await repo.getOrCreateUnderlying(ticker);
        return repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse(strike),
            expiration: expiration,
            contracts: 1,
            openedAt: DateTime.utc(2026, 3, 11),
            openCreditPerShare: Decimal.parse('0.60'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );
      }

      final put = await openPut('AAA', '45.00', putExpiration);
      final secondPut = await openPut('BBB', '20.00', putExpiration);
      final unselected = await openPut('CCC', '25.00', unselectedExpiration);

      // The `holdingShares` cycle: its put is already assigned (closed), its
      // call is the open leg the batch targets.
      final holdingShares = await openPut('DDD', '30.00', callExpiration);
      final assigned = await repo.recordAssignment(
        legId: holdingShares.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 3, 20),
          assignmentStrike: Decimal.parse('30.00'),
          contracts: 1,
        ),
      );
      final call = await repo.openNextLeg(
        cycleId: assigned.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('32.00'),
          expiration: callExpiration,
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 21),
          openCreditPerShare: Decimal.parse('0.50'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      return (
        holdingSharesCall: call,
        put: put.leg,
        secondPut: secondPut.leg,
        unselectedPut: unselected.leg,
        holdingSharesCycle: assigned.cycle,
        putCycle: put.cycle,
        secondPutCycle: secondPut.cycle,
        unselectedCycle: unselected.cycle,
      );
    }

    /// Every leg and every one of the fixture's cycles, as they stand right
    /// now — the "nothing changed" baseline the failure cases compare
    /// against.
    Future<({List<Leg> legs, Map<String, WheelCycle?> cycles})> snapshot(
      List<String> cycleIds,
    ) async => (
          legs: await repo.getAllLegs(),
          cycles: {
            for (final id in cycleIds) id: await repo.getCycle(id),
          },
        );

    test('closes a batch of two, ending the put leg\'s cycle and leaving holdingShares alone',
        () async {
      final fixture = await seed();

      final closed = await repo.markExpired(
        legs: [
          (legId: fixture.put.id, closedAt: putExpiration),
          (legId: fixture.holdingSharesCall.id, closedAt: callExpiration),
        ],
      );

      // The returned legs carry exactly what `closeLeg(reason:
      // expiredWorthless, closeDebitPerShare: Decimal.zero, closeFee: null,
      // closedAt: <supplied>)` records.
      expect(closed.map((l) => l.id), [fixture.put.id, fixture.holdingSharesCall.id]);
      for (final leg in closed) {
        expect(leg.closeReason, CloseReason.expiredWorthless);
        expect(leg.closeDebitPerShare, Decimal.zero);
        expect(leg.closeFee, isNull);
      }
      expect(closed[0].closedAt, putExpiration);
      expect(closed[1].closedAt, callExpiration);

      // Re-read rather than trusting the return value: the write really
      // landed, and it landed identically in both implementations.
      final legs = await repo.getAllLegs();
      final byId = {for (final leg in legs) leg.id: leg};
      expect(byId[fixture.put.id]!.closedAt, putExpiration);
      expect(byId[fixture.put.id]!.closeReason, CloseReason.expiredWorthless);
      expect(byId[fixture.put.id]!.closeDebitPerShare, Decimal.zero);
      expect(byId[fixture.put.id]!.closeFee, isNull);
      expect(byId[fixture.holdingSharesCall.id]!.closedAt, callExpiration);
      expect(byId[fixture.holdingSharesCall.id]!.closeReason, CloseReason.expiredWorthless);
      expect(byId[fixture.holdingSharesCall.id]!.closeDebitPerShare, Decimal.zero);
      expect(byId[fixture.holdingSharesCall.id]!.closeFee, isNull);

      // The put leg's own cycle ended exactly as a direct close ends it.
      final putCycle = await repo.getCycle(fixture.putCycle.id);
      expect(putCycle!.status, WheelCycleStatus.closed);
      expect(putCycle.outcome, WheelCycleOutcome.expiredWorthless);
      expect(putCycle.endedAt, putExpiration);

      // A call leg on a `holdingShares` cycle does not end that cycle.
      final holdingSharesCycle = await repo.getCycle(fixture.holdingSharesCycle.id);
      expect(holdingSharesCycle!.status, WheelCycleStatus.holdingShares);
      expect(holdingSharesCycle.outcome, isNull);
      expect(holdingSharesCycle.endedAt, isNull);
      expect(await repo.getShareLotForCycle(fixture.holdingSharesCycle.id), isNotNull);

      // The leg that was not in the batch, and its cycle, are untouched.
      expect(byId[fixture.secondPut.id]!.closedAt, isNull);
      expect(byId[fixture.unselectedPut.id]!.closedAt, isNull);
      expect((await repo.getCycle(fixture.secondPutCycle.id))!.status, WheelCycleStatus.sellingPuts);
      expect(
        (await repo.getCycle(fixture.unselectedCycle.id))!.status,
        WheelCycleStatus.sellingPuts,
      );
    });

    test('an unknown id in the batch throws and changes nothing', () async {
      final fixture = await seed();
      final before = await snapshot([
        fixture.putCycle.id,
        fixture.secondPutCycle.id,
        fixture.holdingSharesCycle.id,
        fixture.unselectedCycle.id,
      ]);

      await expectLater(
        () => repo.markExpired(
          legs: [
            (legId: fixture.put.id, closedAt: putExpiration),
            (legId: 'no-such-leg', closedAt: putExpiration),
          ],
        ),
        throwsArgumentError,
      );

      expect(await repo.getAllLegs(), before.legs);
      for (final entry in before.cycles.entries) {
        expect(await repo.getCycle(entry.key), entry.value);
      }
      expect(await repo.getShareLotForCycle(fixture.holdingSharesCycle.id), isNotNull);
    });

    test('an empty batch throws ArgumentError', () async {
      final fixture = await seed();
      final before = await snapshot([fixture.putCycle.id]);

      await expectLater(() => repo.markExpired(legs: []), throwsArgumentError);

      expect(await repo.getAllLegs(), before.legs);
      expect(await repo.getCycle(fixture.putCycle.id), before.cycles[fixture.putCycle.id]);
    });

    test('an already-closed leg throws and changes nothing', () async {
      final fixture = await seed();
      await repo.closeLeg(
        legId: fixture.secondPut.id,
        reason: CloseReason.closedEarly,
        closeDebitPerShare: Decimal.parse('0.10'),
        closedAt: DateTime.utc(2026, 4, 1),
      );
      final before = await snapshot([
        fixture.putCycle.id,
        fixture.secondPutCycle.id,
        fixture.holdingSharesCycle.id,
        fixture.unselectedCycle.id,
      ]);

      await expectLater(
        () => repo.markExpired(
          legs: [
            (legId: fixture.put.id, closedAt: putExpiration),
            (legId: fixture.secondPut.id, closedAt: putExpiration),
          ],
        ),
        throwsArgumentError,
      );

      expect(await repo.getAllLegs(), before.legs);
      for (final entry in before.cycles.entries) {
        expect(await repo.getCycle(entry.key), entry.value);
      }
    });
  });

  group('recordAssignment (S-026: put-side assignment)', () {
    test('creates exactly one ShareLot, closes the leg, transitions to holdingShares', () async {
      final underlying = await repo.getOrCreateUnderlying('AAA');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 1),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final result = await repo.recordAssignment(
        legId: created.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 4, 15),
          assignmentStrike: Decimal.parse('50.00'),
          contracts: 1,
        ),
      );

      expect(result.leg.closeReason, CloseReason.assigned);
      expect(result.leg.closedAt, DateTime.utc(2026, 4, 15));

      expect(result.shareLot.cycleId, created.cycle.id);
      expect(result.shareLot.assignmentStrike, Decimal.parse('50.00'));
      expect(result.shareLot.contracts, 1);

      expect(result.cycle.status, WheelCycleStatus.holdingShares);
      // Assignment never ends the cycle (contrast with call-away).
      expect(result.cycle.outcome, isNull);

      final fetchedLot = await repo.getShareLotForCycle(created.cycle.id);
      expect(fetchedLot, result.shareLot);
    });
  });

  group('recordCallAway (S-029: call-side assignment closes the cycle)', () {
    test('closes the call leg, deactivates the ShareLot (retained as history), ends the cycle as calledAway', () async {
      final underlying = await repo.getOrCreateUnderlying('AAA');
      final putLeg = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50.00'),
          expiration: DateTime.utc(2026, 3, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 2, 1),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final assignment = await repo.recordAssignment(
        legId: putLeg.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 3, 15),
          assignmentStrike: Decimal.parse('50.00'),
          contracts: 1,
        ),
      );
      final callLeg = await repo.openNextLeg(
        cycleId: assignment.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('52.00'),
          expiration: DateTime.utc(2026, 4, 17),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 16),
          openCreditPerShare: Decimal.parse('0.55'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final result = await repo.recordCallAway(
        legId: callLeg.id,
        closedAt: DateTime.utc(2026, 4, 17),
      );

      expect(result.leg.closeReason, CloseReason.assigned);
      expect(result.leg.closedAt, DateTime.utc(2026, 4, 17));

      expect(result.cycle.id, assignment.cycle.id);
      expect(result.cycle.status, WheelCycleStatus.closed);
      expect(result.cycle.outcome, WheelCycleOutcome.calledAway);
      expect(result.cycle.endedAt, DateTime.utc(2026, 4, 17));

      // The active accessor stops returning it once the shares are sold
      // (Feature Invariant 14's consumption, unchanged)...
      expect(await repo.getShareLotForCycle(assignment.cycle.id), isNull);

      // ...but the assignment record itself is retained (CR-1), so
      // closed-cycle figures never have to be rebuilt from the leg.
      final retained = await repo.getAssignmentForCycle(assignment.cycle.id);
      expect(retained, isNotNull);
      expect(retained!.id, assignment.shareLot.id);
      expect(retained.assignmentStrike, Decimal.parse('50.00'));
      expect(retained.contracts, 1);
    });
  });

  group('getAssignmentForCycle (CR-1: the assignment record outlives the cycle)', () {
    test('keeps the strike/contracts actually recorded, which the assigned leg does not hold', () async {
      final underlying = await repo.getOrCreateUnderlying('CR1');
      final putLeg = await repo.createCycle(
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

      // Both fields are user-entered at assignment time, so neither can be
      // assumed to equal the leg's own `strike`/`contracts`.
      final assignment = await repo.recordAssignment(
        legId: putLeg.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 3, 20),
          assignmentStrike: Decimal.parse('49.50'),
          contracts: 2,
        ),
      );

      expect(
        await repo.getShareLotForCycle(assignment.cycle.id),
        isNotNull,
        reason: 'live while the cycle is holdingShares',
      );
      expect(
        (await repo.getAssignmentForCycle(assignment.cycle.id))!.assignmentStrike,
        Decimal.parse('49.50'),
      );

      final callLeg = await repo.openNextLeg(
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
      await repo.recordCallAway(legId: callLeg.id, closedAt: DateTime.utc(2026, 4, 17));

      final retained = await repo.getAssignmentForCycle(assignment.cycle.id);
      expect(retained, isNotNull);
      expect(retained!.assignmentStrike, Decimal.parse('49.50'),
          reason: 'the recorded strike must survive, not the leg\'s 50.00');
      expect(retained.contracts, 2,
          reason: 'the recorded contract count must survive, not the leg\'s 1');
    });

    test('is null for a cycle that never reached a put-side assignment', () async {
      final underlying = await repo.getOrCreateUnderlying('NOASSIGN');
      final created = await repo.createCycle(
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
      await repo.closeLeg(
        legId: created.leg.id,
        reason: CloseReason.expiredWorthless,
        closedAt: DateTime.utc(2026, 3, 20),
      );

      expect(await repo.getAssignmentForCycle(created.cycle.id), isNull);
      expect(await repo.getShareLotForCycle(created.cycle.id), isNull);
    });
  });

  group('getClosedCycles (Phase 15/S-096)', () {
    test('returns only closed cycles, newest endedAt first', () async {
      final underlying = await repo.getOrCreateUnderlying('XYZ');

      Future<WheelCycle> openAndDirectlyCloseCycle(DateTime endedAt) async {
        final created = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45.00'),
            expiration: endedAt,
            contracts: 1,
            openedAt: endedAt.subtract(const Duration(days: 30)),
            openCreditPerShare: Decimal.parse('0.60'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );
        final closed = await repo.closeLeg(
          legId: created.leg.id,
          reason: CloseReason.expiredWorthless,
          closedAt: endedAt,
        );
        return closed.cycle;
      }

      final olderClosed = await openAndDirectlyCloseCycle(DateTime.utc(2026, 1, 15));
      final newerClosed = await openAndDirectlyCloseCycle(DateTime.utc(2026, 3, 15));

      // One sellingPuts (open) cycle, never closed.
      await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 5, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 4, 1),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      // One holdingShares (open) cycle, never closed.
      final toAssign = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50.00'),
          expiration: DateTime.utc(2026, 4, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 1),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: toAssign.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 4, 15),
          assignmentStrike: Decimal.parse('50.00'),
          contracts: 1,
        ),
      );

      final closedCycles = await repo.getClosedCycles();

      expect(closedCycles.map((c) => c.id), [newerClosed.id, olderClosed.id]);
      expect(closedCycles.every((c) => c.status == WheelCycleStatus.closed), isTrue);
    });
  });

  group('UserPreferences (Iteration 3, schema v2)', () {
    test('S-035: defaults match the brief, identical from a fresh repository', () async {
      final prefs = await repo.getPreferences();

      expect(
        prefs,
        const UserPreferencesData(
          totalPerContractToggle: false,
          deltaConventionDefault: DeltaConvention.position,
          firstRunExplainerShown: false,
          ivResolutionNoticeDismissed: false,
          exportReminderDismissed: false,
          lastExportAt: null,
          notificationMilestones: [21, 7, 0],
        ),
      );
    });

    test('S-036: update-and-persist round trip changes only the touched fields', () async {
      final defaults = await repo.getPreferences();

      final updated = await repo.updatePreferences(
        defaults.copyWith(
          totalPerContractToggle: true,
          deltaConventionDefault: DeltaConvention.option,
        ),
      );
      expect(updated.totalPerContractToggle, isTrue);
      expect(updated.deltaConventionDefault, DeltaConvention.option);

      // A fresh read reflects both changed fields and leaves the other two
      // at their defaults.
      final reread = await repo.getPreferences();
      expect(
        reread,
        const UserPreferencesData(
          totalPerContractToggle: true,
          deltaConventionDefault: DeltaConvention.option,
          firstRunExplainerShown: false,
          ivResolutionNoticeDismissed: false,
          exportReminderDismissed: false,
          lastExportAt: null,
          notificationMilestones: [21, 7, 0],
        ),
      );
    });

    test('Phase 15: exportReminderDismissed/lastExportAt/notificationMilestones round trip',
        () async {
      final defaults = await repo.getPreferences();

      final updated = await repo.updatePreferences(
        defaults.copyWith(
          exportReminderDismissed: true,
          lastExportAt: DateTime.utc(2026, 3, 1),
          notificationMilestones: const [14, 3],
        ),
      );
      expect(updated.exportReminderDismissed, isTrue);
      expect(updated.lastExportAt, DateTime.utc(2026, 3, 1));
      expect(updated.notificationMilestones, [14, 3]);

      final reread = await repo.getPreferences();
      expect(reread.exportReminderDismissed, isTrue);
      expect(reread.lastExportAt, DateTime.utc(2026, 3, 1));
      expect(reread.notificationMilestones, [14, 3]);
    });

    test('S-215: wheelCapital and concentrationLimitPct round trip through both '
        'implementations', () async {
      final defaults = await repo.getPreferences();
      expect(defaults.wheelCapital, isNull);
      expect(defaults.concentrationLimitPct, 25.0);

      await repo.updatePreferences(
        defaults.copyWith(
          wheelCapital: Decimal.parse('30000.00'),
          concentrationLimitPct: 20.0,
        ),
      );

      final reread = await repo.getPreferences();
      expect(reread.wheelCapital, Decimal.parse('30000.00'));
      expect(reread.concentrationLimitPct, 20.0);

      // Clearing the capital is a real state, not a reset to zero.
      await repo.updatePreferences(reread.copyWith(wheelCapital: null));
      final cleared = await repo.getPreferences();
      expect(cleared.wheelCapital, isNull);
      expect(cleared.concentrationLimitPct, 20.0);
    });
  });

  group('getOpenCycles (Pro Wave 2, D-22)', () {
    test('S-258: returns every non-closed cycle across all underlyings, '
        'oldest startedAt first, including one with no open leg', () async {
      final first = await repo.getOrCreateUnderlying('AAA');
      final second = await repo.getOrCreateUnderlying('BBB');

      Future<WheelCycle> openPutOn(Underlying underlying, DateTime openedAt) =>
          repo.createCycle(
            underlyingId: underlying.id,
            firstLeg: NewLegInput(
              optionType: OptionType.put,
              strike: Decimal.parse('45.00'),
              expiration: openedAt.add(const Duration(days: 40)),
              contracts: 1,
              openedAt: openedAt,
              openCreditPerShare: Decimal.parse('0.60'),
              ruleProfileVersionId: RuleProfileVersionIds.standardV1,
            ),
          ).then((created) => created.cycle);

      // The closed cycle is started *between* the two open ones, so a
      // "returned everything, in insertion order" implementation cannot
      // pass by accident.
      final olderOpen = await openPutOn(first, DateTime.utc(2026, 1, 5));
      final closedCycle = await openPutOn(second, DateTime.utc(2026, 2, 5));
      await repo.closeLeg(
        legId: (await repo.getLegsForCycle(closedCycle.id)).single.id,
        reason: CloseReason.expiredWorthless,
        closedAt: DateTime.utc(2026, 3, 5),
      );
      final newerOpen = await openPutOn(first, DateTime.utc(2026, 4, 5));

      // Two `holdingShares` cycles: the first gets a covered call opened and
      // then closed early, so it has NO open leg at all — the D-P12 case
      // that makes grouping `getAllLegs()` an unacceptable substitute. The
      // second keeps its open call.
      final assignedNoLeg = await repo.createCycle(
        underlyingId: second.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50.00'),
          expiration: DateTime.utc(2026, 5, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 10),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: assignedNoLeg.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 5, 15),
          assignmentStrike: Decimal.parse('50.00'),
          contracts: 1,
        ),
      );
      final callLeg = await repo.openNextLeg(
        cycleId: assignedNoLeg.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('55.00'),
          expiration: DateTime.utc(2026, 7, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 5, 20),
          openCreditPerShare: Decimal.parse('0.80'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.closeLeg(
        legId: callLeg.id,
        reason: CloseReason.closedEarly,
        closeDebitPerShare: Decimal.parse('0.20'),
        closedAt: DateTime.utc(2026, 6, 1),
      );

      final assignedWithCall = await repo.createCycle(
        underlyingId: first.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('60.00'),
          expiration: DateTime.utc(2026, 6, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 5, 1),
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.recordAssignment(
        legId: assignedWithCall.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 6, 15),
          assignmentStrike: Decimal.parse('60.00'),
          contracts: 1,
        ),
      );
      await repo.openNextLeg(
        cycleId: assignedWithCall.cycle.id,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('65.00'),
          expiration: DateTime.utc(2026, 8, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 6, 20),
          openCreditPerShare: Decimal.parse('0.90'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final open = await repo.getOpenCycles();

      // Ascending by startedAt, the closed one absent, both `holdingShares`
      // cycles present, and the two `sellingPuts` cycles in order — even
      // though the closed cycle sits between them by startedAt.
      expect(open.map((c) => c.id), [
        olderOpen.id,
        assignedNoLeg.cycle.id,
        newerOpen.id,
        assignedWithCall.cycle.id,
      ]);
      expect(open.any((c) => c.id == closedCycle.id), isFalse);
      expect(
        open.map((c) => c.status),
        [
          WheelCycleStatus.sellingPuts,
          WheelCycleStatus.holdingShares,
          WheelCycleStatus.sellingPuts,
          WheelCycleStatus.holdingShares,
        ],
      );
      // Cross-underlying, not just the first underlying's cycles.
      expect(open.map((c) => c.underlyingId).toSet(), {first.id, second.id});
      // The D-P12 case, stated directly: the `holdingShares` cycle whose only
      // call was closed early has no open leg at all, yet it is listed —
      // which is exactly what a `getAllLegs()`-grouping implementation would
      // miss. Its sibling, whose call is still open, has one.
      expect(await repo.getOpenLegs(), hasLength(3));
      expect(
        (await repo.getOpenLegs()).any((l) => l.cycleId == assignedNoLeg.cycle.id),
        isFalse,
      );
      expect(
        (await repo.getOpenLegs()).any((l) => l.cycleId == assignedWithCall.cycle.id),
        isTrue,
      );
    });

    test('S-258: an all-closed book returns nothing', () async {
      expect(await repo.getOpenCycles(), isEmpty);

      final underlying = await repo.getOrCreateUnderlying('AAA');
      final created = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45.00'),
          expiration: DateTime.utc(2026, 5, 15),
          contracts: 1,
          openedAt: DateTime.utc(2026, 4, 1),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      expect((await repo.getOpenCycles()).map((c) => c.id), [created.cycle.id]);

      await repo.closeLeg(
        legId: created.leg.id,
        reason: CloseReason.expiredWorthless,
        closedAt: DateTime.utc(2026, 5, 15),
      );

      expect(await repo.getOpenCycles(), isEmpty);
    });
  });

  group('Entitlement cache (Pro Wave 2, schema v6, D-25)', () {
    test('S-256: a fresh repository reports the free tier, never checked', () async {
      expect(await repo.getEntitlementCache(), const EntitlementCacheData());
      expect(EntitlementCacheDefaults.checkedAt, isNull);
      expect(EntitlementCacheDefaults.planKindName, ProPlanKind.none.name);
    });

    test('S-256: an active subscription round trips, then is replaced in place — '
        'never appended', () async {
      final saved = await repo.saveEntitlementCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 1, 1),
          willRenew: true,
          billingIssue: false,
          purchasedAt: DateTime.utc(2026, 1, 1),
          checkedAt: DateTime.utc(2026, 6, 1),
        ),
      );
      expect(saved.planKind, ProPlanKind.annual);

      final reread = await repo.getEntitlementCache();
      expect(reread.isActive, isTrue);
      expect(reread.planKind, ProPlanKind.annual);
      expect(reread.expiresAt, DateTime.utc(2027, 1, 1));
      expect(reread.willRenew, isTrue);
      expect(reread.billingIssue, isFalse);
      expect(reread.purchasedAt, DateTime.utc(2026, 1, 1));
      expect(reread.checkedAt, DateTime.utc(2026, 6, 1));

      // A second write replaces the one row: the fields the new value does
      // not set are genuinely cleared, not merged from the old row, and
      // `getEntitlementCache` still resolves — both the read and the write
      // address the row by its one fixed id, so there is never a second row
      // to choose between.
      await repo.saveEntitlementCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.monthly,
          checkedAt: DateTime.utc(2026, 7, 1),
        ),
      );
      final replaced = await repo.getEntitlementCache();
      expect(replaced.planKind, ProPlanKind.monthly);
      expect(replaced.expiresAt, isNull);
      expect(replaced.willRenew, isFalse);
      expect(replaced.purchasedAt, isNull);
      expect(replaced.checkedAt, DateTime.utc(2026, 7, 1));
    });

    test('S-256: lifetime carries no expiry, and a failed check keeps the last '
        'successful read', () async {
      await repo.saveEntitlementCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.lifetime,
          purchasedAt: DateTime.utc(2026, 2, 1),
          checkedAt: DateTime.utc(2026, 6, 1),
        ),
      );

      final lifetime = await repo.getEntitlementCache();
      expect(lifetime.planKind, ProPlanKind.lifetime);
      expect(lifetime.expiresAt, isNull);
      expect(lifetime.isActive, isTrue);

      // D-26: a failed store read writes nothing, so the previous successful
      // read — including its `checkedAt` — is what a caller still sees. This
      // is the state-layer contract; here it pins that the repository holds
      // exactly what was last saved, with no derivation of its own.
      expect((await repo.getEntitlementCache()).checkedAt, DateTime.utc(2026, 6, 1));
    });
  });
}

/// Builds a [NewRuleProfileVersionInput] at the §4.4 defaults, overriding
/// [profitTargetPct] (and nothing else) when a test needs one version's
/// values to be distinguishable from its neighbours'.
NewRuleProfileVersionInput _versionInput({
  double profitTargetPct = StandardProfileDefaults.profitTargetPct,
}) => NewRuleProfileVersionInput(
      profitTargetPct: profitTargetPct,
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
