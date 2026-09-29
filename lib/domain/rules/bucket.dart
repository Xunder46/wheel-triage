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

/// The neutral-verb display label for [bucket] — `Close`/`Roll`/`Assign`/
/// `Leave`, and `No data` for [BucketUnknown] (Feature Invariant 19).
///
/// One definition, so the label cannot drift between the badge, Today's
/// count chips and the preview's change line.
String bucketLabel(Bucket bucket) => switch (bucket) {
  BucketClose() => 'Close',
  BucketRoll() => 'Roll',
  BucketAssign() => 'Assign',
  BucketLeave() => 'Leave',
  BucketUnknown() => 'No data',
};

/// The one bucket order (D-46): Assign, Roll, Close, Leave, No data.
///
/// Today's filter chips and Portfolio's read-only tiles are two renderings of
/// the same five counts, so the order lives here rather than in each screen —
/// otherwise a leg can sit under `Roll` on one screen and `Close` on the
/// other. Each entry is a **prototype**: it exists so a caller can read
/// [bucketLabel] off it and so the count list always has five rows, never to
/// be shown as a verdict. The empty reason is what makes them `const`;
/// nothing renders it, because a count row renders the label, not the reason.
const List<Bucket> kBucketOrder = [
  BucketAssign(reason: ''),
  BucketRoll(reason: ''),
  BucketClose(reason: ''),
  BucketLeave(reason: ''),
  BucketUnknown(reason: ''),
];

/// The five bucket counts, in [kBucketOrder], **including the zeros** — an
/// empty book is five zeros rather than an empty list, so a row of filter
/// chips never collapses as the book empties.
///
/// Counting is by [Bucket]'s runtime type, not by its reason: two legs that
/// both landed in `Close` for different reasons are one count. Each row
/// carries [kBucketOrder]'s own prototype, so the label comes from the same
/// place the order does.
List<({Bucket bucket, int count})> bucketCountsFor(Iterable<Bucket> buckets) {
  final byType = <Type, int>{};
  for (final bucket in buckets) {
    byType.update(bucket.runtimeType, (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    for (final bucket in kBucketOrder) (bucket: bucket, count: byType[bucket.runtimeType] ?? 0),
  ];
}
