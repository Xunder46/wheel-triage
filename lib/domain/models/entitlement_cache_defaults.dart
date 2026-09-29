import 'pro_plan_kind.dart';

/// Default values for the seeded `entitlement_cache` row (mirrors
/// `user_preferences_defaults.dart`'s pattern exactly), so
/// `InMemoryWheelRepository` never imports `app_database.dart` to reproduce
/// the same default values, and `AppDatabase.seedEntitlementCache()` (the
/// `onCreate` seed step and the `5 -> 6` migration's insert) has exactly one
/// place to read them from.
///
/// Every value here is the free tier's "never checked" state (D-26):
/// inactive, no plan, no expiry, no renewal, no billing issue, no purchase
/// date, and `checkedAt == null` — which is what makes the state `unknown`
/// rather than `inactive` until a store read succeeds. Pro is never forged
/// from an absent answer.
///
/// Pure Dart, no Drift/Flutter import.
abstract final class EntitlementCacheDefaults {
  /// The one, fixed storage-row id, mirroring `UserPreferencesDefaults.rowId`.
  /// A `lib/data/` implementation detail only — never exposed through
  /// `WheelRepository`'s signatures or carried on `EntitlementCacheData`.
  static const rowId = 'default';

  static const isActive = false;
  static const planKind = ProPlanKind.none;
  static const DateTime? expiresAt = null;
  static const willRenew = false;
  static const billingIssue = false;
  static const DateTime? purchasedAt = null;
  static const DateTime? checkedAt = null;

  /// [planKind]'s stored text, for the table's SQL-level `withDefault`.
  /// Spelled out rather than derived from `ProPlanKind.none.name` because a
  /// SQL default must be a compile-time constant and `Enum.name` is not one;
  /// S-255 pins that the two agree.
  static const planKindName = 'none';
}