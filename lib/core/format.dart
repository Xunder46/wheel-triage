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
