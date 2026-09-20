import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';

void main() {
  group('Snapshot round-trip (S-030)', () {
    test('all optional fields null', () {
      final snapshot = Snapshot(
        id: 's1',
        legId: 'l1',
        takenAt: DateTime.utc(2026, 2, 10),
        optionMark: Decimal.parse('0.3000'),
        underlyingPrice: Decimal.parse('46.00'),
        deltaAsEntered: -0.25,
        deltaConvention: DeltaConvention.position,
      );

      final json = snapshot.toJson();
      final restored = Snapshot.fromJson(json);

      expect(restored, snapshot);
      expect(restored.gamma, isNull);
      expect(restored.theta, isNull);
      expect(restored.vega, isNull);
      expect(restored.iv, isNull);
      expect(restored.openInterest, isNull);
      expect(restored.volume, isNull);
    });

    test('all optional fields populated', () {
      final snapshot = Snapshot(
        id: 's2',
        legId: 'l1',
        takenAt: DateTime.utc(2026, 2, 21),
        optionMark: Decimal.parse('0.2700'),
        underlyingPrice: Decimal.parse('9.29'),
        deltaAsEntered: -0.2534,
        deltaConvention: DeltaConvention.option,
        gamma: 0.05,
        theta: -0.01,
        vega: 0.03,
        iv: 87.61,
        openInterest: 1200,
        volume: 340,
      );

      final json = snapshot.toJson();
      final restored = Snapshot.fromJson(json);

      expect(restored, snapshot);
      expect(restored.deltaConvention, DeltaConvention.option);
      expect(restored.iv, 87.61);
    });
  });
}
