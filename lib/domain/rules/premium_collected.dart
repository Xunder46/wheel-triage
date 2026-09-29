import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import 'formulas.dart' show daysBetween;

/// `docs/brief-pro.md` D-P14 / Pro Wave 1 D-8: the ledger strip's two
/// premium figures. Pure, zero Flutter imports, zero I/O; the period is
/// always passed in (`docs/conventions.md` §3).
///
/// ```
/// credits  = Σ (openCreditPerShare x 100 x contracts)  for legs opened in the period
/// buybacks = Σ ((closeDebitPerShare ?? 0) x 100 x contracts)  for legs closed in the period
/// net      = credits - buybacks
/// ```
///
/// **Fees never enter this figure** (D-8) — it is the "before fees" line the
/// on-screen definition names. Legs of open and closed cycles both count; a
/// leg opened in an earlier period belongs to that period's figure, not this
/// one's. An assigned leg records no close debit, so it contributes no
/// buyback.

/// Credits received in `[start, end]`, by **trade date** — a leg's own
/// `date(openedAt)`, inclusive on both ends.
Decimal premiumCredits({required List<Leg> legs, required DateTime start, required DateTime end}) => legs
    .where((leg) => _inPeriod(leg.openedAt, start, end))
    .fold(Decimal.zero, (sum, leg) => sum + leg.openCreditPerShare * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts));

/// Buybacks paid in `[start, end]`, by **trade date** — a leg's own
/// `date(closedAt)`, inclusive on both ends. A leg with no recorded close
/// debit (still open, or assigned — an assignment is not a buyback)
/// contributes nothing.
Decimal premiumBuybacks({required List<Leg> legs, required DateTime start, required DateTime end}) => legs
    .where((leg) => leg.closedAt != null && _inPeriod(leg.closedAt!, start, end))
    .fold(
      Decimal.zero,
      (sum, leg) => sum + (leg.closeDebitPerShare ?? Decimal.zero) * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts),
    );

/// `credits - buybacks` for `[start, end]` (D-8). Can be negative — a month
/// of buybacks with no new credits is a real state, and the caller must
/// render the sign rather than clamping it.
Decimal netPremiumCollected({required List<Leg> legs, required DateTime start, required DateTime end}) =>
    premiumCredits(legs: legs, start: start, end: end) - premiumBuybacks(legs: legs, start: start, end: end);

/// The calendar month containing [now], as a `[start, end]` pair — the
/// "Net premium · month" tile's period.
({DateTime start, DateTime end}) monthPeriodContaining(DateTime now) => (
  start: DateTime.utc(now.year, now.month, 1),
  end: DateTime.utc(now.year, now.month + 1, 0),
);

/// 1 January of [now]'s year through [now] — the "Year to date" tile's
/// period.
({DateTime start, DateTime end}) yearToDatePeriod(DateTime now) => (
  start: DateTime.utc(now.year, 1, 1),
  end: now,
);

/// D-8's on-screen definition, in the reference's own words. Pinned by
/// S-223.
const String kPremiumDefinitionLine =
    'Premium: credits received minus buybacks paid, by trade date, before fees.';

/// Calendar-date containment, inclusive on both ends, UTC-normalized through
/// the shared [daysBetween] so a DST-crossing period boundary cannot drop a
/// leg (the same reasoning `formulas.dart`'s `dte` documents).
bool _inPeriod(DateTime date, DateTime start, DateTime end) =>
    daysBetween(start, date) >= 0 && daysBetween(date, end) >= 0;
