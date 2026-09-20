import 'package:decimal/decimal.dart';

import 'bucket.dart';
import 'rule_profile.dart';
import 'triage_input.dart';

/// Bucket classification — gates fire in order, first match wins (brief
/// §4.3, Feature Invariant 1, `docs/conventions.md` §3). **This order is
/// load-bearing and must never be reordered without a precedence test**:
/// profit target -> assignment -> roll band -> tail -> fallback leave.
///
/// An earlier draft of these rules put the roll band before the assignment
/// check. Because the roll band (0.30-0.40) is *lower* than the assignment
/// threshold (0.70), a delta of 0.85 matched the roll gate first and the
/// assignment branch was unreachable dead code — see S-006.
Bucket classify(TriageInput input, RuleProfile profile) {
  // Gate 0 -- no snapshot at all (brief-followup A4, Feature Invariant 19).
  // Distinguished from the "valid data, nothing fired" `leave` fallback
  // below: this is "nothing has been evaluated", not a verdict. In this
  // codebase this condition is exactly "no snapshot exists yet" --
  // `Snapshot.optionMark`/`Snapshot.deltaAsEntered` are both non-nullable,
  // so any existing snapshot always yields a non-null `deltaMagnitude`.
  if (input.capturedPct == null && input.deltaMagnitude == null) {
    return const Bucket.unknown(reason: 'No snapshot yet');
  }

  // Gate 1 -- profit target. Checked continuously, independent of DTE.
  // Exact Decimal comparison (docs/conventions.md §1) -- never a float
  // epsilon hack.
  final capturedPct = input.capturedPct;
  if (capturedPct != null && capturedPct >= _decimalFromPct(profile.profitTargetPct)) {
    return Bucket.close(reason: '${capturedPct.round()}% of credit captured');
  }

  // Gate 2 -- assignment likely. MUST be checked before the roll band.
  // `docs/brief-ledger.md` §3.3 (Iteration 4): whether this branches to
  // `assign` or `roll` depends on `acceptsAssignment` -- the `roll` reason
  // string is the coordinator's own override (Feature Invariant 30), never
  // the brief's verbatim "...and you'd rather keep this position -- roll it
  // out or buy it back" (that string pairs two action verbs with "this
  // position", which is exactly the pattern `docs/conventions.md` §4 bans).
  final deltaMagnitude = input.deltaMagnitude;
  if (deltaMagnitude != null && deltaMagnitude >= profile.assignThreshold) {
    final magnitudeAndThreshold =
        'Delta ${_fmtMagnitude(deltaMagnitude)} at or above ${_fmt2(profile.assignThreshold)}';
    if (input.acceptsAssignment) {
      return Bucket.assign(reason: magnitudeAndThreshold);
    }
    return Bucket.roll(reason: "$magnitudeAndThreshold, and assignment isn't wanted here");
  }

  // Gate 3 -- strike threatened (IV-adjusted roll band).
  final band = profile.rollBandFor(input.iv);
  if (deltaMagnitude != null && deltaMagnitude >= band) {
    return Bucket.roll(
      reason: 'Delta ${_fmtMagnitude(deltaMagnitude)} at or above the ${_fmt2(band)} band',
    );
  }

  // Gate 4 -- tail. Almost nothing left to collect.
  final extrinsic = input.extrinsic;
  if (input.dte <= profile.tailDteDays &&
      extrinsic != null &&
      extrinsic <= profile.tailExtrinsicThreshold) {
    return Bucket.close(reason: 'Only ${_money(extrinsic)} of time value left');
  }

  // Fall-through -- valid data, no gate fired. `deltaMagnitude` is always
  // non-null here: the only way it could be null is the no-snapshot case,
  // already returned above by Gate 0 (Feature Invariant 19's own
  // reasoning). The original brief's null-`deltaMagnitude` ternary branch
  // is therefore unreachable for this codebase's actual call sites and has
  // been trimmed rather than left as dead defensive code.
  return Bucket.leave(
    reason: 'Delta ${_fmtMagnitude(deltaMagnitude!)} below the ${_fmt2(band)} band',
  );
}

/// Converts a `RuleProfile` percentage threshold (stored as `double`, per
/// Phase 2's Assumption Log) to an exact `Decimal` at the comparison site,
/// so Gate 1's `>=` is a true `Decimal` comparison, never a float one.
Decimal _decimalFromPct(double value) => Decimal.parse(value.toStringAsFixed(6));

/// Fixed two-decimal formatting for profile-defined thresholds (bands,
/// assign threshold) -- these are always specified to two decimal places in
/// §4.4 (e.g. `0.70`, `0.30`).
String _fmt2(double value) => value.toStringAsFixed(2);

/// Formats a magnitude (delta) at its own natural precision, trailing zeros
/// trimmed, rather than forcing every value down to two decimals -- the
/// SBET regression fixture (S-015) cites a delta of `0.2534` verbatim in its
/// reason string; rounding it to `0.25` would lose the precision that made
/// the classification traceable.
String _fmtMagnitude(double value) {
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s += '0';
  return s;
}

/// Money formatting for a reason string (`"Only \$0.03 of time value
/// left"`).
String _money(Decimal amount) => '\$${amount.toStringAsFixed(2)}';
