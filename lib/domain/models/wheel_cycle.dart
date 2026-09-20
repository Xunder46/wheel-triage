import 'package:freezed_annotation/freezed_annotation.dart';

part 'wheel_cycle.freezed.dart';
part 'wheel_cycle.g.dart';

/// Where a cycle currently sits in the wheel loop (§3.2).
enum WheelCycleStatus { sellingPuts, holdingShares, closed }

/// How a closed cycle ended (§3.2). `abandoned` has no trigger in this run's
/// UI (Feature Invariant 15) — it exists in the schema for forward
/// compatibility only.
enum WheelCycleOutcome { expiredWorthless, closedEarly, calledAway, abandoned }

/// One full loop on an [Underlying]: put -> (assignment) -> calls ->
/// (called away). Plain data — cycle-ending transitions are orchestrated by
/// `WheelRepository` write methods, never mutated ad hoc by callers.
@freezed
abstract class WheelCycle with _$WheelCycle {
  const factory WheelCycle({
    required String id,
    required String underlyingId,
    required DateTime startedAt,
    DateTime? endedAt,
    required WheelCycleStatus status,
    WheelCycleOutcome? outcome,
  }) = _WheelCycle;

  factory WheelCycle.fromJson(Map<String, Object?> json) => _$WheelCycleFromJson(json);
}
