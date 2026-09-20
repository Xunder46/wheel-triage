import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/share_lot.dart';
import 'package:wheel_triage/domain/rules/basis.dart';

Leg _putLeg({
  required String id,
  required int sequence,
  required int contracts,
  required Decimal openCreditPerShare,
  Decimal? closeDebitPerShare,
  DateTime? closedAt,
  CloseReason? closeReason,
  String? rolledFromLegId,
}) => Leg(
  id: id,
  cycleId: 'cycle-1',
  sequence: sequence,
  optionType: OptionType.put,
  strike: Decimal.parse('50.00'),
  expiration: DateTime.utc(2026, 6, 19),
  contracts: contracts,
  openedAt: DateTime.utc(2026, 1, 1),
  openCreditPerShare: openCreditPerShare,
  closedAt: closedAt,
  closeDebitPerShare: closeDebitPerShare,
  closeReason: closeReason,
  rolledFromLegId: rolledFromLegId,
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

Leg _callLeg({
  required String id,
  required int sequence,
  required int contracts,
  required Decimal openCreditPerShare,
}) => Leg(
  id: id,
  cycleId: 'cycle-1',
  sequence: sequence,
  optionType: OptionType.call,
  strike: Decimal.parse('55.00'),
  expiration: DateTime.utc(2026, 7, 17),
  contracts: contracts,
  openedAt: DateTime.utc(2026, 2, 1),
  openCreditPerShare: openCreditPerShare,
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

void main() {
  // Supersedes the original S-014 test, which asserted `wheelBasis`/
  // `taxBasis` against S-014's own pre-summed-per-share signature
  // (`putPremiumReceived: Decimal`, `callCreditsSinceAssignment:
  // List<Decimal>`). That fixture was never wrong on its own terms -- it
  // used one contract throughout, where a per-share sum and a
  // contract-weighted sum coincide -- only the *signature* it exercised is
  // superseded now that the fix (Feature Invariant 25) requires the raw
  // `List<Leg>` + `ShareLot` to weight each leg by its own `contracts`.
  // Tracked here by a new id, never reusing S-014, per the S-041/S-042
  // precedent; this test's `--plain-name` tag is S-106, not S-014.
  group(
    'S-106: wheelBasis/taxBasis isolated unit test, contract-weighted '
    '(supersedes S-014)',
    () {
      // Same assignment as S-105: 1 contract at \$0.60/share rolled into 3
      // contracts at \$0.40/share, assigned -> 300 shares, \$180 total put
      // credit -> \$0.60/share -> taxBasis = 50.00 - 0.60 = \$49.40.
      final putLeg0 = _putLeg(
        id: 'put-0',
        sequence: 0,
        contracts: 1,
        openCreditPerShare: Decimal.parse('0.60'),
        closedAt: DateTime.utc(2026, 1, 15),
        closeDebitPerShare: Decimal.zero,
        closeReason: CloseReason.rolled,
      );
      final putLeg1 = _putLeg(
        id: 'put-1',
        sequence: 1,
        contracts: 3,
        openCreditPerShare: Decimal.parse('0.40'),
        rolledFromLegId: 'put-0',
        closedAt: DateTime.utc(2026, 2, 1),
        closeReason: CloseReason.assigned,
      );
      final putLegs = [putLeg0, putLeg1];
      final shareLot = ShareLot(
        id: 'lot-1',
        cycleId: 'cycle-1',
        assignedAt: DateTime.utc(2026, 2, 1),
        assignmentStrike: Decimal.parse('50.00'),
        contracts: 3,
      );

      test('taxBasis == \$49.40, unaffected by any covered calls', () {
        expect(taxBasis(putLegs: putLegs, shareLot: shareLot), Decimal.parse('49.40'));
      });

      test('wheelBasis immediately after assignment (no calls yet) == taxBasis == \$49.40', () {
        final wheel = wheelBasis(putLegs: putLegs, shareLot: shareLot, callLegsSinceAssignment: const []);
        expect(wheel, Decimal.parse('49.40'));
      });

      test(
        'after two covered calls at differing contract counts (call A: 2ct @ \$0.50 = \$100 total, '
        'call B: 1ct @ \$0.45 = \$45 total): wheelBasis = 49.40 - (145/300) = 49.40 - 0.483333 = '
        '\$48.916667, taxBasis stays \$49.40',
        () {
          final callA = _callLeg(id: 'call-a', sequence: 2, contracts: 2, openCreditPerShare: Decimal.parse('0.50'));
          final callB = _callLeg(id: 'call-b', sequence: 3, contracts: 1, openCreditPerShare: Decimal.parse('0.45'));

          final tax = taxBasis(putLegs: putLegs, shareLot: shareLot);
          final wheel = wheelBasis(
            putLegs: putLegs,
            shareLot: shareLot,
            callLegsSinceAssignment: [callA, callB],
          );

          expect(tax, Decimal.parse('49.40')); // unaffected by call premiums
          expect(wheel, Decimal.parse('48.916667'));
          expect(wheel == tax, isFalse); // the divergence is the test
        },
      );
    },
  );
}
