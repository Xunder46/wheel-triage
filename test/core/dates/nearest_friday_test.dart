import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/core/dates/nearest_friday.dart';

void main() {
  group('nearestFriday', () {
    test('already a Friday -> itself', () {
      final friday = DateTime(2026, 1, 2); // a Friday
      expect(nearestFriday(friday), friday);
    });

    test('Monday -> the previous Friday (3 days back beats 4 days forward)', () {
      final monday = DateTime(2026, 1, 5);
      expect(nearestFriday(monday), DateTime(2026, 1, 2));
    });

    test('Tuesday -> the upcoming Friday (3 days forward)', () {
      final tuesday = DateTime(2026, 1, 6);
      expect(nearestFriday(tuesday), DateTime(2026, 1, 9));
    });

    test('Sunday -> the previous Friday (2 days back)', () {
      final sunday = DateTime(2026, 1, 4);
      expect(nearestFriday(sunday), DateTime(2026, 1, 2));
    });
  });

  group('S-054: defaultExpiration -- Friday nearest today+37, inside [30,45]', () {
    test('a Wednesday reference date (distinct no-Friday-collision case)', () {
      final wednesday = DateTime(2026, 1, 7);
      final result = defaultExpiration(wednesday);
      expect(isFriday(result), isTrue);
      final daysOut = result.difference(wednesday).inDays;
      expect(daysOut, inInclusiveRange(30, 45));
      expect(daysOut, closeTo(37, 4));
    });

    test('every weekday as "today" -> default always inside [30,45] and a Friday', () {
      for (var i = 0; i < 7; i++) {
        final today = DateTime(2026, 2, 2).add(Duration(days: i)); // Mon..Sun
        final result = defaultExpiration(today);
        expect(isFriday(result), isTrue);
        final daysOut = result.difference(today).inDays;
        expect(daysOut, inInclusiveRange(30, 45));
      }
    });
  });

  group('isFriday', () {
    test('true for a Friday, false otherwise', () {
      expect(isFriday(DateTime(2026, 1, 2)), isTrue);
      expect(isFriday(DateTime(2026, 1, 7)), isFalse);
    });
  });
}
