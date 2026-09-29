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

  group('S-299 / S-300: expirationsInMonth groups the shown month (D-45)', () {
    final october = DateTime.utc(2026, 10, 1);

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
      expiration: DateTime.utc(2026, 10, 2),
    );
    final f = _leg(
      id: 'f',
      optionType: OptionType.put,
      strike: '12.00',
      contracts: 2,
      expiration: DateTime.utc(2026, 10, 9),
    );
    final intc = _leg(
      id: 'intc',
      optionType: OptionType.put,
      strike: '20.00',
      contracts: 4,
      expiration: DateTime.utc(2026, 10, 16),
    );
    final sbet = _leg(
      id: 'sbet',
      optionType: OptionType.call,
      strike: '11.00',
      expiration: DateTime.utc(2026, 10, 16),
    );
    final pfe = _leg(
      id: 'pfe',
      optionType: OptionType.put,
      strike: '25.00',
      expiration: DateTime.utc(2026, 10, 23),
    );
    final past = _leg(
      id: 'past',
      optionType: OptionType.put,
      strike: '15.00',
      contracts: 2,
      expiration: DateTime.utc(2026, 9, 18),
    );
    final pastSecond = _leg(
      id: 'past-second',
      optionType: OptionType.put,
      strike: '9.00',
      expiration: DateTime.utc(2026, 9, 18),
    );
    final closedInOctober = _leg(
      id: 'closed-in-october',
      optionType: OptionType.put,
      strike: '20.00',
      expiration: DateTime.utc(2026, 10, 2),
      closedAt: DateTime.utc(2026, 9, 25),
    );
    final november = _leg(
      id: 'november',
      optionType: OptionType.put,
      strike: '20.00',
      expiration: DateTime.utc(2026, 11, 6),
    );

    test('the groups are ascending by date, with one group per date', () {
      final groups = expirationsInMonth(
        legs: [pfe, intc, sofi, t, f, sbet, past, pastSecond, closedInOctober, november],
        month: october,
        now: now,
      );
      expect(groups.map((group) => group.date).toList(), [
        DateTime.utc(2026, 10, 2),
        DateTime.utc(2026, 10, 9),
        DateTime.utc(2026, 10, 16),
        DateTime.utc(2026, 10, 23),
      ]);
      expect(groups.map((group) => group.legs.map((leg) => leg.id).toList()).toList(), [
        ['sofi', 't'],
        ['f'],
        ['intc', 'sbet'],
        ['pfe'],
      ]);
    });

    test('each leg keeps its own obligation line', () {
      final groups = expirationsInMonth(legs: [sofi, t], month: october, now: now);
      expect(obligationFor(groups.single.legs[0])!.text, r'$4,200 cash if assigned');
      expect(obligationFor(groups.single.legs[1])!.text, r'100 shares delivered at $28 if assigned');
    });

    test('past-expiration legs and other months are nowhere in the grid', () {
      final groups = expirationsInMonth(
        legs: [sofi, past, pastSecond, november],
        month: october,
        now: now,
      );
      expect(groups, hasLength(1));
      expect(groups.single.legs.map((leg) => leg.id).toList(), ['sofi']);
    });

    test('a leg with a closedAt is absent', () {
      expect(expirationsInMonth(legs: [closedInOctober], month: october, now: now), isEmpty);
    });

    test('a leg expiring today is included, and groups under today', () {
      final today = _leg(
        id: 'today',
        optionType: OptionType.put,
        strike: '15.00',
        expiration: DateTime.utc(2026, 9, 28),
      );
      final groups = expirationsInMonth(legs: [today], month: DateTime.utc(2026, 9, 1), now: now);
      expect(groups.single.date, DateTime.utc(2026, 9, 28));
      expect(groups.single.legs.single.id, 'today');
    });

    test('a month with nothing due is an empty list, not a row of blanks', () {
      expect(expirationsInMonth(legs: [sofi, t], month: DateTime.utc(2027, 1, 1), now: now), isEmpty);
      expect(expirationsInMonth(legs: const [], month: october, now: now), isEmpty);
    });
  });

  group('S-299 / S-301: calendarMonth picks the month to open on (D-45)', () {
    test('the earliest upcoming expiration decides the month', () {
      final legs = [
        _leg(id: 'later', optionType: OptionType.put, strike: '20.00', expiration: DateTime.utc(2026, 10, 23)),
        _leg(id: 'next', optionType: OptionType.put, strike: '14.00', expiration: DateTime.utc(2026, 10, 2)),
        _leg(id: 'later-still', optionType: OptionType.put, strike: '12.00', expiration: DateTime.utc(2026, 10, 9)),
        _leg(id: 'past', optionType: OptionType.put, strike: '15.00', expiration: DateTime.utc(2026, 9, 18)),
      ];
      expect(calendarMonth(now: now, openLegs: legs), DateTime.utc(2026, 10, 1));
    });

    test('a leg expiring today is upcoming, so it decides the month', () {
      final today = _leg(
        id: 'today',
        optionType: OptionType.put,
        strike: '15.00',
        expiration: DateTime.utc(2026, 9, 28),
      );
      expect(calendarMonth(now: now, openLegs: [today]), DateTime.utc(2026, 9, 1));
    });

    test('with every expiration already past, it falls back to today\'s month', () {
      final past = _leg(
        id: 'past',
        optionType: OptionType.put,
        strike: '15.00',
        expiration: DateTime.utc(2026, 9, 18),
      );
      expect(calendarMonth(now: now, openLegs: [past]), DateTime.utc(2026, 9, 1));
    });

    test('with no open legs at all, it falls back to today\'s month', () {
      expect(calendarMonth(now: now, openLegs: const []), DateTime.utc(2026, 9, 1));
    });

    test('a closed leg is not an upcoming expiration', () {
      final closed = _leg(
        id: 'closed',
        optionType: OptionType.put,
        strike: '20.00',
        expiration: DateTime.utc(2026, 10, 2),
        closedAt: DateTime.utc(2026, 9, 25),
      );
      expect(calendarMonth(now: now, openLegs: [closed]), DateTime.utc(2026, 9, 1));
    });

    test('the result is the first of the month, whatever day of it is supplied', () {
      expect(calendarMonth(now: DateTime.utc(2026, 9, 30), openLegs: const []), DateTime.utc(2026, 9, 1));
      expect(calendarMonth(now: DateTime.utc(2026, 12, 31), openLegs: const []), DateTime.utc(2026, 12, 1));
    });
  });
}
