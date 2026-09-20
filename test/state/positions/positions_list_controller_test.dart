import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/state/positions/positions_list_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/rule_profile_fixtures.dart';

final _now = DateTime(2026, 1, 1);

Future<void> _createPosition({
  required WheelRepository repo,
  required String ticker,
  required int dteDays,
  required Decimal openCredit,
  required Decimal mark,
  required double delta,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('50'),
      expiration: _now.add(Duration(days: dteDays)),
      contracts: 1,
      openedAt: _now,
      openCreditPerShare: openCredit,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.appendSnapshot(
    NewSnapshotInput(
      legId: result.leg.id,
      takenAt: _now,
      optionMark: mark,
      underlyingPrice: Decimal.parse('50'),
      deltaAsEntered: delta,
      deltaConvention: DeltaConvention.position,
    ),
  );
}

Future<String> _createPositionNoSnapshot({
  required WheelRepository repo,
  required String ticker,
  required int dteDays,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('50'),
      expiration: _now.add(Duration(days: dteDays)),
      contracts: 1,
      openedAt: _now,
      openCreditPerShare: Decimal.parse('1.00'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  return result.leg.id;
}

void main() {
  group('S-021: positions list -- bucket badge, reason, sort', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    setUp(() async {
      repo = InMemoryWheelRepository();
      // AAA: capturedPct 60% -> close, dte 5.
      await _createPosition(
        repo: repo,
        ticker: 'AAA',
        dteDays: 5,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.40'),
        delta: -0.05,
      );
      // BBB: delta magnitude 0.75 -> assign, dte 10.
      await _createPosition(
        repo: repo,
        ticker: 'BBB',
        dteDays: 10,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.75,
      );
      // CCC: delta magnitude 0.35 -> roll (base band 0.30, no IV), dte 15.
      await _createPosition(
        repo: repo,
        ticker: 'CCC',
        dteDays: 15,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.35,
      );
      // DDD: delta magnitude 0.15 -> leave, dte 20.
      await _createPosition(
        repo: repo,
        ticker: 'DDD',
        dteDays: 20,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.15,
      );

      container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      // Pin this `autoDispose` provider alive for the test's duration (see
      // roll_planner_controller_test.dart for why a bare `read()` isn't
      // reliably enough on its own once multiple `await`s are involved).
      container.listen(positionsListControllerProvider, (previous, next) {});
      await container.read(positionsListControllerProvider.notifier).load(now: _now);
    });

    tearDown(() => container.dispose());

    test('each row carries a bucket badge AND its reason (never a bare verdict)', () {
      final items = container.read(positionsListControllerProvider).items;
      expect(items, hasLength(4));
      for (final item in items) {
        expect(item.bucket.reason, isNotEmpty);
      }
    });

    test('sort by bucket severity orders assign -> roll -> close -> leave', () {
      final controller = container.read(positionsListControllerProvider.notifier);
      controller.setSort(PositionSort.bucketSeverity);
      final tickers = container
          .read(positionsListControllerProvider)
          .items
          .map((i) => i.underlying.ticker)
          .toList();
      expect(tickers, ['BBB', 'CCC', 'AAA', 'DDD']);
    });

    test('sort by DTE is ascending', () {
      final controller = container.read(positionsListControllerProvider.notifier);
      controller.setSort(PositionSort.dte);
      final tickers = container
          .read(positionsListControllerProvider)
          .items
          .map((i) => i.underlying.ticker)
          .toList();
      expect(tickers, ['AAA', 'BBB', 'CCC', 'DDD']);
    });

    test('sort by ticker is alphabetical', () {
      final controller = container.read(positionsListControllerProvider.notifier);
      controller.setSort(PositionSort.ticker);
      final tickers = container
          .read(positionsListControllerProvider)
          .items
          .map((i) => i.underlying.ticker)
          .toList();
      expect(tickers, ['AAA', 'BBB', 'CCC', 'DDD']);
    });
  });

  group('S-023: empty positions list', () {
    test('zero rows -> empty items, no crash, no divide-by-zero', () async {
      final repo = InMemoryWheelRepository();
      final container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(positionsListControllerProvider, (previous, next) {});

      await container.read(positionsListControllerProvider.notifier).load(now: _now);
      final state = container.read(positionsListControllerProvider);

      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);

      // Sort must not throw on an empty list either.
      container.read(positionsListControllerProvider.notifier).setSort(PositionSort.dte);
      expect(container.read(positionsListControllerProvider).items, isEmpty);
    });
  });

  group('S-059: unknown sorts last among all five buckets', () {
    test('row order is exactly assign, roll, close, leave, unknown', () async {
      final repo = InMemoryWheelRepository();
      // AAA/BBB/CCC/DDD reuse S-021's four-leg fixture (assign/roll/close/leave).
      await _createPosition(
        repo: repo,
        ticker: 'AAA',
        dteDays: 5,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.40'),
        delta: -0.05, // capturedPct 60% -> close
      );
      await _createPosition(
        repo: repo,
        ticker: 'BBB',
        dteDays: 10,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.75, // -> assign
      );
      await _createPosition(
        repo: repo,
        ticker: 'CCC',
        dteDays: 15,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.35, // -> roll
      );
      await _createPosition(
        repo: repo,
        ticker: 'DDD',
        dteDays: 20,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.15, // -> leave
      );
      // EEE: zero snapshots -> unknown.
      await _createPositionNoSnapshot(repo: repo, ticker: 'EEE', dteDays: 25);

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionsListControllerProvider, (previous, next) {});
      await container.read(positionsListControllerProvider.notifier).load(now: _now);

      final items = container.read(positionsListControllerProvider).items;
      expect(items.map((i) => i.underlying.ticker).toList(), ['BBB', 'CCC', 'AAA', 'DDD', 'EEE']);

      final unknownItem = items.last;
      expect(unknownItem.bucket, isA<BucketUnknown>());
      expect(unknownItem.bucket.reason, 'No snapshot yet');
    });
  });

  group('S-043-S-046: positions list resolves IV for Gate 3 too, not just the detail screen', () {
    test('snapshot IV null, leg.ivAtOpen=83 -> classifies leave (band 0.40), not roll', () async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('LST');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.call,
          strike: Decimal.parse('11'),
          expiration: _now.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ivAtOpen: 83.0,
        ),
      );
      await repo.appendSnapshot(
        NewSnapshotInput(
          legId: result.leg.id,
          takenAt: _now,
          optionMark: Decimal.parse('0.80'), // capturedPct 20%
          underlyingPrice: Decimal.parse('10'),
          deltaAsEntered: -0.35,
          deltaConvention: DeltaConvention.position,
          iv: null,
        ),
      );

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(positionsListControllerProvider, (previous, next) {});
      await container.read(positionsListControllerProvider.notifier).load(now: _now);

      final items = container.read(positionsListControllerProvider).items;
      expect(items, hasLength(1));
      expect(items.single.bucket, isA<BucketLeave>());
    });
  });

  group('S-196: the audit pin — an edit never reclassifies history', () {
    late InMemoryWheelRepository repo;
    late String legAId;

    setUp(() async {
      repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('PIN');

      // Leg A opens under v1 (50% target) with 55% captured.
      final a = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      legAId = a.leg.id;
      await repo.appendSnapshot(
        NewSnapshotInput(
          legId: legAId,
          takenAt: _now,
          optionMark: Decimal.parse('0.45'),
          underlyingPrice: Decimal.parse('50'),
          deltaAsEntered: -0.20,
          deltaConvention: DeltaConvention.position,
        ),
      );

      // The edit: v2 moves the target to 60%, so 55% no longer clears Gate 1.
      final v2 = await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: _now,
        values: standardVersionInput(profitTargetPct: 60.0),
      );

      // Leg B opens under v2 with an identical snapshot.
      final b = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: _now.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: _now,
          openCreditPerShare: Decimal.parse('1.00'),
          ruleProfileVersionId: v2.id,
        ),
      );
      await repo.appendSnapshot(
        NewSnapshotInput(
          legId: b.leg.id,
          takenAt: _now,
          optionMark: Decimal.parse('0.45'),
          underlyingPrice: Decimal.parse('50'),
          deltaAsEntered: -0.20,
          deltaConvention: DeltaConvention.position,
        ),
      );
    });

    test('one view, two pins: A closes under its 50% target, B leaves under v2\'s 60%', () async {
      final container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(positionsListControllerProvider, (previous, next) {});
      await container.read(positionsListControllerProvider.notifier).load(now: _now);

      final items = container.read(positionsListControllerProvider).items;
      expect(items, hasLength(2));

      final a = items.singleWhere((item) => item.leg.id == legAId);
      expect(a.bucket, isA<BucketClose>());
      expect(a.bucket.reason, '55% of credit captured');

      final b = items.singleWhere((item) => item.leg.id != legAId);
      expect(b.bucket, isA<BucketLeave>());
    });
  });
}
