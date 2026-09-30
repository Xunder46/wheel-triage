import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/widgets/label_value_row.dart';

/// S-318: the one label/value row, in its four call shapes, at every scale the
/// wave certifies.
///
/// The row's contract is geometric, so the assertions are: below
/// [LabelValueRow.stackAtScale] the label and the value overlap vertically
/// (one line, the shipped shape); at and above it the value's top is at or
/// below the label's bottom (stacked, nothing truncated). No exception at any
/// scale, and no ellipsis in the widget's source.
const _scales = [1.0, 1.5, 2.0, 2.5, 3.2];

const _longLabel = 'Extrinsic remaining';
const _longValue = r'$1,234.56';

void main() {
  Future<void> pumpRow(WidgetTester tester, Widget row, double scale) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Align(alignment: Alignment.topLeft, child: row),
          ),
        ),
      ),
    );
  }

  void expectShareALine(WidgetTester tester, String label, String value) {
    final labelRect = tester.getRect(find.text(label));
    final valueRect = tester.getRect(find.text(value));
    expect(
      labelRect.top < valueRect.bottom && valueRect.top < labelRect.bottom,
      isTrue,
      reason:
          'expected "$label" and "$value" to share a line '
          '(label $labelRect, value $valueRect)',
    );
  }

  void expectStacked(WidgetTester tester, String label, String value) {
    final labelRect = tester.getRect(find.text(label));
    final valueRect = tester.getRect(find.text(value));
    expect(
      valueRect.top,
      greaterThanOrEqualTo(labelRect.bottom - 0.01),
      reason:
          'expected "$value" below "$label" '
          '(label $labelRect, value $valueRect)',
    );
  }

  group('S-318 the four call shapes', () {
    testWidgets('plain (the journal stat)', (tester) async {
      for (final scale in _scales) {
        await pumpRow(
          tester,
          const LabelValueRow(label: _longLabel, value: _longValue),
          scale,
        );
        expect(tester.takeException(), isNull, reason: 'at $scale');
        if (scale < LabelValueRow.stackAtScale) {
          expectShareALine(tester, _longLabel, _longValue);
        } else {
          expectStacked(tester, _longLabel, _longValue);
        }
      }
    });

    testWidgets('with a helpTopicId (the screener output row)', (tester) async {
      for (final scale in _scales) {
        await pumpRow(
          tester,
          const LabelValueRow(
            label: _longLabel,
            value: _longValue,
            helpTopicId: 'extrinsic',
          ),
          scale,
        );
        expect(tester.takeException(), isNull, reason: 'at $scale');
        if (scale < LabelValueRow.stackAtScale) {
          expectShareALine(tester, _longLabel, _longValue);
        } else {
          expectStacked(tester, _longLabel, _longValue);
        }
      }
    });

    testWidgets('with trailing (the detail sheet row)', (tester) async {
      for (final scale in _scales) {
        await pumpRow(
          tester,
          const LabelValueRow(
            label: _longLabel,
            value: _longValue,
            trailing: Text('trailing'),
          ),
          scale,
        );
        expect(tester.takeException(), isNull, reason: 'at $scale');
        expect(find.text('trailing'), findsOneWidget);
        if (scale < LabelValueRow.stackAtScale) {
          expectShareALine(tester, _longLabel, _longValue);
        } else {
          expectStacked(tester, _longLabel, _longValue);
        }
      }
    });

    testWidgets('with emphasize (the cycle summary row)', (tester) async {
      for (final scale in _scales) {
        await pumpRow(
          tester,
          const LabelValueRow(
            label: _longLabel,
            value: _longValue,
            emphasize: true,
          ),
          scale,
        );
        expect(tester.takeException(), isNull, reason: 'at $scale');
        if (scale < LabelValueRow.stackAtScale) {
          expectShareALine(tester, _longLabel, _longValue);
        } else {
          expectStacked(tester, _longLabel, _longValue);
        }
      }
    });

    testWidgets('stacked is forced below the threshold (S-144\'s roll band)', (
      tester,
    ) async {
      await pumpRow(
        tester,
        const LabelValueRow(
          label: _longLabel,
          value: _longValue,
          stacked: true,
        ),
        1.0,
      );
      expect(tester.takeException(), isNull);
      expectStacked(tester, _longLabel, _longValue);
    });
  });

  test('S-318 the row truncates nothing', () {
    final source = File('lib/widgets/label_value_row.dart').readAsStringSync();
    expect(source.contains('TextOverflow.ellipsis'), isFalse);
    expect(source.contains('TextOverflow.clip'), isFalse);
    expect(source.contains('maxLines'), isFalse);
  });
}
