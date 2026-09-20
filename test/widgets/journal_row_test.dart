import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/domain/rules/cycle_pnl.dart';
import 'package:wheel_triage/widgets/journal_row.dart';

CyclePnl _pnl({bool hasFeeGap = false}) => CyclePnl(
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
  feeGapCount: hasFeeGap ? 1 : 0,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // S-130: one journal row per outcome, plus one fee-incomplete row.
  group('S-130: golden test -- journal row', () {
    testWidgets('expiredWorthless', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JournalRowTile(
            ticker: 'AAA',
            outcome: WheelCycleOutcome.expiredWorthless,
            legCount: 1,
            pnl: _pnl(),
          ),
        ),
      );
      await expectLater(
        find.byType(JournalRowTile),
        matchesGoldenFile('goldens/journal_row_expired_worthless.png'),
      );
    });

    testWidgets('closedEarly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JournalRowTile(
            ticker: 'BBB',
            outcome: WheelCycleOutcome.closedEarly,
            legCount: 1,
            pnl: _pnl(),
          ),
        ),
      );
      await expectLater(
        find.byType(JournalRowTile),
        matchesGoldenFile('goldens/journal_row_closed_early.png'),
      );
    });

    testWidgets('calledAway', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JournalRowTile(
            ticker: 'CCC',
            outcome: WheelCycleOutcome.calledAway,
            legCount: 4,
            pnl: _pnl(),
          ),
        ),
      );
      await expectLater(
        find.byType(JournalRowTile),
        matchesGoldenFile('goldens/journal_row_called_away.png'),
      );
    });

    testWidgets('fee-incomplete -- "Before fees" replaces the net result value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JournalRowTile(
            ticker: 'DDD',
            outcome: WheelCycleOutcome.calledAway,
            legCount: 2,
            pnl: _pnl(hasFeeGap: true),
          ),
        ),
      );
      expect(find.text('Before fees'), findsOneWidget);
      await expectLater(
        find.byType(JournalRowTile),
        matchesGoldenFile('goldens/journal_row_fee_incomplete.png'),
      );
    });
  });
}
