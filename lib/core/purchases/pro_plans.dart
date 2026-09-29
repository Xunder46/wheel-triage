/// The store's own identifiers and the free tier's limit (Pro Wave 2, D-23/
/// D-31). These are **code, not secrets**: the owner creates the App Store
/// products to match these strings, so a typo here is a visible
/// misconfiguration rather than a silent one.
///
/// The API key is deliberately **not** here — it never enters the repository;
/// see `purchase_configuration.dart`.
///
/// This is the only place the product-id -> [ProPlanKind] mapping exists
/// (D-31); nothing else re-derives it.
library;

import '../../domain/models/pro_plan_kind.dart';
import 'purchase_gateway.dart';

/// The RevenueCat entitlement identifier the owner configures. One
/// entitlement covers all three plans — the *plan* is read from the product
/// identifier, not from a separate entitlement per plan.
const String kProEntitlementId = 'pro';

const String kProMonthlyProductId = 'wheel_triage_pro_monthly';
const String kProAnnualProductId = 'wheel_triage_pro_annual';
const String kProLifetimeProductId = 'wheel_triage_pro_lifetime';

/// How many open cycles the free tier allows (D-23). Evaluated in exactly one
/// place, `NewCycleGate.evaluate()`, and displayed in exactly one other, the
/// Settings plan row's count. Nothing else in the app reads it — the free tier
/// is not extended or restricted anywhere else (D-38).
const int kFreeTierOpenCycles = 3;

/// The same limit phrased for the paywall's feature list (D-24). Built here,
/// beside the number, so the paywall's copy file never names
/// [kFreeTierOpenCycles] — S-265 pins the number's references to the gate and
/// the Settings count, and the paywall is neither. A copy edit that changes the
/// wording cannot drift from the number.
const String kFreeTierLimitPhrase = 'More than $kFreeTierOpenCycles open cycles';

/// Display order for the paywall's plan rows (D-31): annual first, because it
/// is the one the app preselects, then monthly, then lifetime. Whichever
/// subset the store returned is rendered in this order.
const List<ProPlanKind> kProPlanDisplayOrder = [
  ProPlanKind.annual,
  ProPlanKind.monthly,
  ProPlanKind.lifetime,
];

/// Apple's standard end-user licence agreement, the default Terms of Use for
/// an app that has not published its own (D-37).
const String kTermsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// The owner's hosted privacy policy. **Empty until the owner supplies it**,
/// and while it is empty the paywall hides the entry rather than showing a
/// link that goes nowhere (D-37). `docs/privacy.md` is the text it is written
/// from.
const String kPrivacyPolicyUrl = '';

/// Which plan a store product identifier names. `none` for anything
/// unrecognised — including the free tier and a store entitlement for a
/// product this app does not know about.
ProPlanKind kindForProductId(String? productId) => switch (productId) {
  kProMonthlyProductId => ProPlanKind.monthly,
  kProAnnualProductId => ProPlanKind.annual,
  kProLifetimeProductId => ProPlanKind.lifetime,
  _ => ProPlanKind.none,
};

/// Whether [productId] names one of the three plans this app can describe
/// (D-31). Only these are offered for sale: the app knows the period for a
/// plan it can name, and inventing a label for anything else would be exactly
/// the hard-coded store fact D-31 forbids.
bool isKnownProProductId(String? productId) => kindForProductId(productId) != ProPlanKind.none;

/// [offers] sorted into [kProPlanDisplayOrder]. An offer for an unrecognised
/// product sorts last rather than disappearing.
List<ProPlanOffer> inDisplayOrder(List<ProPlanOffer> offers) {
  final ordered = [...offers];
  ordered.sort((a, b) => _rank(a).compareTo(_rank(b)));
  return ordered;
}

/// The row the paywall selects first (D-31): annual when the store offers it,
/// otherwise whatever is first in display order, otherwise nothing.
ProPlanOffer? preselectedOffer(List<ProPlanOffer> offers) {
  if (offers.isEmpty) return null;
  return offers.firstWhere(
    (offer) => kindForProductId(offer.productId) == ProPlanKind.annual,
    orElse: () => offers.first,
  );
}

int _rank(ProPlanOffer offer) {
  final index = kProPlanDisplayOrder.indexOf(kindForProductId(offer.productId));
  return index < 0 ? kProPlanDisplayOrder.length : index;
}
