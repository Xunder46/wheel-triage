// Pro Wave 3 D-47..D-52: the month the share card covers, its five figures,
// and the copy the card renders. The screen, the capture and the share are
// Phase 3's; this file pins the arithmetic and the wording.

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/disclaimer.dart';
import 'package:wheel_triage/core/format.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/domain/rules/cycle_pnl.dart';
import 'package:wheel_triage/domain/rules/premium_collected.dart';
import 'package:wheel_triage/domain/rules/share_card.dart';

final _now = DateTime.utc(2026, 9, 28);

Leg _leg({
  required String id,
  String openCreditPerShare = '1.00',
  String? closeDebitPerShare,
  DateTime? closedAt,
}) => Leg(
  id: id,
  cycleId: 'cycle-$id',
  sequence: 0,
  optionType: OptionType.put,
  strike: Decimal.parse('20.00'),
  expiration: DateTime.utc(2026, 9, 19),
  contracts: 1,
  openedAt: DateTime.utc(2026, 8, 1),
  openCreditPerShare: Decimal.parse(openCreditPerShare),
  closedAt: closedAt ?? DateTime.utc(2026, 9, 15),
  closeDebitPerShare: closeDebitPerShare == null ? null : Decimal.parse(closeDebitPerShare),
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

/// A closed leg whose premium capture is exactly [capture]%: `$1.00` in, and a
/// close debit of what is left over.
Leg _legAtCapture(String id, int capture) => _leg(
  id: id,
  closeDebitPerShare: ((100 - capture) / 100).toStringAsFixed(2),
);

WheelCycle _cycle({
  required String id,
  DateTime? endedAt,
  WheelCycleStatus status = WheelCycleStatus.closed,
}) => WheelCycle(
  id: id,
  underlyingId: 'underlying-$id',
  startedAt: DateTime.utc(2026, 8, 1),
  endedAt: endedAt,
  status: status,
);

CyclePnl _pnl({
  required String netResult,
  required String peakCapital,
  required int daysHeld,
  bool hasFeeGap = false,
  int feeGapCount = 0,
}) => CyclePnl(
  totalPremium: Decimal.parse('100.00'),
  totalFees: Decimal.zero,
  stockPnL: Decimal.zero,
  netResult: Decimal.parse(netResult),
  daysHeld: daysHeld,
  rollCount: 0,
  peakCapitalCommitted: Decimal.parse(peakCapital),
  returnOnCapitalPct: 0,
  hasFeeGap: hasFeeGap,
  feeGapCount: feeGapCount,
);

ShareCardCycle _card(
  String ticker, {
  required String netResult,
  required String peakCapital,
  required int daysHeld,
  required int capture,
  bool hasFeeGap = false,
  int feeGapCount = 0,
  DateTime? endedAt,
}) => (
  cycle: _cycle(id: 'cycle-$ticker', endedAt: endedAt ?? DateTime.utc(2026, 9, 15)),
  ticker: ticker,
  legs: [_legAtCapture('$ticker-1', capture)],
  pnl: _pnl(
    netResult: netResult,
    peakCapital: peakCapital,
    daysHeld: daysHeld,
    hasFeeGap: hasFeeGap,
    feeGapCount: feeGapCount,
  ),
);

/// A cycle with no legs and a zero P&L, for the month-membership cases where
/// only the dates matter.
ShareCardCycle _dated(String ticker, DateTime? endedAt, {WheelCycleStatus status = WheelCycleStatus.closed}) => (
  cycle: _cycle(id: 'cycle-$ticker', endedAt: endedAt, status: status),
  ticker: ticker,
  legs: const [],
  pnl: _pnl(netResult: '0', peakCapital: '0', daysHeld: 0),
);

void main() {
  // S-306's fixture: the reference card's own arithmetic, adopted verbatim.
  final month = <ShareCardCycle>[
    _card('BAC', netResult: '32', peakCapital: '3800', daysHeld: 24, capture: 95, hasFeeGap: true, feeGapCount: 2),
    _card('CCL', netResult: '35', peakCapital: '6250', daysHeld: 31, capture: 88),
    _card('KO', netResult: '-30', peakCapital: '4000', daysHeld: 18, capture: 82, hasFeeGap: true, feeGapCount: 1),
    _card('SNAP', netResult: '110', peakCapital: '7000', daysHeld: 35, capture: 61),
    _card('UBER', netResult: '210', peakCapital: '1800', daysHeld: 27, capture: 40),
  ];

  /// The same month with every closed leg carrying a fee — no gap anywhere.
  final monthWithFees = <ShareCardCycle>[
    _card('BAC', netResult: '32', peakCapital: '3800', daysHeld: 24, capture: 95),
    _card('CCL', netResult: '35', peakCapital: '6250', daysHeld: 31, capture: 88),
    _card('KO', netResult: '-30', peakCapital: '4000', daysHeld: 18, capture: 82),
    _card('SNAP', netResult: '110', peakCapital: '7000', daysHeld: 35, capture: 61),
    _card('UBER', netResult: '210', peakCapital: '1800', daysHeld: 27, capture: 40),
  ];

  group('S-305: which cycles are in the card\'s month (D-47)', () {
    final august = _dated('AUG', DateTime.utc(2026, 8, 31));
    final first = _dated('FIRST', DateTime.utc(2026, 9, 1));
    final middle = _dated('MIDDLE', DateTime.utc(2026, 9, 15));
    final last = _dated('LAST', DateTime.utc(2026, 9, 30));
    final closedWithNoEnd = _dated('NOEND', null);
    final stillOpen = _dated('OPEN', null, status: WheelCycleStatus.sellingPuts);

    final book = [august, first, middle, last, closedWithNoEnd, stillOpen];

    test('the month is the one containing now, the same period the premium tile uses', () {
      final period = cardMonthPeriod(_now);
      expect(period.start, DateTime.utc(2026, 9, 1));
      expect(period.end, DateTime.utc(2026, 9, 30));
      expect(period.start, monthPeriodContaining(_now).start);
      expect(period.end, monthPeriodContaining(_now).end);
    });

    test('the 1st, the 15th and the 30th are in; the previous month\'s last day is out', () {
      expect(
        cyclesInCardMonth(cycles: book, now: _now).map((cycle) => cycle.ticker).toList(),
        ['FIRST', 'MIDDLE', 'LAST'],
      );
    });

    test('both ends are inclusive, and the boundary is a calendar month', () {
      expect(inCardMonth(cycle: first.cycle, now: _now), isTrue);
      expect(inCardMonth(cycle: last.cycle, now: _now), isTrue);
      expect(inCardMonth(cycle: august.cycle, now: _now), isFalse);
    });

    test('a closed cycle with no endedAt is in no month, and never throws', () {
      expect(inCardMonth(cycle: closedWithNoEnd.cycle, now: _now), isFalse);
      expect(inCardMonth(cycle: closedWithNoEnd.cycle, now: DateTime.utc(2026, 8, 15)), isFalse);
      expect(inCardMonth(cycle: closedWithNoEnd.cycle, now: DateTime.utc(2026, 10, 1)), isFalse);
      expect(cyclesInCardMonth(cycles: [closedWithNoEnd], now: _now), isEmpty);
    });

    test('a cycle that is not closed is out, even when it carries an end date', () {
      expect(inCardMonth(cycle: stillOpen.cycle, now: _now), isFalse);
    });

    test('a later month holds none of September\'s cycles', () {
      final october = cyclesInCardMonth(cycles: book, now: DateTime.utc(2026, 10, 1));
      expect(october.map((cycle) => cycle.ticker).toList(), isEmpty);
    });
  });

  group('S-306: the card\'s five figures (D-48, D-49)', () {
    test('the five figures are the reference\'s own arithmetic', () {
      final figures = shareCardFigures(month);
      expect(figures.returnOnCapitalPct, closeTo(1.5624, 0.001));
      expect(percentText(figures.returnOnCapitalPct), '1.6%');
      expect(figures.cyclesClosed, 5);
      expect(figures.closedPositive, 4);
      expect(figures.closedPositiveText, '4 of 5');
      expect(figures.averageDaysInCycle, 27);
      expect(figures.medianPremiumCapturePct, closeTo(82, 1e-9));
      expect(percentText(figures.medianPremiumCapturePct, decimals: 0), '82%');
    });

    test('the return is the sum over the sum, not a mean of per-cycle returns', () {
      // 357 / 22,850 = 1.5627%. A mean of the five per-cycle returns would be
      // 2.78%, which is what a per-cycle average would put on the card.
      final figures = shareCardFigures(month);
      expect(percentText(figures.returnOnCapitalPct), '1.6%');

      final perCycle = month
          .map((cycle) => cycle.pnl.netResult.toDouble() / cycle.pnl.peakCapitalCommitted.toDouble() * 100)
          .toList();
      final mean = perCycle.reduce((a, b) => a + b) / perCycle.length;
      expect(percentText(mean), '2.8%');
      expect(percentText(figures.returnOnCapitalPct), isNot(percentText(mean)));
    });

    test('the capture figure is a median: the mean would read 73.2%', () {
      final figures = shareCardFigures(month);
      expect(percentText(figures.medianPremiumCapturePct, decimals: 0), isNot('73%'));
      expect(percentText(73.2), '73.2%');
    });

    test('a cycle closing at exactly zero is not "positive"', () {
      final figures = shareCardFigures([_card('Z', netResult: '0', peakCapital: '1000', daysHeld: 10, capture: 50)]);
      expect(figures.closedPositive, 0);
      expect(figures.closedPositiveText, '0 of 1');
    });

    test('a month whose cycles carry no peak capital reads 0.0%, never NaN', () {
      final zeroDenominator = [
        _card('A', netResult: '10', peakCapital: '0', daysHeld: 10, capture: 50),
        _card('B', netResult: '-5', peakCapital: '0', daysHeld: 20, capture: 70),
      ];
      final figures = shareCardFigures(zeroDenominator);
      expect(figures.returnOnCapitalPct, 0.0);
      expect(figures.returnOnCapitalPct.isNaN, isFalse);
      expect(percentText(figures.returnOnCapitalPct), '0.0%');
    });

    test('a month whose legs carry no capture reads "--", never 0%', () {
      final noCapture = [
        (
          cycle: _cycle(id: 'cycle-NONE', endedAt: DateTime.utc(2026, 9, 15)),
          ticker: 'NONE',
          legs: [_leg(id: 'none-1', openCreditPerShare: '0')],
          pnl: _pnl(netResult: '12', peakCapital: '2000', daysHeld: 12),
        ),
      ];
      final figures = shareCardFigures(noCapture);
      expect(figures.medianPremiumCapturePct, isNull);
      expect(percentText(figures.medianPremiumCapturePct, decimals: 0), '--');
    });

    test('an empty month has no average and no median, and never a zero claim', () {
      final figures = shareCardFigures(const []);
      expect(figures.cyclesClosed, 0);
      expect(figures.closedPositive, 0);
      expect(figures.averageDaysInCycle, isNull);
      expect(figures.medianPremiumCapturePct, isNull);
      expect(percentText(figures.medianPremiumCapturePct, decimals: 0), '--');
    });
  });

  group('S-307: "Before fees" appears only when there is a gap (D-50)', () {
    test('the month sums the per-cycle gap', () {
      expect(monthFeeGap(month), (hasFeeGap: true, feeGapCount: 3));
    });

    test('a month with no gap has neither half', () {
      expect(monthFeeGap(monthWithFees), (hasFeeGap: false, feeGapCount: 0));
    });

    test('the clause names the count, with a leading space', () {
      expect(beforeFeesClause(hasFeeGap: true, feeGapCount: 3), ' Before fees: 3 closed legs have no fee recorded.');
    });

    test('one leg missing a fee is singular', () {
      expect(beforeFeesClause(hasFeeGap: true, feeGapCount: 1), ' Before fees: 1 closed leg has no fee recorded.');
    });

    test('with no gap the clause is absent, never "Fees included"', () {
      expect(beforeFeesClause(hasFeeGap: false, feeGapCount: 0), '');
      expect(beforeFeesClause(hasFeeGap: false, feeGapCount: 3), '');
    });

    test('the definition paragraph carries the clause, and drops it entirely with no gap', () {
      final gapped = shareCardDefinitionLine(monthYear: monthYearText(DateTime.utc(2026, 9, 1)), cycles: month);
      expect(
        gapped,
        'Return on capital: net result ÷ peak capital committed, over cycles closed in September 2026. '
        'Before fees: 3 closed legs have no fee recorded.',
      );

      final clean = shareCardDefinitionLine(monthYear: monthYearText(DateTime.utc(2026, 9, 1)), cycles: monthWithFees);
      expect(
        clean,
        'Return on capital: net result ÷ peak capital committed, over cycles closed in September 2026.',
      );
      expect(clean.toLowerCase(), isNot(contains('fee')));
    });

    test('the net-result line carries the same count', () {
      expect(netResultLine(cycles: month), contains('3 closed legs have no fee recorded'));
    });
  });

  group('D-52: the two optional lines', () {
    test('the net-result line is two decimals, then the gap clause', () {
      expect(netResultLine(cycles: month), r'Net result $357.00 before fees Before fees: 3 closed legs have no fee recorded.');
    });

    test('with no gap it stops at "before fees"', () {
      expect(netResultLine(cycles: monthWithFees), r'Net result $357.00 before fees');
    });

    test('the ticker line is the month\'s tickers, A-Z and deduplicated', () {
      expect(cardTickerLine(month), 'BAC · CCL · KO · SNAP · UBER');
    });

    test('a ticker on two cycles appears once', () {
      final doubled = [
        _card('BAC', netResult: '32', peakCapital: '3800', daysHeld: 24, capture: 95),
        _card('BAC', netResult: '12', peakCapital: '1900', daysHeld: 12, capture: 60),
      ];
      expect(cardTickerLine(doubled), 'BAC');
    });

    test('an empty month renders no ticker line at all', () {
      expect(cardTickerLine(const []), '');
    });

    test('the tickers are derived from the month\'s cycles, never stored', () {
      expect(cardTickerLine([month[2]]), 'KO');
    });
  });

  group('S-312: the card\'s copy (D-54)', () {
    final copy = [
      shareCardDefinitionLine(monthYear: monthYearText(DateTime.utc(2026, 9, 1)), cycles: month),
      netResultLine(cycles: month),
      cardTickerLine(month),
    ];

    test('no banned word appears in any line the card renders', () {
      final banned = RegExp(
        'recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should',
        caseSensitive: false,
      );
      for (final line in [...copy, kAppDisclaimer]) {
        expect(banned.hasMatch(line), isFalse, reason: line);
      }
    });

    test('no praise, streak, badge or comparison', () {
      for (final line in [...copy, kAppDisclaimer]) {
        final lower = line.toLowerCase();
        for (final word in ['streak', 'badge', 'congrat', 'great', 'keep it up', "you're", 'your best']) {
          expect(lower.contains(word), isFalse, reason: '$word in "$line"');
        }
      }
    });

    test('the definition paragraph states the definition on the card', () {
      expect(copy.first, contains('Return on capital: net result ÷ peak capital committed'));
    });

    test('the footer Phase 3 renders is the app\'s own disclaimer, unparaphrased', () {
      expect(kAppDisclaimer, contains('journal and calculator'));
      expect(kAppDisclaimer, contains('It is not investment advice.'));
    });
  });
}
