import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import '../models/leg.dart';

/// The §4.1 derived metrics. Zero Flutter imports, zero I/O, zero clock
/// access — every "current" value (`referenceDate`) is a parameter. Every
/// function here is nullable-safe: a missing input is a normal state (no
/// snapshot yet), never a thrown exception and never `NaN`
/// (`docs/conventions.md` §1).

/// Percentage of the leg's own credit captured so far:
/// `(openCredit - currentMark) / openCredit * 100`.
///
/// Returns a [Decimal], never a `double` — a captured-credit calculation
/// that lands on `49.999999...` instead of `50.0` would silently fail to
/// fire Gate 1 (brief §2). Division carried through `Decimal`'s own exact
/// `Rational` division and only rounded to a fixed number of fractional
/// digits at the very end (never mid-calculation), so a genuinely exact
/// result (S-012) stays exact.
Decimal? capturedPct({required Decimal? openCredit, required Decimal? currentMark}) {
  if (openCredit == null || currentMark == null) return null;
  if (openCredit == Decimal.zero) return null;
  final ratio = (openCredit - currentMark) / openCredit; // exact Rational
  final pct = ratio * Decimal.fromInt(100).toRational();
  return pct.toDecimal(scaleOnInfinitePrecision: 6);
}

/// `expiration - referenceDate`, in whole days, ignoring time-of-day on
/// both sides (Feature Invariant 7). Can be negative (expired but not yet
/// recorded/closed, S-011 row B). One shared implementation for both the
/// "live, as-of-today" DTE used by `classify()` and a historical snapshot's
/// own DTE — callers vary only the `referenceDate` they pass in.
///
/// Normalizes both dates through [DateTime.utc], not the local-time
/// constructor, even when the inputs themselves are local: a local-time
/// midnight-to-midnight span that crosses a DST transition is only 23 (or
/// 25) hours long, and `Duration.inDays` truncates that short/long day away
/// — a genuine off-by-one, not a rounding nicety. UTC has no DST, so this
/// day count is exact regardless of which local calendar day a DST
/// transition falls on.
int dte(DateTime expiration, DateTime referenceDate) => daysBetween(referenceDate, expiration);

/// Whole-day span from [from] to [to] (`to - from`, can be negative),
/// UTC-normalized for the same DST-crossing reason [dte]'s own doc explains.
/// Factored out so any other "how many days apart" calculation (e.g.
/// `lib/domain/rules/cycle_pnl.dart`'s `daysHeld`) shares this one
/// implementation rather than re-deriving the UTC-normalization by hand.
int daysBetween(DateTime from, DateTime to) {
  final f = DateTime.utc(from.year, from.month, from.day);
  final t = DateTime.utc(to.year, to.month, to.day);
  return t.difference(f).inDays;
}

/// Expected one-standard-deviation dollar move of the underlying by
/// expiration: `spot * (iv / 100) * sqrt(dte / 365)`.
///
/// Takes [spot], **not** `strike` (brief-followup A1 — a formula error in
/// the original brief; Feature Invariant 17). The expected move measures how
/// far the underlying itself can travel from where it currently trades; the
/// strike is a level the user picked arbitrarily and has no business in the
/// formula. Consequently this function is invariant to strike by
/// construction — the signature no longer accepts one at all (S-040).
///
/// `sqrt` has no exact `Decimal` representation, so the irrational
/// `(iv / 100) * sqrt(dte / 365)` multiplier is necessarily computed in
/// `double` (there is no way to avoid this — the term is genuinely
/// irrational for almost every input, not a missed-`Decimal` bug). That
/// multiplier is then applied to [spot] as an exact `Decimal`
/// multiplication, so only the irreducibly-irrational part ever touches a
/// `double`; the dollar arithmetic itself stays exact.
///
/// `dte <= 0` (expired, not yet recorded, or expiring today) returns
/// [Decimal.zero] without ever calling `sqrt` on a non-positive argument
/// (S-011) — a negative `dte` would otherwise make `sqrt` return `NaN`.
Decimal? oneSigmaMove({required Decimal spot, required double? iv, required int dte}) {
  if (iv == null) return null;
  if (dte <= 0) return Decimal.zero;
  final multiplier = (iv / 100) * math.sqrt(dte / 365);
  return spot * Decimal.parse(multiplier.toStringAsFixed(10));
}

/// How many standard deviations away the spot price currently sits from the
/// strike: `|strike - spot| / oneSigmaMove`. Dimensionless, so `double` is
/// the right type (`docs/conventions.md` §1's Greeks/IV allowance) — but the
/// division is guarded: a null or zero [oneSigmaMove] (S-011's `dte <= 0`
/// rows) returns `null` rather than `Infinity`.
double? cushionSigmas({
  required Decimal strike,
  required Decimal spot,
  required Decimal? oneSigmaMove,
}) {
  if (oneSigmaMove == null || oneSigmaMove == Decimal.zero) return null;
  return (strike - spot).abs().toDouble() / oneSigmaMove.toDouble();
}

/// Intrinsic value: `max(0, spot - strike)` for a call, `max(0, strike -
/// spot)` for a put. Null when there is no current [spot] to compare
/// against (no snapshot yet) — [strike] is always known (a fixed leg field).
Decimal? intrinsic({
  required OptionType optionType,
  required Decimal strike,
  required Decimal? spot,
}) {
  if (spot == null) return null;
  final diff = optionType == OptionType.call ? spot - strike : strike - spot;
  return diff > Decimal.zero ? diff : Decimal.zero;
}

/// Time value remaining: `currentMark - intrinsic`. Null when either input
/// is missing.
Decimal? extrinsic({required Decimal? currentMark, required Decimal? intrinsic}) {
  if (currentMark == null || intrinsic == null) return null;
  return currentMark - intrinsic;
}

/// `|deltaAsEntered|` — convention-independent by construction (never
/// branches on `DeltaConvention` before taking the absolute value; see
/// `docs/conventions.md` §2 and S-009's four quadrants).
double? deltaMagnitude(double? deltaAsEntered) => deltaAsEntered?.abs();
