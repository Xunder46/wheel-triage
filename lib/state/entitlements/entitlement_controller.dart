import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/purchase_gateway.dart';
import '../../data/wheel_repository.dart';
import '../../domain/models/entitlement_cache.dart';
import '../../domain/models/entitlement_status.dart';
import '../../domain/models/pro_plan_kind.dart';

/// What the app currently believes about the user's entitlement (Pro Wave 2,
/// D-26/D-29).
///
/// [status] is **tri-valued** on purpose: `unknown` means no store read has
/// ever succeeded, which is not the same fact as `inactive`, and only
/// `active` ever unlocks anything (D-26, R17). A free tier is never inferred
/// from an absent answer.
///
/// The remaining fields are the store's own report, carried verbatim for
/// display: which plan, when it ends, whether it renews, whether the store
/// reports a billing problem, and when it was first bought. Nothing here is
/// derived from the book — this state never reads a leg, a cycle or a
/// snapshot, and nothing about the book is ever gated on it.
class EntitlementState {
  const EntitlementState({
    this.status = EntitlementStatus.unknown,
    this.planKind = ProPlanKind.none,
    this.expiresAt,
    this.willRenew = false,
    this.billingIssue = false,
    this.purchasedAt,
    this.offeringsAvailable = false,
  });

  /// `active` / `inactive` / `unknown` — see the class doc.
  final EntitlementStatus status;

  /// Which plan the store named. `none` for free, and for an active
  /// entitlement on a product this app does not recognise.
  final ProPlanKind planKind;

  /// When the entitlement ends; `null` for lifetime and for free.
  final DateTime? expiresAt;

  /// Whether the store says the subscription will renew. A cancelled but
  /// unexpired subscription is still `active` with this `false` — Pro runs
  /// to the end of the paid period and is never revoked early (D-26).
  final bool willRenew;

  /// Whether the store reports a billing problem. Display only: a
  /// subscription in billing retry is still `active` (D-26, S-273).
  final bool billingIssue;

  /// The store's original purchase date, for the Settings plan row.
  final DateTime? purchasedAt;

  /// Whether the last `loadOfferings()` answered with plans. `false` is the
  /// store being unreachable, which the paywall renders as an honest
  /// unavailable state rather than a hard-coded price (D-31, S-280).
  final bool offeringsAvailable;

  /// Whether Pro is on. The single thing anything gates on.
  bool get isActive => status == EntitlementStatus.active;

  EntitlementState copyWith({
    EntitlementStatus? status,
    ProPlanKind? planKind,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    bool? willRenew,
    bool? billingIssue,
    DateTime? purchasedAt,
    bool clearPurchasedAt = false,
    bool? offeringsAvailable,
  }) => EntitlementState(
    status: status ?? this.status,
    planKind: planKind ?? this.planKind,
    expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    willRenew: willRenew ?? this.willRenew,
    billingIssue: billingIssue ?? this.billingIssue,
    purchasedAt: clearPurchasedAt ? null : (purchasedAt ?? this.purchasedAt),
    offeringsAvailable: offeringsAvailable ?? this.offeringsAvailable,
  );

  @override
  String toString() =>
      'EntitlementState(${status.name}, ${planKind.name}, expiresAt: $expiresAt, '
      'willRenew: $willRenew, billingIssue: $billingIssue, '
      'offeringsAvailable: $offeringsAvailable)';
}

/// The app's single source of entitlement truth, and the **only** reader of
/// [PurchaseGateway] in the whole app (D-28) — no screen imports the gateway
/// or the store SDK, so "is this user Pro?" is answered in exactly one place.
///
/// It owns three refresh points (D-29): the launch read
/// ([initialize], called once by `EntitlementLifecycleScope`), a resume read
/// (the same scope), and the store's own update pushes (the listener
/// registered here at construction). All three funnel into [refresh] or
/// [_applySnapshot], so there is one write path for the state and one for the
/// cache.
///
/// **The cache is written only after a successful read** (D-26). A failed
/// read keeps the last known good state and leaves the cache row exactly as
/// the last successful read left it, which is what makes Pro work offline
/// (S-269) and what stops a dropped connection from revoking a paid
/// entitlement.
class EntitlementController extends StateNotifier<EntitlementState> {
  EntitlementController(this._gateway, this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const EntitlementState()) {
    // D-29c: registered once, at construction, so a renewal or a refund that
    // happens while the app is open lands without the user doing anything.
    _gateway.addEntitlementListener(_onStoreUpdate);
  }

  final PurchaseGateway _gateway;
  final WheelRepository _repository;
  final DateTime Function() _now;

  bool _initialized = false;
  Future<void>? _refreshInFlight;

  /// Configures the store, loads the cached entitlement, then reads the
  /// store once. Idempotent: a second call (the scope's `initState` running
  /// again after a rebuild, say) reads nothing.
  ///
  /// Never throws — a store that cannot be configured or reached leaves the
  /// app on the free tier with the cached entitlement intact, not broken.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _gateway.configure();
    } catch (_) {
      // An inert gateway is a working gateway: every call still answers.
    }
    await _loadCache();
    await refresh();
  }

  /// Re-reads the store. Never throws, and re-entrant: an overlapping call
  /// joins the in-flight read instead of doubling it.
  Future<void> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _refresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  /// The plans the store is offering, or `null` when it cannot be reached.
  /// This is a straight pass-through that also records whether the store
  /// answered at all — the paywall decides what an empty list means, this
  /// layer does not.
  Future<ProOfferings?> loadOfferings() async {
    ProOfferings? offerings;
    try {
      offerings = await _gateway.loadOfferings();
    } catch (_) {
      offerings = null;
    }
    state = state.copyWith(offeringsAvailable: offerings != null);
    return offerings;
  }

  /// Buys [productId]. A completed purchase is followed by a store read, so
  /// the state and the cache reflect what the store actually granted rather
  /// than what the app hoped for; every other outcome leaves both untouched.
  Future<PurchaseOutcome> purchase(String productId) async {
    final PurchaseOutcome outcome;
    try {
      outcome = await _gateway.purchase(productId);
    } catch (_) {
      return const PurchaseUnavailable();
    }
    if (outcome is PurchasePurchased) await refresh();
    return outcome;
  }

  /// Restores from the store account. Same shape as [purchase]: only a
  /// completed restore re-reads.
  Future<PurchaseOutcome> restore() async {
    final PurchaseOutcome outcome;
    try {
      outcome = await _gateway.restore();
    } catch (_) {
      return const PurchaseUnavailable();
    }
    if (outcome is PurchasePurchased) await refresh();
    return outcome;
  }

  /// Opens the store's own subscription-management page. A no-op when the
  /// store reports no management page or the platform has no handler — the
  /// entitlement is unaffected either way, so a failure is not surfaced.
  Future<void> manageSubscription() async {
    try {
      await _gateway.showManageSubscriptions();
    } catch (_) {
      // Nothing to tell the user: the store page simply did not open.
    }
  }

  Future<void> _refresh() async {
    final EntitlementSnapshot snapshot;
    try {
      snapshot = await _gateway.currentEntitlement();
    } catch (_) {
      // D-26: no answer is not "not subscribed". Keep the last known good.
      return;
    }
    await _applySnapshot(snapshot);
  }

  /// The store's own push (S-271). Applied as given — no re-read, because the
  /// snapshot *is* the store's answer.
  void _onStoreUpdate(EntitlementSnapshot snapshot) {
    unawaited(_applySnapshot(snapshot));
  }

  /// The one write path for both the state and the cache. A snapshot the
  /// store never actually answered (`unknown`) is not a read and writes
  /// nothing — Pro is never forged from an absent answer, and never revoked
  /// by one either.
  Future<void> _applySnapshot(EntitlementSnapshot snapshot) async {
    if (snapshot.status == EntitlementStatus.unknown) return;
    state = _stateFrom(snapshot);
    await _writeCache(snapshot);
  }

  Future<void> _loadCache() async {
    final EntitlementCacheData cache;
    try {
      cache = await _repository.getEntitlementCache();
    } catch (_) {
      return;
    }
    // A `null` `checkedAt` means no read has ever succeeded, which is
    // `unknown` — not a cached "no" (D-26).
    if (cache.checkedAt == null) return;
    state = state.copyWith(
      status: cache.isActive ? EntitlementStatus.active : EntitlementStatus.inactive,
      planKind: cache.planKind,
      expiresAt: cache.expiresAt,
      willRenew: cache.willRenew,
      billingIssue: cache.billingIssue,
      purchasedAt: cache.purchasedAt,
    );
  }

  Future<void> _writeCache(EntitlementSnapshot snapshot) async {
    final active = snapshot.isActive;
    try {
      await _repository.saveEntitlementCache(
        EntitlementCacheData(
          isActive: active,
          // An inactive entitlement has no plan, no end and no renewal, so
          // the row is normalised rather than carrying a stale plan forward
          // (S-272). The purchase date is kept: it is a fact about the
          // account, not about the current entitlement.
          planKind: active ? snapshot.planKind : ProPlanKind.none,
          expiresAt: active ? snapshot.expiresAt : null,
          willRenew: active && snapshot.willRenew,
          billingIssue: active && snapshot.billingIssue,
          purchasedAt: snapshot.purchasedAt,
          checkedAt: _now(),
        ),
      );
    } catch (_) {
      // A cache write that fails costs offline Pro, not correctness.
    }
  }

  EntitlementState _stateFrom(EntitlementSnapshot snapshot) => state.copyWith(
    status: snapshot.status,
    planKind: snapshot.isActive ? snapshot.planKind : ProPlanKind.none,
    // A lapsed entitlement has no end and no purchase date in the state: the
    // clear flags are what stop the cached Pro fields outliving the Pro
    // entitlement they described (S-272).
    expiresAt: snapshot.isActive ? snapshot.expiresAt : null,
    clearExpiresAt: !snapshot.isActive,
    willRenew: snapshot.isActive && snapshot.willRenew,
    billingIssue: snapshot.isActive && snapshot.billingIssue,
    purchasedAt: snapshot.purchasedAt,
    clearPurchasedAt: !snapshot.isActive,
  );
}
