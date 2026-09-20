/// The five-way triage verdict (brief §1/§4.3, plus brief-followup A4's
/// `unknown` correction). Bucket names are neutral verbs only — `Close`,
/// `Roll`, `Assign`, `Leave` — never a severity label; `unknown` is the one
/// deliberate exception, carrying **no verb** at all (label "No data") since
/// it represents the absence of any evaluation, not a verdict (Feature
/// Invariant 19). Every variant carries the [reason] that fired it; there is
/// no constructor path that omits one, so "a bare verdict" cannot compile
/// (`docs/conventions.md` §4).
///
/// A plain sealed class rather than `@freezed`, matching `RuleProfile`'s
/// reasoning: `Bucket` is never persisted or JSON-serialized, so no codegen
/// is needed to get value equality — `==`/`hashCode`/`toString` are
/// hand-written below instead.
sealed class Bucket {
  final String reason;

  const Bucket({required this.reason});

  const factory Bucket.close({required String reason}) = BucketClose;
  const factory Bucket.roll({required String reason}) = BucketRoll;
  const factory Bucket.assign({required String reason}) = BucketAssign;
  const factory Bucket.leave({required String reason}) = BucketLeave;

  /// Returned iff `capturedPct == null && deltaMagnitude == null` — in this
  /// codebase, exactly "no snapshot exists yet" (Feature Invariant 19).
  /// Replaces the original brief's erroneous `Bucket.leave` fallback for
  /// this case (a spec error, not an implementation bug — supersedes
  /// S-010, see S-042).
  const factory Bucket.unknown({required String reason}) = BucketUnknown;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bucket && other.runtimeType == runtimeType && other.reason == reason);

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  @override
  String toString() => '$runtimeType(reason: $reason)';
}

final class BucketClose extends Bucket {
  const BucketClose({required super.reason});
}

final class BucketRoll extends Bucket {
  const BucketRoll({required super.reason});
}

final class BucketAssign extends Bucket {
  const BucketAssign({required super.reason});
}

final class BucketLeave extends Bucket {
  const BucketLeave({required super.reason});
}

final class BucketUnknown extends Bucket {
  const BucketUnknown({required super.reason});
}
