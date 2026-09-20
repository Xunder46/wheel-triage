import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/share_lot.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/cycle_pnl.dart';
import '../../domain/rules/journal_aggregates.dart';
import '../repository_providers.dart';

/// One closed cycle's row on the Journal screen (§4.4) plus everything the
/// aggregates section needs to fold it in.
class JournalRow {
  final WheelCycle cycle;
  final String ticker;
  final List<Leg> legs;
  final CyclePnl pnl;

  const JournalRow({required this.cycle, required this.ticker, required this.legs, required this.pnl});
}

/// §4.4's aggregates across every closed cycle. `medianPremiumCapturePct` is
/// `null` when there are no closed legs with a computable capture (e.g. no
/// closed cycles at all).
class JournalAggregatesSummary {
  final double winRate;
  final double averageDaysInCycle;
  final double? medianPremiumCapturePct;
  final Decimal totalPremiumCollected;
  final Decimal totalFeesPaid;
  final Map<String, Decimal> netResultByUnderlying;
  final Map<int, int> rollCountDistribution;

  const JournalAggregatesSummary({
    required this.winRate,
    required this.averageDaysInCycle,
    required this.medianPremiumCapturePct,
    required this.totalPremiumCollected,
    required this.totalFeesPaid,
    required this.netResultByUnderlying,
    required this.rollCountDistribution,
  });

  static final empty = JournalAggregatesSummary(
    winRate: 0,
    averageDaysInCycle: 0,
    medianPremiumCapturePct: null,
    totalPremiumCollected: Decimal.zero,
    totalFeesPaid: Decimal.zero,
    netResultByUnderlying: const {},
    rollCountDistribution: const {},
  );
}

class JournalState {
  final bool isLoading;
  final String? error;
  final List<JournalRow> rows;
  final JournalAggregatesSummary aggregates;

  JournalState({
    this.isLoading = true,
    this.error,
    this.rows = const [],
    JournalAggregatesSummary? aggregates,
  }) : aggregates = aggregates ?? JournalAggregatesSummary.empty;

  JournalState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<JournalRow>? rows,
    JournalAggregatesSummary? aggregates,
  }) => JournalState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    rows: rows ?? this.rows,
    aggregates: aggregates ?? this.aggregates,
  );
}

class JournalController extends StateNotifier<JournalState> {
  JournalController(this._repo) : super(JournalState()) {
    load();
  }

  final WheelRepository _repo;

  /// Loads every closed cycle (newest-`endedAt`-first, per
  /// `WheelRepository.getClosedCycles()`), computes each one's
  /// contract-weighted `CyclePnl` (Feature Invariant 25), and folds the
  /// results into the §4.4 aggregates. `now` is always a parameter
  /// (`docs/conventions.md` §3) even though a closed cycle's own `daysHeld`
  /// uses its real `endedAt`, never `now` -- passed through uniformly so
  /// `computeCyclePnl`'s signature never has to special-case "closed" vs.
  /// "open" callers.
  Future<void> load({DateTime? now}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final effectiveNow = now ?? DateTime.now();
      final cycles = await _repo.getClosedCycles();
      final rows = <JournalRow>[];
      for (final cycle in cycles) {
        final legs = await _repo.getLegsForCycle(cycle.id);
        final underlying = await _repo.getUnderlying(cycle.underlyingId);
        // CR-1: a cycle's assignment record is retained past call-away, so
        // the figures are computed from what was actually entered at
        // assignment -- `assignmentStrike`/`contracts` are user-entered and
        // need not match the assigned leg's own. `_reconstructShareLot` is
        // now only the legacy fallback, for a cycle closed before that
        // record was retained (unrecoverable) or a hand-built import.
        final assignment = await _repo.getAssignmentForCycle(cycle.id);
        final pnl = computeCyclePnl(
          legs: legs,
          shareLot: assignment ?? _reconstructShareLot(legs),
          startedAt: cycle.startedAt,
          endedAt: cycle.endedAt,
          now: effectiveNow,
        );
        rows.add(
          JournalRow(cycle: cycle, ticker: underlying?.ticker ?? '?', legs: legs, pnl: pnl),
        );
      }
      state = JournalState(isLoading: false, rows: rows, aggregates: _computeAggregates(rows));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Could not load the journal: $e');
    }
  }
}

/// Legacy fallback for `JournalController.load` — see its call site. Only
/// reached when the cycle has no retained assignment record (CR-1: a cycle
/// closed before the row was retained, or a hand-built import), where the
/// assigned put leg's own `strike`/`contracts` are the only stand-in
/// available. They are *not* necessarily the assignment's, so this is an
/// approximation, not an equivalent — do not prefer it over the record.
/// `null` when the cycle never reached a put-side assignment (it closed
/// entirely on the put side).
ShareLot? _reconstructShareLot(List<Leg> legs) {
  final assigned = assignedPutLeg(legs);
  if (assigned == null || assigned.closedAt == null) return null;
  return ShareLot(
    id: 'reconstructed-${assigned.id}',
    cycleId: assigned.cycleId,
    assignedAt: assigned.closedAt!,
    assignmentStrike: assigned.strike,
    contracts: assigned.contracts,
  );
}

JournalAggregatesSummary _computeAggregates(List<JournalRow> rows) {
  if (rows.isEmpty) return JournalAggregatesSummary.empty;
  final netResults = rows.map((r) => r.pnl.netResult).toList();
  final daysHeldValues = rows.map((r) => r.pnl.daysHeld).toList();
  final allClosedLegs = rows.expand((r) => r.legs).toList();
  final totalPremiums = rows.map((r) => r.pnl.totalPremium).toList();
  final totalFeesList = rows.map((r) => r.pnl.totalFees).toList();
  final underlyingEntries = rows.map((r) => (ticker: r.ticker, netResult: r.pnl.netResult)).toList();
  final rollCounts = rows.map((r) => r.pnl.rollCount).toList();

  return JournalAggregatesSummary(
    winRate: winRate(netResults),
    averageDaysInCycle: averageDaysInCycle(daysHeldValues),
    medianPremiumCapturePct: medianPremiumCapturePct(allClosedLegs),
    totalPremiumCollected: totalPremiumCollected(totalPremiums),
    totalFeesPaid: totalFeesPaid(totalFeesList),
    netResultByUnderlying: netResultByUnderlying(underlyingEntries),
    rollCountDistribution: rollCountDistribution(rollCounts),
  );
}

final journalControllerProvider = StateNotifierProvider.autoDispose<JournalController, JournalState>((
  ref,
) {
  final repo = ref.watch(wheelRepositoryProvider);
  return JournalController(repo);
});
