import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/features/export/export_reminder_banner.dart';

void main() {
  group('ExportReminderBanner (S-160): pure presentation', () {
    testWidgets('renders nothing when not visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExportReminderBanner(visible: false, onDismiss: () {})),
        ),
      );
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('renders the banner with a Dismiss action when visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExportReminderBanner(visible: true, onDismiss: () {})),
        ),
      );
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('tapping Dismiss invokes onDismiss exactly once', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExportReminderBanner(visible: true, onDismiss: () => dismissed++)),
        ),
      );
      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      expect(dismissed, 1);
    });
  });
}
