// S-154: CSV export of closed cycles -- column set matches the journal
// row. Reuses the exact fixture shape (and confirmed figures) from
// test/state/journal/journal_controller_test.dart's S-096/S-127 case, so
// the expected numbers here are cross-checked against an already-passing
// assertion of the same underlying data. Exercised against BOTH
// DriftWheelRepository and InMemoryWheelRepository (docs/conventions.md §6
// parity requirement).

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/data/db/app_database.dart';
import 'package:wheel_triage/data/db/drift_wheel_repository.dart';
import 'package:wheel_triage/data/export/ledger_csv.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('DriftWheelRepository', () {
    _runTests(() => DriftWheelRepository(AppDatabase(NativeDatabase.memory())));
  });

  group('InMemoryWheelRepository', () {
    _runTests(InMemoryWheelRepository.new);
  });
}

Future<void> _closedPutCycle(
  WheelRepository repo, {
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
}

void _runTests(WheelRepository Function() createRepository) {
  test('S-154: CSV columns match the journal row, newest-endedAt-first, '
      'decimal dollars not cents', () async {
    final repo = createRepository();

    // Same two fixtures (and the same $50 strike) as
    // test/state/journal/journal_controller_test.dart's S-096/S-127 test,
    // whose netResult (-20.00) and daysHeld (14) for 'NEW' are already
    // independently confirmed there.
    await _closedPutCycle(
      repo,
      ticker: 'OLD',
      openedAt: DateTime.utc(2026, 1, 1),
      closedAt: DateTime.utc(2026, 1, 20),
      openCredit: Decimal.parse('0.50'),
      closeDebit: Decimal.zero, // expired worthless -> netResult $50.00
    );
    await _closedPutCycle(
      repo,
      ticker: 'NEW',
      openedAt: DateTime.utc(2026, 2, 1),
      closedAt: DateTime.utc(2026, 2, 15),
      openCredit: Decimal.parse('0.40'),
      closeDebit: Decimal.parse('0.60'), // closed early at a debit -> netResult -$20.00
    );
    // An open cycle -- must never appear in the closed-cycles CSV.
    final openUnderlying = await repo.getOrCreateUnderlying('OPEN');
    await repo.createCycle(
      underlyingId: openUnderlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('40'),
        expiration: DateTime.utc(2026, 4, 1),
        contracts: 1,
        openedAt: DateTime.utc(2026, 3, 1),
        openCreditPerShare: Decimal.parse('0.30'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );

    final csv = await buildClosedCyclesCsv(repo);
    final lines = csv.trim().split('\n');

    expect(
      lines[0],
      'ticker,duration_days,leg_count,total_premium,outcome,net_result,return_on_capital_pct',
    );
    // Newest endedAt first: NEW (Feb 15) before OLD (Jan 20). The open
    // cycle never appears.
    expect(lines, hasLength(3));
    expect(lines[1], 'NEW,14,1,-20.00,Closed early,-20.00,-0.4');
    expect(lines[2], 'OLD,19,1,50.00,Expired worthless,50.00,1.0');
  });

  test('S-154: no closed cycles produces a header-only CSV', () async {
    final repo = createRepository();
    final csv = await buildClosedCyclesCsv(repo);
    expect(csv.trim().split('\n'), [
      'ticker,duration_days,leg_count,total_premium,outcome,net_result,return_on_capital_pct',
    ]);
  });

  test('CR-1: a closed cycle\'s return on capital reflects the assignment '
      'actually recorded, not a reconstruction from the put leg', () async {
    final repo = createRepository();
    final underlying = await repo.getOrCreateUnderlying('CR1');
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

    // Deliberately recorded at values a reconstruction from the leg could
    // not recover: strike 49.50 (the leg is 50.00), 2 contracts (the leg
    // has 1). Both fields are user-entered at assignment time.
    final assignment = await repo.recordAssignment(
      legId: putLeg.leg.id,
      shareLot: NewShareLotInput(
        assignedAt: DateTime.utc(2026, 3, 20),
        assignmentStrike: Decimal.parse('49.50'),
        contracts: 2,
      ),
    );
    final callLeg = await repo.openNextLeg(
      cycleId: assignment.cycle.id,
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
    await repo.recordCallAway(legId: callLeg.id, closedAt: DateTime.utc(2026, 4, 17));

    final csv = await buildClosedCyclesCsv(repo);
    final lines = csv.trim().split('\n');

    // totalPremium = (1.20 x 100 x 1) + (0.55 x 100 x 1) = 175.00
    // stockPnL     = (52 - 49.50) x 100 x 1 = 250.00 -- put-side strike
    //   sourced from the RECORDED assignment (49.50), not the put leg's own
    //   50.00 (Feature Invariant 36 / S-207).
    // netResult    = 175.00 + 250.00 = 425.00
    // peak, from the RECORDED assignment (49.50, 2 contracts):
    //   perShareCredit = 120 / 200 = 0.60 -> basis 48.90 -> 48.90 x 100 x 2 = 9780
    //   (the put leg's own 50.00 x 100 x 1 = 5000 is lower, so 9780 wins)
    //   returnOnCapital = 425 / 9780 = 4.3456...% -> "4.3" (one decimal)
    // Reconstructing from the leg instead (50.00, 1 contract) gives
    //   48.80 x 100 x 1 = 4880 -> peak 5000 -- the CR-1 defect.
    expect(lines[1], 'CR1,75,2,175.00,Called away,425.00,4.3');
  });
}
