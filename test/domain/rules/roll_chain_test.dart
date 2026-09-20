import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/rules/roll_chain.dart';

Leg _leg({
  required String id,
  required int sequence,
  required Decimal openCredit,
  Decimal? closeDebit,
  String? rolledFromLegId,
  DateTime? closedAt,
}) =>
    Leg(
      id: id,
      cycleId: 'cycle-1',
      sequence: sequence,
      optionType: OptionType.put,
      strike: Decimal.parse('45.00'),
      expiration: DateTime.utc(2026, 6, 19),
      contracts: 1,
      openedAt: DateTime.utc(2026, 1, 1),
      openCreditPerShare: openCredit,
      closedAt: closedAt,
      closeDebitPerShare: closeDebit,
      closeReason: closeDebit != null ? CloseReason.rolled : null,
      rolledFromLegId: rolledFromLegId,
      ruleProfileVersionId: 'rule-profile-standard-v1',
    );

void main() {
  group(
    'S-013: roll chain cumulative credit across three legs, including a debit roll '
    '(required test #9)',
    () {
      final leg0 = _leg(
        id: 'leg-0',
        sequence: 0,
        openCredit: Decimal.parse('1.00'),
        closeDebit: Decimal.parse('1.20'),
        closedAt: DateTime.utc(2026, 1, 15),
      );
      final leg1 = _leg(
        id: 'leg-1',
        sequence: 1,
        openCredit: Decimal.parse('0.90'),
        closeDebit: Decimal.parse('0.30'),
        rolledFromLegId: 'leg-0',
        closedAt: DateTime.utc(2026, 2, 1),
      );
      final leg2 = _leg(
        id: 'leg-2',
        sequence: 2,
        openCredit: Decimal.parse('0.50'),
        rolledFromLegId: 'leg-1',
      );

      test('legNetCredit per leg', () {
        expect(legNetCredit(leg0), Decimal.parse('-0.20'));
        expect(legNetCredit(leg1), Decimal.parse('0.60'));
        expect(legNetCredit(leg2), Decimal.parse('0.50')); // still open -> closeDebit 0
      });

      test('cycleCumulativeCredit = -0.20 + 0.60 + 0.50 = 0.90', () {
        expect(cycleCumulativeCredit([leg0, leg1, leg2]), Decimal.parse('0.90'));
      });

      test(
        'cycleTotalPremium contract-weights each leg independently (Feature Invariant 25) -- '
        'every leg here shares contracts=1, so this coincides with cycleCumulativeCredit x 100 x 1, '
        'the varying-contracts case is pinned separately by S-105',
        () {
          expect(cycleTotalPremium([leg0, leg1, leg2]), Decimal.parse('90.00'));
        },
      );

      test(
        'netRollCredit for the Leg0->Leg1 pair = 0.90 - 1.20 = -0.30 '
        '(a debit roll -- must never be displayed as income)',
        () {
          final net = netRollCredit(leg0, leg1);
          expect(net, Decimal.parse('-0.30'));
          expect(net < Decimal.zero, isTrue);
        },
      );
    },
  );
}
