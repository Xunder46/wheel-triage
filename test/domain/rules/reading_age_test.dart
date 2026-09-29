import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/reading_age.dart';

Snapshot _snapshot({required String id, required DateTime takenAt}) => Snapshot(
  id: id,
  legId: 'leg-$id',
  takenAt: takenAt,
  optionMark: Decimal.parse('1.00'),
  underlyingPrice: Decimal.parse('20.00'),
  deltaAsEntered: -0.25,
  deltaConvention: DeltaConvention.position,
);

void main() {
  final now = DateTime.utc(2026, 9, 28, 12, 0);

  group('S-224: reading age and the needs-a-reading predicate', () {
    test('kAgingDays is 7', () {
      expect(kAgingDays, 7);
    });

    test('no snapshot -> needs a reading, and is not in the aging count', () {
      expect(needsReading(latestSnapshot: null, now: now), isTrue);
      expect(olderThanAging(latestSnapshot: null, now: now), isFalse);
    });

    test('taken 1 hour ago -> does not need a reading', () {
      final s = _snapshot(id: 'a', takenAt: now.subtract(const Duration(hours: 1)));
      expect(needsReading(latestSnapshot: s, now: now), isFalse);
      expect(olderThanAging(latestSnapshot: s, now: now), isFalse);
    });

    test('taken today -> does not need a reading', () {
      final s = _snapshot(id: 'b', takenAt: DateTime.utc(2026, 9, 28, 9, 30));
      expect(needsReading(latestSnapshot: s, now: now), isFalse);
      expect(readingAgeDays(s, now), 0);
    });

    test('exactly 7 calendar days old is NOT counted', () {
      final s = _snapshot(id: 'c', takenAt: DateTime.utc(2026, 9, 21, 8, 0));
      expect(readingAgeDays(s, now), 7);
      expect(needsReading(latestSnapshot: s, now: now), isFalse);
      expect(olderThanAging(latestSnapshot: s, now: now), isFalse);
    });

    test('8 calendar days old IS counted', () {
      final s = _snapshot(id: 'd', takenAt: DateTime.utc(2026, 9, 20, 8, 0));
      expect(readingAgeDays(s, now), 8);
      expect(needsReading(latestSnapshot: s, now: now), isTrue);
      expect(olderThanAging(latestSnapshot: s, now: now), isTrue);
    });

    test('the five-leg fixture partitions exactly as the scenario states', () {
      final legs = <({String id, Snapshot? snapshot})>[
        (id: 'no-snapshot', snapshot: null),
        (id: 'one-hour', snapshot: _snapshot(id: 'one-hour', takenAt: now.subtract(const Duration(hours: 1)))),
        (id: 'today', snapshot: _snapshot(id: 'today', takenAt: DateTime.utc(2026, 9, 28, 9, 30))),
        (id: 'seven-days', snapshot: _snapshot(id: 'seven-days', takenAt: DateTime.utc(2026, 9, 21, 8, 0))),
        (id: 'eight-days', snapshot: _snapshot(id: 'eight-days', takenAt: DateTime.utc(2026, 9, 20, 8, 0))),
      ];

      final needs = legs.where((l) => needsReading(latestSnapshot: l.snapshot, now: now)).map((l) => l.id).toList();
      expect(needs, ['no-snapshot', 'eight-days']);

      final aging = legs.where((l) => olderThanAging(latestSnapshot: l.snapshot, now: now)).toList();
      expect(aging.map((l) => l.id).toList(), ['eight-days']);
      expect(aging, hasLength(1));
    });

    test('the aging count names the leg and its date', () {
      final s = _snapshot(id: 'eight-days', takenAt: DateTime.utc(2026, 9, 20, 8, 0));
      final line = agingLine(legs: [(ticker: 'T', snapshot: s)], now: now);
      expect(line, '1 reading older than 7 days · T, from Sep 20');
    });

    test('the aging count is overlapping -- a leg stays in its bucket count', () {
      // The predicate is a pure function of the snapshot, so nothing about
      // it can remove a leg from a bucket count; this asserts the shape the
      // caller relies on: the same leg answers both questions.
      final s = _snapshot(id: 'eight-days', takenAt: DateTime.utc(2026, 9, 20, 8, 0));
      expect(olderThanAging(latestSnapshot: s, now: now), isTrue);
      expect(needsReading(latestSnapshot: s, now: now), isTrue);
    });

    test('a future-dated reading is not aged', () {
      final s = _snapshot(id: 'future', takenAt: DateTime.utc(2026, 10, 5));
      expect(readingAgeDays(s, now), -7);
      expect(olderThanAging(latestSnapshot: s, now: now), isFalse);
    });
  });
}
