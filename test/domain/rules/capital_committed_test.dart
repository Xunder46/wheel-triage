import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/share_lot.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/domain/rules/capital_committed.dart';

/// S-221's fixture, built exactly as the scenario enumerates it: six
/// underlyings, one of them a closed cycle with no open leg, one an open put
/// that has already passed its expiration, and two `holdingShares` cycles
/// whose share side is `wheelBasis x 100 x contracts`.
Leg _leg({
  required String id,
  required String cycleId,
  required OptionType optionType,
  required String strike,
  required int contracts,
  required DateTime expiration,
  DateTime? closedAt,
  CloseReason? closeReason,
  Decimal? openCreditPerShare,
  int sequence = 0,
}) => Leg(
  id: id,
  cycleId: cycleId,
  sequence: sequence,
  optionType: optionType,
  strike: Decimal.parse(strike),
  expiration: expiration,
  contracts: contracts,
  openedAt: DateTime.utc(2026, 8, 1),
  openCreditPerShare: openCreditPerShare ?? Decimal.parse('0.50'),
  closedAt: closedAt,
  closeReason: closeReason,
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

WheelCycle _cycle({
  required String id,
  required String underlyingId,
  required WheelCycleStatus status,
}) => WheelCycle(
  id: id,
  underlyingId: underlyingId,
  startedAt: DateTime.utc(2026, 8, 1),
  status: status,
);

void main() {
  final now = DateTime.utc(2026, 9, 28);

  group('S-221: currentCapitalCommitted -- per cycle and in total', () {
    // INTC: open put $20 x4 -> $8,000.
    final intcLeg = _leg(
      id: 'intc-1',
      cycleId: 'intc-cycle',
      optionType: OptionType.put,
      strike: '20.00',
      contracts: 4,
      expiration: DateTime.utc(2026, 10, 16),
    );
    // SOFI: open put $14 x3, expiration already passed but still open.
    final sofiLeg = _leg(
      id: 'sofi-1',
      cycleId: 'sofi-cycle',
      optionType: OptionType.put,
      strike: '14.00',
      contracts: 3,
      expiration: DateTime.utc(2026, 9, 18),
    );
    // PFE: open put $25 x1 -> $2,500.
    final pfeLeg = _leg(
      id: 'pfe-1',
      cycleId: 'pfe-cycle',
      optionType: OptionType.put,
      strike: '25.00',
      contracts: 1,
      expiration: DateTime.utc(2026, 10, 16),
    );
    // T: holdingShares, put legs netting $0.45/share at a $27 assignment,
    // one share lot x1, plus an open call.
    final tPut = _leg(
      id: 't-put',
      cycleId: 't-cycle',
      optionType: OptionType.put,
      strike: '27.00',
      contracts: 1,
      expiration: DateTime.utc(2026, 8, 21),
      closedAt: DateTime.utc(2026, 8, 21),
      closeReason: CloseReason.assigned,
      openCreditPerShare: Decimal.parse('0.45'),
    );
    final tCall = _leg(
      id: 't-call',
      cycleId: 't-cycle',
      optionType: OptionType.call,
      strike: '28.00',
      contracts: 1,
      expiration: DateTime.utc(2026, 10, 2),
      sequence: 1,
    );
    final tLot = ShareLot(
      id: 't-lot',
      cycleId: 't-cycle',
      assignedAt: DateTime.utc(2026, 8, 21),
      assignmentStrike: Decimal.parse('27.00'),
      contracts: 1,
    );
    // SBET: holdingShares, put credits $0.50 - $0.62 + $0.92, assignment
    // $11.50, lot x1.
    final sbetPut1 = _leg(
      id: 'sbet-put-1',
      cycleId: 'sbet-cycle',
      optionType: OptionType.put,
      strike: '11.50',
      contracts: 1,
      expiration: DateTime.utc(2026, 7, 17),
      closedAt: DateTime.utc(2026, 7, 17),
      closeReason: CloseReason.rolled,
      openCreditPerShare: Decimal.parse('0.50'),
    );
    final sbetPut2 = _leg(
      id: 'sbet-put-2',
      cycleId: 'sbet-cycle',
      optionType: OptionType.put,
      strike: '11.50',
      contracts: 1,
      expiration: DateTime.utc(2026, 8, 21),
      closedAt: DateTime.utc(2026, 8, 21),
      closeReason: CloseReason.assigned,
      openCreditPerShare: Decimal.parse('0.62'),
      sequence: 1,
    );
    final sbetPut3 = _leg(
      id: 'sbet-put-3',
      cycleId: 'sbet-cycle',
      optionType: OptionType.put,
      strike: '11.50',
      contracts: 1,
      expiration: DateTime.utc(2026, 8, 21),
      closedAt: DateTime.utc(2026, 8, 21),
      closeReason: CloseReason.assigned,
      openCreditPerShare: Decimal.parse('0.92'),
      sequence: 2,
    );
    final sbetLot = ShareLot(
      id: 'sbet-lot',
      cycleId: 'sbet-cycle',
      assignedAt: DateTime.utc(2026, 8, 21),
      assignmentStrike: Decimal.parse('11.50'),
      contracts: 1,
    );
    // BAC: closed cycle with no open leg -> $0.
    final bacLeg = _leg(
      id: 'bac-1',
      cycleId: 'bac-cycle',
      optionType: OptionType.put,
      strike: '40.00',
      contracts: 1,
      expiration: DateTime.utc(2026, 8, 21),
      closedAt: DateTime.utc(2026, 8, 21),
      closeReason: CloseReason.closedEarly,
    );
    // WBD: open put $11 x1 that has already been closed -> $0.
    final wbdLeg = _leg(
      id: 'wbd-1',
      cycleId: 'wbd-cycle',
      optionType: OptionType.put,
      strike: '11.00',
      contracts: 1,
      expiration: DateTime.utc(2026, 9, 18),
      closedAt: DateTime.utc(2026, 9, 18),
      closeReason: CloseReason.expiredWorthless,
    );

    final cycles = <CycleCapitalInput>[
      CycleCapitalInput(
        cycle: _cycle(id: 'intc-cycle', underlyingId: 'intc', status: WheelCycleStatus.sellingPuts),
        ticker: 'INTC',
        legs: [intcLeg],
      ),
      CycleCapitalInput(
        cycle: _cycle(id: 'sofi-cycle', underlyingId: 'sofi', status: WheelCycleStatus.sellingPuts),
        ticker: 'SOFI',
        legs: [sofiLeg],
      ),
      CycleCapitalInput(
        cycle: _cycle(id: 'pfe-cycle', underlyingId: 'pfe', status: WheelCycleStatus.sellingPuts),
        ticker: 'PFE',
        legs: [pfeLeg],
      ),
      CycleCapitalInput(
        cycle: _cycle(id: 't-cycle', underlyingId: 't', status: WheelCycleStatus.holdingShares),
        ticker: 'T',
        legs: [tPut, tCall],
        shareLot: tLot,
      ),
      CycleCapitalInput(
        cycle: _cycle(id: 'sbet-cycle', underlyingId: 'sbet', status: WheelCycleStatus.holdingShares),
        ticker: 'SBET',
        legs: [sbetPut1, sbetPut2, sbetPut3],
        shareLot: sbetLot,
      ),
      CycleCapitalInput(
        cycle: _cycle(id: 'bac-cycle', underlyingId: 'bac', status: WheelCycleStatus.closed),
        ticker: 'BAC',
        legs: [bacLeg],
      ),
      CycleCapitalInput(
        cycle: _cycle(id: 'wbd-cycle', underlyingId: 'wbd', status: WheelCycleStatus.sellingPuts),
        ticker: 'WBD',
        legs: [wbdLeg],
      ),
    ];

    test(r'INTC: open put $20 x4 -> $8,000', () {
      expect(capitalCommittedForCycle(cycles[0]), Decimal.parse('8000'));
    });

    test(r'SOFI: $4,200, included despite the passed expiration', () {
      expect(capitalCommittedForCycle(cycles[1]), Decimal.parse('4200'));
    });

    test(r'PFE: open put $25 x1 -> $2,500', () {
      expect(capitalCommittedForCycle(cycles[2]), Decimal.parse('2500'));
    });

    test('T: share side is wheelBasis x 100 x contracts', () {
      // taxBasis = 27.00 - 0.45 = 26.55; no calls since assignment, so
      // wheelBasis = 26.55 -> 26.55 x 100 x 1 = $2,655.
      expect(capitalCommittedForCycle(cycles[3]), Decimal.parse('2655'));
    });

    test('SBET: share side is wheelBasis x 100 x contracts', () {
      // taxBasis = 11.50 - (0.50 + 0.62 + 0.92) = 9.46 -> $946.
      expect(capitalCommittedForCycle(cycles[4]), Decimal.parse('946'));
    });

    test(r'BAC: a closed cycle with no open leg contributes $0', () {
      expect(capitalCommittedForCycle(cycles[5]), Decimal.zero);
    });

    test(r'WBD: an already-closed open put contributes $0', () {
      expect(capitalCommittedForCycle(cycles[6]), Decimal.zero);
    });

    test('total equals the sum of the per-cycle figures', () {
      final total = currentCapitalCommitted(cycles);
      expect(total, Decimal.parse('8000') + Decimal.parse('4200') + Decimal.parse('2500') + Decimal.parse('2655') + Decimal.parse('946'));
      expect(total, Decimal.parse('18301'));
    });

    test('the per-underlying map keys by ticker', () {
      final byUnderlying = capitalCommittedByUnderlying(cycles);
      expect(byUnderlying.keys.toSet(), {'INTC', 'SOFI', 'PFE', 'T', 'SBET', 'BAC', 'WBD'});
      expect(byUnderlying['INTC'], Decimal.parse('8000'));
      expect(byUnderlying['SOFI'], Decimal.parse('4200'));
      expect(byUnderlying['PFE'], Decimal.parse('2500'));
      expect(byUnderlying['T'], Decimal.parse('2655'));
      expect(byUnderlying['SBET'], Decimal.parse('946'));
      expect(byUnderlying['BAC'], Decimal.zero);
      expect(byUnderlying['WBD'], Decimal.zero);
    });

    test('a holdingShares cycle with no open call still counts its shares', () {
      final noCall = CycleCapitalInput(
        cycle: _cycle(id: 't-cycle', underlyingId: 't', status: WheelCycleStatus.holdingShares),
        ticker: 'T',
        legs: [tPut],
        shareLot: tLot,
      );
      expect(capitalCommittedForCycle(noCall), Decimal.parse('2655'));
    });

    test('a cycle with neither an open put leg nor a share lot contributes zero', () {
      final empty = CycleCapitalInput(
        cycle: _cycle(id: 'x-cycle', underlyingId: 'x', status: WheelCycleStatus.sellingPuts),
        ticker: 'X',
        legs: const [],
      );
      expect(capitalCommittedForCycle(empty), Decimal.zero);
    });

    test('now is a parameter and does not change the figure', () {
      expect(currentCapitalCommitted(cycles, now: now), currentCapitalCommitted(cycles));
    });
  });

  group('S-222: concentration and the limit boundary', () {
    Decimal capital(String dollars) => Decimal.parse(dollars);

    test('exactly at the limit is not flagged', () {
      final flags = concentrationFlags(
        capitalByUnderlying: {'INTC': capital('7500')},
        wheelCapital: capital('30000'),
        concentrationLimitPct: 25.0,
      );
      expect(flags, isEmpty);
    });

    test('just over the limit is flagged', () {
      final flags = concentrationFlags(
        capitalByUnderlying: {'INTC': capital('7500.01')},
        wheelCapital: capital('30000'),
        concentrationLimitPct: 25.0,
      );
      expect(flags, hasLength(1));
      expect(flags.single.ticker, 'INTC');
      expect(flags.single.percent, 25);
      expect(flags.single.limitPct, 25.0);
    });

    test('a zero-capital underlying is absent from the flag set and is 0%', () {
      final byUnderlying = {'BAC': Decimal.zero};
      final flags = concentrationFlags(
        capitalByUnderlying: byUnderlying,
        wheelCapital: capital('30000'),
        concentrationLimitPct: 25.0,
      );
      expect(flags, isEmpty);
      expect(concentrationPercent(capital: Decimal.zero, wheelCapital: capital('30000')), 0);
    });

    test('with wheelCapital == null the flag set is empty', () {
      final flags = concentrationFlags(
        capitalByUnderlying: {'INTC': capital('7500.01')},
        wheelCapital: null,
        concentrationLimitPct: 25.0,
      );
      expect(flags, isEmpty);
    });

    test('with wheelCapital == null the invite line is what renders', () {
      expect(kConcentrationInviteLine, 'Concentration per underlying appears once wheel capital is set in Settings.');
    });

    test('two exceeding underlyings are ordered largest first', () {
      final flags = concentrationFlags(
        capitalByUnderlying: {'INTC': capital('8100'), 'SOFI': capital('7800')},
        wheelCapital: capital('30000'),
        concentrationLimitPct: 25.0,
      );
      expect(flags.map((f) => f.ticker).toList(), ['INTC', 'SOFI']);
      expect(flags.map((f) => f.percent).toList(), [27, 26]);
    });

    test('percentages round to the nearest whole percent', () {
      expect(concentrationPercent(capital: capital('7500.01'), wheelCapital: capital('30000')), 25);
      expect(concentrationPercent(capital: capital('8100'), wheelCapital: capital('30000')), 27);
      expect(concentrationPercent(capital: capital('7800'), wheelCapital: capital('30000')), 26);
    });

    test('the flag line is worded as a fact', () {
      final flags = concentrationFlags(
        capitalByUnderlying: {'INTC': capital('8100')},
        wheelCapital: capital('30000'),
        concentrationLimitPct: 25.0,
      );
      expect(concentrationFlagLine(flags.single), 'INTC 27% of wheel capital · limit 25%');
    });
  });

  group('S-294: the bars\' order, fills and the limit mark (D-42)', () {
    Decimal dollars(String value) => Decimal.parse(value);

    // S-293's bookFull, per underlying: INTC $8,000, SOFI $4,200, AAL $3,000,
    // T $2,700, PFE $2,500, F $2,400, SBET $1,200, WBD $900 -- $24,900 over
    // $30,000 of wheel capital.
    final bookFull = <String, Decimal>{
      'INTC': dollars('8000'),
      'SOFI': dollars('4200'),
      'AAL': dollars('3000'),
      'T': dollars('2700'),
      'PFE': dollars('2500'),
      'F': dollars('2400'),
      'SBET': dollars('1200'),
      'WBD': dollars('900'),
    };
    final wheel = dollars('30000');

    List<({String ticker, Decimal committed, int percent})> barsOf(
      Map<String, Decimal> book, {
      Decimal? wheelCapital,
    }) => concentrationBars(
      capitalByUnderlying: book,
      wheelCapital: wheelCapital ?? wheel,
      concentrationLimitPct: 25.0,
    );

    test('the order is percent descending, ties broken by ticker A-Z', () {
      final bars = barsOf(bookFull);
      expect(bars.map((bar) => bar.ticker).toList(), ['INTC', 'SOFI', 'AAL', 'T', 'F', 'PFE', 'SBET', 'WBD']);
      expect(bars.map((bar) => bar.percent).toList(), [27, 14, 10, 9, 8, 8, 4, 3]);
    });

    test('the 8% tie puts F before PFE', () {
      final bars = barsOf(bookFull);
      final f = bars.indexWhere((bar) => bar.ticker == 'F');
      final pfe = bars.indexWhere((bar) => bar.ticker == 'PFE');
      expect(f, lessThan(pfe));
      expect(bars[f].percent, bars[pfe].percent);
    });

    test('the order is concentrationFlags\' own order where the two overlap', () {
      // Two underlyings tied above the limit: the bar order and the flag
      // order are one comparator, so they cannot disagree.
      final tied = <String, Decimal>{'PFE': dollars('3000'), 'F': dollars('3000')};
      final flags = concentrationFlags(
        capitalByUnderlying: tied,
        wheelCapital: dollars('10000'),
        concentrationLimitPct: 25.0,
      );
      expect(flags.map((flag) => flag.ticker).toList(), ['F', 'PFE']);
      expect(barsOf(tied, wheelCapital: dollars('10000')).map((bar) => bar.ticker).toList(), ['F', 'PFE']);
    });

    test('each bar carries the exact Decimal capital, not the rounded percent', () {
      final bars = barsOf(bookFull);
      expect(bars.first.committed, dollars('8000'));
      expect(bars.last.committed, dollars('900'));
    });

    test('a bar\'s percent is the shipped concentrationPercent', () {
      for (final bar in barsOf(bookFull)) {
        expect(bar.percent, concentrationPercent(capital: bar.committed, wheelCapital: wheel));
      }
    });

    test('an underlying at exactly zero is omitted from the bars', () {
      final bars = barsOf({'INTC': dollars('8000'), 'ZZZ': Decimal.zero});
      expect(bars.map((bar) => bar.ticker).toList(), ['INTC']);
    });

    test('no wheel capital is no bars at all', () {
      // Called directly rather than through barsOf: that helper's `?? wheel`
      // default cannot express an explicit null.
      expect(
        concentrationBars(capitalByUnderlying: bookFull, wheelCapital: null, concentrationLimitPct: 25.0),
        isEmpty,
      );
      expect(barsOf(bookFull, wheelCapital: Decimal.zero), isEmpty);
      expect(concentrationBars(capitalByUnderlying: const {}, wheelCapital: wheel, concentrationLimitPct: 25.0), isEmpty);
    });

    test('the track max is the limit plus a fifth', () {
      expect(concentrationTrackMaxPct(25), closeTo(30, 1e-9));
      expect(concentrationTrackMaxPct(50), closeTo(60, 1e-9));
      expect(concentrationTrackMaxPct(10), closeTo(12, 1e-9));
      expect(concentrationTrackMaxPct(100), closeTo(120, 1e-9));
    });

    test('a bar past the limit crosses the mark and one at it does not', () {
      final trackMax = concentrationTrackMaxPct(25);
      final mark = 25 / trackMax;
      double fill(String capital) =>
          concentrationRatio(capital: dollars(capital), wheelCapital: wheel)!.toDouble() / trackMax;

      // INTC sits at 26.67% of wheel capital and crosses the mark.
      expect(fill('8000'), greaterThan(mark));
      // Exactly at the limit: equal is not a breach, so the fill stops at the mark.
      expect(fill('7500'), closeTo(mark, 1e-12));
      expect(fill('7500') > mark, isFalse);
      // A book a cent over the limit is over it, even though it rounds to 25%.
      expect(concentrationPercent(capital: dollars('7500.01'), wheelCapital: wheel), 25);
      expect(fill('7500.01'), greaterThan(mark));
    });

    test('a bar at exactly the limit is absent from the flags but present in the bars', () {
      final book = <String, Decimal>{'INTC': dollars('7500'), 'F': dollars('2400')};
      expect(
        concentrationFlags(capitalByUnderlying: book, wheelCapital: wheel, concentrationLimitPct: 25.0),
        isEmpty,
      );
      expect(
        barsOf(book).map((bar) => bar.ticker).toList(),
        ['INTC', 'F'],
      );
    });
  });

  group('S-294: the limit key line (D-42)', () {
    test('it reads the limit and the track max in one sentence', () {
      expect(concentrationKeyLine(25), 'Limit 25% · bars run to 30%');
    });

    test('a whole limit renders without a trailing decimal', () {
      expect(concentrationKeyLine(30), 'Limit 30% · bars run to 36%');
      expect(concentrationKeyLine(50), 'Limit 50% · bars run to 60%');
      expect(concentrationKeyLine(100), 'Limit 100% · bars run to 120%');
    });

    test('a fractional limit keeps its fraction on both numbers', () {
      expect(concentrationKeyLine(12.5), 'Limit 12.5% · bars run to 15%');
      expect(concentrationKeyLine(7.5), 'Limit 7.5% · bars run to 9%');
    });
  });

  group('S-293: Portfolio\'s committed definition (D-42)', () {
    Decimal dollars(String value) => Decimal.parse(value);

    test('with no past-expiration leg it is the shipped sentence, unchanged', () {
      expect(
        portfolioCommittedDefinition(
          committedNow: dollars('24900'),
          wheelCapital: dollars('30000'),
          pastExpirationTickers: const [],
        ),
        committedNowDefinition(committedNow: dollars('24900'), wheelCapital: dollars('30000')),
      );
      expect(
        portfolioCommittedDefinition(
          committedNow: dollars('24900'),
          wheelCapital: dollars('30000'),
          pastExpirationTickers: const [],
        ),
        'Committed now: open puts at strike, shares at wheel-adjusted basis; '
        '83% of your \$30,000 wheel capital.',
      );
    });

    test('past-expiration legs are named, A-Z and deduplicated', () {
      expect(
        portfolioCommittedDefinition(
          committedNow: dollars('24900'),
          wheelCapital: dollars('30000'),
          pastExpirationTickers: const ['WBD', 'AAL', 'WBD'],
        ),
        'Committed now: open puts at strike, shares at wheel-adjusted basis; '
        '83% of your \$30,000 wheel capital. '
        'Includes AAL and WBD, past expiration and not yet recorded.',
      );
    });

    test('one past-expiration leg reads as one name', () {
      expect(
        portfolioCommittedDefinition(
          committedNow: dollars('24900'),
          wheelCapital: dollars('30000'),
          pastExpirationTickers: const ['AAL'],
        ),
        endsWith(' Includes AAL, past expiration and not yet recorded.'),
      );
    });

    test('with no wheel capital the percentage half is absent and the naming still holds', () {
      expect(
        portfolioCommittedDefinition(
          committedNow: dollars('24900'),
          wheelCapital: null,
          pastExpirationTickers: const ['AAL', 'WBD'],
        ),
        'Committed now: open puts at strike, shares at wheel-adjusted basis. '
        'Includes AAL and WBD, past expiration and not yet recorded.',
      );
    });
  });
}
