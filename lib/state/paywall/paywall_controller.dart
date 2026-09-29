/// The paywall's state layer (Pro Wave 2, Phase 6).
///
/// It reads `entitlementControllerProvider` and computes **no** entitlement of
/// its own (D-28): "is this user Pro?" is answered in exactly one place, and
/// this class only decides which plans a state like that should be shown. The
/// plan list is the store's answer, filtered to the products the app can
/// describe (D-31) and ordered by `pro_plans.dart`, so no price, period or
/// trial term is ever invented here.
///
/// Nothing in this file touches the store SDK: every call goes through
/// `EntitlementController`, which is the only reader of `PurchaseGateway`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/paywall_copy.dart';
import '../../core/purchases/pro_plans.dart';
import '../../core/purchases/purchase_gateway.dart';
import '../../domain/models/pro_plan_kind.dart';
import '../entitlements/entitlement_controller.dart';
import '../entitlements/entitlement_providers.dart';

/// What the paywall is showing right now.
///
/// [offers] is the store's answer with two filters applied — unknown product
/// ids dropped and display order imposed — and nothing else. Which of those
/// plans the user may be *offered* depends on the entitlement, so it is a
/// method ([visibleOffers]) rather than a field: a copy of the entitlement
/// inside this state would be a second source of truth for Pro.
class PaywallState {
  const PaywallState({
    this.offers = const [],
    this.selectedProductId,
    this.isBusy = false,
    this.message,
    this.offersLoaded = false,
    this.showManageSubscription = false,
  });

  /// The store's plans, in display order, unknown product ids removed.
  final List<ProPlanOffer> offers;

  /// The plan the button would buy. Kept across a reload when it is still on
  /// offer, so a retry does not silently move the user's selection.
  final String? selectedProductId;

  /// A purchase or a restore is in flight. The button is disabled while it is.
  final bool isBusy;

  /// The D-32 line for the last outcome, or `null` when there is nothing to
  /// say — which includes a purchase the user deliberately cancelled.
  final String? message;

  /// Whether the store has answered at least once. Distinguishes "not asked
  /// yet" from "asked, and the answer was nothing" (S-280).
  final bool offersLoaded;

  /// D-33: a subscriber who just bought lifetime still has a subscription to
  /// cancel, and the app has no backend to cancel it on.
  final bool showManageSubscription;

  /// The plans [entitlement] may be shown (D-33). Free and unknown see
  /// everything; an active subscription sees the lifetime upgrade only, so a
  /// subscriber is never sold a second subscription; a lifetime owner sees
  /// nothing to buy, because lifetime does not expire and never lapses.
  List<ProPlanOffer> visibleOffers(EntitlementState entitlement) =>
      visibleProOffers(offers, entitlement);

  /// The rows the screen renders (D-31/D-33): the visible offers, each with
  /// every string already derived, so the paywall screen never names a store
  /// type (Feature Invariant 10).
  List<PaywallPlanRow> visibleRows(EntitlementState entitlement) => [
    for (final offer in visibleOffers(entitlement)) planRowFor(offer),
  ];

  /// Which plan [selectedProductId] names, without needing the offer in hand.
  ProPlanKind get selectedKind => kindForProductId(selectedProductId);

  /// The selected row, when it is one of [visible]. Resolving through the
  /// visible list is what stops a stale selection (from before an entitlement
  /// change) from being purchasable.
  PaywallPlanRow? selectedRowIn(List<PaywallPlanRow> visible) {
    for (final row in visible) {
      if (row.productId == selectedProductId) return row;
    }
    return null;
  }

  /// The selected plan, when it is one of [visible]. Resolving through the
  /// visible list is what stops a stale selection (from before an entitlement
  /// change) from being purchasable.
  ProPlanOffer? selectedOfferIn(List<ProPlanOffer> visible) {
    for (final offer in visible) {
      if (offer.productId == selectedProductId) return offer;
    }
    return null;
  }

  /// S-280: the store answered, and the answer was no plans. Rendered as an
  /// honest unavailable state, never as a hard-coded fallback price.
  bool get offersUnavailable => offersLoaded && offers.isEmpty;

  PaywallState copyWith({
    List<ProPlanOffer>? offers,
    String? selectedProductId,
    bool clearSelectedProductId = false,
    bool? isBusy,
    String? message,
    bool clearMessage = false,
    bool? offersLoaded,
    bool? showManageSubscription,
  }) => PaywallState(
    offers: offers ?? this.offers,
    selectedProductId: clearSelectedProductId
        ? null
        : (selectedProductId ?? this.selectedProductId),
    isBusy: isBusy ?? this.isBusy,
    message: clearMessage ? null : (message ?? this.message),
    offersLoaded: offersLoaded ?? this.offersLoaded,
    showManageSubscription: showManageSubscription ?? this.showManageSubscription,
  );

  @override
  String toString() =>
      'PaywallState(${offers.length} offers, selected: $selectedProductId, '
      'busy: $isBusy, loaded: $offersLoaded, message: $message)';
}

/// Which of [offers] a user in [entitlement] may be shown (D-33).
///
/// A pure function rather than a method on the state, because it is the one
/// rule here worth asserting on its own, and because both the controller and
/// the screen need the same answer.
List<ProPlanOffer> visibleProOffers(
  List<ProPlanOffer> offers,
  EntitlementState entitlement,
) {
  if (!entitlement.isActive) return offers;
  if (entitlement.planKind == ProPlanKind.lifetime) return const [];
  return offers
      .where((offer) => kindForProductId(offer.productId) == ProPlanKind.lifetime)
      .toList();
}

/// The paywall's orchestration: load the store's plans, hold the selection,
/// buy, restore, and open the store's own management page.
///
/// Every store call goes through [EntitlementController], so a purchase that
/// succeeded is followed by that controller's own re-read and cache write —
/// this class never decides what the store granted, and never writes the
/// entitlement cache.
class PaywallController extends StateNotifier<PaywallState> {
  PaywallController(this._ref) : super(const PaywallState());

  final Ref _ref;

  EntitlementController get _entitlement => _ref.read(entitlementControllerProvider.notifier);

  /// Asks the store for its plans and preselects the annual one when it is
  /// there (D-31). Safe to call again: the paywall's retry action and its
  /// `initState` both go through here, and a second load replaces the list
  /// without touching an entitlement.
  Future<void> load() async {
    state = state.copyWith(isBusy: true, clearMessage: true);
    try {
      final offerings = await _entitlement.loadOfferings();
      final known = inDisplayOrder(
        (offerings?.plans ?? const <ProPlanOffer>[])
            .where((offer) => isKnownProProductId(offer.productId))
            .toList(),
      );
      final visible = visibleProOffers(known, _ref.read(entitlementControllerProvider));
      final stillVisible = visible.any((offer) => offer.productId == state.selectedProductId);
      state = state.copyWith(
        offers: known,
        offersLoaded: true,
        selectedProductId: stillVisible
            ? state.selectedProductId
            : preselectedOffer(visible)?.productId,
        clearSelectedProductId: !stillVisible && visible.isEmpty,
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Chooses [productId]. A product the store did not return — a stale
  /// identifier, or one this build does not know — is ignored rather than
  /// stored, so the selection always names a real offer.
  ///
  /// A plan the *entitlement* hides is a different case and is stored: the
  /// filter is applied where it matters, in [purchase] and in the rendered
  /// rows, both of which resolve through [PaywallState.visibleOffers]. So a
  /// hidden plan can be selected but never bought, and the button is never
  /// offered something the user was not shown.
  void select(String productId) {
    if (!state.offers.any((offer) => offer.productId == productId)) return;
    state = state.copyWith(selectedProductId: productId);
  }

  /// Buys the selected plan. Nothing happens when there is nothing selected or
  /// a purchase is already in flight.
  Future<void> purchase() async {
    if (state.isBusy) return;
    final entitlement = _ref.read(entitlementControllerProvider);
    final offer = state.selectedOfferIn(state.visibleOffers(entitlement));
    if (offer == null) return;

    // D-33's case, captured *before* the store is asked: an active
    // subscription that then buys lifetime leaves the subscription running,
    // and the app has to say so.
    final subscriptionOnTop = entitlement.isActive &&
        entitlement.planKind != ProPlanKind.lifetime &&
        kindForProductId(offer.productId) == ProPlanKind.lifetime;

    state = state.copyWith(isBusy: true, clearMessage: true);
    try {
      final outcome = await _entitlement.purchase(offer.productId);
      if (subscriptionOnTop && outcome is PurchasePurchased) {
        state = state.copyWith(
          message: kLifetimeAfterSubscriptionLine,
          showManageSubscription: true,
        );
      } else {
        final line = purchaseOutcomeLine(outcome);
        state = state.copyWith(message: line, clearMessage: line == null);
      }
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Restores from the store account. The same call the Settings row makes, so
  /// the two entry points cannot drift (S-282).
  Future<void> restore() async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true, clearMessage: true);
    try {
      final outcome = await _entitlement.restore();
      state = state.copyWith(message: restoreOutcomeLine(outcome));
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Opens the store's own subscription-management page (D-33). A no-op when
  /// the store has no page to open — the entitlement is unaffected either way,
  /// so there is nothing to report.
  Future<void> manageSubscription() => _entitlement.manageSubscription();
}

/// Deliberately **not** `.autoDispose`: Settings reads it too, and a notifier
/// disposed while a purchase or a restore is in flight would throw when the
/// store's answer came back. It holds no trade data and no entitlement of its
/// own — only the store's plan list and the current selection.
final paywallControllerProvider = StateNotifierProvider<PaywallController, PaywallState>(
  (ref) => PaywallController(ref),
);
