import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import 'expiry.dart' show isPastExpiration;
import 'formulas.dart' show daysBetween;

/// `docs/brief-pro.md` D-P13 / Pro Wave 1 D-13's "Expiring this week" card
/// (S-226, S-250): which legs expire inside the next seven days, and what
/// each one obliges the user to do if it is assigned. Pure, zero Flutter
/// imports, zero I/O; `now` is a parameter (`docs/conventions.md` §3).

/// The window the card covers, in calendar days from [now] — inclusive of
/// today and of the seventh day out.
const int kExpiringWindowDays = 7;

/// What an expiring leg obliges if it is assigned.
enum ObligationKind { cashIfAssigned, sharesDelivered }

/// One expiring leg's obligation line.
class Obligation {
  final ObligationKind kind;

  /// The dollar figure the assignment would move: `strike x 100 x contracts`
  /// for both kinds — cash paid for a put, shares' value delivered for a
  /// call. `Decimal` end to end (Feature Invariant 2); the caller converts
  /// to `double` only inside a display formatter.
  final Decimal amount;

  /// The rendered line, e.g. `$4,200 cash if assigned` or
  /// `100 shares delivered at $28 if assigned`.
  final String text;

  const Obligation({required this.kind, required this.amount, required this.text});
}

/// The obligation line for one **open** leg, or `null` when the leg has no
/// open position (D-13: a leg with no open position contributes nothing).
///
/// A put's line is the cash the assignment would cost; a call's is the
/// shares it would deliver, named by count and strike.
Obligation? obligationFor(Leg leg) {
  if (leg.closedAt != null) return null;
  final amount = leg.strike * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts);
  if (leg.optionType == OptionType.put) {
    return Obligation(
      kind: ObligationKind.cashIfAssigned,
      amount: amount,
      text: '${_dollars(amount)} cash if assigned',
    );
  }
  final shares = leg.contracts * 100;
  return Obligation(
    kind: ObligationKind.sharesDelivered,
    amount: amount,
    text: '$shares shares delivered at ${_dollars(leg.strike)} if assigned',
  );
}

/// The open legs expiring inside `[now, now + 7 days]` (D-13's card), in the
/// order supplied. A leg expiring today is inside the window; one expiring
/// eight days out is not. Past-expiration legs are **not** here — they
/// belong to the past-expiration card.
List<Leg> expiringWithinSevenDays({required List<Leg> legs, required DateTime now}) => legs
    .where((leg) => leg.closedAt == null)
    .where((leg) {
      final days = daysBetween(now, leg.expiration);
      return days >= 0 && days <= kExpiringWindowDays;
    })
    .toList();

/// One date's worth of the card.
class ExpiringGroup {
  final DateTime date;
  final List<Leg> legs;

  const ExpiringGroup({required this.date, required this.legs});
}

/// The card's contents, grouped by expiration date in ascending date order
/// (S-250). Empty when nothing expires inside the window — the caller
/// renders no card at all in that case.
List<ExpiringGroup> expiringThisWeek({required List<Leg> legs, required DateTime now}) {
  final selected = expiringWithinSevenDays(legs: legs, now: now);
  final byDate = <DateTime, List<Leg>>{};
  for (final leg in selected) {
    final key = DateTime.utc(leg.expiration.year, leg.expiration.month, leg.expiration.day);
    byDate.putIfAbsent(key, () => <Leg>[]).add(leg);
  }
  final dates = byDate.keys.toList()..sort();
  return dates.map((date) => ExpiringGroup(date: date, legs: byDate[date]!)).toList();
}

/// Every date in [month] on which an open leg expires, ascending, each with
/// that date's legs in the order supplied (D-45).
///
/// A leg is here when it is open, its expiration is **not** past, and its
/// expiration falls in [month]'s calendar month. A leg expiring today is
/// upcoming, so it is included and groups under today. Past-expiration legs
/// belong to the past-expiration card, not the grid. Empty when nothing is
/// due — the grid renders no row at all rather than a row of blanks.
///
/// [now] is used for the past-expiration test only; the month shown is the
/// caller's, because the user can page the grid away from today's month.
List<ExpiringGroup> expirationsInMonth({
  required List<Leg> legs,
  required DateTime month,
  required DateTime now,
}) {
  final byDate = <DateTime, List<Leg>>{};
  for (final leg in legs) {
    if (leg.closedAt != null) continue;
    if (isPastExpiration(leg, now)) continue;
    if (leg.expiration.year != month.year || leg.expiration.month != month.month) continue;
    final key = DateTime.utc(leg.expiration.year, leg.expiration.month, leg.expiration.day);
    byDate.putIfAbsent(key, () => <Leg>[]).add(leg);
  }
  final dates = byDate.keys.toList()..sort();
  return dates.map((date) => ExpiringGroup(date: date, legs: byDate[date]!)).toList();
}

/// The month the assignment calendar opens on (D-45): the calendar month of
/// the **earliest upcoming** expiration in [openLegs], or of [now] when
/// nothing is upcoming.
///
/// Opening on the month the user actually has something due in saves a page
/// turn in the common case, and falling back to today's month means a book
/// with nothing due still lands somewhere sensible rather than nowhere. A leg
/// expiring today is upcoming. Closed legs are not expirations at all. The
/// result is the **first** of the month, so the caller holds a month
/// identifier and not a date that drifts with the clock.
DateTime calendarMonth({required DateTime now, required List<Leg> openLegs}) {
  final upcoming = openLegs
      .where((leg) => leg.closedAt == null)
      .where((leg) => daysBetween(now, leg.expiration) >= 0)
      .map((leg) => leg.expiration)
      .toList()
    ..sort();
  final anchor = upcoming.isEmpty ? now : upcoming.first;
  return DateTime.utc(anchor.year, anchor.month, 1);
}

/// `$4,200` — whole dollars with thousands separators, matching the
/// reference's own rendering of an obligation figure.
String _dollars(Decimal value) {
  final whole = value.round().toBigInt().toString();
  final negative = whole.startsWith('-');
  final digits = negative ? whole.substring(1) : whole;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$$buffer';
}
