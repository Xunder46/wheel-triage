import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/snapshot.dart' as models;
import '../../domain/models/underlying.dart';
import '../../domain/rules/bucket.dart';
import '../../domain/rules/classify.dart';
import '../../domain/rules/formulas.dart' as formulas;
import '../../domain/rules/iv_resolution.dart';
import '../../domain/rules/rule_profile.dart';
import '../../domain/rules/triage_input.dart';
import '../repository_providers.dart';

/// Sort options for the positions list (§5.2): by bucket severity (the
/// screen's default), by DTE ascending, or by ticker alphabetically.
enum PositionSort { bucketSeverity, dte, ticker }

/// One row's worth of pre-computed display data — the screen never
/// re-derives a bucket or re-reads the repository itself.
class PositionListItem {
  final Leg leg;
  final Underlying underlying;
  final models.Snapshot? latestSnapshot;
  final Bucket bucket;
  final int dte;

  const PositionListItem({
    required this.leg,
    required this.underlying,
    required this.latestSnapshot,
    required this.bucket,
    required this.dte,
  });
}

class PositionsListState {
  final bool isLoading;
  final String? error;
  final List<PositionListItem> items;
  final PositionSort sort;

  const PositionsListState({
    this.isLoading = true,
    this.error,
    this.items = const [],
    this.sort = PositionSort.bucketSeverity,
  });

  PositionsListState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<PositionListItem>? items,
    PositionSort? sort,
  }) => PositionsListState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    items: items ?? this.items,
    sort: sort ?? this.sort,
  );
}

/// Bucket severity for sort purposes only (§5.2: "assign -> roll -> close ->
/// leave"; Feature Invariant 19 appends `unknown` last). Lower sorts first.
int _severity(Bucket bucket) => switch (bucket) {
  BucketAssign() => 0,
  BucketRoll() => 1,
  BucketClose() => 2,
  BucketLeave() => 3,
  BucketUnknown() => 4,
};

class PositionsListController extends StateNotifier<PositionsListState> {
  PositionsListController(this._repo) : super(const PositionsListState()) {
    load();
  }

  final WheelRepository _repo;

  /// Loads every open leg, its underlying, its latest snapshot, and
  /// classifies it (S-021). `now` is always a parameter (Feature Invariant
  /// 7), defaulting to the wall clock only at this orchestration boundary —
  /// never inside `lib/domain/rules/`.
  Future<void> load({DateTime? now}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final effectiveNow = now ?? DateTime.now();
      final legs = await _repo.getOpenLegs();
      final items = <PositionListItem>[];

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
          profile = RuleProfile.fromVersion(versionData, profileName: profileData?.name ?? 'Standard');
        }

        final dteValue = formulas.dte(leg.expiration, effectiveNow);
        final input = _triageInputFor(leg: leg, snapshot: snapshot, dte: dteValue);
        final bucket = classify(input, profile);

        items.add(
          PositionListItem(
            leg: leg,
            underlying: underlying,
            latestSnapshot: snapshot,
            bucket: bucket,
            dte: dteValue,
          ),
        );
      }

      state = state.copyWith(isLoading: false, items: _sorted(items, state.sort));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Could not load positions: $e');
    }
  }

  void setSort(PositionSort sort) => state = state.copyWith(sort: sort, items: _sorted(state.items, sort));

  List<PositionListItem> _sorted(List<PositionListItem> items, PositionSort sort) {
    final copy = List<PositionListItem>.of(items);
    switch (sort) {
      case PositionSort.dte:
        copy.sort((a, b) => a.dte.compareTo(b.dte));
      case PositionSort.ticker:
        copy.sort((a, b) => a.underlying.ticker.compareTo(b.underlying.ticker));
      case PositionSort.bucketSeverity:
        copy.sort((a, b) => _severity(a.bucket).compareTo(_severity(b.bucket)));
    }
    return copy;
  }
}

/// Shared with `position_detail_controller.dart` in spirit (same formula
/// calls) but kept local to each file rather than factored into a third
/// shared helper — each caller's snapshot-shape and error handling differ
/// enough (list needs only the latest snapshot; detail needs the whole
/// history for the sparkline) that a shared function would need as many
/// parameters as it saves.
TriageInput _triageInputFor({
  required Leg leg,
  required models.Snapshot? snapshot,
  required int dte,
}) {
  if (snapshot == null) {
    return TriageInput(dte: dte, acceptsAssignment: leg.acceptsAssignment);
  }
  final captured = formulas.capturedPct(
    openCredit: leg.openCreditPerShare,
    currentMark: snapshot.optionMark,
  );
  final deltaMag = formulas.deltaMagnitude(snapshot.deltaAsEntered);
  final intrinsicValue = formulas.intrinsic(
    optionType: leg.optionType,
    strike: leg.strike,
    spot: snapshot.underlyingPrice,
  );
  final extrinsicValue = formulas.extrinsic(currentMark: snapshot.optionMark, intrinsic: intrinsicValue);
  // Feature Invariant 18 (brief-followup A3): resolved IV (snapshot -> leg's
  // ivAtOpen -> profile default) feeds Gate 3, never `snapshot.iv` directly.
  final resolved = resolveIv(snapshot: snapshot, leg: leg);
  return TriageInput(
    capturedPct: captured,
    deltaMagnitude: deltaMag,
    iv: resolved.value,
    dte: dte,
    extrinsic: extrinsicValue,
    acceptsAssignment: leg.acceptsAssignment,
  );
}

final positionsListControllerProvider =
    StateNotifierProvider.autoDispose<PositionsListController, PositionsListState>((ref) {
      final repo = ref.watch(wheelRepositoryProvider);
      return PositionsListController(repo);
    });
