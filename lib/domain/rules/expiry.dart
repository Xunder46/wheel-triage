import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import '../models/snapshot.dart';
import 'formulas.dart' show daysBetween, intrinsic;

/// `docs/brief-pro.md` D-P13 / Pro Wave 1 D-13: which past-expiration legs
/// the expiry card shows, which of them "Mark all expired" covers, and what
/// date a recorded expiry carries. Pure, zero Flutter imports, zero I/O;
/// `now` is a parameter (`docs/conventions.md` §3).

/// Whether this leg's expiration is strictly in the past — the predicate
/// that puts a leg on the past-expiration card and keeps it out of the
/// bucket counts and the open-positions list (D-13). A leg expiring **today**
/// is not past expiration.
bool isPastExpiration(Leg leg, DateTime now) => daysBetween(leg.expiration, now) > 0;

/// The date a "Mark expired" action records (D-13):
///
/// ```
/// recordedCloseDate(leg, now) = daysBetween(leg.expiration, now) >= 0 ? leg.expiration : now
/// ```
///
/// On or after the expiration date the expiration date is recorded, so a leg
/// marked on the Monday after a Friday expiry lands in the month it actually
/// expired in. Before the expiration date the tap time is kept — today's
/// behaviour, unchanged.
DateTime recordedCloseDateForExpiry(Leg leg, DateTime now) =>
    daysBetween(leg.expiration, now) >= 0 ? leg.expiration : now;

/// One past-expiration leg as the card renders it.
class ExpiryCardEntry {
  final Leg leg;
  final Snapshot? latestSnapshot;

  /// Whether "Mark all expired" covers this leg (D-13): past expiration
  /// **and** a latest reading exists **and** that reading was out of the
  /// money. A reading exactly at the strike is not in the money, so such a
  /// leg *is* eligible.
  final bool batchEligible;

  const ExpiryCardEntry({required this.leg, required this.latestSnapshot, required this.batchEligible});
}

/// Whether one past-expiration leg is covered by "Mark all expired" (D-13).
/// Legs with no reading, and legs whose last reading was in the money, are
/// listed on the card with their own actions and are never included.
bool expiryBatchEligible({required Leg leg, required Snapshot? latestSnapshot, required DateTime now}) {
  if (!isPastExpiration(leg, now)) return false;
  if (latestSnapshot == null) return false;
  final value = intrinsic(
    optionType: leg.optionType,
    strike: leg.strike,
    spot: latestSnapshot.underlyingPrice,
  );
  return value == null || value == Decimal.zero;
}

/// The past-expiration card's contents (D-13): every **open** leg whose
/// expiration has passed, in the order supplied, each tagged with whether
/// "Mark all expired" covers it. A leg expiring today is absent entirely.
List<ExpiryCardEntry> pastExpirationCard({
  required List<({Leg leg, Snapshot? latestSnapshot})> legs,
  required DateTime now,
}) => legs
    .where((entry) => entry.leg.closedAt == null && isPastExpiration(entry.leg, now))
    .map(
      (entry) => ExpiryCardEntry(
        leg: entry.leg,
        latestSnapshot: entry.latestSnapshot,
        batchEligible: expiryBatchEligible(leg: entry.leg, latestSnapshot: entry.latestSnapshot, now: now),
      ),
    )
    .toList();

/// The reading line under one past-expiration leg (D-13): the date and price
/// of its latest reading and which side of the strike that price was on. A
/// price exactly at the strike reads "at the strike". A leg with no reading
/// says so, so the card never renders a blank line where a number belongs.
String expiryReadingLine(ExpiryCardEntry entry) {
  final snapshot = entry.latestSnapshot;
  if (snapshot == null) return 'No reading recorded';
  final comparison = snapshot.underlyingPrice.compareTo(entry.leg.strike);
  final side = comparison > 0
      ? 'above the strike'
      : comparison < 0
      ? 'below the strike'
      : 'at the strike';
  return 'Last reading ${_shortDate(snapshot.takenAt)}: '
      'stock ${_money(snapshot.underlyingPrice)}, $side';
}

/// What "Mark all expired" will record, in the card's own words (D-13). The
/// one-leg case names the leg and the date it expires, matching the reference
/// copy; two or more say "each leg" and leave the dates to the rows.
String expiryBatchExplanation({required List<ExpiryCardEntry> eligible, String? singleTicker}) {
  if (eligible.length == 1 && singleTicker != null) {
    return 'Records $singleTicker as expired worthless on '
        '${_shortDate(eligible.single.leg.expiration)}, no close debit. '
        'The close fee stays blank.';
  }
  return 'Records each leg as expired worthless on its own expiration date, '
      'no close debit. The close fee stays blank.';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

String _money(Decimal value) => '\$${value.toStringAsFixed(2)}';
