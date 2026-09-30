import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/domain/rules/capital_committed.dart' as capital;
import 'package:wheel_triage/domain/rules/rule_profile.dart';
import 'package:wheel_triage/state/book/book_reads.dart';

/// D-45's shared read: Portfolio and Today assemble their capital inputs the
/// same way, so the two screens cannot disagree about what the book commits.
///
/// The fixture is deliberately the shape that makes the extraction
/// observable: a `holdingShares` cycle with a share lot (the only status whose
/// lot is read) and a `sellingPuts` cycle whose lot must **not** be read.
void main() {
  final now = DateTime(2026, 9, 28);

  Future<InMemoryWheelRepository> book() async {
    final repo = InMemoryWheelRepository();

    final intc = await repo.getOrCreateUnderlying('INTC');
    await repo.createCycle(
      underlyingId: intc.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('20.00'),
        expiration: DateTime(2026, 10, 16),
        contracts: 4,
        openedAt: DateTime(2026, 9, 1),
        openCreditPerShare: Decimal.parse('0.50'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    // A `holdingShares` cycle: its lot is the book's, so it is read.
    final t = await repo.getOrCreateUnderlying('T');
    final tCycle = await repo.createCycle(
      underlyingId: t.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('28.00'),
        expiration: DateTime(2026, 9, 18),
        contracts: 1,
        openedAt: DateTime(2026, 8, 20),
        openCreditPerShare: Decimal.parse('1.00'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    await repo.recordAssignment(
      legId: tCycle.leg.id,
      closeFee: Decimal.zero,
      shareLot: NewShareLotInput(
        assignedAt: DateTime(2026, 9, 18),
        assignmentStrike: Decimal.parse('28.00'),
        contracts: 1,
      ),
    );

    return repo;
  }

  group('capitalInputsFor', () {
    test('one input per cycle, carrying the ticker and the cycle\'s own legs', () async {
      final repo = await book();
      final legs = await repo.getAllLegs();
      final inputs = await capitalInputsFor(repo, legs);

      expect(inputs.map((i) => i.ticker).toList()..sort(), ['INTC', 'T']);
      for (final input in inputs) {
        expect(input.legs, isNotEmpty);
        expect(input.legs.every((l) => l.cycleId == input.cycle.id), isTrue);
      }
    });

    test('the share lot is read only for a holdingShares cycle', () async {
      final repo = await book();
      final legs = await repo.getAllLegs();
      final inputs = await capitalInputsFor(repo, legs);

      final holding = inputs.singleWhere((i) => i.ticker == 'T');
      expect(holding.cycle.status, WheelCycleStatus.holdingShares);
      expect(holding.shareLot, isNotNull);
      expect(holding.shareLot!.contracts, 1);

      final selling = inputs.singleWhere((i) => i.ticker == 'INTC');
      expect(selling.cycle.status, WheelCycleStatus.sellingPuts);
      expect(selling.shareLot, isNull);
    });

    test('a leg whose cycle the repository does not know is skipped, not guessed at', () async {
      final repo = await book();
      final legs = await repo.getAllLegs();
      // A cycle the repository cannot resolve contributes nothing rather than
      // a fabricated ticker.
      final inputs = await capitalInputsFor(repo, [
        ...legs,
        legs.first.copyWith(cycleId: 'no-such-cycle'),
      ]);

      expect(inputs.map((i) => i.ticker).toList()..sort(), ['INTC', 'T']);
    });

    test('the inputs feed currentCapitalCommitted unchanged', () async {
      final repo = await book();
      final legs = await repo.getAllLegs();
      final inputs = await capitalInputsFor(repo, legs);

      // INTC 20.00 x 400 = 8,000; T's wheel basis 27.00 x 100 = 2,700.
      expect(capital.currentCapitalCommitted(inputs, now: now), Decimal.parse('10700'));
    });
  });

  group('profileForLeg', () {
    test('resolves the leg\'s pinned version, never the profile\'s current one', () async {
      final repo = await book();
      final legs = await repo.getAllLegs();
      final profile = await profileForLeg(repo, legs.first.ruleProfileVersionId);

      expect(profile.name, 'Standard');
    });

    test('a dangling pin degrades to the built-in defaults', () async {
      final repo = await book();
      final profile = await profileForLeg(repo, 'no-such-version');

      expect(profile, RuleProfile.standard);
    });
  });
}
