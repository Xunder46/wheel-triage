/// Every string the Pro surfaces show, in one place (D-24, D-31, D-32, D-37).
///
/// Pure Dart: no Flutter import, no widget, no state. Two rules hold here and
/// are checked by `test/core/purchases/paywall_copy_test.dart` rather than by
/// review:
///
/// 1. **No store fact is hard-coded.** Prices, periods, trial lengths and
///    currency symbols come from the `ProPlanOffer` the store returned. The
///    only literals in this file are the three product identifiers' *kind*
///    labels (a plan is called "Annual" because the app asked for the annual
///    product, not because a price said so) and the words around them.
/// 2. **Nothing here evaluates the free tier.** The D-24 line builders take
///    the limit as a parameter, because the limit lives in `pro_plans.dart`
///    and is evaluated in exactly one place, `NewCycleGate.evaluate()` (D-28).
library;

import 'package:decimal/decimal.dart';

import '../../domain/models/entitlement_status.dart';
import '../../domain/models/pro_plan_kind.dart';
import '../format.dart';
import 'pro_plans.dart';
import 'purchase_gateway.dart';

// --- The paywall's own chrome ------------------------------------------

const String kPaywallTitle = 'Wheel Triage Pro';

const String kPaywallPrivacyLine =
    'Your trades never leave your phone. Purchases go through the App Store, '
    'with no account to create.';

/// The launch features only (OC-9). [lead] is the bolded phrase, [detail] the
/// plain clause after it, matching the reference's row shape. Nothing is
/// promised by name before it ships, which is why the last row is generic.
///
/// The first row states the free tier's limit, so it uses
/// [kFreeTierLimitPhrase] — the phrase is built beside the number in
/// `pro_plans.dart` so this file never names the number itself (S-265).
const List<({String lead, String? detail})> kPaywallFeatures = [
  (lead: kFreeTierLimitPhrase, detail: null),
  (
    lead: 'Screenshot scan',
    detail: 'read a broker screenshot on this phone instead of typing',
  ),
  (
    lead: 'Portfolio and assignment calendar',
    detail: 'capital, concentration and net delta across your book',
  ),
  (lead: 'New Pro features reach every plan as they ship', detail: null),
];

// --- The Settings plan section (D-34) ----------------------------------

/// The section's own name for the free tier's count display. A count, not a
/// verdict: the row says how many cycles are open, and the gate is the only
/// thing that ever acts on that number (D-23).
const String kFreePlanDetailLine = 'Everything you\'ve recorded stays available.';

/// The free tier's header before the book read answers. The tier is known the
/// moment the entitlement is; the count is not, and an unverified "0 of 3"
/// would read as a claim about the user's book.
const String kFreePlanCountPendingLine = 'Free';

/// Shown when no store read has ever succeeded. Deliberately not "Free": the
/// app has not been told that, and a free tier is never inferred from an
/// absent answer (D-26).
const String kProStatusUnavailableLine = 'Pro status unavailable';

const String kProStatusUnavailableDetailLine =
    'Purchases can be restored from this App Store account.';

/// D-34's billing-retry line. Display only: a subscription in billing retry is
/// still Pro (D-26).
const String kBillingIssueLine =
    'There\'s a billing problem with your subscription. Pro stays on while the '
    'store retries.';

/// D-34's third entry point, and the free row's own wording for it.
const String kSeeProPlansLabel = 'See Pro plans';

/// D-34's header line: the plan the user is on, or the free tier's count.
///
/// [limit] is a parameter rather than a read of `kFreeTierOpenCycles` for the
/// same reason the D-24 builders take it: the limit is written down once, and
/// this file must not become a second place that knows it.
///
/// [openCycleCount] is `null` while the book read has not answered. A free row
/// then states the tier without a count — never "0 of 3", which is a claim
/// about the user's book that nothing has verified.
String proPlanHeaderLine({
  required EntitlementStatus status,
  required ProPlanKind kind,
  required int? openCycleCount,
  required int limit,
}) => switch (status) {
  EntitlementStatus.unknown => kProStatusUnavailableLine,
  EntitlementStatus.inactive =>
    openCycleCount == null
        ? kFreePlanCountPendingLine
        : openCycleCount <= limit
        ? 'Free · $openCycleCount of $limit open cycles'
        : 'Free · $openCycleCount open cycles',
  EntitlementStatus.active => switch (kind) {
    ProPlanKind.none => kProPlanUnnamedLine,
    ProPlanKind.monthly => 'Pro · Monthly',
    ProPlanKind.annual => 'Pro · Annual',
    ProPlanKind.lifetime => 'Pro · Lifetime',
  },
};

/// An active entitlement the app cannot name — the store granted a product
/// this build does not know about. Pro is on, so the row must not claim
/// otherwise; it simply has no plan name to show.
const String kProPlanUnnamedLine = 'Pro';

/// D-34's second line, or `null` when the state has nothing more to say.
String? proPlanDetailLine({
  required EntitlementStatus status,
  required ProPlanKind kind,
  required DateTime? expiresAt,
  required bool willRenew,
  required DateTime? purchasedAt,
}) => switch (status) {
  EntitlementStatus.unknown => kProStatusUnavailableDetailLine,
  EntitlementStatus.inactive => kFreePlanDetailLine,
  EntitlementStatus.active => switch (kind) {
    ProPlanKind.none => null,
    ProPlanKind.lifetime => purchasedAt == null
        ? null
        : 'Purchased ${renewalDateText(purchasedAt)}',
    ProPlanKind.monthly || ProPlanKind.annual => expiresAt == null
        ? null
        : '${willRenew ? 'Renews' : 'Cancels'} ${renewalDateText(expiresAt)}',
  },
};

/// D-34's row set for a state. Which rows exist follows from the entitlement
/// alone, so it is decided here rather than in the widget — and it is then
/// testable without pumping a screen.
///
/// A lifetime owner has no subscription to manage and nothing left to buy; a
/// free tier has nothing to manage but is the one state shown the paywall's
/// door; restoring is offered in every state, because a purchase made on
/// another device is exactly the case it exists for.
({bool seePlans, bool manageSubscription, bool restore}) proPlanRowsFor(
  EntitlementStatus status,
  ProPlanKind kind,
) => switch (status) {
  EntitlementStatus.inactive => (
    seePlans: true,
    manageSubscription: false,
    restore: true,
  ),
  EntitlementStatus.unknown => (
    seePlans: false,
    manageSubscription: false,
    restore: true,
  ),
  EntitlementStatus.active => (
    seePlans: false,
    manageSubscription:
        kind == ProPlanKind.monthly || kind == ProPlanKind.annual,
    restore: true,
  ),
};

// --- The D-24 refusal lines --------------------------------------------

/// Exactly at the free limit. [count] is the open-cycle count that fired it,
/// which at the limit is the limit itself — the line names the count the user
/// actually has, not a constant (D-24).
String newCycleAtLimitLine(int count) =>
    'You have $count open cycles, the free plan\'s limit, so recording a '
    'fourth needs Pro. Everything you\'ve already recorded stays available on '
    'every plan.';

/// Past the limit, which is reachable only after a lapse from Pro (D-24). The
/// limit is named as well as the count, so the two numbers can never be read
/// as one.
String newCyclePastLimitLine({required int count, required int limit}) =>
    'You have $count open cycles, past the free plan\'s limit of $limit, so '
    'recording another needs Pro. Everything you\'ve already recorded stays '
    'available on every plan.';

/// D-24's single dispatcher: the at-the-limit wording when the count is the
/// limit, the past-the-limit wording above it. One call site, so a gate cannot
/// pick the wrong line.
String newCycleRefusalLine({required int count, required int limit}) =>
    count <= limit ? newCycleAtLimitLine(count) : newCyclePastLimitLine(count: count, limit: limit);

/// The line for a Pro feature reached on the free tier (D-30's second entry
/// point, wired in Wave 3). [feature] names the feature; the second sentence
/// is the same promise every refusal makes.
String proFeatureLine(String feature) =>
    '$feature is part of Pro. Everything you\'ve already recorded stays '
    'available on every plan.';

/// D-30's third entry point, and the fallback for a `/paywall` route reached
/// with no trigger (a deep link). It says what Pro *does* rather than what it
/// might earn, and repeats the promise the other two triggers make.
const String kPaywallSettingsLine =
    'Pro raises the free plan\'s open-cycle limit and adds the features below. '
    'Everything you\'ve already recorded stays available on every plan.';

// --- Purchase and restore outcomes (D-32) ------------------------------

const String kPurchaseSucceededLine = 'Pro is on.';

const String kPurchasePendingLine =
    'Your purchase is pending. Pro unlocks as soon as the store approves it.';

const String kPurchaseFailedLine =
    'The purchase didn\'t complete. You can try again, or restore purchases.';

const String kPurchaseUnavailableLine =
    'The App Store isn\'t reachable right now. Nothing was charged.';

const String kRestoredLine = 'Purchases restored.';

const String kNothingToRestoreLine =
    'No purchases to restore on this App Store account.';

/// D-33: a subscriber who buys lifetime still has a subscription to cancel,
/// and there is no backend to cancel it on.
const String kLifetimeAfterSubscriptionLine =
    'You now have lifetime Pro. Cancel the subscription in your App Store '
    'account settings so it doesn\'t renew.';

/// The one line a *cancelled* purchase produces: none. Kept as a named
/// constant so the outcome switch is exhaustive and the omission is visible.
const String? kPurchaseCancelledLine = null;

/// The single mapping from a purchase outcome to the line the paywall shows
/// (D-32). One function rather than a switch at the call site, so the four
/// lines and the deliberate absence of a fifth are decided in one place.
String? purchaseOutcomeLine(PurchaseOutcome outcome) => switch (outcome) {
  PurchasePurchased() => kPurchaseSucceededLine,
  PurchasePending() => kPurchasePendingLine,
  PurchaseCancelled() => kPurchaseCancelledLine,
  PurchaseFailed() => kPurchaseFailedLine,
  PurchaseUnavailable() => kPurchaseUnavailableLine,
};

/// The same mapping for a restore (D-32). A restore the store completed but
/// which found nothing is *not* a failure: the store answered, and the answer
/// is that this account holds no purchase — which is the adapter's own
/// `cancelled`, and the reason this is a separate mapping from
/// [purchaseOutcomeLine].
String restoreOutcomeLine(PurchaseOutcome outcome) => switch (outcome) {
  PurchasePurchased() => kRestoredLine,
  PurchaseUnavailable() => kPurchaseUnavailableLine,
  PurchaseFailed() => kPurchaseFailedLine,
  PurchasePending() || PurchaseCancelled() => kNothingToRestoreLine,
};

// --- Labels ------------------------------------------------------------

const String kNotNowLabel = 'Not now';
const String kRestorePurchasesLabel = 'Restore purchases';
const String kManageSubscriptionLabel = 'Manage subscription';
const String kTermsOfUseLabel = 'Terms of Use';
const String kPrivacyPolicyLabel = 'Privacy Policy';
const String kPaywallRetryLabel = 'Try again';
const String kPaywallCloseLabel = 'Close';

/// What the button says before a plan has been chosen — and the only state in
/// which it is rendered disabled.
const String kContinueLabel = 'Continue';

/// The plan rows' own name for a kind. A kind label, not a store fact: the
/// period and the price in the same row come from the store.
String planKindLabel(ProPlanKind kind) => switch (kind) {
  ProPlanKind.annual => 'Annual',
  ProPlanKind.monthly => 'Monthly',
  ProPlanKind.lifetime => 'Lifetime',
  ProPlanKind.none => 'Pro',
};

/// The button's label for [offer] (S-279): it names what actually happens for
/// the selected plan, so no plan ever reads as a different plan. A trial is
/// named exactly as the store reported it (D-31), and a lifetime purchase is
/// not a subscription, so it is never labelled as one.
String purchaseButtonLabel(ProPlanOffer? offer) {
  if (offer == null) return kContinueLabel;
  final trial = offer.trial;
  if (trial != null) return 'Start ${trialText(trial)} free trial';
  return switch (kindForProductId(offer.productId)) {
    ProPlanKind.lifetime => 'Buy lifetime for ${offer.priceString}',
    ProPlanKind.monthly || ProPlanKind.annual =>
      'Subscribe for ${offer.priceString} ${planPeriodPhrase(kindForProductId(offer.productId))}',
    ProPlanKind.none => kContinueLabel,
  };
}

/// The store's own trial term — `7-day`, `1-month` — never a length the app
/// invented.
String trialText(TrialOffer trial) {
  final unit = switch (trial.unit) {
    TrialPeriodUnit.day => 'day',
    TrialPeriodUnit.week => 'week',
    TrialPeriodUnit.month => 'month',
    TrialPeriodUnit.year => 'year',
    TrialPeriodUnit.unknown => 'period',
  };
  return '${trial.units}-$unit';
}

/// A plan row's second line, built from the store's `priceString` alone
/// (D-31): `7-day free trial, then $29.99 a year · $2.50 a month`. The
/// per-month figure is derived for the annual row only, and the row makes no
/// savings claim.
String planRowSubtitle(ProPlanOffer offer) {
  final kind = kindForProductId(offer.productId);
  final period = planPeriodPhrase(kind);
  final price = '${offer.priceString} $period';
  final trial = offer.trial;
  final base = trial == null ? price : '${trialText(trial)} free trial, then $price';
  if (kind != ProPlanKind.annual) return base;
  return '$base · ${annualPerMonthText(offer)}';
}

/// The annual row's derived per-month figure (D-31): the store's annual price
/// divided by twelve, in the store's own currency.
///
/// `Decimal`'s `/` yields a `Rational`, and `Rational.toDecimal` **truncates**
/// at the scale it is given — so the division is taken to ten-thousandths
/// (the precision money is stored at) and then rounded to the nearest cent,
/// half away from zero. Rounding rather than truncating is deliberate: a
/// truncation would show $2.49 for a $29.99 annual, understating the cost.
/// Every step is `Decimal`, and the conversion to `num` happens inside
/// [currencyText], the display formatter.
String annualPerMonthText(ProPlanOffer offer) {
  final perMonth = (offer.price / Decimal.fromInt(12))
      .toDecimal(scaleOnInfinitePrecision: 4)
      .round(scale: 2);
  return '${currencyText(perMonth, offer.currencyCode)} a month';
}

/// `a year` / `a month` / `once`. A kind label, not a hard-coded store period:
/// which product is annual is code (`pro_plans.dart`), what it costs and how
/// long it runs are the store's.
String planPeriodPhrase(ProPlanKind kind) => switch (kind) {
  ProPlanKind.annual => 'a year',
  ProPlanKind.monthly => 'a month',
  ProPlanKind.lifetime => 'once',
  ProPlanKind.none => '',
};

/// One plan row, with every string already derived (D-31).
///
/// The screen renders these and names **no store type** — `ProPlanOffer` never
/// reaches `lib/features/` (Feature Invariant 10) — and the derivation itself
/// stays here, beside the copy it produces, rather than in the state layer or
/// the widget.
class PaywallPlanRow {
  const PaywallPlanRow({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.finePrint,
  });

  /// The store's product identifier — the only thing a purchase ever carries.
  final String productId;

  /// The plan's own name, e.g. `Annual`.
  final String title;

  /// The row's second line, e.g. `7-day free trial, then $29.99 a year`.
  final String subtitle;

  /// What the button says while this plan is the selected one.
  final String buttonLabel;

  /// The fine print under the button while this plan is the selected one.
  final String finePrint;

  @override
  String toString() => 'PaywallPlanRow($productId, $title, $subtitle)';
}

/// Derives every string a plan row shows from the store's own offer.
PaywallPlanRow planRowFor(ProPlanOffer offer) => PaywallPlanRow(
  productId: offer.productId,
  title: planKindLabel(kindForProductId(offer.productId)),
  subtitle: planRowSubtitle(offer),
  buttonLabel: purchaseButtonLabel(offer),
  finePrint: paywallFinePrint(offer),
);

/// The fine print under the button, built from the store's price and the
/// store's trial term. A subscription's renewal wording is the App Store's own
/// terms; a lifetime purchase gets the one-time wording instead.
String paywallFinePrint(ProPlanOffer offer) {
  final kind = kindForProductId(offer.productId);
  final price = '${offer.priceString} ${planPeriodPhrase(kind)}';
  if (kind == ProPlanKind.lifetime) {
    return 'One payment of $price is charged to your Apple ID. This is a '
        'one-time purchase, not a subscription.';
  }
  final trial = offer.trial;
  final opening = trial == null
      ? '$price is charged to your Apple ID.'
      : 'After the ${trialText(trial)} free trial, $price is charged to your '
            'Apple ID.';
  return '$opening The subscription renews automatically unless cancelled at '
      'least 24 hours before the end of the period. Manage or cancel it in '
      'your App Store account settings.';
}

/// The line above the plan rows while the store has not answered (D-31): an
/// empty offerings list is the honest rendering of a store that returned
/// nothing, and it must not read as a failure the user caused.
const String kPaywallOffersUnavailableLine =
    'Pro plans aren\'t available from the App Store right now. You can try '
    'again later, or restore purchases.';

/// D-33: the owned state. It is shown *beside* whatever plans remain visible
/// rather than replacing them: a subscriber can still buy lifetime (S-283b),
/// and a lifetime owner has no plans left to be shown, so the two cases differ
/// by which offers survive the filter, not by this line.
String paywallOwnedLine(ProPlanKind kind, DateTime? purchasedAt) {
  final since = purchasedAt == null ? '' : ', purchased ${renewalDateText(purchasedAt)}';
  return 'Pro is on — ${planKindLabel(kind).toLowerCase()}$since.';
}
