// D-46: the five bucket counts and their order come from one shared source,
// so Today's filter chips and Portfolio's read-only tiles cannot drift.

import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/domain/rules/bucket.dart';

void main() {
  group('D-46: the five bucket counts come from one shared source', () {
    test('the order is Assign, Roll, Close, Leave, No data', () {
      expect(
        kBucketOrder.map(bucketLabel).toList(),
        ['Assign', 'Roll', 'Close', 'Leave', 'No data'],
      );
      expect(
        kBucketOrder.map((bucket) => bucket.runtimeType).toList(),
        [BucketAssign, BucketRoll, BucketClose, BucketLeave, BucketUnknown],
      );
    });

    test('every bucket gets an entry, including the zeros', () {
      final counts = bucketCountsFor(const [
        BucketAssign(reason: 'captured 95%'),
        BucketAssign(reason: 'captured 80%'),
        BucketUnknown(reason: 'no snapshot'),
      ]);
      expect(counts.map((row) => row.count).toList(), [2, 0, 0, 0, 1]);
    });

    test('an empty book is five zeros, so the row of chips never collapses', () {
      final counts = bucketCountsFor(const []);
      expect(counts, hasLength(5));
      expect(counts.map((row) => row.count).toList(), [0, 0, 0, 0, 0]);
    });

    test('the entry is the prototype, so a label can be read off it', () {
      final counts = bucketCountsFor(const [BucketRoll(reason: 'delta 0.32')]);
      expect(counts.map((row) => bucketLabel(row.bucket)).toList(), [
        'Assign',
        'Roll',
        'Close',
        'Leave',
        'No data',
      ]);
      expect(counts[1].count, 1);
    });

    test('the reason a leg carried does not split its count', () {
      final counts = bucketCountsFor(const [
        BucketClose(reason: 'captured 50%'),
        BucketClose(reason: 'captured 50%'),
        BucketClose(reason: 'captured 62%'),
      ]);
      expect(counts[2].count, 3);
    });
  });
}
