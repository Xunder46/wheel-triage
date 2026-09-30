import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/state/portfolio/portfolio_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/today/today_controller.dart';

/// S-302's state half: the five bucket counts come from one shared source, and
/// each leg is classified under **its own pinned** version, so editing
/// `Standard` never reclassifies an open position.
///
/// The fixture is seven open legs: 1 Assign, 1 Roll, 1 Close, 2 Leave and one
/// with no snapshot (`BucketUnknown`) — six counted, one of them pinned to
/// `standard-v1` while the profile has since moved on.
void main() {
  final now = DateTime(2026, 9, 28);

  /// A leg whose delta lands it in [bucket], with a snapshot carrying that
  /// delta. `delta` is a magnitude; the convention is the option's own.
  /// `expiration` defaults to 30 days out; a fixture can place a leg past
  /// expiration on purpose.
  Future<Leg> leg(
    InMemoryWheelRepository repo, {
    required String ticker,
    required String delta,
    required String strike,
    int contracts = 1,
    String? versionId,
    bool snapshot = true,
    String mark = '0.50',
    DateTime? expiration,
    DateTime? readingAt,
  }) async {
    final underlying = await repo.getOrCreateUnderlying(ticker);
    final created = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse(strike),
        expiration: expiration ?? now.add(const Duration(days: 30)),
        contracts: contracts,
        openedAt: now.subtract(const Duration(days: 5)),
        openCreditPerShare: Decimal.parse('0.50'),
        ruleProfileVersionId: versionId ?? RuleProfileVersionIds.standardV1,
      ),
    );
    if (snapshot) {
      await repo.appendSnapshot(
        NewSnapshotInput(
          legId: created.leg.id,
          takenAt: readingAt ?? now,
          optionMark: Decimal.parse(mark),
          underlyingPrice: Decimal.parse(strike),
          deltaAsEntered: -double.parse(delta),
          deltaConvention: DeltaConvention.option,
          iv: 45,
        ),
      );
    }
    return created.leg;
  }

  /// A leg with almost no extrinsic left: its only fired gate is the tail, so
  /// it is `Leave` at calendar DTE 4+ and `Close` at DTE 3 or less.
  Future<void> tailLeg(
    InMemoryWheelRepository repo, {
    required String ticker,
    required DateTime expiration,
    required DateTime at,
  }) async {
    final underlying = await repo.getOrCreateUnderlying(ticker);
    final created = await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('20'),
        expiration: expiration,
        contracts: 1,
        openedAt: at.subtract(const Duration(days: 5)),
        openCreditPerShare: Decimal.parse('0.05'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: created.leg.id,
        takenAt: at,
        optionMark: Decimal.parse('0.05'),
        underlyingPrice: Decimal.parse('20'),
        deltaAsEntered: -0.15,
        deltaConvention: DeltaConvention.option,
        iv: 45,
      ),
    );
  }

  Future<ProviderContainer> build(InMemoryWheelRepository repo, {DateTime? at}) async {
    final container = ProviderContainer(
      overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(portfolioControllerProvider, (previous, next) {});
    await container.read(portfolioControllerProvider.notifier).load(now: at ?? now);
    return container;
  }

  group('S-302: the bucket summary cannot drift from Today\'s', () {
    test('the five counts and their order come from kBucketOrder', () async {
      final repo = InMemoryWheelRepository();
      // Assign: delta at or above 0.70.
      await leg(repo, ticker: 'A', delta: '0.85', strike: '20');
      // Roll: inside the 0.30-0.40 band.
      await leg(repo, ticker: 'B', delta: '0.35', strike: '20');
      // Close: profit target captured -- 0.50 credit against a 0.20 mark is
      // 60% captured, past the 50% target. Delta stays below the band so
      // Gate 1 is the only gate that can fire.
      await leg(repo, ticker: 'C', delta: '0.10', strike: '20', mark: '0.20');
      // Leave: below the band, no profit target.
      await leg(repo, ticker: 'D', delta: '0.15', strike: '20');
      await leg(repo, ticker: 'E', delta: '0.12', strike: '20');
      // No data: no snapshot at all.
      await leg(repo, ticker: 'F', delta: '0.00', strike: '20', snapshot: false);

      final container = await build(repo);
      final counts = container.read(portfolioControllerProvider).bucketCounts;

      expect(counts.map((c) => c.bucket.runtimeType).toList(), [
        for (final bucket in kBucketOrder) bucket.runtimeType,
      ]);
      expect(counts.map((c) => c.count).toList(), [1, 1, 1, 2, 1]);
    });

    test('"No data" is its own count, never folded into Leave', () async {
      final repo = InMemoryWheelRepository();
      await leg(repo, ticker: 'D', delta: '0.15', strike: '20');
      await leg(repo, ticker: 'F', delta: '0.00', strike: '20', snapshot: false);

      final container = await build(repo);
      final counts = container.read(portfolioControllerProvider).bucketCounts;

      final leave = counts.singleWhere((c) => c.bucket is BucketLeave);
      final unknown = counts.singleWhere((c) => c.bucket is BucketUnknown);
      expect(leave.count, 1);
      expect(unknown.count, 1);
    });

    test('Portfolio and Today agree, leg for leg', () async {
      final repo = InMemoryWheelRepository();
      await leg(repo, ticker: 'A', delta: '0.85', strike: '20');
      await leg(repo, ticker: 'B', delta: '0.35', strike: '20');
      await leg(repo, ticker: 'C', delta: '0.10', strike: '20');
      await leg(repo, ticker: 'D', delta: '0.15', strike: '20');
      await leg(repo, ticker: 'E', delta: '0.12', strike: '20');
      await leg(repo, ticker: 'F', delta: '0.00', strike: '20', snapshot: false);

      final container = await build(repo);
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: now);

      final portfolio = container.read(portfolioControllerProvider).bucketCounts;
      final today = container.read(todayControllerProvider).bucketCounts;

      expect(
        portfolio.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
        today.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
      );
    });

    test('a past-expiration leg is in neither screen\'s counts', () async {
      final repo = InMemoryWheelRepository();
      await leg(repo, ticker: 'D', delta: '0.15', strike: '20');
      // Expired 3 days ago, still open in the book. Today leaves it out of its
      // five counts, so Portfolio must too or the two screens disagree.
      await leg(
        repo,
        ticker: 'X',
        delta: '0.85',
        strike: '20',
        expiration: now.subtract(const Duration(days: 3)),
      );

      final container = await build(repo);
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: now);

      final portfolio = container.read(portfolioControllerProvider).bucketCounts;
      final today = container.read(todayControllerProvider).bucketCounts;

      expect(
        portfolio.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
        today.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
      );
      expect(today.singleWhere((c) => c.bucket is BucketLeave).count, 1);
      expect(today.singleWhere((c) => c.bucket is BucketAssign).count, 0);
    });

    test('a past-expiration reading is not in the aging note', () async {
      final repo = InMemoryWheelRepository();
      await leg(
        repo,
        ticker: 'D',
        delta: '0.15',
        strike: '20',
        readingAt: now.subtract(const Duration(days: 10)),
      );
      await leg(
        repo,
        ticker: 'X',
        delta: '0.15',
        strike: '20',
        expiration: now.subtract(const Duration(days: 3)),
        readingAt: now.subtract(const Duration(days: 10)),
      );

      final container = await build(repo);
      final aging = container.read(portfolioControllerProvider).agingLine;

      expect(aging, startsWith('1 reading older than 7 days'));
      expect(aging, contains('D'));
      expect(aging, isNot(contains('X')));
    });

    test('an edited profile never reclassifies a leg pinned to the old version', () async {
      final repo = InMemoryWheelRepository();
      // Pinned to v1, whose assign threshold is 0.70: 0.85 assigns.
      await leg(repo, ticker: 'A', delta: '0.85', strike: '20');

      final container = await build(repo);
      final before = container.read(portfolioControllerProvider).bucketCounts;
      expect(before.singleWhere((c) => c.bucket is BucketAssign).count, 1);

      // `Standard` moves on: a new version with a much higher assign
      // threshold, so 0.85 would no longer assign under the *current*
      // thresholds. The pinned leg must not move.
      await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: now,
        values: NewRuleProfileVersionInput(
          profitTargetPct: 50,
          assignThreshold: 0.95,
          baseRollBand: 0.30,
          midIvRollBand: 0.35,
          highIvRollBand: 0.40,
          midIvCutoff: 40,
          highIvCutoff: 70,
          tailDteDays: 7,
          tailExtrinsicThreshold: Decimal.parse('0.05'),
          minIvRank: 0,
          minAnnualisedYield: 0,
          targetDteMin: 30,
          targetDteMax: 45,
          targetDelta: 0.30,
        ),
      );

      await container.read(portfolioControllerProvider.notifier).load(now: now);
      final after = container.read(portfolioControllerProvider).bucketCounts;

      expect(
        after.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
        before.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
      );
      expect(after.singleWhere((c) => c.bucket is BucketAssign).count, 1);
    });
  });

  group('the DTE gate reads the same calendar difference Today does', () {
    test('a leg at calendar DTE 4 is Leave on both screens, not Close', () async {
      // 20:30 on Sep 28 to an Oct 2 expiration is a raw instant difference of
      // 3 days and a calendar difference of 4. Almost no extrinsic is left, so
      // the tail gate is the only one in play: the raw count puts the leg at
      // DTE 3 (inside the tail) and the calendar count puts it at 4 (outside).
      final lateNow = DateTime(2026, 9, 28, 20, 30);
      final repo = InMemoryWheelRepository();
      await tailLeg(repo, ticker: 'A', expiration: DateTime(2026, 10, 2), at: lateNow);
      await tailLeg(repo, ticker: 'B', expiration: DateTime(2026, 10, 3), at: lateNow);

      final container = await build(repo, at: lateNow);
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: lateNow);

      final portfolio = container.read(portfolioControllerProvider).bucketCounts;
      final today = container.read(todayControllerProvider).bucketCounts;

      expect(today.singleWhere((c) => c.bucket is BucketLeave).count, 2);
      expect(
        portfolio.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
        today.map((c) => '${c.bucket.runtimeType}:${c.count}').toList(),
      );
    });
  });
}
