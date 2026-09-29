import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/help/help_topics.dart';
import 'package:wheel_triage/core/theme/app_theme.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/widgets/bucket_badge.dart';

// S-032's goldens predate the theme work (Stage 4A), so they are rendered
// under the app's own light theme rather than a bare `MaterialApp`. S-218's
// goldens cover the dark theme and the full token set.
Widget _wrap(Bucket bucket) => MaterialApp(
  theme: lightTheme,
  home: Scaffold(
    body: Center(child: BucketBadge(bucket: bucket)),
  ),
);

void main() {
  group('S-032: BucketBadge golden tests, all four states', () {
    testWidgets('close', (tester) async {
      await tester.pumpWidget(_wrap(Bucket.close(reason: '55% of credit captured')));
      await expectLater(
        find.byType(BucketBadge),
        matchesGoldenFile('goldens/bucket_badge_close.png'),
      );
    });

    testWidgets('roll', (tester) async {
      await tester.pumpWidget(_wrap(Bucket.roll(reason: 'Delta 0.32 at or above the 0.30 band')));
      await expectLater(
        find.byType(BucketBadge),
        matchesGoldenFile('goldens/bucket_badge_roll.png'),
      );
    });

    testWidgets('assign', (tester) async {
      await tester.pumpWidget(_wrap(Bucket.assign(reason: 'Delta 0.75 at or above 0.70')));
      await expectLater(
        find.byType(BucketBadge),
        matchesGoldenFile('goldens/bucket_badge_assign.png'),
      );
    });

    testWidgets('leave', (tester) async {
      await tester.pumpWidget(_wrap(Bucket.leave(reason: 'Delta 0.15 below the 0.30 band')));
      await expectLater(
        find.byType(BucketBadge),
        matchesGoldenFile('goldens/bucket_badge_leave.png'),
      );
    });

    // S-058: the fifth bucket state, extending this group to five. Must be
    // visibly distinct from `leave`'s golden above (Feature Invariant 19).
    testWidgets('unknown', (tester) async {
      await tester.pumpWidget(_wrap(Bucket.unknown(reason: 'No snapshot yet')));
      await expectLater(
        find.byType(BucketBadge),
        matchesGoldenFile('goldens/bucket_badge_unknown.png'),
      );
    });
  });

  group('S-083: bucket badge tap opens that bucket\'s help content', () {
    final rows = <(Bucket, String)>[
      (Bucket.close(reason: '55% of credit captured'), 'bucket_close'),
      (Bucket.roll(reason: 'Delta 0.32 at or above the 0.30 band'), 'bucket_roll'),
      (Bucket.assign(reason: 'Delta 0.75 at or above 0.70'), 'bucket_assign'),
      (Bucket.leave(reason: 'Delta 0.15 below the 0.30 band'), 'bucket_leave'),
      (Bucket.unknown(reason: 'No snapshot yet'), 'bucket_unknown'),
    ];

    for (final (bucket, topicId) in rows) {
      testWidgets('$topicId sheet shows that bucket\'s §C2 content verbatim', (tester) async {
        await tester.pumpWidget(_wrap(bucket));
        await tester.tap(find.byType(BucketBadge));
        await tester.pumpAndSettle();

        final topic = helpTopics[topicId]!;
        // The badge's own label can coincide with the sheet's title text
        // (e.g. `bucket_leave`'s "Leave", `bucket_unknown`'s "No data"), so
        // the title check allows the badge's own copy too; the body text is
        // unique to the sheet and proves it actually opened.
        expect(find.text(topic.title), findsWidgets);
        expect(find.text(topic.body), findsOneWidget);
      });
    }
  });
}
