import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/share_lot.dart';
import 'package:wheel_triage/domain/rules/basis.dart';
import 'package:wheel_triage/domain/rules/cycle_pnl.dart';
import 'package:wheel_triage/domain/rules/roll_chain.dart';
import 'package:wheel_triage/domain/rules/screener.dart' show screenerAnnualisedYield;

Leg _leg({
  required String id,
  required int sequence,
  required OptionType optionType,
  required Decimal strike,
  required int contracts,
  required DateTime openedAt,
  required Decimal openCreditPerShare,
  DateTime? closedAt,
  Decimal? closeDebitPerShare,
  CloseReason? closeReason,
  String? rolledFromLegId,
  Decimal? openFee,
  Decimal? closeFee,
}) => Leg(
  id: id,
  cycleId: 'cycle-1',
  sequence: sequence,
  optionType: optionType,
  strike: strike,
  expiration: openedAt.add(const Duration(days: 30)),
  contracts: contracts,
  openedAt: openedAt,
  openCreditPerShare: openCreditPerShare,
  closedAt: closedAt,
  closeDebitPerShare: closeDebitPerShare,
  closeReason: closeReason,
  rolledFromLegId: rolledFromLegId,
  ruleProfileVersionId: 'rule-profile-standard-v1',
  openFee: openFee,
  closeFee: closeFee,
);

void main() {
  group(
    'S-104: full-wheel cycle P&L, uniform contracts (2) throughout '
    '(§9 required test #5, literal)',
    () {
      // Dates chosen so daysHeld == 73 (365 / 73 == 5 exactly), keeping the
      // annualised-return arithmetic clean and hand-checkable.
      final startedAt = DateTime.utc(2026, 1, 1);
      final leg0OpenedAt = startedAt;
      final leg0ClosedAt = DateTime.utc(2026, 1, 21); // rolled -> Leg1, 20 days
      final leg1ClosedAt = DateTime.utc(2026, 2, 10); // rolled -> Leg2, 20 days
      final leg2ClosedAt = DateTime.utc(2026, 3, 2); // assigned, 20 days
      final endedAt = DateTime.utc(2026, 3, 15); // called away, 13 days -> 73 total

      final leg0 = _leg(
        id: 'leg-0',
        sequence: 0,
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        contracts: 2,
        openedAt: leg0OpenedAt,
        openCreditPerShare: Decimal.parse('0.60'),
        openFee: Decimal.parse('1.30'),
        closedAt: leg0ClosedAt,
        closeDebitPerShare: Decimal.parse('0.80'), // a net debit roll
        closeReason: CloseReason.rolled,
        closeFee: Decimal.parse('1.30'),
      );
      final leg1 = _leg(
        id: 'leg-1',
        sequence: 1,
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        contracts: 2,
        openedAt: leg0ClosedAt,
        openCreditPerShare: Decimal.parse('0.35'),
        rolledFromLegId: 'leg-0',
        closedAt: leg1ClosedAt,
        closeDebitPerShare: Decimal.parse('0.20'),
        closeReason: CloseReason.rolled,
        closeFee: Decimal.parse('1.30'),
      );
      final leg2 = _leg(
        id: 'leg-2',
        sequence: 2,
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        contracts: 2,
        openedAt: leg1ClosedAt,
        openCreditPerShare: Decimal.parse('0.90'),
        rolledFromLegId: 'leg-1',
        closedAt: leg2ClosedAt,
        closeReason: CloseReason.assigned, // no buyback debit on assignment
        closeFee: Decimal.zero, // explicitly $0, not "not recorded"
      );
      final shareLot = ShareLot(
        id: 'lot-1',
        cycleId: 'cycle-1',
        assignedAt: leg2ClosedAt,
        assignmentStrike: Decimal.parse('50'),
        contracts: 2,
      );
      final leg3 = _leg(
        id: 'leg-3',
        sequence: 3,
        optionType: OptionType.call,
        strike: Decimal.parse('52'),
        contracts: 2,
        openedAt: leg2ClosedAt,
        openCreditPerShare: Decimal.parse('0.55'),
        openFee: Decimal.parse('1.30'),
        closedAt: endedAt,
        closeReason: CloseReason.assigned, // called away, no buyback debit
        closeFee: Decimal.zero,
      );
      final legs = [leg0, leg1, leg2, leg3];

      test('totalPremium: Σ(legNetCredit x 100 x contracts) across all 4 legs', () {
        // Per-share net credits: leg0 0.60-0.80=-0.20, leg1 0.35-0.20=0.15,
        // leg2 0.90-0=0.90, leg3 0.55-0=0.55 -> sum 1.40 -> x100x2 = $280.00.
        expect(cycleTotalPremium(legs), Decimal.parse('280.00'));
      });

      test('totalFees: every recorded openFee/closeFee, closed legs\' null fees never coerced', () {
        // leg0: 1.30 + 1.30; leg1: 0 (openFee not recorded) + 1.30;
        // leg2: 0 + 0 (explicit); leg3: 1.30 + 0 (explicit) = $5.20.
        expect(totalFees(legs), Decimal.parse('5.20'));
      });

      test('stockPnL: (callStrike - assignmentStrike) x 100 x the called-away leg\'s own contracts', () {
        expect(
          stockPnL(assignedPutLeg: assignedPutLeg(legs), calledAwayCallLeg: calledAwayCallLeg(legs)),
          Decimal.parse('400.00'), // (52-50) x 100 x 2
        );
      });

      test('netResult = totalPremium - totalFees + stockPnL = 280.00 - 5.20 + 400.00 = 674.80', () {
        expect(
          netResult(legs: legs, assignedPutLeg: assignedPutLeg(legs), calledAwayCallLeg: calledAwayCallLeg(legs)),
          Decimal.parse('674.80'),
        );
      });

      test('daysHeld and rollCount', () {
        final pnl = computeCyclePnl(
          legs: legs,
          shareLot: shareLot,
          startedAt: startedAt,
          endedAt: endedAt,
          now: endedAt, // closed cycle -- `now` is unused, but always passed
        );
        expect(pnl.daysHeld, 73);
        expect(pnl.rollCount, 2); // leg1 and leg2 both rolled-from
      });

      test(
        'peakCapitalCommitted, returnOnCapital, journalAnnualisedReturn '
        '(computed against this fixture\'s own peak, S-109 pins the figure in isolation)',
        () {
          final pnl = computeCyclePnl(
            legs: legs,
            shareLot: shareLot,
            startedAt: startedAt,
            endedAt: endedAt,
            now: endedAt,
          );
          // Every put leg commits $50 x 100 x 2 = $10,000; the post-
          // assignment wheelBasis (49.15) x 100 x 2 = $9,830 is lower, so
          // the peak stays $10,000.
          expect(pnl.peakCapitalCommitted, Decimal.parse('10000.00'));
          expect(pnl.returnOnCapitalPct, closeTo(6.748, 1e-9)); // 674.80 / 10000 x 100
          expect(pnl.annualisedReturnPct, closeTo(33.74, 1e-9)); // 6.748 x (365/73)
          expect(pnl.annualisedReturnNote, isNull);
        },
      );
    },
  );

  group(
    'S-105: contract-count change across a roll -- the fourth formula error\'s '
    'pinned fixture (1 contract rolled into 3, assigned)',
    () {
      final openedAt = DateTime.utc(2026, 1, 1);
      final rolledAt = DateTime.utc(2026, 1, 15);
      final assignedAt = DateTime.utc(2026, 2, 1);

      final leg0 = _leg(
        id: 'leg-0',
        sequence: 0,
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        contracts: 1,
        openedAt: openedAt,
        openCreditPerShare: Decimal.parse('0.60'),
        closedAt: rolledAt,
        closeDebitPerShare: Decimal.zero, // an even roll -- isolates the contract-count defect
        closeReason: CloseReason.rolled,
      );
      final leg1 = _leg(
        id: 'leg-1',
        sequence: 1,
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        contracts: 3,
        openedAt: rolledAt,
        openCreditPerShare: Decimal.parse('0.40'),
        rolledFromLegId: 'leg-0',
        closedAt: assignedAt,
        closeReason: CloseReason.assigned,
      );
      final putLegs = [leg0, leg1];
      final shareLot = ShareLot(
        id: 'lot-1',
        cycleId: 'cycle-1',
        assignedAt: assignedAt,
        assignmentStrike: Decimal.parse('50'),
        contracts: 3, // -> 300 shares
      );

      test(
        'totalPremium = Σ(legNetCredit x 100 x contracts) = \$60 + \$120 = \$180 '
        '-- NOT \$1.00 x 100 x 3 = \$300, NOT \$1.00 x 100 x 1 = \$100',
        () {
          final total = cycleTotalPremium(putLegs);
          expect(total, Decimal.parse('180.00'));
          expect(total, isNot(Decimal.parse('300.00')));
          expect(total, isNot(Decimal.parse('100.00')));
        },
      );

      test(
        'wheelBasis = 50.00 - (180/300) = 50.00 - 0.60 = \$49.40 per share '
        '-- NOT 50.00 - 1.00 = \$49.00 (the naive unweighted-per-share defect)',
        () {
          final basis = wheelBasis(putLegs: putLegs, shareLot: shareLot, callLegsSinceAssignment: const []);
          expect(basis, Decimal.parse('49.40'));
          expect(basis, isNot(Decimal.parse('49.00')));
        },
      );
    },
  );

  test('S-107: daysHeld == 0 guards against division by zero, returns an un-annualised note', () {
    final result = journalAnnualisedReturn(
      netResult: Decimal.parse('50.00'),
      peakCapitalCommitted: Decimal.parse('5000.00'),
      daysHeld: 0,
    );
    expect(result.annualisedReturnPct, isNull);
    expect(result.note, 'Same-day close -- return not annualised');
    expect(result.returnOnCapitalPct, closeTo(1.0, 1e-9)); // 50 / 5000 x 100
  });

  test(
    'S-108: journalAnnualisedReturn (wheel-basis-anchored) and screenerAnnualisedYield '
    '(strike-denominated) legitimately differ on the same trade -- computed from different bases '
    'on purpose, not by accident',
    () {
      // A closed cycle: put sold, assigned, one call, called away.
      final openedAt = DateTime.utc(2026, 1, 1);
      final assignedAt = DateTime.utc(2026, 1, 31); // 30 days
      final endedAt = DateTime.utc(2026, 3, 2); // +30 more days, 60 total

      final putLeg = _leg(
        id: 'put-0',
        sequence: 0,
        optionType: OptionType.put,
        strike: Decimal.parse('40'),
        contracts: 1,
        openedAt: openedAt,
        openCreditPerShare: Decimal.parse('1.00'),
        closedAt: assignedAt,
        closeReason: CloseReason.assigned,
      );
      final shareLot = ShareLot(
        id: 'lot-1',
        cycleId: 'cycle-1',
        assignedAt: assignedAt,
        assignmentStrike: Decimal.parse('40'),
        contracts: 1,
      );
      final callLeg = _leg(
        id: 'call-0',
        sequence: 1,
        optionType: OptionType.call,
        strike: Decimal.parse('42'),
        contracts: 1,
        openedAt: assignedAt,
        openCreditPerShare: Decimal.parse('0.50'),
        closedAt: endedAt,
        closeReason: CloseReason.assigned,
      );
      final legs = [putLeg, callLeg];

      final pnl = computeCyclePnl(
        legs: legs,
        shareLot: shareLot,
        startedAt: openedAt,
        endedAt: endedAt,
        now: endedAt,
      );
      // totalPremium = (1.00 + 0.50) x 100 x 1 = $150; stockPnL = (42-40) x 100 = $200;
      // netResult = $350; peakCapitalCommitted = max(40x100x1, taxBasis-basis...) = $4,000 (put strike).
      expect(pnl.netResult, Decimal.parse('350.00'));
      expect(pnl.peakCapitalCommitted, Decimal.parse('4000.00'));
      expect(pnl.returnOnCapitalPct, closeTo(8.75, 1e-9)); // 350/4000 x 100

      final screenerYield = screenerAnnualisedYield(
        credit: putLeg.openCreditPerShare,
        strike: putLeg.strike,
        dteAtOpen: 30,
      );
      // screenerAnnualisedYield: (1.00/40) x (365/30) x 100 ≈ 30.42%.
      expect(screenerYield, closeTo(30.4166666, 1e-4));

      // The two numbers are computed from genuinely different bases and
      // legitimately disagree on the same trade -- that disagreement is the
      // point of this scenario, not a bug in either function.
      expect(pnl.returnOnCapitalPct, isNot(closeTo(screenerYield, 1)));
    },
  );

  test(
    'S-109: "peak capital committed" -- multi-strike roll chain, the highest put-side '
    'strike in the chain wins, not the assignment strike or the post-assignment wheel basis',
    () {
      final openedAt = DateTime.utc(2026, 1, 1);
      // Per-share net credits (0.60, 0.50, 0.40) are chosen so the roll
      // chain's contract-weighted total, divided across the 200 shares the
      // 2-contract assignment creates, lands exactly on the scenario's own
      // pinned $46.50 wheel basis: (0.60+0.50+0.40) x 100 x 2 / 200 = $1.50
      // per share; $48.00 (Leg2's strike) - $1.50 = $46.50.
      final leg0 = _leg(
        id: 'leg-0',
        sequence: 0,
        optionType: OptionType.put,
        strike: Decimal.parse('50'),
        contracts: 2,
        openedAt: openedAt,
        openCreditPerShare: Decimal.parse('0.70'),
        closedAt: openedAt.add(const Duration(days: 10)),
        closeDebitPerShare: Decimal.parse('0.10'),
        closeReason: CloseReason.rolled,
      );
      final leg1 = _leg(
        id: 'leg-1',
        sequence: 1,
        optionType: OptionType.put,
        strike: Decimal.parse('45'), // strike moved down
        contracts: 2,
        openedAt: leg0.closedAt!,
        openCreditPerShare: Decimal.parse('0.60'),
        rolledFromLegId: 'leg-0',
        closedAt: openedAt.add(const Duration(days: 20)),
        closeDebitPerShare: Decimal.parse('0.10'),
        closeReason: CloseReason.rolled,
      );
      final leg2 = _leg(
        id: 'leg-2',
        sequence: 2,
        optionType: OptionType.put,
        strike: Decimal.parse('48'),
        contracts: 2,
        openedAt: leg1.closedAt!,
        openCreditPerShare: Decimal.parse('0.40'),
        rolledFromLegId: 'leg-1',
        closedAt: openedAt.add(const Duration(days: 30)),
        closeReason: CloseReason.assigned,
      );
      final putLegs = [leg0, leg1, leg2];
      final shareLot = ShareLot(
        id: 'lot-1',
        cycleId: 'cycle-1',
        assignedAt: leg2.closedAt!,
        assignmentStrike: Decimal.parse('48'),
        contracts: 2,
      );

      // wheelBasis after assignment is pinned by the scenario at $46.50 --
      // verified here directly from the same leg history so the fixture's
      // internal consistency is auditable, not just asserted by fiat.
      final basis = wheelBasis(putLegs: putLegs, shareLot: shareLot, callLegsSinceAssignment: const []);
      expect(basis, Decimal.parse('46.50'));

      final peak = peakCapitalCommitted(putLegs: putLegs, shareLot: shareLot);
      // max($50x100x2, $45x100x2, $48x100x2, $46.50x100x2)
      // = max($10000, $9000, $9600, $9300) = $10000.
      expect(peak, Decimal.parse('10000'));
    },
  );
}
