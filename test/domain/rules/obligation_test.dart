import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/rules/obligation.dart';

Leg _leg({
  required String id,
  required OptionType optionType,
  required String strike,
  required DateTime expiration,
  int contracts = 1,
  DateTime? closedAt,
}) => Leg(
  id: id,
  cycleId: 'cycle-$id',
  sequence: 0,
  optionType: optionType,
  strike: Decimal.parse(strike),
  expiration: expiration,
  contracts: contracts,
  openedAt: DateTime.utc(2026, 8, 1),
  openCreditPerShare: Decimal.parse('0.50'),
  closedAt: closedAt,
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

void main() {
  // S-250's fixture: today Mon 2026-09-28.
  final now = DateTime.utc(2026, 9, 28);

  group('S-226 / S-250: obligations at an expiration', () {
    final sofi = _leg(
      id: 'sofi',
      optionType: OptionType.put,
      strike: '14.00',
      contracts: 3,
      expiration: DateTime.utc(2026, 10, 2),
    );
    final t = _leg(
      id: 't',
      optionType: OptionType.call,
      strike: '28.00',
      contracts: 1,
      expiration: DateTime.utc(2026, 10, 2),
    );

    test('a put obligation is "cash if assigned" at strike x 100 x contracts', () {
      final line = obligationFor(sofi)!;
      expect(line.kind, ObligationKind.cashIfAssigned);
      expect(line.amount, Decimal.parse('4200'));
      expect(line.text, r'$4,200 cash if assigned');
    });

    test(r'a call obligation is "100 shares delivered at $28 if assigned"', () {
      final line = obligationFor(t)!;
      expect(line.kind, ObligationKind.sharesDelivered);
      expect(line.amount, Decimal.parse('2800'));
      expect(line.text, r'100 shares delivered at $28 if assigned');
    });

    test('a call with more contracts delivers more shares', () {
      final two = _leg(
        id: 't2',
        optionType: OptionType.call,
        strike: '28.00',
        contracts: 2,
        expiration: DateTime.utc(2026, 10, 2),
      );
      expect(obligationFor(two)!.text, r'200 shares delivered at $28 if assigned');
    });

    test('a leg with no open position contributes nothing', () {
      final closed = _leg(
        id: 'closed',
        optionType: OptionType.put,
        strike: '14.00',
        contracts: 3,
        expiration: DateTime.utc(2026, 10, 2),
        closedAt: DateTime.utc(2026, 9, 25),
      );
      expect(obligationFor(closed), isNull);
    });

    test('the expiring-this-week selection keeps only the next seven days', () {
      final f = _leg(
        id: 'f',
        optionType: OptionType.put,
        strike: '20.00',
        expiration: DateTime.utc(2026, 10, 9),
      );
      final yesterday = _leg(
        id: 'yesterday',
        optionType: OptionType.put,
        strike: '11.00',
        expiration: DateTime.utc(2026, 9, 27),
      );
      final selected = expiringWithinSevenDays(
        legs: [sofi, t, f, yesterday],
        now: now,
      );
      expect(selected.map((l) => l.id).toList(), ['sofi', 't']);
    });

    test('the card groups by date and is absent when nothing is in the window', () {
      final groups = expiringThisWeek(
        legs: [sofi, t],
        now: now,
      );
      expect(groups, hasLength(1));
      expect(groups.single.date, DateTime.utc(2026, 10, 2));
      expect(groups.single.legs.map((l) => l.id).toList(), ['sofi', 't']);

      expect(expiringThisWeek(legs: const [], now: now), isEmpty);
    });

    test('a leg expiring today is inside the window', () {
      final today = _leg(
        id: 'today',
        optionType: OptionType.put,
        strike: '15.00',
        expiration: DateTime.utc(2026, 9, 28),
      );
      expect(expiringWithinSevenDays(legs: [today], now: now).map((l) => l.id).toList(), ['today']);
    });

    test('a leg expiring exactly seven days out is inside the window', () {
      final seventh = _leg(
        id: 'seventh',
        optionType: OptionType.put,
        strike: '15.00',
        expiration: DateTime.utc(2026, 10, 5),
      );
      expect(expiringWithinSevenDays(legs: [seventh], now: now).map((l) => l.id).toList(), ['seventh']);
    });

    test('a leg expiring eight days out is outside the window', () {
      final eighth = _leg(
        id: 'eighth',
        optionType: OptionType.put,
        strike: '15.00',
        expiration: DateTime.utc(2026, 10, 6),
      );
      expect(expiringWithinSevenDays(legs: [eighth], now: now), isEmpty);
    });
  });
}
