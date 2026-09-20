import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/rules/formulas.dart';

void main() {
  group('S-009: four delta sign quadrants (required test #5)', () {
    // Description, deltaAsEntered, expected deltaMagnitude. All
    // magnitude-only, convention-independent -- deltaMagnitude never
    // branches on DeltaConvention before taking the absolute value
    // (docs/conventions.md §2).
    const rows = <(String, double, double)>[
      ('short call, entered -0.35', -0.35, 0.35),
      ('short call, entered +0.35', 0.35, 0.35),
      ('short put, entered +0.28', 0.28, 0.28),
      ('short put, entered -0.28', -0.28, 0.28),
    ];

    for (final (description, enteredDelta, expectedMagnitude) in rows) {
      test('$description -> deltaMagnitude $expectedMagnitude', () {
        expect(deltaMagnitude(enteredDelta), expectedMagnitude);
      });
    }
  });
}
