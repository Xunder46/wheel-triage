import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_converters.dart';

part 'leg.freezed.dart';
part 'leg.g.dart';

/// A short put or short call (§1 — the app only models one short leg at a
/// time; no spreads).
enum OptionType { put, call }

/// Why a leg closed (§3.3).
enum CloseReason { rolled, closedEarly, expiredWorthless, assigned }

/// One option contract as it was opened. A roll closes one [Leg] and opens
/// the next — it never mutates a leg in place (§3.3). `legNetCredit` and
/// `cycleCumulativeCredit` are derived, never stored (see
/// `lib/domain/rules/roll_chain.dart`, owned by @developer).
///
/// [ruleProfileVersionId] is set once at creation and never mutated by a
/// later profile edit (Feature Invariant 8, reshaped by Iteration 5's
/// D-3/D-4): the stored id names a `rule_profile_version` row, not the
/// mutable profile, so a position's rules stay truthful to what was in
/// force when it opened. `deltaConvention` deliberately does
/// NOT live here — it lives on [Snapshot] only (Feature Invariant 5).
@freezed
abstract class Leg with _$Leg {
  const factory Leg({
    required String id,
    required String cycleId,
    required int sequence,
    required OptionType optionType,
    @DecimalJsonConverter() required Decimal strike,
    required DateTime expiration,
    required int contracts,
    required DateTime openedAt,
    @DecimalJsonConverter() required Decimal openCreditPerShare,
    DateTime? closedAt,
    @NullableDecimalJsonConverter() Decimal? closeDebitPerShare,
    CloseReason? closeReason,
    String? rolledFromLegId,
    required String ruleProfileVersionId,
    double? ivAtOpen,
    double? ivRankAtOpen,
    double? deltaAtOpen,
    @NullableDecimalJsonConverter() Decimal? underlyingPriceAtOpen,

    /// Total fee for opening this leg's transaction, in dollars (integer
    /// cents on disk) — never per-share, never per-contract (Phase 15).
    /// `null` means "not recorded," never zero (§4.3) — a pre-v3 leg
    /// migrates to `null`, and callers must not coerce a missing fee to
    /// `Decimal.zero` anywhere above the persistence boundary.
    @NullableDecimalJsonConverter() Decimal? openFee,

    /// Same shape as [openFee], for the transaction that closed this leg.
    /// Always `null` while [closedAt] is still `null` (Feature Invariant
    /// 28: an open leg's missing closing cost is expected, not a gap).
    @NullableDecimalJsonConverter() Decimal? closeFee,

    /// Whether this leg's owner is willing to be assigned rather than roll
    /// (Gate 2, `docs/brief-ledger.md` §3.3). Set once at leg creation;
    /// existing pre-v3 rows migrate to `true`. A roll's new leg inherits or
    /// re-asks this value at the caller's discretion (`lib/state/`) — the
    /// repository itself never derives it.
    @Default(true) bool acceptsAssignment,
  }) = _Leg;

  factory Leg.fromJson(Map<String, Object?> json) => _$LegFromJson(json);
}
