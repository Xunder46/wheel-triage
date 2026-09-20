/// Pure date-picker default helper for "expiration is a date picker, never
/// derived from typed DTE" (brief-followup A5, Feature Invariant 22). Lives
/// in `lib/core/`, not `lib/domain/rules/` — this is UI-input mechanics (a
/// picker's default value), not a gate/classification formula; it never
/// feeds `classify()` or any of the four gates. Shared by the screener and
/// the assignment-flow covered-call entry step so the same default/warning
/// logic is never independently reinvented at a second call site.
library;

/// The Friday nearest to [date] — could be before or after. Ties are
/// impossible: a 7-day week has no exact midpoint, so exactly one candidate
/// is always strictly closer (verified for all seven weekdays).
DateTime nearestFriday(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final diff = DateTime.friday - normalized.weekday; // always in [-2, 4]
  final altDiff = diff > 0 ? diff - 7 : diff + 7;
  final offset = diff.abs() <= altDiff.abs() ? diff : altDiff;
  return normalized.add(Duration(days: offset));
}

/// The date-picker's default value (Feature Invariant 22): the Friday
/// nearest the midpoint of the 30-45-day window, i.e. nearest to
/// `today + 37` days. By construction of [nearestFriday]'s bounded offset
/// (at most 4 days either way), this always itself falls inside
/// `[today + 30, today + 45]`.
DateTime defaultExpiration(DateTime today) => nearestFriday(today.add(const Duration(days: 37)));

/// Whether [date] is a trading-week Friday. A `false` result warns the user
/// (Feature Invariant 22) — index/month-end/weekly products legitimately
/// expire on other days, so this never blocks.
bool isFriday(DateTime date) => date.weekday == DateTime.friday;
