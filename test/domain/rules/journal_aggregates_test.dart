import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/rules/journal_aggregates.dart';

Leg _closedLeg({
  required String id,
  required Decimal openCreditPerShare,
  required Decimal closeDebitPerShare,
}) => Leg(
  id: id,
  cycleId: 'cycle-1',
  sequence: 0,
  optionType: OptionType.put,
  strike: Decimal.parse('50.00'),
  expiration: DateTime.utc(2026, 6, 19),
  contracts: 1,
  openedAt: DateTime.utc(2026, 1, 1),
  openCreditPerShare: openCreditPerShare,
  closedAt: DateTime.utc(2026, 1, 20),
  closeDebitPerShare: closeDebitPerShare,
  closeReason: CloseReason.closedEarly,
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

void main() {
  test(
    'S-110: average premium capture is a median, table-driven -- '
    'expired worthless (100%), debit roll (-50%), profit-target close (50%) -> median 50%, '
    'the bare mean (33.3%) failing this test is the point (Feature Invariant 29)',
    () {
      final legA = _closedLeg(
        id: 'a',
        openCreditPerShare: Decimal.parse('0.50'),
        closeDebitPerShare: Decimal.zero,
      ); // 100%
      final legB = _closedLeg(
        id: 'b',
        openCreditPerShare: Decimal.parse('0.40'),
        closeDebitPerShare: Decimal.parse('0.60'),
      ); // -50%
      final legC = _closedLeg(
        id: 'c',
        openCreditPerShare: Decimal.parse('0.60'),
        closeDebitPerShare: Decimal.parse('0.30'),
      ); // 50%

      expect(legPremiumCapturePct(legA), Decimal.parse('100'));
      expect(legPremiumCapturePct(legB), Decimal.parse('-50'));
      expect(legPremiumCapturePct(legC), Decimal.parse('50'));

      final median = medianPremiumCapturePct([legA, legB, legC]);
      expect(median, 50.0);
      // The bare arithmetic mean (100 - 50 + 50) / 3 = 33.3(3)% must NOT be
      // what this aggregate reports.
      expect(median, isNot(closeTo(33.3, 0.5)));
    },
  );

  test('S-111: net result by underlying -- no cross-contamination', () {
    final result = netResultByUnderlying([
      (ticker: 'AAA', netResult: Decimal.parse('100')),
      (ticker: 'AAA', netResult: Decimal.parse('50')),
      (ticker: 'BBB', netResult: Decimal.parse('-30')),
    ]);
    expect(result['AAA'], Decimal.parse('150'));
    expect(result['BBB'], Decimal.parse('-30'));
    expect(result.length, 2);
  });

  test('S-112: roll-count distribution -- one cycle in each of the 0/1/2 buckets', () {
    final distribution = rollCountDistribution([0, 1, 2]);
    expect(distribution, {0: 1, 1: 1, 2: 1});
  });

  test(
    'S-113: win rate -- exactly-zero net result is not a win (literal > 0 per §4.4), '
    'win rate is 1/3, not 2/3',
    () {
      final rate = winRate([Decimal.parse('50'), Decimal.zero, Decimal.parse('-20')]);
      expect(rate, closeTo(1 / 3, 1e-9));
    },
  );
}
