import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import '../models/snapshot.dart';
import 'formulas.dart' as formulas;
import 'iv_resolution.dart';

/// Everything `classify()` needs to decide a [Bucket]. Every field is
/// nullable except [dte] — Feature Invariant 7: `dte` is always computable
/// from `expiration`/`now`, even with zero snapshots recorded, so it is the
/// one input that is never "missing".
///
/// [capturedPct] must be computed from the **current leg only**, never
/// cycle-cumulative credit (Feature Invariant 1) — `classify()` itself just
/// consumes whatever the caller puts here; that contract is enforced by the
/// caller (`lib/state/positions/`, Phase 4), not by this struct or by
/// `classify()`.
class TriageInput {
  final Decimal? capturedPct;
  final double? deltaMagnitude;
  final double? iv;
  final int dte;
  final Decimal? extrinsic;

  /// Whether this leg's owner is willing to be assigned rather than roll
  /// (`docs/brief-ledger.md` §3.3, Phase 16). Non-nullable, defaulting to
  /// `true` so every pre-Iteration-4 call site/test keeps compiling and
  /// keeps its old behavior unchanged. Gate 2 branches on this: `true`
  /// keeps today's `assign` verdict; `false` redirects to `roll` instead
  /// (Feature Invariant 30).
  final bool acceptsAssignment;

  const TriageInput({
    this.capturedPct,
    this.deltaMagnitude,
    this.iv,
    required this.dte,
    this.extrinsic,
    this.acceptsAssignment = true,
  });
}

/// The one assembly of a [TriageInput] from a leg and its latest reading
/// (Pro Wave 1 D-17, S-227). Three callers share it — the positions list,
/// the position detail sheet, and Record's pre-save preview — so a preview
/// cannot drift from a live classification.
///
/// [dte] is passed in rather than derived here because the two live callers
/// already compute it from their own reference date (Feature Invariant 7:
/// classification's DTE is always `expiration - now`, never a backdated
/// snapshot's own `takenAt`), and the preview passes real `now` for the same
/// reason.
///
/// A null [snapshot] is a normal state, not an error: every derived figure
/// is null and only [dte] and [acceptsAssignment] are known. IV still
/// resolves through [resolveIv] in that case, so a leg opened at a known
/// high IV keeps its own IV for Gate 3 (Feature Invariant 18) rather than
/// silently dropping to the profile default.
TriageInput triageInputFor({required Leg leg, required Snapshot? snapshot, required int dte}) {
  if (snapshot == null) {
    return TriageInput(
      iv: resolveIv(snapshot: null, leg: leg).value,
      dte: dte,
      acceptsAssignment: leg.acceptsAssignment,
    );
  }
  final captured = formulas.capturedPct(
    openCredit: leg.openCreditPerShare,
    currentMark: snapshot.optionMark,
  );
  final deltaMag = formulas.deltaMagnitude(snapshot.deltaAsEntered);
  final intrinsicValue = formulas.intrinsic(
    optionType: leg.optionType,
    strike: leg.strike,
    spot: snapshot.underlyingPrice,
  );
  final extrinsicValue = formulas.extrinsic(currentMark: snapshot.optionMark, intrinsic: intrinsicValue);
  return TriageInput(
    capturedPct: captured,
    deltaMagnitude: deltaMag,
    iv: resolveIv(snapshot: snapshot, leg: leg).value,
    dte: dte,
    extrinsic: extrinsicValue,
    acceptsAssignment: leg.acceptsAssignment,
  );
}
