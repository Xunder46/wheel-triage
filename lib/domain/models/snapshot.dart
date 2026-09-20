import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_converters.dart';

part 'snapshot.freezed.dart';
part 'snapshot.g.dart';

/// Which sign convention `deltaAsEntered` was typed under (§3.5,
/// Feature Invariant 5). Stored once at write time, never mutated after.
enum DeltaConvention { position, option }

/// A dated reading of the numbers off the broker screen for one [Leg].
/// Snapshots are append-only history — nothing overwrites a prior snapshot.
///
/// `dte` is deliberately absent: it is always computed as
/// `expiration - takenAt.date` (`lib/domain/rules/formulas.dart`, owned by
/// @developer), never stored, so it can never go stale (§3.4).
@freezed
abstract class Snapshot with _$Snapshot {
  const factory Snapshot({
    required String id,
    required String legId,
    required DateTime takenAt,
    @DecimalJsonConverter() required Decimal optionMark,
    @DecimalJsonConverter() required Decimal underlyingPrice,
    required double deltaAsEntered,
    required DeltaConvention deltaConvention,
    double? gamma,
    double? theta,
    double? vega,
    double? iv,
    int? openInterest,
    int? volume,
  }) = _Snapshot;

  factory Snapshot.fromJson(Map<String, Object?> json) => _$SnapshotFromJson(json);
}
