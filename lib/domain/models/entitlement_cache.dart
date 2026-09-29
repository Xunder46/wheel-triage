import 'package:freezed_annotation/freezed_annotation.dart';

import 'pro_plan_kind.dart';

part 'entitlement_cache.freezed.dart';

/// The store-derived entitlement cache (Pro Wave 2, schema v6, D-25) — what
/// the last **successful** store read reported, so Pro keeps working offline
/// and a failed read never has to guess.
///
/// Deliberately **not** part of the export envelope, and therefore
/// deliberately **without** `json_serializable`: it has no wire format at
/// all. Adding it to `LedgerExport` would let a hand-edited backup file
/// grant Pro, and restoring an old ledger would silently revoke it — so
/// `exportToJson` never carries this row and `restoreFromJson` never deletes
/// or rewrites it (S-257). The export's key set is unchanged by this model's
/// existence.
///
/// Plain data, no derivation: the tri-valued `EntitlementStatus` the app
/// reasons about (`active` / `inactive` / `unknown`, D-26) is computed in
/// `lib/state/`, never here.
@freezed
abstract class EntitlementCacheData with _$EntitlementCacheData {
  const factory EntitlementCacheData({
    /// Whether the store reported an active entitlement on the last
    /// successful read. `false` covers both "the store said no" and "never
    /// checked" — [checkedAt] is what tells those two apart (D-26).
    @Default(false) bool isActive,

    /// Which plan the store reported. `none` on the free tier.
    @Default(ProPlanKind.none) ProPlanKind planKind,

    /// When the entitlement expires, or `null` for lifetime and for
    /// "never checked".
    DateTime? expiresAt,

    /// Whether the store says the subscription will renew. `false` for
    /// lifetime and for a cancelled-but-not-yet-expired subscription, which
    /// stays active until the paid period ends (D-26).
    @Default(false) bool willRenew,

    /// Whether the store reports a billing problem. Display only — a
    /// subscription in billing retry is still active (D-26).
    @Default(false) bool billingIssue,

    /// The store's `originalPurchaseDate`, for the Settings plan row.
    DateTime? purchasedAt,

    /// When this row was last written from a successful store read; `null`
    /// means no read has ever succeeded, which is what makes the state
    /// `unknown` rather than `inactive` (D-26).
    DateTime? checkedAt,
  }) = _EntitlementCacheData;
}