import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';

void main() {
  group('WheelCycle round-trip (S-030)', () {
    test('all optional fields null', () {
      final cycle = WheelCycle(
        id: 'c1',
        underlyingId: 'u1',
        startedAt: DateTime.utc(2026, 1, 1),
        status: WheelCycleStatus.sellingPuts,
      );

      final json = cycle.toJson();
      final restored = WheelCycle.fromJson(json);

      expect(restored, cycle);
      expect(restored.endedAt, isNull);
      expect(restored.outcome, isNull);
    });

    test('all optional fields populated', () {
      final cycle = WheelCycle(
        id: 'c2',
        underlyingId: 'u1',
        startedAt: DateTime.utc(2026, 1, 1),
        endedAt: DateTime.utc(2026, 2, 1),
        status: WheelCycleStatus.closed,
        outcome: WheelCycleOutcome.calledAway,
      );

      final json = cycle.toJson();
      final restored = WheelCycle.fromJson(json);

      expect(restored, cycle);
      expect(restored.endedAt, DateTime.utc(2026, 2, 1));
      expect(restored.outcome, WheelCycleOutcome.calledAway);
    });
  });
}
