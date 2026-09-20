import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/help/help_topics.dart';
import 'package:wheel_triage/widgets/help_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('S-080: HelpChip opens a bottom sheet, not a tooltip', () {
    testWidgets('tap opens a modal bottom sheet with title, definition, "Where to find it"', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const HelpChip(topicId: 'option_mark')));

      expect(find.byType(Tooltip), findsNothing);

      await tester.tap(find.byType(HelpChip));
      await tester.pumpAndSettle();

      final topic = helpTopics['option_mark']!;
      expect(find.text(topic.title), findsOneWidget);
      expect(find.text(topic.body), findsOneWidget);
      expect(find.text('Where to find it'), findsOneWidget);
      expect(find.text(topic.whereToFind!), findsOneWidget);
    });

    testWidgets('dismissible by tap-outside', (tester) async {
      await tester.pumpWidget(_wrap(const HelpChip(topicId: 'option_mark')));
      await tester.tap(find.byType(HelpChip));
      await tester.pumpAndSettle();

      expect(find.text('Where to find it'), findsOneWidget);

      // Tap outside the sheet (top of the screen, above the modal).
      await tester.tapAt(const Offset(400, 50));
      await tester.pumpAndSettle();

      expect(find.text('Where to find it'), findsNothing);
    });
  });

  group('S-081: HelpChip accessibility', () {
    testWidgets('Semantics(button: true, label: "Help: Delta") present on the chip', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const HelpChip(topicId: 'delta')));

      final semantics = tester.getSemantics(find.byType(HelpChip));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.label, 'Help: Delta');

      handle.dispose();
    });

    testWidgets(
      "the opened sheet's content is reachable by screen-reader traversal "
      '(no ExcludeSemantics swallowing the sheet text)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(const HelpChip(topicId: 'delta')));
        await tester.tap(find.byType(HelpChip));
        await tester.pumpAndSettle();

        final topic = helpTopics['delta']!;

        // A real traversal of the currently visible semantics tree, as
        // assistive technology would perform it -- not merely a lookup of
        // one widget's own isolated semantics node. If any ancestor
        // (e.g. an `ExcludeSemantics`) had cut the sheet's content out of
        // the accessibility tree, neither node would appear here at all,
        // regardless of order.
        final traversal = tester.semantics.simulatedAccessibilityTraversal();
        expect(
          traversal,
          containsAllInOrder(<Matcher>[
            isSemantics(label: topic.title),
            isSemantics(label: topic.body),
          ]),
        );

        handle.dispose();
      },
    );
  });
}
