import 'package:decimal/decimal.dart';

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
