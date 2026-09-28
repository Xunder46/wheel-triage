import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/rules/cycle_pnl.dart';
import 'package:wheel_triage/state/journal/journal_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';

final _now = DateTime(2026, 3, 1);

Future<String> _closedPutCycle(
  InMemoryWheelRepository repo, {
  required String ticker,
  required DateTime openedAt,
  required DateTime closedAt,
  required Decimal openCredit,
  required Decimal closeDebit,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('50'),
      expiration: openedAt.add(const Duration(days: 30)),
      contracts: 1,
      openedAt: openedAt,
      openCreditPerShare: openCredit,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.closeLeg(
    legId: result.leg.id,
    reason: closeDebit == Decimal.zero ? CloseReason.expiredWorthless : CloseReason.closedEarly,
    closeDebitPerShare: closeDebit,
    closedAt: closedAt,
  );
  return result.cycle.id;
}

void main() {
  test('S-096/S-127: journal row shape -- newest-endedAt-first, correct per-row figures', () async {
    final repo = InMemoryWheelRepository();
    // Two closed cycles with distinct tickers/durations/outcomes; an open
    // cycle must never appear.
    await _closedPutCycle(
      repo,
      ticker: 'OLD',
      openedAt: DateTime.utc(2026, 1, 1),
      closedAt: DateTime.utc(2026, 1, 20),
      openCredit: Decimal.parse('0.50'),
      closeDebit: Decimal.zero, // expired worthless
    );
    await _closedPutCycle(
      repo,
      ticker: 'NEW',
      openedAt: DateTime.utc(2026, 2, 1),
      closedAt: DateTime.utc(2026, 2, 15),
      openCredit: Decimal.parse('0.40'),
      closeDebit: Decimal.parse('0.60'), // closed early at a debit
    );
    // An open cycle -- must be excluded from the journal entirely.
    final openUnderlying = await repo.getOrCreateUnderlying('OPEN');
    await repo.createCycle(
      underlyingId: openUnderlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('40'),
        expiration: _now.add(const Duration(days: 20)),
        contracts: 1,
        openedAt: _now,
        openCreditPerShare: Decimal.parse('0.30'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    container.listen(journalControllerProvider, (previous, next) {});
    await container.read(journalControllerProvider.notifier).load(now: _now);

    final state = container.read(journalControllerProvider);
    expect(state.rows, hasLength(2)); // the open cycle is excluded
    expect(state.rows.map((r) => r.ticker).toList(), ['NEW', 'OLD']); // newest endedAt first
    expect(state.rows.first.pnl.daysHeld, 14); // Feb 1 -> Feb 15
    expect(state.rows.first.pnl.netResult, Decimal.parse('-20.00')); // (0.40-0.60) x 100 x 1
  });

  test(
    'S-113/S-128: journal aggregates render the correct computed values '
    '(win rate excludes an exactly-zero cycle)',
    () async {
      final repo = InMemoryWheelRepository();
      await _closedPutCycle(
        repo,
        ticker: 'AAA',
        openedAt: DateTime.utc(2026, 1, 1),
        closedAt: DateTime.utc(2026, 1, 11),
        openCredit: Decimal.parse('0.50'),
        closeDebit: Decimal.zero, // net +$50 -> a win
      );
      await _closedPutCycle(
        repo,
        ticker: 'BBB',
        openedAt: DateTime.utc(2026, 1, 1),
        closedAt: DateTime.utc(2026, 1, 11),
        openCredit: Decimal.parse('0.50'),
        closeDebit: Decimal.parse('0.50'), // net $0 -> NOT a win
      );
      await _closedPutCycle(
        repo,
        ticker: 'CCC',
        openedAt: DateTime.utc(2026, 1, 1),
        closedAt: DateTime.utc(2026, 1, 11),
        openCredit: Decimal.parse('0.20'),
        closeDebit: Decimal.parse('0.50'), // net -$30 -> a loss
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(journalControllerProvider, (previous, next) {});
      await container.read(journalControllerProvider.notifier).load(now: _now);

      final aggregates = container.read(journalControllerProvider).aggregates;
      expect(aggregates.winRate, closeTo(1 / 3, 1e-9)); // only AAA is a win
      expect(aggregates.averageDaysInCycle, 10);
      expect(aggregates.netResultByUnderlying['AAA'], Decimal.parse('50.00'));
      expect(aggregates.netResultByUnderlying['BBB'], Decimal.parse('0.00'));
      expect(aggregates.netResultByUnderlying['CCC'], Decimal.parse('-30.00'));
      expect(aggregates.rollCountDistribution, {0: 3}); // none of these rolled
    },
  );

  test(
    'CR-1: an open cycle and the same cycle after call-away report identical '
    'assignment-derived figures (the guard the defect class needs)',
    () async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('EQV');
      final putLeg = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50.00'),
          expiration: DateTime.utc(2026, 3, 20),
          contracts: 1,
          openedAt: DateTime.utc(2026, 2, 1),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      // Recorded at values the assigned leg does not hold -- the whole point
      // of CR-1: `assignmentStrike`/`contracts` are user-entered, so a
      // reconstruction from the leg is not equivalent to the record.
      final assignment = await repo.recordAssignment(
        legId: putLeg.leg.id,
        shareLot: NewShareLotInput(
          assignedAt: DateTime.utc(2026, 3, 20),
          assignmentStrike: Decimal.parse('49.50'),
          contracts: 2,
        ),
      );
      final cycleId = assignment.cycle.id;
      final callLeg = await repo.openNextLeg(
        cycleId: cycleId,
        leg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('52.00'),
          expiration: DateTime.utc(2026, 4, 17),
          contracts: 1,
          openedAt: DateTime.utc(2026, 3, 21),
          openCreditPerShare: Decimal.parse('0.55'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      // While open: the live ShareLot is what the position sheet uses.
      final openPnl = computeCyclePnl(
        legs: await repo.getLegsForCycle(cycleId),
        shareLot: await repo.getShareLotForCycle(cycleId),
        startedAt: assignment.cycle.startedAt,
        now: _now,
      );

      await repo.recordCallAway(legId: callLeg.id, closedAt: DateTime.utc(2026, 4, 17));

      final container =
          ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(journalControllerProvider, (previous, next) {});
      await container.read(journalControllerProvider.notifier).load(now: _now);

      final closedPnl = container.read(journalControllerProvider).rows.single.pnl;

      // 49.50 x 100 x 2 = 9900 commitment less the 120 put premium = 9780,
      // which beats the put leg's own 50 x 100 x 1 = 5000.
      expect(openPnl.peakCapitalCommitted, Decimal.parse('9780.00'));
      // The assignment-derived figure must be identical before and after the
      // cycle closes -- this is the part CR-1 corrupted, because the open
      // path reads the live ShareLot while the closed path used to
      // reconstruct from the leg.
      expect(closedPnl.peakCapitalCommitted, openPnl.peakCapitalCommitted);
      // `netResult` (and therefore return on capital) is NOT invariant, and
      // must not be asserted equal: a still-open cycle has no realized stock
      // P&L yet, since `stockPnL` only exists once the call is assigned
      // (`netResult` 175 while open, 425 after call-away -- stockPnL =
      // (52 - 49.50) x 100 x 1 = 250.00, the put-side strike sourced from
      // the retained assignment record, not the put leg's own 50.00
      // (Feature Invariant 36 / S-207)). Only the assignment-derived
      // denominator is shared between the two states.
      expect(closedPnl.netResult, Decimal.parse('425.00'));
      expect(closedPnl.returnOnCapitalPct, closeTo(4.35, 0.01));
    },
  );
}
