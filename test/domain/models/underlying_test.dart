import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/underlying.dart';

void main() {
  group('Underlying round-trip (S-030)', () {
    test('all optional fields null', () {
      const underlying = Underlying(id: 'u1', ticker: 'SBET');

      final json = underlying.toJson();
      final restored = Underlying.fromJson(json);

      expect(restored, underlying);
      expect(restored.displayName, isNull);
      expect(restored.notes, isNull);
    });

    test('all optional fields populated', () {
      const underlying = Underlying(
        id: 'u2',
        ticker: 'SBET',
        displayName: 'Sportsbet Inc',
        notes: 'watch earnings date',
      );

      final json = underlying.toJson();
      final restored = Underlying.fromJson(json);

      expect(restored, underlying);
      expect(restored.displayName, 'Sportsbet Inc');
      expect(restored.notes, 'watch earnings date');
    });
  });
}
