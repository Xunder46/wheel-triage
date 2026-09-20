import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/domain/rules/cycle_pnl.dart';
import 'package:wheel_triage/widgets/cycle_summary_card.dart';

CyclePnl _pnl({bool hasFeeGap = false, int feeGapCount = 0}) => CyclePnl(
  totalPremium: Decimal.parse('280.00'),
  totalFees: Decimal.parse('5.20'),
  stockPnL: Decimal.parse('400.00'),
  netResult: Decimal.parse('674.80'),
  daysHeld: 73,
  rollCount: 2,
  peakCapitalCommitted: Decimal.parse('10000.00'),
  returnOnCapitalPct: 6.748,
  annualisedReturnPct: 33.74,
  hasFeeGap: hasFeeGap,
  feeGapCount: feeGapCount,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  // S-131: one closed-cycle summary card, one open-cycle (unrealised)
  // summary card -- the unrealised card's qualifier must be visibly present
  // and visually distinct from the closed card's real net figure.
  group('S-131: golden test -- cycle summary card, open and closed variants', () {
    testWidgets('closed cycle -- real net result, no qualifier', (tester) async {
      await tester.pumpWidget(
        _wrap(CycleSummaryCard(pnl: _pnl(), isClosed: true, outcomeLabel: 'calledAway')),
      );
      expect(find.text('Unrealised, excludes closing costs'), findsNothing);
      expect(find.text('\$674.80'), findsOneWidget);
      await expectLater(
        find.byType(CycleSummaryCard),
        matchesGoldenFile('goldens/cycle_summary_card_closed.png'),
      );
    });

    testWidgets('open cycle -- "Unrealised, excludes closing costs" qualifier present', (tester) async {
      await tester.pumpWidget(_wrap(CycleSummaryCard(pnl: _pnl(), isClosed: false)));
      expect(find.text('Unrealised, excludes closing costs'), findsOneWidget);
      await expectLater(
        find.byType(CycleSummaryCard),
        matchesGoldenFile('goldens/cycle_summary_card_open.png'),
      );
    });
  });

  testWidgets(
    'S-121: fee-incomplete CLOSED cycle renders "Before fees" naming the exact count, '
    'never a real net result',
    (tester) async {
      await tester.pumpWidget(
        _wrap(CycleSummaryCard(pnl: _pnl(hasFeeGap: true, feeGapCount: 1), isClosed: true)),
      );
      expect(find.text('Before fees -- 1 leg missing fee data'), findsOneWidget);
      expect(find.text('\$674.80'), findsNothing); // never shown as though fees were zero
    },
  );

  testWidgets(
    'S-126: an open cycle never shows "Before fees", even if hasFeeGap were somehow true -- '
    'only the unrealised qualifier',
    (tester) async {
      await tester.pumpWidget(
        _wrap(CycleSummaryCard(pnl: _pnl(hasFeeGap: true, feeGapCount: 1), isClosed: false)),
      );
      expect(find.textContaining('Before fees'), findsNothing);
      expect(find.text('Unrealised, excludes closing costs'), findsOneWidget);
    },
  );

  testWidgets('S-129: "Peak capital committed" label, never a bare "Capital committed"', (tester) async {
    await tester.pumpWidget(_wrap(CycleSummaryCard(pnl: _pnl(), isClosed: true)));
    expect(find.text('Peak capital committed'), findsOneWidget);
    expect(find.text('Capital committed'), findsNothing);
  });
}
