import 'package:decimal/decimal.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/user_preferences.dart';

/// Counts `updatePreferences` writes, so S-308 can assert the toggles are
/// session state and never a persisted preference.
class CountingRepository extends InMemoryWheelRepository {
  int preferenceWrites = 0;

  @override
  Future<UserPreferencesData> updatePreferences(UserPreferencesData prefs) {
    preferenceWrites++;
    return super.updatePreferences(prefs);
  }
}

/// S-306's month, built through the real repository so the card reads the
/// same `CyclePnl` the Journal would.
///
/// The five cycles reproduce the reference card's own arithmetic:
///
/// | ticker | net result | peak capital | days | capture |
/// |---|---|---|---|---|
/// | BAC | +32 | 3,800 | 24 | 88% |
/// | CCL | +35 | 6,250 | 31 | 82% |
/// | KO | -30 | 4,000 | 18 | 100% |
/// | SNAP | +110 | 7,000 | 35 | 61% |
/// | UBER | +210 | 1,800 | 27 | 40% |
///
/// Sums: net result 357, peak capital 22,850 -> 1.6%; days 135 / 5 = 27;
/// median capture 82%; 4 of 5 closed positive; 3 closed legs with no fee.
///
/// KO is the loss, and it carries its -30 as a **close fee** rather than a
/// close debit: a single-leg cycle's capture is `netCredit / openCredit`, so
/// a debit large enough to make the cycle a loss would also drive its capture
/// negative, and the reference card's loss cycle reports 100%. Routing the
/// loss through the fee decouples the two figures, which is exactly what the
/// reference's own numbers do.
///
/// Shared by the screen test (S-306, S-308, S-309, S-311, S-312) and the
/// golden test (S-310), so the two cannot drift onto different months.
Future<CountingRepository> septemberBook({required DateTime now}) async {
  final repo = CountingRepository();

  Future<void> closedEarly({
    required String ticker,
    required String strike,
    required String credit,
    required String debit,
    required int days,
    Decimal? closeFee,
  }) async {
    final underlying = await repo.getOrCreateUnderlying(ticker);
    final openedAt = now.subtract(Duration(days: days));
    final created = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse(strike),
        expiration: openedAt.add(const Duration(days: 30)),
        contracts: 1,
        openedAt: openedAt,
        openCreditPerShare: Decimal.parse(credit),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    await repo.closeLeg(
      legId: created.leg.id,
      reason: CloseReason.closedEarly,
      closeDebitPerShare: Decimal.parse(debit),
      closeFee: closeFee,
      closedAt: now,
    );
  }

  // BAC: 0.3636 - 0.0436 = 0.32 -> +32; capture 88.0088% -> 88%.
  await closedEarly(ticker: 'BAC', strike: '38.00', credit: '0.3636', debit: '0.0436', days: 24);
  // CCL: 0.4268 - 0.0768 = 0.35 -> +35; capture 82.0056% -> 82%.
  await closedEarly(
    ticker: 'CCL',
    strike: '62.50',
    credit: '0.4268',
    debit: '0.0768',
    days: 31,
    closeFee: Decimal.zero,
  );
  // SNAP: 1.8033 - 0.7033 = 1.10 -> +110; capture 60.9993% -> 61%.
  await closedEarly(ticker: 'SNAP', strike: '70.00', credit: '1.8033', debit: '0.7033', days: 35);
  // UBER: 5.25 - 3.15 = 2.10 -> +210; capture 40%.
  await closedEarly(ticker: 'UBER', strike: '18.00', credit: '5.25', debit: '3.15', days: 27);

  // KO: assigned, then called away, so the cycle actually closes. Its capture
  // is 100% (neither leg carries a close debit) and its -30 comes from the
  // 62.00 close fee on the call: 0.32 x 100 + 0.00 x 100 - 62 = -30.
  final koUnderlying = await repo.getOrCreateUnderlying('KO');
  final koOpenedAt = now.subtract(const Duration(days: 18));
  final ko = await repo.createCycle(
    underlyingId: koUnderlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('40.00'),
      expiration: koOpenedAt.add(const Duration(days: 30)),
      contracts: 1,
      openedAt: koOpenedAt,
      openCreditPerShare: Decimal.parse('0.32'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.recordAssignment(
    legId: ko.leg.id,
    closeFee: Decimal.zero,
    shareLot: NewShareLotInput(
      assignedAt: now,
      assignmentStrike: Decimal.parse('40.00'),
      contracts: 1,
    ),
  );
  final koCall = await repo.openNextLeg(
    cycleId: ko.cycle.id,
    leg: NewLegInput(
      optionType: OptionType.call,
      strike: Decimal.parse('40.00'),
      expiration: now.add(const Duration(days: 30)),
      contracts: 1,
      openedAt: now,
      openCreditPerShare: Decimal.zero,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.recordCallAway(legId: koCall.id, closeFee: Decimal.parse('62.00'), closedAt: now);

  return repo;
}

/// S-311's month: one cycle closed in August, one still open, nothing in
/// September.
Future<InMemoryWheelRepository> emptySeptemberBook() async {
  final repo = InMemoryWheelRepository();

  final august = await repo.getOrCreateUnderlying('BAC');
  final augustCycle = await repo.createCycle(
    underlyingId: august.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('38.00'),
      expiration: DateTime(2026, 8, 21),
      contracts: 1,
      openedAt: DateTime(2026, 7, 20),
      openCreditPerShare: Decimal.parse('0.40'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.closeLeg(
    legId: augustCycle.leg.id,
    reason: CloseReason.closedEarly,
    closeDebitPerShare: Decimal.parse('0.10'),
    closedAt: DateTime(2026, 8, 31),
  );

  final open = await repo.getOrCreateUnderlying('CCL');
  await repo.createCycle(
    underlyingId: open.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('62.50'),
      expiration: DateTime(2026, 10, 16),
      contracts: 1,
      openedAt: DateTime(2026, 9, 20),
      openCreditPerShare: Decimal.parse('0.50'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );

  return repo;
}
