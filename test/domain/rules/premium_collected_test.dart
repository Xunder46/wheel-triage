import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/rules/premium_collected.dart';

/// S-223's fixture: the sample book's September, an August credit that must
/// stay out of the month, and a closed leg carrying a recorded fee that must
/// never move the figure.
Leg _leg({
  required String id,
  required OptionType optionType,
  required String openCreditPerShare,
  required int contracts,
  required DateTime openedAt,
  DateTime? closedAt,
  Decimal? closeDebitPerShare,
  Decimal? openFee,
  Decimal? closeFee,
  CloseReason? closeReason,
}) => Leg(
  id: id,
  cycleId: 'cycle-$id',
  sequence: 0,
  optionType: optionType,
  strike: Decimal.parse('20.00'),
  expiration: DateTime.utc(2026, 10, 16),
  contracts: contracts,
  openedAt: openedAt,
  openCreditPerShare: Decimal.parse(openCreditPerShare),
  closedAt: closedAt,
  closeDebitPerShare: closeDebitPerShare,
  closeReason: closeReason,
  ruleProfileVersionId: 'rule-profile-standard-v1',
  openFee: openFee,
  closeFee: closeFee,
);

void main() {
  final now = DateTime.utc(2026, 9, 28);

  group('S-223: netPremiumCollected -- a month and the year to date', () {
    final legs = <Leg>[
      // September credits.
      _leg(id: 'intc', optionType: OptionType.put, openCreditPerShare: '0.62', contracts: 4, openedAt: DateTime.utc(2026, 9, 4)),
      _leg(id: 'sofi', optionType: OptionType.put, openCreditPerShare: '0.41', contracts: 3, openedAt: DateTime.utc(2026, 9, 4)),
      _leg(id: 'f', optionType: OptionType.put, openCreditPerShare: '0.35', contracts: 2, openedAt: DateTime.utc(2026, 9, 11)),
      _leg(id: 't-call', optionType: OptionType.call, openCreditPerShare: '0.30', contracts: 1, openedAt: DateTime.utc(2026, 9, 11)),
      _leg(id: 'sbet-call', optionType: OptionType.call, openCreditPerShare: '0.35', contracts: 1, openedAt: DateTime.utc(2026, 9, 18)),
      _leg(id: 'pfe', optionType: OptionType.put, openCreditPerShare: '0.48', contracts: 1, openedAt: DateTime.utc(2026, 9, 18)),
      _leg(id: 'wbd', optionType: OptionType.put, openCreditPerShare: '0.27', contracts: 1, openedAt: DateTime.utc(2026, 9, 18)),
      _leg(id: 'aal', optionType: OptionType.put, openCreditPerShare: '0.29', contracts: 2, openedAt: DateTime.utc(2026, 9, 25)),
      _leg(id: 'ccl', optionType: OptionType.put, openCreditPerShare: '0.40', contracts: 2, openedAt: DateTime.utc(2026, 9, 25)),
      // September buybacks.
      _leg(
        id: 'bac',
        optionType: OptionType.put,
        openCreditPerShare: '0.55',
        contracts: 1,
        openedAt: DateTime.utc(2026, 8, 7),
        closedAt: DateTime.utc(2026, 9, 4),
        closeDebitPerShare: Decimal.parse('0.28'),
        closeReason: CloseReason.closedEarly,
      ),
      _leg(
        id: 'ccl-close',
        optionType: OptionType.put,
        openCreditPerShare: '0.40',
        contracts: 2,
        openedAt: DateTime.utc(2026, 8, 14),
        closedAt: DateTime.utc(2026, 9, 11),
        closeDebitPerShare: Decimal.parse('0.55'),
        closeReason: CloseReason.rolled,
      ),
      _leg(
        id: 'ko',
        optionType: OptionType.put,
        openCreditPerShare: '0.30',
        contracts: 1,
        openedAt: DateTime.utc(2026, 8, 21),
        closedAt: DateTime.utc(2026, 9, 18),
        closeDebitPerShare: Decimal.parse('0.20'),
        closeReason: CloseReason.closedEarly,
      ),
      // An August credit: out of the month, inside the year.
      _leg(id: 'uber', optionType: OptionType.put, openCreditPerShare: '1.10', contracts: 1, openedAt: DateTime.utc(2026, 8, 7)),
      // A closed leg with a recorded fee that must not move the figure.
      _leg(
        id: 'fee-leg',
        optionType: OptionType.put,
        openCreditPerShare: '0.00',
        contracts: 1,
        openedAt: DateTime.utc(2026, 9, 4),
        closedAt: DateTime.utc(2026, 9, 4),
        closeDebitPerShare: Decimal.zero,
        closeReason: CloseReason.expiredWorthless,
        openFee: Decimal.parse('1.30'),
        closeFee: Decimal.parse('1.30'),
      ),
      // An assigned leg: no close debit recorded, so no buyback.
      _leg(
        id: 'assigned',
        optionType: OptionType.put,
        openCreditPerShare: '0.50',
        contracts: 1,
        openedAt: DateTime.utc(2026, 8, 7),
        closedAt: DateTime.utc(2026, 9, 18),
        closeReason: CloseReason.assigned,
      ),
    ];

    test(r'September 2026 = $719 - $158 = $561', () {
      final net = netPremiumCollected(
        legs: legs,
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 9, 30),
      );
      expect(net, Decimal.parse('561'));
    });

    test(r'the credits side alone is $719', () {
      expect(
        premiumCredits(
          legs: legs,
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 30),
        ),
        Decimal.parse('719'),
      );
    });

    test(r'the buybacks side alone is $158', () {
      expect(
        premiumBuybacks(
          legs: legs,
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 30),
        ),
        Decimal.parse('158'),
      );
    });

    test('fees are never subtracted', () {
      final withFees = netPremiumCollected(
        legs: legs,
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 9, 30),
      );
      final withoutFeeLeg = netPremiumCollected(
        legs: legs.where((l) => l.id != 'fee-leg').toList(),
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 9, 30),
      );
      expect(withFees, withoutFeeLeg);
    });

    test('the August credit is excluded from the month', () {
      final august = netPremiumCollected(
        legs: legs,
        start: DateTime.utc(2026, 8, 1),
        end: DateTime.utc(2026, 8, 31),
      );
      // By D-8 a credit belongs to the period its own `openedAt` falls in,
      // so August holds UBER $110, BAC $55, CCL $80, KO $30 and the assigned
      // leg's $50 -- and none of September's credits.
      expect(august, Decimal.parse('325'));
    });

    test('the August credit is included in the year to date', () {
      final ytdValue = netPremiumCollected(
        legs: legs,
        start: DateTime.utc(2026, 1, 1),
        end: now,
      );
      // September's $561 net plus August's $325 of credits.
      expect(ytdValue, Decimal.parse('886'));
    });

    test('an assigned leg contributes no buyback', () {
      final assignedOnly = legs.where((l) => l.id == 'assigned').toList();
      expect(
        premiumBuybacks(
          legs: assignedOnly,
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 30),
        ),
        Decimal.zero,
      );
    });

    test('a leg opened in an earlier period belongs to that period', () {
      final september = netPremiumCollected(
        legs: legs,
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 9, 30),
      );
      final august = netPremiumCollected(
        legs: legs,
        start: DateTime.utc(2026, 8, 1),
        end: DateTime.utc(2026, 8, 31),
      );
      final ytdValue = netPremiumCollected(legs: legs, start: DateTime.utc(2026, 1, 1), end: now);
      // The year is the two months added: every credit and every buyback in
      // the fixture falls in August or September, so the year-to-date figure
      // is exactly their sum -- and the August credit is inside it.
      expect(september + august, ytdValue);
      expect(ytdValue, Decimal.parse('886'));
    });

    test('the period bounds are inclusive on both ends', () {
      final single = netPremiumCollected(
        legs: legs,
        start: DateTime.utc(2026, 9, 4),
        end: DateTime.utc(2026, 9, 4),
      );
      // INTC $248 + SOFI $123 + the fee leg's $0 credit, minus BAC's $28
      // buyback, which also closed on Sep 4.
      expect(single, Decimal.parse('343'));
    });

    test('the definition line is the reference wording', () {
      expect(kPremiumDefinitionLine, 'Premium: credits received minus buybacks paid, by trade date, before fees.');
    });
  });
}
