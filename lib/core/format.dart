/// Fixed-decimal display formatting, shared by the screens that show money
/// and percentages (D-15's whole-dollar rounding for tiles lives separately
/// in `whole_dollars.dart`, since it rounds rather than truncates).
///
/// Every one of these is "'--' when null, else fixed decimals" — no raw
/// `Decimal` (e.g. `-45.16129...%`) ever reaches the widget tree (S-143).
library;

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../domain/models/leg.dart';

String moneyText(Decimal? value) => value == null ? '--' : '\$${value.toStringAsFixed(2)}';

String pctText(Decimal? value, {int decimals = 0}) =>
    value == null ? '--' : '${value.toStringAsFixed(decimals)}%';

/// Formats a carried-forward prefill value without a trailing `.0` (a whole
/// IV like `40.0` should prefill as "40", not "40.0"); `null` becomes the
/// empty string, matching every other unset `TextEditingController`.
String trimTrailingZeros(double? value) {
  if (value == null) return '';
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

String dateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The reference's own short form for a day — `Sep 17`. Hand-rolled rather
/// than `intl`-formatted so the month abbreviation is fixed and
/// locale-independent, matching `reading_age.dart`'s aging line.
String shortDateText(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// Today's header date — `Mon, Sep 28`.
String weekdayDateText(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${shortDateText(date)}';

/// The expiry cards' date form — `Fri Oct 2`, no comma (D-13). Deliberately
/// distinct from [weekdayDateText], which is Today's own header.
String shortWeekdayDateText(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${shortDateText(date)}';

/// One leg as a list row names it — `$14 put ×3` — with no ticker, which the
/// caller supplies separately (D-10's rows).
String legContractText(Leg leg) =>
    '\$${leg.strike} ${leg.optionType.name} ×${leg.contracts}';

/// The month alone — `Sep` — for the ledger strip's "Net premium · Sep" tile
/// label (D-8).
String monthAbbreviation(DateTime date) => _months[date.month - 1];

/// The month spelled out with its year — `September 2026` — for the surfaces
/// that name a month on its own: the assignment calendar's header and the
/// share card's definition line (D-45, D-51). A bare `Sep` is a column
/// heading, not a sentence, so it cannot carry either.
///
/// Hand-rolled from [_monthsFull] rather than `intl`-formatted, so the name
/// is fixed and locale-independent like every other date in this file.
String monthYearText(DateTime date) => '${_monthsFull[date.month - 1]} ${date.year}';

/// The month spelled out alone — `September` — for a title that names the
/// month without its year, where the year is already unambiguous from
/// context (the share screen's `Share September`). [monthAbbreviation] is the
/// column-heading form and cannot carry a title.
String monthName(DateTime date) => _monthsFull[date.month - 1];

/// A net position delta in shares — `+360 shares`, `−30 shares`, `0 shares`
/// (D-43). [value] is `null` when nothing in the book could be read, which
/// renders `--` rather than a zero that would read as a flat book.
///
/// The sign is explicit on a non-zero total, because a signed total's whole
/// point is which way the book leans, and it uses the app's own minus sign
/// (U+2212) rather than a hyphen, matching every other signed figure. Shares
/// are whole, rounded away from zero on a half, and grouped by thousands; the
/// delta is a dimensionless `double`, so rounding here cannot reach a gate
/// (`docs/conventions.md` §2).
///
/// The rounding goes through `Decimal.parse(value.toString()).round()`, which
/// is D-43's pinned half-away-from-zero form and the same one
/// `whole_dollars.dart` uses — `Decimal`'s default rounding is half-away-from-
/// zero, so this matches `double.round()` while keeping the app's one rounding
/// rule in one place.
String signedSharesText(double? value) {
  if (value == null) return '--';
  final shares = Decimal.parse(value.toString()).round();
  if (shares == Decimal.zero) return '0 shares';
  final sign = shares < Decimal.zero ? '\u2212' : '+';
  return '$sign${_grouped(shares.abs().toBigInt())} shares';
}

/// A ratio rendered as a percentage — `1.6%` by default, `82%` at
/// `decimals: 0` (D-48). `null` renders `--`: a ratio the app could not
/// compute (no capital to divide by) is not the same fact as a ratio of zero,
/// and rendering `0.0%` would assert a return that was never measured.
///
/// Distinct from [pctText], which takes a `Decimal` from a money-side
/// calculation; this one takes the dimensionless `double` the return and
/// capture figures are computed as.
String percentText(double? value, {int decimals = 1}) =>
    value == null ? '--' : '${value.toStringAsFixed(decimals)}%';

/// `1,234` — thousands separators, hand-rolled for the same
/// locale-independence reason the dates are.
String _grouped(BigInt value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// A store price, in the currency the store reported (D-31): `$2.50`, `€2,50`.
/// The one place a money value is converted to `num` for display — this is a
/// formatter, so the conversion cannot reach a gate, and the store's own
/// `priceString` is preferred everywhere it exists; this is for the annual
/// row's *derived* per-month figure, which the store does not return.
///
/// An unknown/empty [currencyCode] falls back to the device locale's currency
/// rather than throwing, because a gateway that reported a price without a
/// code must not be able to crash a paywall.
String currencyText(Decimal value, String currencyCode) {
  final format = currencyCode.isEmpty
      ? NumberFormat.simpleCurrency()
      : NumberFormat.simpleCurrency(name: currencyCode);
  return format.format(value.toDouble());
}

/// A renewal, cancellation or purchase date — `Oct 5, 2027`. The year is
/// spelled out because a subscription renews further out than the rest of the
/// app ever looks, and a bare `Oct 5` would be ambiguous by then.
String renewalDateText(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `DateTime.weekday` is 1-based from Monday.
const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// [monthYearText]'s full month names, which no other formatter uses — the
/// abbreviation list above is deliberately kept separate so neither can
/// silently acquire the other's length.
const List<String> _monthsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
