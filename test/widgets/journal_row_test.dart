import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

    testWidgets(
      'fee-incomplete -- "Before fees" replaces the net result value',
      (tester) async {
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
      },
    );
  });

  // S-313 / A-7: the row stopped being a `ListTile` to let it grow at
  // `kMaxTextScale`. `ListTile` set `Semantics(button: true)` from `onTap`
  // alone; an `InkWell` sets only the tap action, so these pin the role the
  // rewrite could have dropped.
  group('S-313 / A-7: the rewritten row keeps the tile\'s behaviour', () {
    Widget row({VoidCallback? onTap}) => _wrap(
      JournalRowTile(
        ticker: 'AAA',
        outcome: WheelCycleOutcome.expiredWorthless,
        legCount: 1,
        pnl: _pnl(),
        onTap: onTap,
      ),
    );

    testWidgets('a tap fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(row(onTap: () => taps++));
      await tester.tap(find.byType(JournalRowTile));
      expect(taps, 1);
    });

    testWidgets('the row is announced as a button carrying the tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(row(onTap: () {}));

      final data = tester
          .getSemantics(find.byType(JournalRowTile))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    testWidgets('the tap target is at least 48dp tall', (tester) async {
      await tester.pumpWidget(row(onTap: () {}));
      expect(
        tester.getSize(find.byType(JournalRowTile)).height,
        greaterThanOrEqualTo(48.0),
      );
    });
  });
}
