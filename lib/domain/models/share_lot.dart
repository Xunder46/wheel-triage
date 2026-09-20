import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_converters.dart';

part 'share_lot.freezed.dart';
part 'share_lot.g.dart';

/// 100 x contracts shares, created on put-side assignment (§3.6).
///
/// Raw facts only, per Feature Invariant 12 — `wheelBasis` and `taxBasis`
/// are NEVER persisted here or anywhere. Both are computed live from
/// `assignmentStrike` plus the owning cycle's leg history every time they
/// are displayed (`lib/domain/rules/basis.dart`, owned by @developer),
/// because `wheelBasis` genuinely changes as more calls are sold.
@freezed
abstract class ShareLot with _$ShareLot {
  const factory ShareLot({
    required String id,
    required String cycleId,
    required DateTime assignedAt,
    @DecimalJsonConverter() required Decimal assignmentStrike,
    required int contracts,
  }) = _ShareLot;

  factory ShareLot.fromJson(Map<String, Object?> json) => _$ShareLotFromJson(json);
}
