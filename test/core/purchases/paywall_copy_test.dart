// Pro Wave 2, Phase 6 (S-278, S-279, S-284): every string the Pro surfaces
// show, unit-tested where a grep cannot reach.
//
// S-284 asks for the tone rules to be a *test*, not only a Done Criterion
// grep: the paywall is the highest-risk new copy in the app, and a future edit
// that reintroduces "opportunity" must fail CI rather than pass review.
// S-279 pins the derived per-month figure's arithmetic and its currency.
//
// The Settings plan row's own lines (D-34) are added to [everyProString] by
// `test/features/settings/pro_plan_section_test.dart`, which is where they are
// built.

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';

ProPlanOffer _offer(
  String productId,
  String priceString,
  String currencyCode,
  String price, {
  TrialOffer? trial,
}) => ProPlanOffer(
  productId: productId,
  priceString: priceString,
  price: Decimal.parse(price),
  currencyCode: currencyCode,
  trial: trial,
);

/// S-278(a): annual with the store's own 7-day trial.
final _annualWithTrial = _offer(
  kProAnnualProductId,
  '\$29.99',
  'USD',
  '29.99',
  trial: const TrialOffer(units: 7, unit: TrialPeriodUnit.day),
);

/// S-278(c): the same plan without a trial.
final _annualNoTrial = _offer(kProAnnualProductId, '\$29.99', 'USD', '29.99');

/// S-279's second fixture: the same plan priced in euro, at a price that
/// rounds to a different cent than the dollar fixture's — so a formatter that
/// dropped the currency, or a derivation that ignored the price, would fail.
final _annualEur = _offer(kProAnnualProductId, '29,90 €', 'EUR', '29.90');

final _monthly = _offer(kProMonthlyProductId, '\$4.99', 'USD', '4.99');

final _lifetime = _offer(kProLifetimeProductId, '\$79.99', 'USD', '79.99');

/// Every string `paywall_copy.dart` can hand a widget, as a list a future
/// string must be added to. Written against the file's public surface rather
/// than against one screen, so a string only the Settings row shows is still
/// tone-checked.
List<String> everyProString() => [
  kPaywallTitle,
  kPaywallPrivacyLine,
  kPaywallSettingsLine,
  kPaywallOffersUnavailableLine,
  kPaywallRetryLabel,
  kPaywallCloseLabel,
  kPurchaseSucceededLine,
  kPurchasePendingLine,
  kPurchaseFailedLine,
  kPurchaseUnavailableLine,
  kRestoredLine,
  kNothingToRestoreLine,
  kLifetimeAfterSubscriptionLine,
  kNotNowLabel,
  kRestorePurchasesLabel,
  kManageSubscriptionLabel,
  kTermsOfUseLabel,
  kPrivacyPolicyLabel,
  // The free row's header before the book read answers (D-34).
  kFreePlanCountPendingLine,
  // Both D-24 forms, at the limit and past it.
  newCycleAtLimitLine(3),
  newCyclePastLimitLine(count: 5, limit: 3),
  newCycleRefusalLine(count: 3, limit: 3),
  newCycleRefusalLine(count: 4, limit: 3),
  newCycleRefusalLine(count: 5, limit: 3),
  // D-30's second entry point, whose caller arrives in Wave 3.
  proFeatureLine('Screenshot scan'),
  // Every store-driven string, built from a fixture the store could return.
  for (final offer in [_annualWithTrial, _annualNoTrial, _annualEur, _monthly, _lifetime]) ...[
    planRowSubtitle(offer),
    paywallFinePrint(offer),
    purchaseButtonLabel(offer),
  ],
  paywallOwnedLine(ProPlanKind.annual, DateTime(2026, 10, 5)),
  paywallOwnedLine(ProPlanKind.lifetime, DateTime(2026, 3, 3)),
  paywallOwnedLine(ProPlanKind.none, null),
  trialText(const TrialOffer(units: 7, unit: TrialPeriodUnit.day)),
  trialText(const TrialOffer(units: 1, unit: TrialPeriodUnit.month)),
  annualPerMonthText(_annualWithTrial),
  for (final kind in ProPlanKind.values) planKindLabel(kind),
  for (final kind in ProPlanKind.values) planPeriodPhrase(kind),
  for (final outcome in const [
    PurchasePurchased(),
    PurchasePending(),
    PurchaseCancelled(),
    PurchaseFailed(),
    PurchaseUnavailable(),
  ])
    if (purchaseOutcomeLine(outcome) != null) purchaseOutcomeLine(outcome)!,
];

void main() {
  group('S-284: the paywall copy passes the tone rules', () {
    /// The exact pattern the Done Criterion greps for, case-insensitive.
    final banned = RegExp(
      r'recommend|we suggest|our analysis|buy signal|sell signal|opportunity'
      r'|guaranteed|you should',
      caseSensitive: false,
    );

    test('no string matches the banned pattern, case-insensitively', () {
      final strings = everyProString();
      expect(strings, isNotEmpty);
      for (final string in strings) {
        expect(banned.hasMatch(string), isFalse, reason: 'banned word in: $string');
      }
    });

    test('a cancelled purchase produces no line at all', () {
      expect(kPurchaseCancelledLine, isNull);
      expect(purchaseOutcomeLine(const PurchaseCancelled()), isNull);
    });

    test('every other outcome has its own line, and none of them is empty', () {
      expect(purchaseOutcomeLine(const PurchasePurchased()), kPurchaseSucceededLine);
      expect(purchaseOutcomeLine(const PurchasePending()), kPurchasePendingLine);
      expect(purchaseOutcomeLine(const PurchaseFailed()), kPurchaseFailedLine);
      expect(purchaseOutcomeLine(const PurchaseUnavailable()), kPurchaseUnavailableLine);
      for (final line in [
        kPurchaseSucceededLine,
        kPurchasePendingLine,
        kPurchaseFailedLine,
        kPurchaseUnavailableLine,
        kRestoredLine,
        kNothingToRestoreLine,
        kLifetimeAfterSubscriptionLine,
      ]) {
        expect(line.trim(), isNotEmpty);
      }
    });

    test('the D-24 lines carry the count the user actually has', () {
      expect(newCycleAtLimitLine(3), contains('You have 3 open cycles'));
      expect(newCycleAtLimitLine(3), contains('the free plan\'s limit'));
      expect(newCyclePastLimitLine(count: 5, limit: 3), contains('You have 5 open cycles'));
      expect(
        newCyclePastLimitLine(count: 5, limit: 3),
        contains('past the free plan\'s limit of 3'),
      );
      // Both promise the same thing, because the promise is the rule.
      for (final line in [
        newCycleAtLimitLine(3),
        newCyclePastLimitLine(count: 5, limit: 3),
        proFeatureLine('Screenshot scan'),
      ]) {
        expect(line, contains('stays available on every plan'));
      }
    });

    test('the refusal dispatcher picks the at-limit form exactly at the limit', () {
      expect(newCycleRefusalLine(count: 3, limit: 3), newCycleAtLimitLine(3));
      expect(newCycleRefusalLine(count: 4, limit: 3), newCyclePastLimitLine(count: 4, limit: 3));
      expect(newCycleRefusalLine(count: 5, limit: 3), newCyclePastLimitLine(count: 5, limit: 3));
    });

    test('the trigger line names the feature for a Pro-feature trigger', () {
      expect(proFeatureLine('Screenshot scan'), startsWith('Screenshot scan is part of Pro.'));
    });

    test('the feature list states the free limit from the one constant', () {
      // D-P2's limit is declared once, in `pro_plans.dart`; the paywall's
      // first feature line must be derived from it rather than repeat the
      // number, so raising the limit cannot leave the paywall advertising
      // the old one. The phrase is built beside the number rather than here,
      // because S-265 pins the number's references to the gate and the
      // Settings count.
      expect(kFreeTierLimitPhrase, 'More than $kFreeTierOpenCycles open cycles');
      expect(kPaywallFeatures.first.lead, kFreeTierLimitPhrase);
    });
  });

  group('S-278: the store\'s own trial term, never an invented one', () {
    test('the trial line and the button use the store\'s units and unit', () {
      expect(trialText(const TrialOffer(units: 7, unit: TrialPeriodUnit.day)), '7-day');
      expect(trialText(const TrialOffer(units: 1, unit: TrialPeriodUnit.month)), '1-month');
      expect(trialText(const TrialOffer(units: 3, unit: TrialPeriodUnit.week)), '3-week');
      expect(trialText(const TrialOffer(units: 1, unit: TrialPeriodUnit.year)), '1-year');
      // An unrecognised unit is still stated, not guessed at.
      expect(trialText(const TrialOffer(units: 2, unit: TrialPeriodUnit.unknown)), '2-period');

      expect(purchaseButtonLabel(_annualWithTrial), 'Start 7-day free trial');
      expect(purchaseButtonLabel(_annualNoTrial), 'Subscribe for \$29.99 a year');
      expect(
        planRowSubtitle(_annualWithTrial),
        '7-day free trial, then \$29.99 a year · \$2.50 a month',
      );
    });

    test('a plan with no trial has no trial line and no trial in its button', () {
      expect(planRowSubtitle(_annualNoTrial), '\$29.99 a year · \$2.50 a month');
      expect(planRowSubtitle(_monthly), '\$4.99 a month');
      expect(planRowSubtitle(_lifetime), '\$79.99 once');
      expect(purchaseButtonLabel(_monthly), 'Subscribe for \$4.99 a month');
      expect(purchaseButtonLabel(_lifetime), 'Buy lifetime for \$79.99');
      for (final label in [
        purchaseButtonLabel(_annualNoTrial),
        purchaseButtonLabel(_monthly),
        purchaseButtonLabel(_lifetime),
      ]) {
        expect(label.toLowerCase(), isNot(contains('trial')));
      }
    });
  });

  group('S-279: the button names the outcome and the per-month figure is derived', () {
    test('the annual per-month figure is the store price divided by twelve', () {
      expect(annualPerMonthText(_annualWithTrial), '\$2.50 a month');
      expect(annualPerMonthText(_annualNoTrial), '\$2.50 a month');
    });

    test('the derived figure stays in the store\'s own currency', () {
      expect(annualPerMonthText(_annualEur), '€2.49 a month');
    });

    test('the arithmetic is Decimal division, rounded once at the display boundary', () {
      // $29.99 / 12 = $2.499166…, so this fixture is the one that tells a
      // rounded figure apart from a truncated one: truncating would show
      // $2.49 and understate the cost.
      final exact = _annualNoTrial.price / Decimal.fromInt(12);
      expect(exact.toDecimal(scaleOnInfinitePrecision: 4), Decimal.parse('2.4991'));
      expect(
        exact.toDecimal(scaleOnInfinitePrecision: 4).round(scale: 2),
        Decimal.parse('2.50'),
      );
      expect(annualPerMonthText(_annualNoTrial), '\$2.50 a month');
    });

    test('no savings claim is made anywhere in the copy', () {
      for (final string in [
        planRowSubtitle(_annualWithTrial),
        planRowSubtitle(_monthly),
        planRowSubtitle(_lifetime),
        paywallFinePrint(_annualWithTrial),
      ]) {
        expect(string.toLowerCase(), isNot(contains('save')));
        expect(string.toLowerCase(), isNot(contains('best value')));
        expect(string.toLowerCase(), isNot(contains('% off')));
      }
    });
  });

  group('S-284: the paywall is dismissable copy, not a wall', () {
    test('the fine print states the auto-renewal terms and the one-time case', () {
      final subscription = paywallFinePrint(_annualWithTrial);
      expect(subscription, contains('charged to your Apple ID'));
      expect(subscription, contains('renews automatically'));
      expect(subscription, contains('App Store account settings'));

      final lifetime = paywallFinePrint(_lifetime);
      expect(lifetime, contains('one-time purchase'));
      expect(lifetime, isNot(contains('renews automatically')));
    });

    test('the privacy line promises what S-288 proves', () {
      expect(kPaywallPrivacyLine, contains('never leave your phone'));
      expect(kPaywallPrivacyLine, contains('no account'));
    });
  });
}
