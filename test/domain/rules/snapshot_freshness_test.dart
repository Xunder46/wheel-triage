import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/rules/snapshot_freshness.dart';

void main() {
  group('S-141: freshnessOf -- calendar-boundary matrix (Feature Invariant 33)', () {
    final now = DateTime(2026, 3, 15, 12, 0, 0);

    test('now - 35min -> fresh', () {
      expect(
        freshnessOf(takenAt: now.subtract(const Duration(minutes: 35)), now: now),
        Freshness.fresh,
      );
    });

    test('now - 3h, same calendar date -> recent', () {
      expect(
        freshnessOf(takenAt: now.subtract(const Duration(hours: 3)), now: now),
        Freshness.recent,
      );
    });

    test("now's previous calendar date -> old", () {
      // 13h back crosses midnight (now is 12:00) onto the previous calendar
      // date without landing inside the <1hr fresh window.
      expect(
        freshnessOf(takenAt: now.subtract(const Duration(hours: 13)), now: now),
        Freshness.old,
      );
    });

    test('now - 2 calendar days -> stale', () {
      expect(
        freshnessOf(takenAt: now.subtract(const Duration(days: 2)), now: now),
        Freshness.stale,
      );
    });

    test('boundary: exactly 1 hour elapsed is no longer fresh', () {
      expect(
        freshnessOf(takenAt: now.subtract(const Duration(hours: 1)), now: now),
        isNot(Freshness.fresh),
      );
    });
  });
}
