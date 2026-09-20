import 'formulas.dart' show daysBetween;

/// How stale the latest snapshot behind a displayed figure is (§7,
/// Feature Invariant 33). Purely descriptive -- never fed into `classify()`
/// or any gate; it exists so the UI can tell the user which reading its
/// numbers came from, not to change what those numbers are.
enum Freshness { fresh, recent, old, stale }

/// Pure function of `(takenAt, now)` (Feature Invariant 33) -- `now` is
/// always a passed-in parameter, matching every other "current time" rule
/// in this codebase (`docs/conventions.md` §3), so this stays testable
/// without a widget harness, the same "pure, display-only, still worth
/// testing" reasoning `resolveIv`/`checkCreditBound` already established.
///
/// Boundaries, checked in order:
///  - less than 1 hour elapsed -> [Freshness.fresh]
///  - else, [takenAt] falls on the same calendar date as [now] ->
///    [Freshness.recent]
///  - else, [takenAt] falls on [now]'s previous calendar date ->
///    [Freshness.old]
///  - else -> [Freshness.stale]
///
/// Calendar-date comparisons reuse `formulas.dart`'s [daysBetween] (the same
/// UTC-normalized day count `dte`/`daysHeld` already share) rather than a
/// second by-hand date-truncation, so this shares one implementation of
/// "how many calendar days apart" with the rest of `lib/domain/rules/`.
Freshness freshnessOf({required DateTime takenAt, required DateTime now}) {
  if (now.difference(takenAt) < const Duration(hours: 1)) return Freshness.fresh;
  final calendarDaysAgo = daysBetween(takenAt, now);
  if (calendarDaysAgo == 0) return Freshness.recent;
  if (calendarDaysAgo == 1) return Freshness.old;
  return Freshness.stale;
}
