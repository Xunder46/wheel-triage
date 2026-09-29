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
}
