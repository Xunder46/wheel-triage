import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/features/screener/screener_screen.dart';
import 'package:wheel_triage/state/repository_providers.dart';

void main() {
  testWidgets(
    '"Sorting score" label is used verbatim, and is not the largest element on screen '
    '(Acceptance Criteria; docs/conventions.md §4)',
    (tester) async {
      // A tall test surface so the whole scrollable form -- including the
      // outputs card at the bottom -- is actually built (a `ListView`'s
      // sliver mechanics only build children within the viewport/cache
      // extent, list-backed or not), not just scrolled-to.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
          child: const MaterialApp(home: ScreenerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sorting score'), findsOneWidget);
      // Never "rating" or "grade" -- see docs/conventions.md §4.
      expect(find.textContaining('rating', findRichText: true), findsNothing);
      expect(find.textContaining('grade', findRichText: true), findsNothing);

      final scoreLabelSize = tester.getSize(find.text('Sorting score'));
      final titleSize = tester.getSize(find.text('Outputs'));
      // The score label's own text is not larger than a plain section
      // title elsewhere on the same screen -- a crude but effective check
      // that it isn't the visually dominant element.
      expect(scoreLabelSize.height, lessThanOrEqualTo(titleSize.height + 4));

      expect(tester.takeException(), isNull);
    },
  );
}
