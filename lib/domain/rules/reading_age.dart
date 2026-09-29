import '../models/snapshot.dart';
import 'formulas.dart' show daysBetween;

/// `docs/brief-pro.md` D-P11 / Pro Wave 1 D-11: how stale a position's
/// latest reading is, and whether that puts an inline Update on its row.
/// Pure, zero Flutter imports, zero I/O; `now` is a parameter
/// (`docs/conventions.md` §3).

/// The one place the aging threshold lives (D-11). A reading exactly this
/// many calendar days old is **not** counted; one day more is.
const int kAgingDays = 7;

/// Calendar days between [snapshot]'s `takenAt` and [now], through the
/// shared UTC-normalized [daysBetween] — the same day count `dte` and
/// `daysHeld` use, so a DST-crossing span cannot shift the answer by one.
/// Can be negative for a future-dated reading.
int readingAgeDays(Snapshot snapshot, DateTime now) => daysBetween(snapshot.takenAt, now);

/// Whether this leg's row carries the inline Update (D-11, OC-4 ratified):
/// no reading at all, or a reading older than [kAgingDays]. This is the same
/// predicate that puts the leg in the "needs a reading" count.
bool needsReading({required Snapshot? latestSnapshot, required DateTime now}) =>
    latestSnapshot == null || readingAgeDays(latestSnapshot, now) > kAgingDays;

/// Whether this leg belongs in the aging count (D-11). Deliberately
/// **excludes** the no-reading case: "No data" stays its own, exclusive
/// count (Feature Invariant 19) and is never part of the aging count.
bool olderThanAging({required Snapshot? latestSnapshot, required DateTime now}) =>
    latestSnapshot != null && readingAgeDays(latestSnapshot, now) > kAgingDays;

/// One leg's contribution to the aging line.
typedef AgingEntry = ({String ticker, Snapshot snapshot});

/// D-11's aging line, naming the legs and dates it counts:
/// `1 reading older than 7 days · T, from Sep 17`. Empty when nothing is
/// aging — the caller renders no line at all in that case.
///
/// The count is **overlapping** (D-11): an aging leg stays in its bucket's
/// count too, so this line is rendered separately rather than replacing
/// anything.
String agingLine({required List<AgingEntry> legs, required DateTime now}) {
  final aging = legs.where((entry) => olderThanAging(latestSnapshot: entry.snapshot, now: now)).toList();
  if (aging.isEmpty) return '';
  final names = aging.map((entry) => '${entry.ticker}, from ${_shortDate(entry.snapshot.takenAt)}').join('; ');
  final noun = aging.length == 1 ? 'reading' : 'readings';
  return '${aging.length} $noun older than $kAgingDays days · $names';
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `Sep 17` — the reference's own short form for a reading's date.
String _shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';
