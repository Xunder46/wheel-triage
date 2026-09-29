import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/domain/rules/capital_committed.dart';
import 'package:wheel_triage/domain/rules/obligation.dart';
import 'package:wheel_triage/domain/rules/premium_collected.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/today/today_controller.dart';

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

/// A leg whose reading can be dated independently of [now] -- S-244's aging
/// fixtures need a reading that is exactly so many calendar days old.
Future<String> _createLeg({
  required WheelRepository repo,
  required String ticker,
  required DateTime now,
  required int dteDays,
  Decimal? mark,
  double delta = 0,
  DateTime? readingAt,
  String strike = '50',
  String spot = '50',
  int contracts = 1,
  OptionType optionType = OptionType.put,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: optionType,
      strike: Decimal.parse(strike),
      expiration: now.add(Duration(days: dteDays)),
      contracts: contracts,
      openedAt: now,
      openCreditPerShare: Decimal.parse('1.00'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  if (mark != null) {
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: result.leg.id,
        takenAt: readingAt ?? now,
        optionMark: mark,
        underlyingPrice: Decimal.parse(spot),
        deltaAsEntered: delta,
        deltaConvention: DeltaConvention.position,
      ),
    );
  }
  return result.leg.id;
}

/// Counts the batch writes, so S-252 can assert "one call, every eligible
/// leg" rather than inferring it from the legs' end state. It is still the
/// in-memory implementation, just observed (`_CountingRepository`'s
/// precedent in `rule_profile_editor_controller_test.dart`).
class _CountingRepository extends InMemoryWheelRepository {
  int markExpiredCalls = 0;
  List<({String legId, DateTime closedAt})> lastBatch = const [];

  @override
  Future<List<Leg>> markExpired({
    required List<({String legId, DateTime closedAt})> legs,
  }) {
    markExpiredCalls++;
    lastBatch = legs;
    return super.markExpired(legs: legs);
  }
}

/// A batch write that fails, for the "nothing changed" half of S-252.
class _FailingMarkExpiredRepository extends InMemoryWheelRepository {
  @override
  Future<List<Leg>> markExpired({
    required List<({String legId, DateTime closedAt})> legs,
  }) async => throw StateError('write failed');
}

List<String> _tickers(ProviderContainer container) => container
    .read(todayControllerProvider)
    .visible
    .map((i) => i.underlying.ticker)
    .toList();

void main() {
  group('S-021: today list -- bucket badge, reason, sort', () {
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

      container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      // Pin this `autoDispose` provider alive for the test's duration (see
      // roll_planner_controller_test.dart for why a bare `read()` isn't
      // reliably enough on its own once multiple `await`s are involved).
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: _now);
    });

    tearDown(() => container.dispose());

    test(
      'each row carries a bucket badge AND its reason (never a bare verdict)',
      () {
        final items = container.read(todayControllerProvider).items;
        expect(items, hasLength(4));
        for (final item in items) {
          expect(item.bucket.reason, isNotEmpty);
        }
      },
    );

    test('sort by bucket orders assign -> roll -> close -> leave', () {
      final controller = container.read(todayControllerProvider.notifier);
      controller.setSort(TodaySort.bucket);
      final tickers = container
          .read(todayControllerProvider)
          .items
          .map((i) => i.underlying.ticker)
          .toList();
      expect(tickers, ['BBB', 'CCC', 'AAA', 'DDD']);
    });

    test('sort by DTE is ascending', () {
      final controller = container.read(todayControllerProvider.notifier);
      controller.setSort(TodaySort.dte);
      final tickers = container
          .read(todayControllerProvider)
          .items
          .map((i) => i.underlying.ticker)
          .toList();
      expect(tickers, ['AAA', 'BBB', 'CCC', 'DDD']);
    });

    test('sort by ticker is alphabetical', () {
      final controller = container.read(todayControllerProvider.notifier);
      controller.setSort(TodaySort.ticker);
      final tickers = container
          .read(todayControllerProvider)
          .items
          .map((i) => i.underlying.ticker)
          .toList();
      expect(tickers, ['AAA', 'BBB', 'CCC', 'DDD']);
    });

    test('every sort option has a label of its own (D-14)', () {
      expect(todaySortLabel(TodaySort.bucket), 'By bucket');
      expect(todaySortLabel(TodaySort.dte), 'By DTE');
      expect(todaySortLabel(TodaySort.ticker), 'By ticker');
    });
  });

  group('S-023: empty today list', () {
    test('zero rows -> empty items, no crash, no divide-by-zero', () async {
      final repo = InMemoryWheelRepository();
      final container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(todayControllerProvider, (previous, next) {});

      await container.read(todayControllerProvider.notifier).load(now: _now);
      final state = container.read(todayControllerProvider);

      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.bucketCounts.map((c) => c.count).toList(), [0, 0, 0, 0, 0]);
      expect(state.agingLine, isEmpty);

      // Sort must not throw on an empty list either.
      container.read(todayControllerProvider.notifier).setSort(TodaySort.dte);
      expect(container.read(todayControllerProvider).items, isEmpty);
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

      final container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: _now);

      final items = container.read(todayControllerProvider).items;
      expect(items.map((i) => i.underlying.ticker).toList(), [
        'BBB',
        'CCC',
        'AAA',
        'DDD',
        'EEE',
      ]);

      final unknownItem = items.last;
      expect(unknownItem.bucket, isA<BucketUnknown>());
      expect(unknownItem.bucket.reason, 'No snapshot yet');
    });
  });

  group(
    'S-043-S-046: today list resolves IV for Gate 3 too, not just the detail screen',
    () {
      test(
        'snapshot IV null, leg.ivAtOpen=83 -> classifies leave (band 0.40), not roll',
        () async {
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

          final container = ProviderContainer(
            overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);
          container.listen(todayControllerProvider, (previous, next) {});
          await container
              .read(todayControllerProvider.notifier)
              .load(now: _now);

          final items = container.read(todayControllerProvider).items;
          expect(items, hasLength(1));
          expect(items.single.bucket, isA<BucketLeave>());
        },
      );
    },
  );

  group('S-196: the audit pin -- an edit never reclassifies history', () {
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

    test(
      'one view, two pins: A closes under its 50% target, B leaves under v2\'s 60%',
      () async {
        final container = ProviderContainer(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        container.listen(todayControllerProvider, (previous, next) {});
        await container.read(todayControllerProvider.notifier).load(now: _now);

        final items = container.read(todayControllerProvider).items;
        expect(items, hasLength(2));

        final a = items.singleWhere((item) => item.leg.id == legAId);
        expect(a.bucket, isA<BucketClose>());
        expect(a.bucket.reason, '55% of credit captured');

        final b = items.singleWhere((item) => item.leg.id != legAId);
        expect(b.bucket, isA<BucketLeave>());
      },
    );
  });

  group('S-243: bucket counts and filters', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    setUp(() async {
      repo = InMemoryWheelRepository();
      await _createPosition(
        repo: repo,
        ticker: 'AAA',
        dteDays: 5,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.40'),
        delta: -0.05, // close
      );
      await _createPosition(
        repo: repo,
        ticker: 'BBB',
        dteDays: 10,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.75, // assign
      );
      await _createPosition(
        repo: repo,
        ticker: 'CCC',
        dteDays: 15,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.35, // roll
      );
      await _createPosition(
        repo: repo,
        ticker: 'DDD',
        dteDays: 20,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.15, // leave
      );
      await _createPosition(
        repo: repo,
        ticker: 'FFF',
        dteDays: 30,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.10, // leave
      );
      await _createPositionNoSnapshot(
        repo: repo,
        ticker: 'EEE',
        dteDays: 25,
      ); // no data
      // GGG expired yesterday and is still open: D-P13 keeps it out of the
      // counts and out of the list entirely.
      await _createPosition(
        repo: repo,
        ticker: 'GGG',
        dteDays: -1,
        openCredit: Decimal.parse('1.00'),
        mark: Decimal.parse('0.90'),
        delta: -0.75,
      );

      container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: _now);
    });

    tearDown(() => container.dispose());

    test(
      'counts render in sort order: Assign, Roll, Close, Leave, No data',
      () {
        final counts = container.read(todayControllerProvider).bucketCounts;
        expect(counts.map((c) => bucketLabel(c.bucket)).toList(), [
          'Assign',
          'Roll',
          'Close',
          'Leave',
          'No data',
        ]);
        expect(counts.map((c) => c.count).toList(), [1, 1, 1, 2, 1]);
      },
    );

    test(
      'the past-expiration leg is in none of the counts and not in the list',
      () {
        final state = container.read(todayControllerProvider);
        expect(
          state.items.map((i) => i.underlying.ticker),
          isNot(contains('GGG')),
        );
        expect(
          state.visible.map((i) => i.underlying.ticker),
          isNot(contains('GGG')),
        );
        expect(state.pastExpiration.map((i) => i.underlying.ticker), ['GGG']);
        expect(state.bucketCounts.fold<int>(0, (sum, c) => sum + c.count), 6);
      },
    );

    test(
      'each tap filters the list to exactly those legs and clears on the second tap',
      () {
        final controller = container.read(todayControllerProvider.notifier);

        controller.toggleBucketFilter(BucketAssign);
        expect(_tickers(container), ['BBB']);

        // A second tap on the same count clears the filter.
        controller.toggleBucketFilter(BucketAssign);
        expect(_tickers(container), hasLength(6));

        controller.toggleBucketFilter(BucketClose);
        expect(_tickers(container), ['AAA']);

        // Tapping a different count replaces the filter rather than stacking.
        controller.toggleBucketFilter(BucketLeave);
        expect(_tickers(container).toSet(), {'DDD', 'FFF'});

        controller.toggleBucketFilter(BucketUnknown);
        expect(_tickers(container), ['EEE']);

        controller.toggleBucketFilter(BucketUnknown);
        expect(_tickers(container), hasLength(6));
      },
    );
  });

  group('S-244: the aging count and the inline Update', () {
    final now = DateTime(2026, 9, 28);
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    Future<void> build({required int tReadingAgeDays}) async {
      repo = InMemoryWheelRepository();
      await _createLeg(
        repo: repo,
        ticker: 'T',
        now: now,
        dteDays: 4,
        mark: Decimal.parse('0.90'),
        delta: -0.10, // leave
        readingAt: now.subtract(Duration(days: tReadingAgeDays)),
      );
      await _createLeg(
        repo: repo,
        ticker: 'PFE',
        now: now,
        dteDays: 25,
      ); // no reading
      await _createLeg(
        repo: repo,
        ticker: 'SOFI',
        now: now,
        dteDays: 4,
        mark: Decimal.parse('0.90'),
        delta: -0.10, // leave
        readingAt: now,
      );

      container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: now);
    }

    tearDown(() => container.dispose());

    test('the aging line names the leg and the date it was read', () async {
      await build(tReadingAgeDays: 11);
      final state = container.read(todayControllerProvider);
      expect(state.agingLine, '1 reading older than 7 days · T, from Sep 17');
      expect(state.agingCount, 1);
    });

    test(
      'the aging count overlaps: T is still counted under Leave, and No data is separate',
      () async {
        await build(tReadingAgeDays: 11);
        final state = container.read(todayControllerProvider);
        final counts = {
          for (final c in state.bucketCounts) bucketLabel(c.bucket): c.count,
        };
        expect(counts['Leave'], 2);
        expect(counts['No data'], 1);
        // PFE needs a reading but is never part of the aging count.
        expect(state.agingCount, 1);
        expect(
          state.items
              .singleWhere((i) => i.underlying.ticker == 'PFE')
              .needsReading,
          isTrue,
        );
      },
    );

    test(
      'tapping the aging line filters to exactly the aging legs and clears on the second tap',
      () async {
        await build(tReadingAgeDays: 11);
        final controller = container.read(todayControllerProvider.notifier);

        controller.toggleAgingFilter();
        expect(_tickers(container), ['T']);

        controller.toggleAgingFilter();
        expect(_tickers(container), hasLength(3));
      },
    );

    test(
      'the inline Update appears only where the predicate is true',
      () async {
        await build(tReadingAgeDays: 11);
        final items = container.read(todayControllerProvider).items;
        expect(
          items.singleWhere((i) => i.underlying.ticker == 'T').needsReading,
          isTrue,
        );
        expect(
          items.singleWhere((i) => i.underlying.ticker == 'PFE').needsReading,
          isTrue,
        );
        expect(
          items.singleWhere((i) => i.underlying.ticker == 'SOFI').needsReading,
          isFalse,
        );
      },
    );

    test(
      'a reading exactly 7 days old is not aging and gets no inline Update',
      () async {
        await build(tReadingAgeDays: 7);
        final state = container.read(todayControllerProvider);
        expect(state.agingLine, isEmpty);
        expect(state.agingCount, 0);
        expect(
          state.items
              .singleWhere((i) => i.underlying.ticker == 'T')
              .needsReading,
          isFalse,
        );
        expect(
          state.items
              .singleWhere((i) => i.underlying.ticker == 'T')
              .readingAgeDays,
          7,
        );
      },
    );

    test(
      'a reload clears a stale filter rather than hiding everything',
      () async {
        await build(tReadingAgeDays: 11);
        final controller = container.read(todayControllerProvider.notifier);
        controller.toggleBucketFilter(BucketLeave);
        expect(_tickers(container).toSet(), {'T', 'SOFI'});

        await controller.load(now: now);
        expect(_tickers(container), hasLength(3));
      },
    );
  });

  group('S-246/S-247: the ledger and concentration, computed at load', () {
    // A fixed clock, so the month and year-to-date windows are pinned.
    final now = DateTime(2026, 9, 28);
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    /// One leg, opened [openedAt], optionally closed [closedAt] for
    /// [closeDebit]. Puts commit `strike x 100 x contracts`.
    Future<String> leg({
      required String ticker,
      required String strike,
      required int contracts,
      required String credit,
      required DateTime openedAt,
      String? closeDebit,
      DateTime? closedAt,
      OptionType optionType = OptionType.put,
    }) async {
      final underlying = await repo.getOrCreateUnderlying(ticker);
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: optionType,
          strike: Decimal.parse(strike),
          expiration: now.add(const Duration(days: 30)),
          contracts: contracts,
          openedAt: openedAt,
          openCreditPerShare: Decimal.parse(credit),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      if (closedAt != null) {
        await repo.closeLeg(
          legId: result.leg.id,
          reason: CloseReason.closedEarly,
          closeDebitPerShare: Decimal.parse(closeDebit!),
          closedAt: closedAt,
        );
      }
      return result.leg.id;
    }

    Future<void> build({String? wheelCapital, double limit = 25.0}) async {
      await leg(
        ticker: 'INTC',
        strike: '20',
        contracts: 4,
        credit: '0.60',
        openedAt: DateTime(2026, 9, 3),
      );
      await leg(
        ticker: 'SOFI',
        strike: '14',
        contracts: 3,
        credit: '0.55',
        openedAt: DateTime(2026, 9, 10),
      );
      await leg(
        ticker: 'T',
        optionType: OptionType.call,
        strike: '28',
        contracts: 1,
        credit: '0.40',
        openedAt: DateTime(2026, 9, 17),
      );
      // Opened in August, closed in September: the credit belongs to
      // August's figure and the buyback to September's.
      await leg(
        ticker: 'F',
        strike: '12',
        contracts: 2,
        credit: '0.70',
        openedAt: DateTime(2026, 8, 5),
        closeDebit: '0.20',
        closedAt: DateTime(2026, 9, 12),
      );
      await leg(
        ticker: 'SBET',
        strike: '11',
        contracts: 1,
        credit: '0.35',
        openedAt: DateTime(2026, 7, 20),
        closeDebit: '0.10',
        closedAt: DateTime(2026, 7, 30),
      );

      if (wheelCapital != null || limit != 25.0) {
        await repo.updatePreferences(
          (await repo.getPreferences()).copyWith(
            wheelCapital: wheelCapital == null ? null : Decimal.parse(wheelCapital),
            concentrationLimitPct: limit,
          ),
        );
      }

      container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: now);
    }

    TodayState state() => container.read(todayControllerProvider);

    setUp(() => repo = InMemoryWheelRepository());
    tearDown(() => container.dispose());

    test('the three figures match the reducers exactly', () async {
      await build(wheelCapital: '30000');

      final allLegs = await repo.getAllLegs();
      final month = monthPeriodContaining(now);
      final year = yearToDatePeriod(now);

      expect(state().ledgerMonthLabel, 'Sep');
      expect(state().netPremiumMonth, Decimal.parse('405'));
      // Year to date adds August's 140 credit and July's 35 credit less its
      // 10 buyback: 405 + 140 + 25.
      expect(state().netPremiumYearToDate, Decimal.parse('570'));
      expect(state().committedNow, Decimal.parse('12200'));

      expect(
        state().netPremiumMonth,
        netPremiumCollected(legs: allLegs, start: month.start, end: month.end),
      );
      expect(
        state().netPremiumYearToDate,
        netPremiumCollected(legs: allLegs, start: year.start, end: year.end),
      );
    });

    test('the definition line names the book\'s share of wheel capital', () async {
      await build(wheelCapital: '30000');
      expect(
        state().ledgerDefinitionLine,
        '$kPremiumDefinitionLine Committed now: open puts at strike, shares at '
        'wheel-adjusted basis; 41% of your \$30,000 wheel capital.',
      );
    });

    test('the definition line stops at the basis when no capital is set', () async {
      await build();
      expect(
        state().ledgerDefinitionLine,
        '$kPremiumDefinitionLine Committed now: open puts at strike, shares at '
        'wheel-adjusted basis.',
      );
      expect(state().wheelCapital, isNull);
    });

    test('one underlying over the limit is flagged, at its own limit', () async {
      await build(wheelCapital: '30000');
      final flags = state().concentrationFlags;
      expect(flags, hasLength(1));
      expect(flags.single.ticker, 'INTC');
      expect(flags.single.percent, 27);
      expect(flags.single.limitPct, 25.0);
      expect(concentrationFlagLine(flags.single), 'INTC 27% of wheel capital · limit 25%');
    });

    test('no wheel capital means no flags at all', () async {
      await build();
      expect(state().concentrationFlags, isEmpty);
    });

    test('a load preserves the ledger across a filter change', () async {
      await build(wheelCapital: '30000');
      final controller = container.read(todayControllerProvider.notifier);
      controller.toggleBucketFilter(BucketLeave);
      await controller.load(now: now);

      expect(state().bucketFilter, isNull);
      expect(state().netPremiumMonth, Decimal.parse('405'));
      expect(state().concentrationFlags, hasLength(1));
    });
  });

  group('S-250: the expiring-this-week groups', () {
    final now = DateTime(2026, 9, 28);
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    setUp(() async {
      repo = InMemoryWheelRepository();
      await _createLeg(
        repo: repo,
        ticker: 'TODAY',
        now: now,
        dteDays: 0,
        mark: Decimal.parse('0.90'),
        delta: -0.20,
      );
      await _createLeg(
        repo: repo,
        ticker: 'SOFI',
        now: now,
        dteDays: 4,
        mark: Decimal.parse('0.90'),
        delta: -0.52,
      );
      await _createLeg(
        repo: repo,
        ticker: 'T',
        now: now,
        dteDays: 6,
        mark: Decimal.parse('0.70'),
        delta: -0.28,
      );
      await _createLeg(
        repo: repo,
        ticker: 'SEVEN',
        now: now,
        dteDays: 7,
        mark: Decimal.parse('0.90'),
        delta: -0.20,
      );
      await _createLeg(
        repo: repo,
        ticker: 'EIGHT',
        now: now,
        dteDays: 8,
        mark: Decimal.parse('0.90'),
        delta: -0.20,
      );
      await _createLeg(
        repo: repo,
        ticker: 'WBD',
        now: now,
        dteDays: -3,
        mark: Decimal.parse('0.90'),
        delta: -0.20,
      );

      container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: now);
    });

    tearDown(() => container.dispose());

    test('groups the legs inside seven days by date, ascending, today included', () {
      final groups = container.read(todayControllerProvider).expiringThisWeek;
      expect(groups.map((group) => group.date).toList(), [
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 4),
        DateTime(2026, 10, 5),
      ]);
      expect(
        groups
            .map(
              (group) =>
                  group.legs.map((item) => item.underlying.ticker).toList(),
            )
            .toList(),
        [
          ['TODAY'],
          ['SOFI'],
          ['T'],
          ['SEVEN'],
        ],
      );
    });

    test('the eighth day out and a past-expiration leg are not in the card', () {
      final groups = container.read(todayControllerProvider).expiringThisWeek;
      final tickers = [
        for (final group in groups)
          ...group.legs.map((item) => item.underlying.ticker),
      ];
      expect(tickers, isNot(contains('EIGHT')));
      expect(tickers, isNot(contains('WBD')));
    });

    test('a grouped leg carries the obligation the card prints beside it', () {
      final groups = container.read(todayControllerProvider).expiringThisWeek;
      final sofi = groups[1].legs.single;
      expect(obligationFor(sofi.leg)!.text, '\$5,000 cash if assigned');
    });

    test('a past-expiration leg is batch-eligible only when its reading is out of the money', () {
      final past = container.read(todayControllerProvider).pastExpiration;
      expect(past.map((item) => item.underlying.ticker), ['WBD']);
      // Strike 50, reading 50 -- at the strike, so not in the money.
      expect(past.single.batchEligible, isTrue);
    });
  });

  group('S-252: Mark all expired', () {
    final now = DateTime(2026, 9, 28);
    late ProviderContainer container;

    /// WBD out of the money (eligible), AAL in it, XYZ with no reading at
    /// all, and one live leg.
    Future<({String wbd, String aal, String xyz, String sofi})> build(
      WheelRepository repo,
    ) async => (
      wbd: await _createLeg(
        repo: repo,
        ticker: 'WBD',
        now: now,
        dteDays: -3,
        strike: '11',
        spot: '12.10',
        mark: Decimal.parse('0.90'),
        delta: -0.20,
      ),
      aal: await _createLeg(
        repo: repo,
        ticker: 'AAL',
        now: now,
        dteDays: -3,
        strike: '13',
        spot: '12.60',
        contracts: 2,
        mark: Decimal.parse('0.50'),
        delta: -0.70,
      ),
      xyz: await _createLeg(
        repo: repo,
        ticker: 'XYZ',
        now: now,
        dteDays: -5,
        strike: '20',
      ),
      sofi: await _createLeg(
        repo: repo,
        ticker: 'SOFI',
        now: now,
        dteDays: 4,
        strike: '14',
        contracts: 3,
        mark: Decimal.parse('0.90'),
        delta: -0.52,
      ),
    );

    Future<void> load(WheelRepository repo) async {
      container = ProviderContainer(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: now);
    }

    tearDown(() => container.dispose());

    test('one write covers every eligible leg, each on its own expiration date', () async {
      final repo = _CountingRepository();
      final ids = await build(repo);
      await load(repo);

      final message = await container
          .read(todayControllerProvider.notifier)
          .markAllExpired();

      expect(message, isNull);
      expect(repo.markExpiredCalls, 1);
      expect(repo.lastBatch, hasLength(1));
      expect(repo.lastBatch.single.legId, ids.wbd);
      expect(repo.lastBatch.single.closedAt, DateTime(2026, 9, 25));

      final wbd = (await repo.getLeg(ids.wbd))!;
      expect(wbd.closeReason, CloseReason.expiredWorthless);
      expect(wbd.closedAt, DateTime(2026, 9, 25));
      expect(wbd.closeDebitPerShare, Decimal.zero);
      expect(wbd.closeFee, isNull);

      // The two legs left out are untouched.
      expect((await repo.getLeg(ids.aal))!.closedAt, isNull);
      expect((await repo.getLeg(ids.xyz))!.closedAt, isNull);
      expect((await repo.getLeg(ids.sofi))!.closedAt, isNull);

      final state = container.read(todayControllerProvider);
      expect(
        state.pastExpiration.map((item) => item.underlying.ticker),
        ['AAL', 'XYZ'],
      );
      expect(state.items.map((item) => item.underlying.ticker), ['SOFI']);
      // WBD's 1,100 of committed cash is released; the rest is unchanged.
      expect(state.committedNow, Decimal.parse('8800'));
    });

    test('a batch with nothing eligible writes nothing and reports nothing', () async {
      final repo = _CountingRepository();
      final ids = await build(repo);
      await load(repo);
      final controller = container.read(todayControllerProvider.notifier);

      await controller.markAllExpired();
      final message = await controller.markAllExpired();

      expect(message, isNull);
      expect(repo.markExpiredCalls, 1);
      expect((await repo.getLeg(ids.wbd))!.closedAt, isNotNull);
    });

    test('a failed write leaves the book exactly as it was and returns the message', () async {
      final repo = _FailingMarkExpiredRepository();
      await build(repo);
      await load(repo);

      final message = await container
          .read(todayControllerProvider.notifier)
          .markAllExpired();

      expect(message, contains('write failed'));
      final state = container.read(todayControllerProvider);
      // Not `state.error`: the card must survive its own failure.
      expect(state.error, isNull);
      expect(state.pastExpiration, hasLength(3));
      expect(state.items, hasLength(1));
    });

    test('markExpiredLeg records one leg on its own expiration date', () async {
      final repo = _CountingRepository();
      final ids = await build(repo);
      await load(repo);

      final message = await container
          .read(todayControllerProvider.notifier)
          .markExpiredLeg(legId: ids.aal);

      expect(message, isNull);
      // The per-leg action is a single close, not a batch write.
      expect(repo.markExpiredCalls, 0);

      final aal = (await repo.getLeg(ids.aal))!;
      expect(aal.closeReason, CloseReason.expiredWorthless);
      expect(aal.closedAt, DateTime(2026, 9, 25));
      expect(aal.closeDebitPerShare, Decimal.zero);

      final state = container.read(todayControllerProvider);
      expect(
        state.pastExpiration.map((item) => item.underlying.ticker),
        ['WBD', 'XYZ'],
      );
    });
  });
}
