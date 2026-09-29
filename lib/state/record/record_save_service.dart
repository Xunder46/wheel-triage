import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/share_lot.dart';
import '../../domain/models/underlying.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/basis.dart';
import '../entitlements/entitlement_providers.dart';
import '../entitlements/new_cycle_gate.dart';
import '../notifications/notification_providers.dart';
import '../preferences/preferences_provider.dart';
import '../repository_providers.dart';
import '../rule_profiles/rule_profile_providers.dart';

/// What a save did (D-19's result type). [created] opened a new cycle,
/// [attached] appended a leg to an existing share-holding cycle (D-12) and
/// [refused] wrote nothing and carries the one line to show.
///
/// [paywallRequired] is the free tier's own outcome (D-23): the book is at the
/// limit and the entitlement is not active, so no row of any table was
/// written. It is separate from [refused] because the two mean different
/// things to the screen — a refusal is the user's input being wrong, a paywall
/// requirement is the plan — and because the screen shows the D-24 line either
/// way while only one of them opens the paywall (D-30).
enum RecordSaveOutcome { created, attached, refused, paywallRequired }

class RecordSaveResult {
  const RecordSaveResult._({
    required this.outcome,
    this.ticker,
    this.legId,
    this.cycleId,
    this.refusalReason,
    this.trigger,
  });

  const RecordSaveResult.created({
    required String ticker,
    required String legId,
    required String cycleId,
  }) : this._(
         outcome: RecordSaveOutcome.created,
         ticker: ticker,
         legId: legId,
         cycleId: cycleId,
       );

  const RecordSaveResult.attached({
    required String ticker,
    required String legId,
    required String cycleId,
  }) : this._(
         outcome: RecordSaveOutcome.attached,
         ticker: ticker,
         legId: legId,
         cycleId: cycleId,
       );

  const RecordSaveResult.refused({required String reason})
    : this._(outcome: RecordSaveOutcome.refused, refusalReason: reason);

  /// D-23's outcome: nothing was written because the free tier's open-cycle
  /// limit is reached and the entitlement is not active. [trigger] is the
  /// finished D-24 line, built by the gate, which the screen shows and hands
  /// to the paywall.
  const RecordSaveResult.paywallRequired({required String trigger})
    : this._(outcome: RecordSaveOutcome.paywallRequired, trigger: trigger);

  final RecordSaveOutcome outcome;
  final String? ticker;
  final String? legId;
  final String? cycleId;
  final String? refusalReason;

  /// The D-24 line to show when [outcome] is `paywallRequired`, and `null`
  /// otherwise.
  final String? trigger;

  bool get isRefused => outcome == RecordSaveOutcome.refused;
  bool get isCreated => outcome == RecordSaveOutcome.created;
  bool get isAttached => outcome == RecordSaveOutcome.attached;
  bool get isPaywallRequired => outcome == RecordSaveOutcome.paywallRequired;
}

/// D-12's host-cycle resolution for a call, plus the one-line explanation
/// the Record screen shows *before* the save (S-233).
class CallHostResolution {
  const CallHostResolution._({
    required this.ticker,
    this.underlying,
    this.cycle,
    this.shareLot,
    this.wheelBasisPerShare,
    this.explanation,
    this.refusalReason,
  });

  const CallHostResolution.resolved({
    required String ticker,
    required Underlying underlying,
    required WheelCycle cycle,
    required ShareLot shareLot,
    required Decimal wheelBasisPerShare,
    required String explanation,
  }) : this._(
         ticker: ticker,
         underlying: underlying,
         cycle: cycle,
         shareLot: shareLot,
         wheelBasisPerShare: wheelBasisPerShare,
         explanation: explanation,
       );

  const CallHostResolution.refused({required String ticker, required String reason})
    : this._(ticker: ticker, refusalReason: reason);

  final String ticker;
  final Underlying? underlying;
  final WheelCycle? cycle;
  final ShareLot? shareLot;
  final Decimal? wheelBasisPerShare;
  final String? explanation;
  final String? refusalReason;

  bool get isRefused => refusalReason != null;
}

/// D-19's single entry point for a new leg: Record and the screener's
/// "Track this position" both call [save], so the two paths cannot diverge.
///
/// It owns D-12's host-cycle resolution, `createCycle` vs `openNextLeg`, the
/// standard profile's current version pin and reminder scheduling. Nothing
/// here writes a row on a refusal path — the refusal line is discovered by
/// reading, never by creating an `Underlying` the user did not ask for
/// (S-234).
class RecordSaveService {
  RecordSaveService(this._ref);

  final Ref _ref;

  /// D-12's resolution, as a pure read. `candidates` are the ticker's
  /// `holdingShares` cycles; `eligible` are those without an open call.
  Future<CallHostResolution> resolveCallHost(String ticker) async {
    final normalized = ticker.trim().toUpperCase();
    final repo = _ref.read(wheelRepositoryProvider);

    final candidates = <WheelCycle>[];
    for (final leg in await repo.getAllLegs()) {
      final cycle = await repo.getCycle(leg.cycleId);
      if (cycle == null || cycle.status != WheelCycleStatus.holdingShares) continue;
      if (candidates.any((c) => c.id == cycle.id)) continue;
      final underlying = await repo.getUnderlying(cycle.underlyingId);
      if (underlying?.ticker != normalized) continue;
      candidates.add(cycle);
    }

    if (candidates.isEmpty) {
      return CallHostResolution.refused(
        ticker: normalized,
        reason:
            'Calls are recorded against shares held from an assignment, and '
            'there are no $normalized shares on record.',
      );
    }

    final eligible = <WheelCycle>[];
    for (final cycle in candidates) {
      final legs = await repo.getLegsForCycle(cycle.id);
      final hasOpenCall = legs.any((l) => l.closedAt == null && l.optionType == OptionType.call);
      if (!hasOpenCall) eligible.add(cycle);
    }

    if (eligible.isEmpty) {
      return CallHostResolution.refused(
        ticker: normalized,
        reason: '$normalized already has an open call; close or roll it first.',
      );
    }

    // Derived (vetoable): more than one eligible is a data-repair edge case,
    // so the most recently started cycle wins.
    final cycle = eligible.reduce((a, b) => a.startedAt.isAfter(b.startedAt) ? a : b);
    final underlying = await repo.getUnderlying(cycle.underlyingId);
    final shareLot = await repo.getShareLotForCycle(cycle.id);
    if (underlying == null || shareLot == null) {
      return CallHostResolution.refused(
        ticker: normalized,
        reason:
            'Calls are recorded against shares held from an assignment, and '
            'there are no $normalized shares on record.',
      );
    }

    final legs = await repo.getLegsForCycle(cycle.id);
    final basis = wheelBasis(
      putLegs: legs.where((l) => l.optionType == OptionType.put).toList(),
      shareLot: shareLot,
      callLegsSinceAssignment: legs
          .where((l) => l.optionType == OptionType.call && l.closedAt != null)
          .toList(),
    );

    return CallHostResolution.resolved(
      ticker: normalized,
      underlying: underlying,
      cycle: cycle,
      shareLot: shareLot,
      wheelBasisPerShare: basis,
      explanation:
          'Attaches to the $normalized cycle started ${_shortDate(cycle.startedAt)}: '
          '${shareLot.contracts * 100} shares at a wheel-adjusted basis of '
          '\$${basis.toStringAsFixed(2)}.',
    );
  }

  /// The one write path. Puts always open a new cycle; calls resolve their
  /// host cycle first and are refused when there is none.
  Future<RecordSaveResult> save({
    required String ticker,
    required OptionType side,
    required Decimal strike,
    required DateTime expiration,
    required int contracts,
    required Decimal openCreditPerShare,
    double? ivAtOpen,
    double? ivRankAtOpen,
    Decimal? underlyingPriceAtOpen,
    Decimal? openFee,
    bool acceptsAssignment = true,
    DateTime? now,
  }) async {
    final normalized = ticker.trim().toUpperCase();
    final effectiveNow = now ?? DateTime.now();
    final repo = _ref.read(wheelRepositoryProvider);
    final profile = await _ref.read(currentRuleProfileProvider.future);

    final newLeg = NewLegInput(
      optionType: side,
      strike: strike,
      expiration: expiration,
      contracts: contracts,
      openedAt: effectiveNow,
      openCreditPerShare: openCreditPerShare,
      ruleProfileVersionId: profile.versionId,
      ivAtOpen: ivAtOpen,
      ivRankAtOpen: ivRankAtOpen,
      underlyingPriceAtOpen: underlyingPriceAtOpen,
      openFee: openFee,
      acceptsAssignment: acceptsAssignment,
    );

    final String legId;
    final String cycleId;
    final RecordSaveOutcome outcome;

    if (side == OptionType.call && normalized.isNotEmpty) {
      final host = await resolveCallHost(normalized);
      if (host.isRefused) return RecordSaveResult.refused(reason: host.refusalReason!);
      final leg = await repo.openNextLeg(cycleId: host.cycle!.id, leg: newLeg);
      legId = leg.id;
      cycleId = host.cycle!.id;
      outcome = RecordSaveOutcome.attached;
    } else {
      // D-23's gate, and the only place it is consulted. It runs *before*
      // `getOrCreateUnderlying` deliberately: a blocked save must not create
      // an underlying the user did not ask for (S-234's principle), and a
      // refusal that wrote an `Underlying` row would leave the book holding a
      // ticker with no trade behind it.
      final NewCycleGate gate = _ref.read(newCycleGateProvider);
      final decision = await gate.evaluate();
      if (decision is NewCycleBlocked) {
        return RecordSaveResult.paywallRequired(trigger: decision.line);
      }
      final underlying = await repo.getOrCreateUnderlying(normalized);
      final result = await repo.createCycle(underlyingId: underlying.id, firstLeg: newLeg);
      legId = result.leg.id;
      cycleId = result.cycle.id;
      outcome = RecordSaveOutcome.created;
    }

    final milestones =
        _ref.read(preferencesControllerProvider).valueOrNull?.notificationMilestones ??
        const [21, 7, 0];
    await _ref
        .read(notificationSchedulerProvider)
        .scheduleForLeg(
          legId: legId,
          ticker: normalized,
          optionType: side,
          strike: strike,
          expiration: expiration,
          milestones: milestones,
          now: effectiveNow,
        );

    return outcome == RecordSaveOutcome.attached
        ? RecordSaveResult.attached(ticker: normalized, legId: legId, cycleId: cycleId)
        : RecordSaveResult.created(ticker: normalized, legId: legId, cycleId: cycleId);
  }

  static String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

final recordSaveServiceProvider = Provider<RecordSaveService>(
  (ref) => RecordSaveService(ref),
);
