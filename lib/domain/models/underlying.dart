import 'package:freezed_annotation/freezed_annotation.dart';

part 'underlying.freezed.dart';
part 'underlying.g.dart';

/// A traded symbol the user runs the wheel on. Plain data — no derived
/// fields, no business logic.
@freezed
abstract class Underlying with _$Underlying {
  const factory Underlying({
    required String id,
    required String ticker,
    String? displayName,
    String? notes,
  }) = _Underlying;

  factory Underlying.fromJson(Map<String, Object?> json) => _$UnderlyingFromJson(json);
}
