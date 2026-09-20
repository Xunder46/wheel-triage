import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/share_lot.dart';

void main() {
  group('ShareLot round-trip (S-030)', () {
    // ShareLot has no optional fields (Feature Invariant 12: raw facts
    // only) — one round-trip case covers the whole shape.
    test('round-trips exactly', () {
      final shareLot = ShareLot(
        id: 'sl1',
        cycleId: 'c1',
        assignedAt: DateTime.utc(2026, 3, 1),
        assignmentStrike: Decimal.parse('50.00'),
        contracts: 1,
      );

      final json = shareLot.toJson();
      final restored = ShareLot.fromJson(json);

      expect(restored, shareLot);
      expect(restored.assignmentStrike, Decimal.parse('50.00'));
    });
  });
}
