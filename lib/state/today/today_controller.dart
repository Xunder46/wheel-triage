import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/snapshot.dart' as models;
import '../../domain/models/underlying.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/bucket.dart';
import '../../domain/rules/capital_committed.dart' as capital;
import '../../domain/rules/classify.dart';
import '../../domain/rules/expiry.dart' as expiry;
import '../../domain/rules/formulas.dart' as formulas;
import '../../domain/rules/obligation.dart' as obligation;
import '../../domain/rules/premium_collected.dart' as premium;
import '../../domain/rules/reading_age.dart' as reading;
import '../../domain/rules/rule_profile.dart';
import '../../domain/rules/triage_input.dart';
import '../notifications/notification_providers.dart';
import '../repository_providers.dart';

/// Today's sort options (D-14): the list's own order — `Assign`, `Roll`,
/// `Close`, `Leave`, `No data` — is the default, because "what needs me?" is
/// the question this screen answers first. DTE and ticker are the two
/// lookups that follow.
enum TodaySort { bucket, dte, ticker }

/// The label the sort control shows for [sort] (D-14). One definition, so
/// the button and the menu cannot drift.
String todaySortLabel(TodaySort sort) => switch (sort) {
  TodaySort.bucket => 'By bucket',
  TodaySort.dte => 'By DTE',
  TodaySort.ticker => 'By ticker',
};

/// One row's worth of pre-computed display data — the screen never
/// re-derives a bucket or re-reads the repository itself.
class TodayItem {
  final Leg leg;
  final Underlying underlying;
  final models.Snapshot? latestSnapshot;
  final Bucket bucket;
  final int dte;

  /// Calendar days since the latest reading, or `null` when there is none.
  /// Carried so a row can name its date without re-reading the snapshot.
  final int? readingAgeDays;

  /// D-11's inline-Update predicate: no reading at all, or one older than
  /// `kAgingDays`.
  final bool needsReading;

  /// D-11's aging predicate, which deliberately excludes the no-reading
  /// case — "No data" is its own count (Feature Invariant 19).
  final bool olderThanAging;

  /// Whether "Mark all expired" covers this leg (D-13) — only meaningful on
  /// a past-expiration item; computed at load so the card never re-derives
  /// the rule.
  final bool batchEligible;

  const TodayItem({
    required this.leg,
    required this.underlying,
    required this.latestSnapshot,
    required this.bucket,
    required this.dte,
    required this.readingAgeDays,
    required this.needsReading,
    required this.olderThanAging,
    this.batchEligible = false,
  });

  /// This item as the rules engine's own card entry, so the expiry card's
  /// copy builders (`expiryReadingLine`, `expiryBatchExplanation`) can be
  /// called without the card re-deriving anything.
  expiry.ExpiryCardEntry get cardEntry => expiry.ExpiryCardEntry(
    leg: leg,
    latestSnapshot: latestSnapshot,
    batchEligible: batchEligible,
  );
}

/// One expiration date's worth of the "Expiring this week" card (D-10):
/// the date and the legs expiring on it, earliest date first.
class ExpiringDateGroup {
  final DateTime date;
  final List<TodayItem> legs;

  const ExpiringDateGroup({required this.date, required this.legs});
}

/// `docs/brief-pro.md` D-P13: a leg past its expiration is no longer part of
/// the book's live counts — it appears only in the past-expiration card
/// (Phase 10), so it is split out of [items] rather than filtered at render
/// time. The order itself is [kBucketOrder] (D-46), shared with Portfolio so
/// the two screens cannot rank the same legs differently.
int _rank(Bucket bucket) =>
    kBucketOrder.indexWhere((prototype) => prototype.runtimeType == bucket.runtimeType);

class TodayState {
  final bool isLoading;
  final String? error;

  /// Every open leg that has not passed its expiration, in [sort] order.
  final List<TodayItem> items;

  /// Open legs whose expiration has already passed (D-P13), oldest first.
  final List<TodayItem> pastExpiration;

  /// The legs expiring inside the next seven days, grouped by expiration
  /// date (D-10), earliest first. Empty when nothing is due — the screen
  /// then renders no card at all.
  final List<ExpiringDateGroup> expiringThisWeek;

  final TodaySort sort;

  /// The bucket a count chip has filtered the list to, or `null` for no
  /// filter. A [Type] (`BucketAssign`, …) rather than a [Bucket] instance:
  /// the filter is about *which* verdict, and two `Bucket`s with different
  /// reasons are the same filter.
  final Type? bucketFilter;

  /// Whether the aging line has filtered the list to the legs it counts.
  final bool agingOnly;

  /// D-11's aging line — `1 reading older than 7 days · T, from Sep 17`, or
  /// the empty string when nothing is aging.
  final String agingLine;

  /// The overlapping aging count (D-11): an aging leg stays in its bucket's
  /// count too.
  final int agingCount;

  /// D-8's ledger strip, all computed at load: credits minus buybacks for the
  /// calendar month containing the load, the same figure from 1 January, and
  /// the book's live committed capital. All three are whole dollars by the
  /// time they render (D-15).
  final Decimal netPremiumMonth;
  final Decimal netPremiumYearToDate;
  final Decimal committedNow;

  /// The month the first tile names — `Sep` — so the label and the figure can
  /// never describe different periods.
  final String ledgerMonthLabel;

  /// The user's wheel capital, or `null` when they have not set one (D-6).
  final Decimal? wheelCapital;

  /// Underlyings over the concentration limit, largest share first (D-10).
  /// Always empty when [wheelCapital] is null — with nothing to divide by
  /// there is no ratio to exceed anything.
  final List<capital.ConcentrationFlag> concentrationFlags;

  const TodayState({
    this.isLoading = true,
    this.error,
    this.items = const [],
    this.pastExpiration = const [],
    this.expiringThisWeek = const [],
    this.sort = TodaySort.bucket,
    this.bucketFilter,
    this.agingOnly = false,
    this.agingLine = '',
    this.agingCount = 0,
    required this.netPremiumMonth,
    required this.netPremiumYearToDate,
    required this.committedNow,
    required this.ledgerMonthLabel,
    this.wheelCapital,
    this.concentrationFlags = const [],
  });

  /// The state before the first load settles: nothing is known yet, so every
  /// ledger figure sits at zero and no month or capital is named.
  factory TodayState.initial() => TodayState(
    netPremiumMonth: Decimal.zero,
    netPremiumYearToDate: Decimal.zero,
    committedNow: Decimal.zero,
    ledgerMonthLabel: '',
  );

  /// The single paragraph under the ledger strip: D-8's premium definition
  /// followed by D-9's committed-now definition.
  String get ledgerDefinitionLine =>
      '${premium.kPremiumDefinitionLine} '
      '${capital.committedNowDefinition(committedNow: committedNow, wheelCapital: wheelCapital)}';

  /// The five counts, in [kBucketOrder] (D-46). Computed from [items], so a
  /// past-expiration leg is in none of them. The order, the zeros and the
  /// counting itself are `bucketCountsFor`'s — Portfolio's tiles read the same
  /// function, so the two screens cannot disagree about a count.
  List<({Bucket bucket, int count})> get bucketCounts =>
      bucketCountsFor(items.map((item) => item.bucket));

  /// How many legs currently sit in [bucket]'s bucket.
  int countFor(Type bucket) =>
      items.where((item) => item.bucket.runtimeType == bucket).length;

  /// The rows actually rendered: the bucket filter, then the aging filter,
  /// each preserving [sort] order.
  List<TodayItem> get visible {
    var rows = items;
    final bucket = bucketFilter;
    if (bucket != null) {
      rows = rows.where((item) => item.bucket.runtimeType == bucket).toList();
    }
    if (agingOnly) {
      rows = rows.where((item) => item.olderThanAging).toList();
    }
    return rows;
  }

  TodayState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<TodayItem>? items,
    List<TodayItem>? pastExpiration,
    List<ExpiringDateGroup>? expiringThisWeek,
    TodaySort? sort,
    Type? bucketFilter,
    bool clearBucketFilter = false,
    bool? agingOnly,
    String? agingLine,
    int? agingCount,
    Decimal? netPremiumMonth,
    Decimal? netPremiumYearToDate,
    Decimal? committedNow,
    String? ledgerMonthLabel,
    Decimal? wheelCapital,
    List<capital.ConcentrationFlag>? concentrationFlags,
  }) => TodayState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    items: items ?? this.items,
    pastExpiration: pastExpiration ?? this.pastExpiration,
    expiringThisWeek: expiringThisWeek ?? this.expiringThisWeek,
    sort: sort ?? this.sort,
    bucketFilter: clearBucketFilter ? null : (bucketFilter ?? this.bucketFilter),
    agingOnly: agingOnly ?? this.agingOnly,
    agingLine: agingLine ?? this.agingLine,
    agingCount: agingCount ?? this.agingCount,
    netPremiumMonth: netPremiumMonth ?? this.netPremiumMonth,
    netPremiumYearToDate: netPremiumYearToDate ?? this.netPremiumYearToDate,
    committedNow: committedNow ?? this.committedNow,
    ledgerMonthLabel: ledgerMonthLabel ?? this.ledgerMonthLabel,
    wheelCapital: wheelCapital ?? this.wheelCapital,
    concentrationFlags: concentrationFlags ?? this.concentrationFlags,
  );
}

/// The ledger strip's figures plus the concentration flags (D-8, D-9, D-10),
/// as [TodayController.load] collects them.
typedef _LedgerFigures = ({
  Decimal netPremiumMonth,
  Decimal netPremiumYearToDate,
  Decimal committedNow,
  String ledgerMonthLabel,
  Decimal? wheelCapital,
  List<capital.ConcentrationFlag> concentrationFlags,
});

class TodayController extends StateNotifier<TodayState> {
  TodayController(this._ref, this._repo) : super(TodayState.initial()) {
    load();
  }

  /// Needed for the notification scheduler: both mark-expired actions cancel
  /// the closed leg's reminders, exactly as a direct close does (S-171).
  final Ref _ref;
  final WheelRepository _repo;

  /// Loads every open leg, its underlying, its latest snapshot, and
  /// classifies it (S-021). `now` is always a parameter (Feature Invariant
  /// 7), defaulting to the wall clock only at this orchestration boundary —
  /// never inside `lib/domain/rules/`.
  ///
  /// A load is a fresh statement of the book, so it clears any active filter
  /// rather than leaving the list narrowed to a count that may no longer
  /// exist.
  Future<void> load({DateTime? now}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final effectiveNow = now ?? DateTime.now();
      final legs = await _repo.getOpenLegs();
      final items = <TodayItem>[];
      final past = <TodayItem>[];
      final aging = <reading.AgingEntry>[];

      for (final leg in legs) {
        final cycle = await _repo.getCycle(leg.cycleId);
        if (cycle == null) continue;
        final underlying = await _repo.getUnderlying(cycle.underlyingId);
        if (underlying == null) continue;

        final snapshot = await _repo.getLatestSnapshotForLeg(leg.id);

        // The leg's pinned threshold version — never the profile's current
        // one (Iteration 5 D-5): an edit must not reclassify what an open
        // position was opened under. A dangling pin degrades to the
        // built-in defaults (D-7).
        final versionData = await _repo.getRuleProfileVersion(leg.ruleProfileVersionId);
        final RuleProfile profile;
        if (versionData == null) {
          profile = RuleProfile.standard;
        } else {
          final profileData = await _repo.getRuleProfile(versionData.profileId);
          profile = RuleProfile.fromVersion(
            versionData,
            profileName: profileData?.name ?? 'Standard',
          );
        }

        final dteValue = formulas.dte(leg.expiration, effectiveNow);
        final input = triageInputFor(leg: leg, snapshot: snapshot, dte: dteValue);
        final bucket = classify(input, profile);
        final pastExpiration = expiry.isPastExpiration(leg, effectiveNow);

        final item = TodayItem(
          leg: leg,
          underlying: underlying,
          latestSnapshot: snapshot,
          bucket: bucket,
          dte: dteValue,
          readingAgeDays: snapshot == null ? null : reading.readingAgeDays(snapshot, effectiveNow),
          needsReading: reading.needsReading(latestSnapshot: snapshot, now: effectiveNow),
          olderThanAging: reading.olderThanAging(latestSnapshot: snapshot, now: effectiveNow),
          batchEligible: expiry.expiryBatchEligible(
            leg: leg,
            latestSnapshot: snapshot,
            now: effectiveNow,
          ),
        );

        if (pastExpiration) {
          past.add(item);
          continue;
        }
        items.add(item);
        if (snapshot != null) {
          aging.add((ticker: underlying.ticker, snapshot: snapshot));
        }
      }

      final ledger = await _ledger(effectiveNow);
      state = TodayState(
        isLoading: false,
        items: _sorted(items, state.sort),
        pastExpiration: past,
        expiringThisWeek: _expiringGroups(items, effectiveNow),
        sort: state.sort,
        agingLine: reading.agingLine(legs: aging, now: effectiveNow),
        agingCount: items.where((item) => item.olderThanAging).length,
        netPremiumMonth: ledger.netPremiumMonth,
        netPremiumYearToDate: ledger.netPremiumYearToDate,
        committedNow: ledger.committedNow,
        ledgerMonthLabel: ledger.ledgerMonthLabel,
        wheelCapital: ledger.wheelCapital,
        concentrationFlags: ledger.concentrationFlags,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Could not load positions: $e');
    }
  }

  /// The ledger strip's five figures plus the concentration flags (D-8, D-9,
  /// D-10). Split out of [load] so the read path reads as one statement.
  Future<_LedgerFigures> _ledger(DateTime effectiveNow) async {
    // `getAllLegs`, not `getOpenLegs`: a buyback is a closed leg's own debit,
    // and a closed cycle's assigned put is what proves the cycle still holds
    // shares.
    final allLegs = await _repo.getAllLegs();
    final prefs = await _repo.getPreferences();
    final inputs = await _capitalInputs(allLegs);
    final month = premium.monthPeriodContaining(effectiveNow);
    final year = premium.yearToDatePeriod(effectiveNow);

    return (
      netPremiumMonth: premium.netPremiumCollected(
        legs: allLegs,
        start: month.start,
        end: month.end,
      ),
      netPremiumYearToDate: premium.netPremiumCollected(
        legs: allLegs,
        start: year.start,
        end: year.end,
      ),
      committedNow: capital.currentCapitalCommitted(inputs, now: effectiveNow),
      ledgerMonthLabel: monthAbbreviation(month.start),
      wheelCapital: prefs.wheelCapital,
      concentrationFlags: capital.concentrationFlags(
        capitalByUnderlying: capital.capitalCommittedByUnderlying(inputs),
        wheelCapital: prefs.wheelCapital,
        concentrationLimitPct: prefs.concentrationLimitPct,
      ),
    );
  }

  /// One [capital.CycleCapitalInput] per cycle the book has legs for. The
  /// cycle list is derived from the legs rather than read from the repository:
  /// `WheelRepository` has no `getAllCycles` (Phase 9's Predicted Files keep
  /// `lib/data/` out of this change), and a cycle with no legs at all commits
  /// nothing anyway.
  Future<List<capital.CycleCapitalInput>> _capitalInputs(List<Leg> allLegs) async {
    final legsByCycle = <String, List<Leg>>{};
    for (final leg in allLegs) {
      legsByCycle.putIfAbsent(leg.cycleId, () => []).add(leg);
    }

    final inputs = <capital.CycleCapitalInput>[];
    for (final entry in legsByCycle.entries) {
      final cycle = await _repo.getCycle(entry.key);
      if (cycle == null) continue;
      final underlying = await _repo.getUnderlying(cycle.underlyingId);
      if (underlying == null) continue;
      inputs.add(
        capital.CycleCapitalInput(
          cycle: cycle,
          ticker: underlying.ticker,
          legs: entry.value,
          // Only a `holdingShares` cycle has an active lot; reading it for any
          // other status would be reading a lot that is no longer the book's.
          shareLot: cycle.status == WheelCycleStatus.holdingShares
              ? await _repo.getShareLotForCycle(cycle.id)
              : null,
        ),
      );
    }
    return inputs;
  }

  /// D-10's "Expiring this week" groups. The seven-day window, the
  /// inclusion of a leg expiring today and the date order all come from
  /// `obligation.expiringThisWeek`; this only maps its legs back to the
  /// items [load] already built, so the card never re-reads the repository.
  List<ExpiringDateGroup> _expiringGroups(List<TodayItem> items, DateTime now) {
    final byLegId = {for (final item in items) item.leg.id: item};
    return [
      for (final group in obligation.expiringThisWeek(
        legs: [for (final item in items) item.leg],
        now: now,
      ))
        ExpiringDateGroup(
          date: DateTime(group.date.year, group.date.month, group.date.day),
          legs: [for (final leg in group.legs) byLegId[leg.id]!],
        ),
    ];
  }

  /// D-13's "Mark all expired" (S-252): one atomic write covering every
  /// past-expiration leg whose latest reading was out of the money, each
  /// recorded on its own expiration date, followed by cancelling each
  /// closed leg's reminders.
  ///
  /// Returns `null` on success, or the failure's message. A failure is
  /// deliberately **not** put in `state.error`: the card reports it inline
  /// and must survive it, and the book is left exactly as it was.
  Future<String?> markAllExpired() async {
    final eligible = state.pastExpiration.where((item) => item.batchEligible).toList();
    // The repository treats an empty batch as an argument error, so the
    // nothing-to-do case is answered before the write is attempted.
    if (eligible.isEmpty) return null;
    try {
      final now = DateTime.now();
      await _repo.markExpired(
        legs: [
          for (final item in eligible)
            (legId: item.leg.id, closedAt: expiry.recordedCloseDateForExpiry(item.leg, now)),
        ],
      );
      for (final item in eligible) {
        await _ref.read(notificationSchedulerProvider).cancelForLeg(item.leg.id);
      }
      await load();
      return null;
    } catch (e) {
      return 'Could not mark these legs expired: $e';
    }
  }

  /// D-13's per-leg "Mark expired" on the card (S-253), for a leg the batch
  /// leaves out. The recorded date follows the same rule the detail sheet's
  /// own "Mark expired" uses, so the two entry points cannot disagree.
  /// Returns `null` on success, or the failure's message (see
  /// [markAllExpired]).
  Future<String?> markExpiredLeg({required String legId, DateTime? now}) async {
    TodayItem? item;
    for (final row in state.pastExpiration) {
      if (row.leg.id == legId) {
        item = row;
        break;
      }
    }
    if (item == null) return null;
    try {
      await _repo.closeLeg(
        legId: legId,
        reason: CloseReason.expiredWorthless,
        closeDebitPerShare: Decimal.zero,
        closeFee: null,
        closedAt: expiry.recordedCloseDateForExpiry(item.leg, now ?? DateTime.now()),
      );
      await _ref.read(notificationSchedulerProvider).cancelForLeg(legId);
      await load();
      return null;
    } catch (e) {
      return 'Could not mark this leg expired: $e';
    }
  }

  void setSort(TodaySort sort) =>
      state = state.copyWith(sort: sort, items: _sorted(state.items, sort));
  /// A second tap on the same count clears the filter; a tap on a different
  /// one replaces it (D-14).
  void toggleBucketFilter(Type bucket) => state = state.copyWith(
    bucketFilter: bucket,
    clearBucketFilter: state.bucketFilter == bucket,
  );

  void toggleAgingFilter() => state = state.copyWith(agingOnly: !state.agingOnly);

  List<TodayItem> _sorted(List<TodayItem> items, TodaySort sort) {
    final copy = List<TodayItem>.of(items);
    switch (sort) {
      case TodaySort.dte:
        copy.sort((a, b) => a.dte.compareTo(b.dte));
      case TodaySort.ticker:
        copy.sort((a, b) => a.underlying.ticker.compareTo(b.underlying.ticker));
      case TodaySort.bucket:
        copy.sort((a, b) => _rank(a.bucket).compareTo(_rank(b.bucket)));
    }
    return copy;
  }
}

final todayControllerProvider =
    StateNotifierProvider.autoDispose<TodayController, TodayState>((ref) {
      final repo = ref.watch(wheelRepositoryProvider);
      return TodayController(ref, repo);
    });
