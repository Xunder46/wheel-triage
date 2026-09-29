import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/theme/app_theme.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/widgets/bucket_badge.dart';

/// D-5: the badge's five states in both themes, generated and compared on
/// the Mac only.
Widget _wrap(Bucket bucket, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    backgroundColor: theme.scaffoldBackgroundColor,
    body: Center(child: BucketBadge(bucket: bucket)),
  ),
);

/// The five states, each with the reason it would carry in the app (the
/// badge shows the label only, but the reason is what the real caller
/// supplies, so the fixture is not a fiction).
final _states = <(String, Bucket)>[
  ('close', Bucket.close(reason: '55% of credit captured')),
  ('roll', Bucket.roll(reason: 'Delta 0.32 at or above the 0.30 band')),
  ('assign', Bucket.assign(reason: 'Delta 0.75 at or above 0.70')),
  ('leave', Bucket.leave(reason: 'Delta 0.15 below the 0.30 band')),
  ('unknown', Bucket.unknown(reason: 'No snapshot yet')),
];

void main() {
  group('S-218: bucket badge goldens, five states x two themes', () {
    for (final (themeName, theme) in <(String, ThemeData)>[
      ('dark', darkTheme),
      ('light', lightTheme),
    ]) {
      for (final (stateName, bucket) in _states) {
        testWidgets('$stateName in the $themeName theme', (tester) async {
          await tester.pumpWidget(_wrap(bucket, theme));
          await expectLater(
            find.byType(BucketBadge),
            matchesGoldenFile('bucket_badge_${stateName}_$themeName.png'),
          );
        });
      }
    }

    // The goldens catch a palette drift; these pin the two things the
    // goldens alone would let through as "looks fine" (D-4, Feature
    // Invariant 19) without needing an image diff to say why.
    testWidgets('Assign is painted from its own token, never the error role', (tester) async {
      for (final theme in [darkTheme, lightTheme]) {
        final buckets = theme.extension<BucketColors>()!;
        await tester.pumpWidget(_wrap(Bucket.assign(reason: 'Delta 0.75 at or above 0.70'), theme));
        // `MaterialApp` cross-fades a theme change over 200ms, and the second
        // iteration of this loop is a change; settle so the assertions read
        // the theme they name rather than a half-lerped one.
        await tester.pumpAndSettle();
        final container = tester.widget<Container>(
          find.descendant(of: find.byType(BucketBadge), matching: find.byType(Container)),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, buckets.assignFill);
        expect(decoration.color, isNot(theme.colorScheme.error));
        expect(decoration.color, isNot(theme.colorScheme.errorContainer));
        expect(
          (tester.widget<Text>(find.byType(Text)).style!).color,
          buckets.assignInk,
        );
      }
    });

    testWidgets('"No data" has no fill, muted ink, and a dashed outline', (tester) async {
      for (final theme in [darkTheme, lightTheme]) {
        final buckets = theme.extension<BucketColors>()!;
        await tester.pumpWidget(_wrap(Bucket.unknown(reason: 'No snapshot yet'), theme));
        await tester.pumpAndSettle();
        final container = tester.widget<Container>(
          find.descendant(of: find.byType(BucketBadge), matching: find.byType(Container)),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, isNull, reason: 'No data keeps no fill');
        expect(
          (tester.widget<Text>(find.byType(Text)).style!).color,
          buckets.noDataInk,
        );
        // The dashed outline is a painter, not a `Border`, precisely so it
        // cannot be mistaken for `Leave`'s solid pill (Feature Invariant 19).
        expect(decoration.border, isNull);
        expect(
          find.descendant(
            of: find.byType(BucketBadge),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
        );
      }
    });

    testWidgets('the light theme draws the pill hairline; the dark theme does not', (tester) async {
      for (final (theme, expectEdge) in [(darkTheme, false), (lightTheme, true)]) {
        final buckets = theme.extension<BucketColors>()!;
        expect(buckets.pillEdge.a, expectEdge ? greaterThan(0) : 0);
        await tester.pumpWidget(_wrap(Bucket.close(reason: '55% of credit captured'), theme));
        expect(find.byType(BucketBadge), findsOneWidget);
      }
    });
  });
}
