/// Pure derivation for the 30-day export reminder (`docs/brief-ledger.md`
/// §5, Feature Invariant 34): true exactly when Settings' dismissable
/// export-reminder banner should show.
///
/// `lastExportAt == null` (nothing has ever been exported) falls back to
/// [earliestOpenPositionOpenedAt] -- the earliest currently-open leg's own
/// `openedAt` -- as the only "how long has there been something worth
/// protecting" signal this app persists. There is no separate "installed
/// at" timestamp anywhere in the schema (Phase 15 is closed, and the data
/// layer is not this phase's to extend); using the oldest open position's
/// own open date is real, already-available data that answers the same
/// question the brief's "no export in 30 days" language is really asking --
/// see the phase's Assumption Log for this call.
///
/// A pure function of its inputs (`now` always passed in, never
/// `DateTime.now()` internally) so it is testable without a widget harness,
/// matching `docs/conventions.md` §3's "now is always a parameter"
/// convention even though this file lives in `lib/core/`, not
/// `lib/domain/rules/`.
bool exportReminderDue({
  required DateTime? lastExportAt,
  required DateTime? earliestOpenPositionOpenedAt,
  required bool hasOpenPositions,
  required bool exportReminderDismissed,
  required DateTime now,
  int thresholdDays = 30,
}) {
  if (exportReminderDismissed || !hasOpenPositions) return false;
  final reference = lastExportAt ?? earliestOpenPositionOpenedAt;
  if (reference == null) return false;
  return _daysBetween(reference, now) >= thresholdDays;
}

/// UTC-normalized whole-day span, ignoring time-of-day -- the same shape as
/// every other day-count helper in this codebase
/// (`lib/domain/rules/formulas.dart#daysBetween`,
/// `lib/data/export/ledger_csv.dart#_daysBetween`).
int _daysBetween(DateTime from, DateTime to) {
  final f = DateTime.utc(from.year, from.month, from.day);
  final t = DateTime.utc(to.year, to.month, to.day);
  return t.difference(f).inDays;
}
