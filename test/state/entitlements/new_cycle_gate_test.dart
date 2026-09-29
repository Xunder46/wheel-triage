import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/entitlements/new_cycle_gate.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_purchase_gateway.dart';

final _now = DateTime(2026, 10, 1, 10);

/// Counts the gate's only observable side effect — the book read — so
/// "the gate is consulted" (S-259) and "the gate is never called"
/// (S-261/S-262/S-263) are assertions rather than claims.
class _CountingRepository extends InMemoryWheelRepository {
  int openCycleReads = 0;

  @override
  Future<List<WheelCycle>> getOpenCycles() {
    openCycleReads++;
    return super.getOpenCycles();
  }
}

/// [count] open `sellingPuts` cycles, one per distinct ticker.
Future<List<Leg>> _openCycles(_CountingRepository repo, int count) async {
  final legs = <Leg>[];
  for (var i = 0; i < count; i++) {
    final underlying = await repo.getOrCreateUnderlying('T$i');
    final result = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('30'),
        expiration: _now.add(const Duration(days: 30)),
        contracts: 1,
        openedAt: _now,
        openCreditPerShare: Decimal.parse('1.00'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    legs.add(result.leg);
  }
  return legs;
}

void main() {
  late _CountingRepository repo;
  late FakePurchaseGateway gateway;
  late ProviderContainer container;

  setUp(() {
    repo = _CountingRepository();
    gateway = FakePurchaseGateway();
    container = ProviderContainer(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        purchaseGatewayProvider.overrideWithValue(gateway),
      ],
    );
    container.listen(entitlementControllerProvider, (previous, next) {});
    addTearDown(container.dispose);
  });

  Future<void> entitle(EntitlementSnapshot snapshot) async {
    gateway.snapshot = snapshot;
    await container.read(entitlementControllerProvider.notifier).initialize();
  }

  NewCycleGate gate() => container.read(newCycleGateProvider);

  test('S-259: three open cycles and an active Pro entitlement is allowed, '
      'and the book is still read', () async {
    await _openCycles(repo, 3);
    await entitle(
      EntitlementSnapshot.active(
        planKind: ProPlanKind.annual,
        expiresAt: DateTime(2027, 10, 1),
        willRenew: true,
      ),
    );

    final decision = await gate().evaluate();

    expect(decision, isA<NewCycleAllowed>());
    expect(repo.openCycleReads, 1);
  });

  test('S-260: three open cycles and no entitlement is blocked with the '
      "at-the-limit line, the limit's own count substituted", () async {
    await _openCycles(repo, 3);
    await entitle(const EntitlementSnapshot.inactive());

    final decision = await gate().evaluate();

    expect(decision, isA<NewCycleBlocked>());
    final blocked = decision as NewCycleBlocked;
    expect(blocked.openCycleCount, 3);
    expect(
      blocked.line,
      'You have 3 open cycles, the free plan\'s limit, so recording a fourth '
      'needs Pro. Everything you\'ve already recorded stays available on '
      'every plan.',
    );
  });

  test('S-260: an unknown entitlement behaves exactly as free', () async {
    await _openCycles(repo, 3);
    await entitle(const EntitlementSnapshot.unknown());

    final decision = await gate().evaluate();

    expect(decision, isA<NewCycleBlocked>());
    expect((decision as NewCycleBlocked).openCycleCount, 3);
  });

  test('S-264: below the limit a free user is allowed — the boundary is 3, '
      'not 2', () async {
    await _openCycles(repo, 2);
    await entitle(const EntitlementSnapshot.inactive());

    expect(await gate().evaluate(), isA<NewCycleAllowed>());
  });

  test('S-264: closing a cycle frees a slot immediately', () async {
    final legs = await _openCycles(repo, 3);
    await entitle(const EntitlementSnapshot.inactive());
    expect(await gate().evaluate(), isA<NewCycleBlocked>());

    await repo.closeLeg(
      legId: legs.first.id,
      reason: CloseReason.closedEarly,
      closeDebitPerShare: Decimal.parse('0.10'),
      closedAt: _now,
    );

    expect(await gate().evaluate(), isA<NewCycleAllowed>());
  });

  test('S-268: past the limit the line names both counts', () async {
    await _openCycles(repo, 5);
    await entitle(const EntitlementSnapshot.inactive());

    final decision = await gate().evaluate();

    expect(decision, isA<NewCycleBlocked>());
    final blocked = decision as NewCycleBlocked;
    expect(blocked.openCycleCount, 5);
    expect(
      blocked.line,
      'You have 5 open cycles, past the free plan\'s limit of 3, so recording '
      'another needs Pro. Everything you\'ve already recorded stays available '
      'on every plan.',
    );
  });

  test('S-268: the same five cycles are allowed again the moment Pro is back '
      'on, with no data change', () async {
    await _openCycles(repo, 5);
    await entitle(const EntitlementSnapshot.inactive());
    expect(await gate().evaluate(), isA<NewCycleBlocked>());

    gateway.snapshot = const EntitlementSnapshot.active(planKind: ProPlanKind.annual);
    await container.read(entitlementControllerProvider.notifier).refresh();

    expect(await gate().evaluate(), isA<NewCycleAllowed>());
  });

  test('the free tier is the default: a never-initialised controller is free',
      () async {
    await _openCycles(repo, 3);

    expect(await gate().evaluate(), isA<NewCycleBlocked>());
  });

  test('the limit is read from the one constant, not a literal', () async {
    await _openCycles(repo, kFreeTierOpenCycles);
    await entitle(const EntitlementSnapshot.inactive());

    expect(await gate().evaluate(), isA<NewCycleBlocked>());
  });

  test('S-261: three open cycles and a roll — the gate is never consulted', () async {
    final legs = await _openCycles(repo, 3);
    await entitle(const EntitlementSnapshot.inactive());
    final before = await repo.getOpenCycles();

    final rolled = await repo.recordRoll(
      closingLegId: legs.first.id,
      closeDebitPerShare: Decimal.parse('0.20'),
      closedAt: _now.add(const Duration(days: 5)),
      newLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('28'),
        expiration: _now.add(const Duration(days: 40)),
        contracts: 1,
        openedAt: _now.add(const Duration(days: 5)),
        openCreditPerShare: Decimal.parse('1.10'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    // One atomic two-write transition: the old leg closed as a roll, the new
    // one chained to it, and the cycle count unchanged.
    expect(rolled.closedLeg.closeReason, CloseReason.rolled);
    expect(rolled.newLeg.rolledFromLegId, legs.first.id);
    expect(await repo.getOpenCycles(), hasLength(before.length));
    expect(
      repo.openCycleReads,
      2,
      reason: 'the two book reads this test made, and nothing the roll did',
    );
  });

  test('S-262: three open cycles and an assignment — the gate is never consulted', () async {
    final legs = await _openCycles(repo, 3);
    await entitle(const EntitlementSnapshot.inactive());
    final before = await repo.getOpenCycles();

    final assigned = await repo.recordAssignment(
      legId: legs.first.id,
      shareLot: NewShareLotInput(
        assignedAt: _now.add(const Duration(days: 30)),
        assignmentStrike: Decimal.parse('30'),
        contracts: 1,
      ),
    );

    expect(assigned.leg.closeReason, CloseReason.assigned);
    expect(assigned.cycle.status, WheelCycleStatus.holdingShares);
    expect(await repo.getShareLotForCycle(assigned.cycle.id), isNotNull);
    expect(await repo.getOpenCycles(), hasLength(before.length));
    expect(
      repo.openCycleReads,
      2,
      reason: 'the two book reads this test made, and nothing the assignment did',
    );
  });
}
