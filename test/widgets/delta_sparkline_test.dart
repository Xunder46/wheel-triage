import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/widgets/delta_sparkline.dart';

// Code review finding (auto-fix pass): DeltaSparkline had no dedicated
// widget test. Covers empty/single-point/multi-point per the finding's
// "at minimum" list -- a render-without-throwing assertion, no goldens.

Widget _wrap(List<double> values) => MaterialApp(home: Scaffold(body: DeltaSparkline(values: values)));

void main() {
  group('DeltaSparkline', () {
    testWidgets('empty data renders the "no snapshots yet" state without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const []));

      expect(find.byType(DeltaSparkline), findsOneWidget);
      expect(find.text('No snapshots yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single point renders the "not enough history" state without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const [0.25]));

      expect(find.byType(DeltaSparkline), findsOneWidget);
      expect(find.text('Not enough history yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple points render the painted line without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const [0.10, 0.35, -0.20, 0.05]));

      expect(find.byType(DeltaSparkline), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
