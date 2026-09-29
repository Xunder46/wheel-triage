import 'package:decimal/decimal.dart';

import '../../domain/models/entitlement_status.dart';
import '../../domain/models/pro_plan_kind.dart';

/// The injectable seam between the app and the App Store (Pro Wave 2, D-27),
/// in the shape `NotificationGateway` already established
/// (`docs/conventions.md` §6): everything above it depends on this interface,
/// and exactly one implementation talks to the store SDK.
///
/// **No type in this file is a trade type.** There is no `Leg`, no `Snapshot`,
/// no `Underlying` and no ledger value here, so the seam *cannot* carry the
/// user's trading data to a purchase SDK — that is a structural guarantee, not
/// a convention (D-35, S-288). The only thing that ever crosses it is a store
/// product identifier, a price string and an entitlement flag.
///
/// The gateway is a thin transport. It never decides whether the user is Pro:
/// it reports what the store said (`EntitlementSnapshot`), and the free-tier
/// decision lives in `lib/state/entitlements/` (D-28).
abstract class PurchaseGateway {
  /// Prepares the SDK. Idempotent, and never throws: a failed or impossible
  /// configuration leaves the gateway inert (no offerings, `unknown`
  /// entitlement, every purchase `unavailable`) rather than broken.
  Future<void> configure();

  /// The plans the store is currently offering, or `null` when the store
  /// cannot be reached — which the paywall renders as "no plans", never as a
  /// hard-coded fallback price (D-31).
  Future<ProOfferings?> loadOfferings();

  /// What the store currently reports. `unknown` is the answer for "no
  /// successful read" — including every failure — so a caller can tell a
  /// successful "not subscribed" apart from "no answer at all" (D-26).
  Future<EntitlementSnapshot> currentEntitlement();

  /// Buys [productId]. The identifier is the only thing this call takes; it
  /// carries no position, quantity or price from the app.
  Future<PurchaseOutcome> purchase(String productId);

  /// Restores from the store account.
  Future<PurchaseOutcome> restore();

  /// Opens the store's own subscription-management page. A no-op when the
  /// store reports no management page, or on a platform that has no handler.
  Future<void> showManageSubscriptions();

  /// Registers [listener] for the store's own entitlement updates, so a
  /// renewal, a cancellation or a refund that happens outside the app is
  /// reflected without the user doing anything (S-271). Registering twice
  /// must not double-fire.
  void addEntitlementListener(void Function(EntitlementSnapshot) listener);
}

/// What the store says about the entitlement right now (D-25/D-26).
///
/// Mirrors the persisted cache's fields exactly, minus `checkedAt` (which is a
/// property of the *read*, not of the store) — so a snapshot can be written to
/// the cache as-is and a cache row can be replayed as a snapshot when a read
/// fails.
class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.status,
    this.planKind = ProPlanKind.none,
    this.expiresAt,
    this.willRenew = false,
    this.billingIssue = false,
    this.purchasedAt,
  });

  /// No read has ever succeeded.
  const EntitlementSnapshot.unknown() : this(status: EntitlementStatus.unknown);

  /// A successful read that reported no entitlement.
  const EntitlementSnapshot.inactive() : this(status: EntitlementStatus.inactive);

  /// A successful read that reported the entitlement.
  const EntitlementSnapshot.active({
    ProPlanKind planKind = ProPlanKind.none,
    DateTime? expiresAt,
    bool willRenew = false,
    bool billingIssue = false,
    DateTime? purchasedAt,
  }) : this(
         status: EntitlementStatus.active,
         planKind: planKind,
         expiresAt: expiresAt,
         willRenew: willRenew,
         billingIssue: billingIssue,
         purchasedAt: purchasedAt,
       );

  final EntitlementStatus status;

  /// Which plan the store named. `none` when free, and also when the store
  /// reports an active entitlement for a product this app does not recognise.
  final ProPlanKind planKind;

  /// When the entitlement ends. `null` for lifetime, and for a free tier.
  final DateTime? expiresAt;

  /// Whether the store says the subscription will renew. Always `false` for
  /// lifetime.
  final bool willRenew;

  /// Whether the store reports a billing problem. Display only — a
  /// subscription in billing retry stays `active`.
  final bool billingIssue;

  /// The store's original purchase date, for the Settings plan row.
  final DateTime? purchasedAt;

  /// Whether this snapshot is an active entitlement. A convenience for the
  /// adapter, which cannot name `EntitlementStatus` without importing
  /// `lib/domain/models/` (D-27).
  bool get isActive => status == EntitlementStatus.active;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntitlementSnapshot &&
          other.status == status &&
          other.planKind == planKind &&
          other.expiresAt == expiresAt &&
          other.willRenew == willRenew &&
          other.billingIssue == billingIssue &&
          other.purchasedAt == purchasedAt);

  @override
  int get hashCode =>
      Object.hash(status, planKind, expiresAt, willRenew, billingIssue, purchasedAt);

  @override
  String toString() =>
      'EntitlementSnapshot(${status.name}, ${planKind.name}, expiresAt: $expiresAt, '
      'willRenew: $willRenew, billingIssue: $billingIssue, purchasedAt: $purchasedAt)';
}

/// The result of a purchase or a restore (D-27/D-32). A sealed class with a
/// variant per outcome, so a caller that forgets one cannot compile — the same
/// shape as `Bucket`.
sealed class PurchaseOutcome {
  const PurchaseOutcome();

  const factory PurchaseOutcome.purchased() = PurchasePurchased;
  const factory PurchaseOutcome.pending() = PurchasePending;
  const factory PurchaseOutcome.cancelled() = PurchaseCancelled;
  const factory PurchaseOutcome.failed() = PurchaseFailed;
  const factory PurchaseOutcome.unavailable() = PurchaseUnavailable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PurchaseOutcome && other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => runtimeType.toString();
}

/// The store completed the purchase.
final class PurchasePurchased extends PurchaseOutcome {
  const PurchasePurchased();
}

/// The store accepted the purchase but has not approved it yet — Ask to Buy,
/// or a pending payment method. Pro does **not** turn on (D-32).
final class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}

/// The user dismissed the store's sheet. Not an error, and not worth a
/// message: the user did it deliberately (D-32).
final class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

/// The store tried and refused, for a reason the app cannot act on.
final class PurchaseFailed extends PurchaseOutcome {
  const PurchaseFailed();
}

/// Nothing was attempted because the store could not be reached, or the
/// gateway was never configured.
final class PurchaseUnavailable extends PurchaseOutcome {
  const PurchaseUnavailable();
}

/// The plans the store is offering, as the store returned them. Ordering is
/// **not** this type's job: `pro_plans.dart` imposes the display order (D-31).
class ProOfferings {
  const ProOfferings({required this.plans});

  final List<ProPlanOffer> plans;
}

/// One purchasable plan, built only from the store's own fields (D-31).
///
/// Nothing here is hard-coded: [priceString] is the store's own localized
/// price text, [price] is its numeric value (used **only** to derive the
/// annual per-month figure, and never as a gate input), and [trial] is
/// whatever the store says the introductory offer is. An empty `plans` list is
/// the honest rendering of a store that returned nothing.
class ProPlanOffer {
  const ProPlanOffer({
    required this.productId,
    required this.priceString,
    required this.price,
    required this.currencyCode,
    this.trial,
  });

  final String productId;

  /// The store's own formatted price, e.g. `"$29.99"` in the device's locale.
  final String priceString;

  /// The store's numeric price, converted once from the SDK's `double` at the
  /// adapter boundary. Display only — no gate in this app reads it.
  final Decimal price;

  final String currencyCode;

  /// The store's introductory offer, when there is one.
  final TrialOffer? trial;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProPlanOffer &&
          other.productId == productId &&
          other.priceString == priceString &&
          other.price == price &&
          other.currencyCode == currencyCode &&
          other.trial == trial);

  @override
  int get hashCode => Object.hash(productId, priceString, price, currencyCode, trial);

  @override
  String toString() => 'ProPlanOffer($productId, $priceString $currencyCode, trial: $trial)';
}

/// An introductory offer, in the store's own units (D-27/D-31). The app never
/// states a trial length the store did not report.
class TrialOffer {
  const TrialOffer({required this.units, required this.unit});

  final int units;
  final TrialPeriodUnit unit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrialOffer && other.units == units && other.unit == unit);

  @override
  int get hashCode => Object.hash(units, unit);

  @override
  String toString() => 'TrialOffer($units ${unit.name})';
}

/// The store's own period unit for an introductory offer. Mirrors the SDK's
/// enum so the seam never exposes an SDK type (D-27).
enum TrialPeriodUnit { day, week, month, year, unknown }
