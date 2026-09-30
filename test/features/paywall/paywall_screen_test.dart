// Pro Wave 2, Phase 6 (S-276, S-278 … S-284): the paywall screen.
//
// Every assertion here is about what a user sees and what the screen asks for.
// The store is scripted through `FakePurchaseGateway`, and the entitlement is
// read through the real `EntitlementController`, so "is this user Pro?" is
// never answered by the screen under test.
//
// The router is deliberately minimal — `/home` plus `/paywall` — so the two
// dismissals can be observed as a real `pop()` rather than as a callback.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/features/paywall/paywall_route.dart';
import 'package:wheel_triage/features/paywall/paywall_screen.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_purchase_gateway.dart';

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

final _annualWithTrial = _offer(
  kProAnnualProductId,
  '\$29.99',
  'USD',
  '29.99',
  trial: const TrialOffer(units: 7, unit: TrialPeriodUnit.day),
);

final _monthly = _offer(kProMonthlyProductId, '\$4.99', 'USD', '4.99');

final _lifetime = _offer(kProLifetimeProductId, '\$79.99', 'USD', '79.99');

final _allThree = ProOfferings(plans: [_annualWithTrial, _monthly, _lifetime]);

/// The purchase date used by the owned-state fixtures.
final _purchasedAt = DateTime(2026, 3, 3);

const _annualProductId = kProAnnualProductId;
const _monthlyProductId = kProMonthlyProductId;
const _lifetimeProductId = kProLifetimeProductId;

/// A finder for any plan row, whatever product id it carries — used to assert
/// that *no* row is rendered without naming the three ids again.
Finder get _anyPlanRow => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('paywall-plan-'),
);

/// Pumps the app shell, opens the paywall with [trigger], and hands back the
/// container so a test can read the entitlement the screen is rendering from.
///
/// The surface is made tall on purpose: the paywall is a scrolling page, and a
/// 600-pixel viewport would leave the button, the message and the policy text
/// unbuilt, so a test would fail for a reason that has nothing to do with what
/// it is asserting.
Future<ProviderContainer> _pumpPaywall(
  WidgetTester tester, {
  required FakePurchaseGateway gateway,
  PaywallTrigger trigger = const SettingsPaywallTrigger(),
  bool initializeEntitlement = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [
      wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository()),
      purchaseGatewayProvider.overrideWithValue(gateway),
    ],
  );
  addTearDown(container.dispose);

  if (initializeEntitlement) {
    // What `EntitlementLifecycleScope` does at launch. Called before the pump
    // so the screen's first build already sees the settled entitlement.
    await container.read(entitlementControllerProvider.notifier).initialize();
  }

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-paywall'),
              onPressed: () => showPaywall(context, trigger: trigger),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      // The real route: the trigger travels in `extra`, exactly as
      // `app_router.dart` wires it.
      GoRoute(
        path: '/paywall',
        builder: (context, state) =>
            PaywallScreen(trigger: paywallTriggerFrom(state.extra)),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-paywall')));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapPurchase(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('paywall-purchase-button')));
  await tester.pumpAndSettle();
}

void main() {
  group('S-276: the paywall states why it opened, in the trigger\'s own words', () {
    testWidgets('a new-cycle refusal renders the line the gate produced', (
      tester,
    ) async {
      const line = 'You have 3 open cycles, the free plan\'s limit.';
      await _pumpPaywall(
        tester,
        gateway: FakePurchaseGateway(offerings: _allThree),
        trigger: const NewCyclePaywallTrigger(line),
      );
      expect(
        find.byKey(const ValueKey('paywall-trigger-line')),
        findsOneWidget,
      );
      expect(find.text(line), findsOneWidget);
    });

    testWidgets('a Pro feature renders the feature line', (tester) async {
      await _pumpPaywall(
        tester,
        gateway: FakePurchaseGateway(offerings: _allThree),
        trigger: const ProFeaturePaywallTrigger('Screenshot scan'),
      );
      expect(find.text(proFeatureLine('Screenshot scan')), findsOneWidget);
    });

    testWidgets(
      'the Settings row and a triggerless deep link both render the generic line',
      (tester) async {
        await _pumpPaywall(
          tester,
          gateway: FakePurchaseGateway(offerings: _allThree),
          trigger: const SettingsPaywallTrigger(),
        );
        expect(find.text(kPaywallSettingsLine), findsOneWidget);
      },
    );

    test(
      'the route falls back to the Settings trigger for an unexpected extra',
      () {
        expect(paywallTriggerFrom(null), const SettingsPaywallTrigger());
        expect(paywallTriggerFrom('nonsense'), const SettingsPaywallTrigger());
        expect(
          paywallTriggerFrom(const NewCyclePaywallTrigger('x')),
          const NewCyclePaywallTrigger('x'),
        );
      },
    );

    test(
      'every trigger type is distinct, so a trigger cannot be mistaken for another',
      () {
        expect(
          const NewCyclePaywallTrigger('x') == const SettingsPaywallTrigger(),
          isFalse,
        );
        expect(
          const ProFeaturePaywallTrigger('x') ==
              const NewCyclePaywallTrigger('x'),
          isFalse,
        );
        expect(
          const ProFeaturePaywallTrigger('a'),
          const ProFeaturePaywallTrigger('a'),
        );
      },
    );
  });

  group('S-278: the plans are the store\'s, in the app\'s order', () {
    testWidgets(
      'three plans render annual, monthly, lifetime, with annual selected',
      (tester) async {
        await _pumpPaywall(
          tester,
          gateway: FakePurchaseGateway(offerings: _allThree),
        );

        expect(_anyPlanRow, findsNWidgets(3));
        final annualY = tester
            .getTopLeft(
              find.byKey(const ValueKey('paywall-plan-$_annualProductId')),
            )
            .dy;
        final monthlyY = tester
            .getTopLeft(
              find.byKey(const ValueKey('paywall-plan-$_monthlyProductId')),
            )
            .dy;
        final lifetimeY = tester
            .getTopLeft(
              find.byKey(const ValueKey('paywall-plan-$_lifetimeProductId')),
            )
            .dy;
        expect(annualY, lessThan(monthlyY));
        expect(monthlyY, lessThan(lifetimeY));

        // Annual is preselected, and the button says what buying it does.
        expect(find.text('Start 7-day free trial'), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      },
    );

    testWidgets(
      'the selected and unselected indicators paint theme roles, not a hairline',
      (tester) async {
        await _pumpPaywall(
          tester,
          gateway: FakePurchaseGateway(offerings: _allThree),
        );

        final scheme = Theme.of(
          tester.element(find.byType(PaywallScreen)),
        ).colorScheme;
        final selected = tester.widget<Icon>(
          find.byIcon(Icons.radio_button_checked),
        );
        final unselected = tester.widget<Icon>(
          find.byIcon(Icons.radio_button_unchecked).first,
        );

        expect(selected.color, scheme.primary);
        // D-68: `outline` is the hairline this replaced, and it fails 3:1 in
        // both themes -- the assertion names it so a revert is not silent.
        expect(unselected.color, scheme.onSurfaceVariant);
        expect(unselected.color, isNot(scheme.outline));
      },
    );

    testWidgets('the annual row states the store\'s own trial term', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        gateway: FakePurchaseGateway(offerings: _allThree),
      );
      expect(
        find.text('7-day free trial, then \$29.99 a year · \$2.50 a month'),
        findsOneWidget,
      );
    });

    testWidgets('only monthly on offer: one row, and it is the selected one', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        gateway: FakePurchaseGateway(
          offerings: ProOfferings(plans: [_monthly]),
        ),
      );
      expect(_anyPlanRow, findsOneWidget);
      expect(find.text('Subscribe for \$4.99 a month'), findsOneWidget);
    });

    testWidgets('annual without a trial: no trial line anywhere', (
      tester,
    ) async {
      final annual = _offer(kProAnnualProductId, '\$29.99', 'USD', '29.99');
      await _pumpPaywall(
        tester,
        gateway: FakePurchaseGateway(
          offerings: ProOfferings(plans: [annual, _lifetime]),
        ),
      );
      expect(find.textContaining('free trial'), findsNothing);
      expect(find.text('Subscribe for \$29.99 a year'), findsOneWidget);
    });

    testWidgets('a store price the app has never seen is rendered as given', (
      tester,
    ) async {
      // The screen must not be able to fall back to a price of its own: this
      // price appears nowhere in `lib/`.
      final chf = _offer(kProMonthlyProductId, 'CHF 9.00', 'CHF', '9.00');
      await _pumpPaywall(
        tester,
        gateway: FakePurchaseGateway(offerings: ProOfferings(plans: [chf])),
      );
      expect(find.text('CHF 9.00 a month'), findsOneWidget);
      expect(find.text('Subscribe for CHF 9.00 a month'), findsOneWidget);
    });

    testWidgets('a product the app cannot describe is not offered for sale', (
      tester,
    ) async {
      final stranger = _offer('pro_stranger', '\$99.99', 'USD', '99.99');
      await _pumpPaywall(
        tester,
        gateway: FakePurchaseGateway(
          offerings: ProOfferings(plans: [stranger, _monthly]),
        ),
      );
      expect(_anyPlanRow, findsOneWidget);
      expect(find.textContaining('99.99'), findsNothing);
    });
  });

  group('S-279: the button buys the selected plan', () {
    testWidgets(
      'selecting monthly changes the button, and the purchase carries that id',
      (tester) async {
        final gateway = FakePurchaseGateway(offerings: _allThree);
        await _pumpPaywall(tester, gateway: gateway);

        await tester.tap(
          find.byKey(const ValueKey('paywall-plan-$_monthlyProductId')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Subscribe for \$4.99 a month'), findsOneWidget);

        await _tapPurchase(tester);
        expect(gateway.purchasedProductIds, [_monthlyProductId]);
      },
    );

    testWidgets(
      'selecting lifetime changes the button, and it is not a subscription',
      (tester) async {
        final gateway = FakePurchaseGateway(offerings: _allThree);
        await _pumpPaywall(tester, gateway: gateway);

        await tester.tap(
          find.byKey(const ValueKey('paywall-plan-$_lifetimeProductId')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Buy lifetime for \$79.99'), findsOneWidget);

        await _tapPurchase(tester);
        expect(gateway.purchasedProductIds, [_lifetimeProductId]);
      },
    );

    testWidgets(
      'the annual row\'s derived per-month figure is the store price over twelve',
      (tester) async {
        await _pumpPaywall(
          tester,
          gateway: FakePurchaseGateway(offerings: _allThree),
        );
        expect(find.textContaining('\$2.50 a month'), findsOneWidget);
      },
    );
  });

  group(
    'S-280: a store that cannot be reached is an honest unavailable state',
    () {
      testWidgets('no row, no price, no purchase button — and a retry', (
        tester,
      ) async {
        final gateway = FakePurchaseGateway(offerings: null)
          ..entitlementThrows = true
          ..offeringsThrows = true;
        await _pumpPaywall(tester, gateway: gateway);

        expect(find.text(kPaywallOffersUnavailableLine), findsOneWidget);
        expect(find.byKey(const ValueKey('paywall-retry')), findsOneWidget);
        expect(_anyPlanRow, findsNothing);
        expect(
          find.byKey(const ValueKey('paywall-purchase-button')),
          findsNothing,
        );
        expect(find.textContaining('\$'), findsNothing);

        // What survives an unreachable store: the explanation, the privacy
        // line, restore and the policy text.
        expect(
          find.byKey(const ValueKey('paywall-privacy-line')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('paywall-restore')), findsOneWidget);
        expect(find.text(kTermsOfUseUrl), findsOneWidget);
      });

      testWidgets(
        'retrying asks the store again, and a store that then answers renders plans',
        (tester) async {
          final gateway = FakePurchaseGateway(offerings: null);
          await _pumpPaywall(tester, gateway: gateway);
          expect(gateway.loadOfferingsCount, 1);

          gateway.offerings = _allThree;
          await tester.tap(find.byKey(const ValueKey('paywall-retry')));
          await tester.pumpAndSettle();

          expect(gateway.loadOfferingsCount, 2);
          expect(_anyPlanRow, findsNWidgets(3));
          expect(find.text(kPaywallOffersUnavailableLine), findsNothing);
        },
      );

      testWidgets('a store that answers with no plans is not a crash', (
        tester,
      ) async {
        await _pumpPaywall(
          tester,
          gateway: FakePurchaseGateway(
            offerings: const ProOfferings(plans: []),
          ),
        );
        expect(find.text(kPaywallOffersUnavailableLine), findsOneWidget);
        expect(_anyPlanRow, findsNothing);
      });
    },
  );

  group(
    'S-281: a purchase that did not complete says so and grants nothing',
    () {
      testWidgets(
        'pending: the line appears and the entitlement is unchanged',
        (tester) async {
          final gateway = FakePurchaseGateway(offerings: _allThree)
            ..purchaseOutcomes = const [PurchasePending()];
          final container = await _pumpPaywall(tester, gateway: gateway);

          await _tapPurchase(tester);

          expect(find.text(kPurchasePendingLine), findsOneWidget);
          expect(find.byKey(const ValueKey('paywall-owned')), findsNothing);
          expect(
            container.read(entitlementControllerProvider).isActive,
            isFalse,
          );
        },
      );

      testWidgets('cancelled: no message at all, and nothing was bought', (
        tester,
      ) async {
        final gateway = FakePurchaseGateway(offerings: _allThree)
          ..purchaseOutcomes = const [PurchaseCancelled()];
        await _pumpPaywall(tester, gateway: gateway);

        await _tapPurchase(tester);

        expect(find.byKey(const ValueKey('paywall-message')), findsNothing);
        expect(find.byKey(const ValueKey('paywall-owned')), findsNothing);
        // The plans are still there: a deliberate cancellation leaves the
        // paywall exactly as it was.
        expect(_anyPlanRow, findsNWidgets(3));
      });

      testWidgets(
        'failed: the line appears, and the button can be used again',
        (tester) async {
          final gateway = FakePurchaseGateway(offerings: _allThree)
            ..purchaseOutcomes = const [PurchaseFailed(), PurchasePurchased()];
          await _pumpPaywall(tester, gateway: gateway);

          await _tapPurchase(tester);
          expect(find.text(kPurchaseFailedLine), findsOneWidget);
          expect(find.byKey(const ValueKey('paywall-owned')), findsNothing);

          await _tapPurchase(tester);
          expect(gateway.purchaseCount, 2);
          expect(find.text(kPurchaseSucceededLine), findsOneWidget);
        },
      );

      testWidgets('a successful purchase turns Pro on in the same view', (
        tester,
      ) async {
        final gateway = FakePurchaseGateway(offerings: _allThree)
          ..snapshot = const EntitlementSnapshot.inactive();
        final container = await _pumpPaywall(tester, gateway: gateway);

        // The store grants what was bought; the app reads that back rather than
        // assuming it.
        gateway.snapshot = EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime(2027, 10, 5),
          willRenew: true,
          purchasedAt: _purchasedAt,
        );
        await _tapPurchase(tester);

        expect(find.text(kPurchaseSucceededLine), findsOneWidget);
        expect(container.read(entitlementControllerProvider).isActive, isTrue);
        expect(
          find.text(paywallOwnedLine(ProPlanKind.annual, _purchasedAt)),
          findsOneWidget,
        );
      });

      testWidgets(
        'a store error is reported as unavailable, not as a failure',
        (tester) async {
          final gateway = FakePurchaseGateway(offerings: _allThree)
            ..purchaseThrows = true;
          await _pumpPaywall(tester, gateway: gateway);

          await _tapPurchase(tester);

          expect(find.text(kPurchaseUnavailableLine), findsOneWidget);
          expect(find.text(kPurchaseFailedLine), findsNothing);
        },
      );
    },
  );

  group('S-283: what a user who already has Pro is shown', () {
    testWidgets('(a) a lifetime owner sees the owned line and nothing to buy', (
      tester,
    ) async {
      final gateway = FakePurchaseGateway(
        offerings: _allThree,
        snapshot: EntitlementSnapshot.active(
          planKind: ProPlanKind.lifetime,
          purchasedAt: _purchasedAt,
        ),
      );
      await _pumpPaywall(tester, gateway: gateway);

      expect(find.byKey(const ValueKey('paywall-owned')), findsOneWidget);
      expect(
        find.text(paywallOwnedLine(ProPlanKind.lifetime, _purchasedAt)),
        findsOneWidget,
      );
      expect(_anyPlanRow, findsNothing);
      expect(
        find.byKey(const ValueKey('paywall-purchase-button')),
        findsNothing,
      );
    });

    testWidgets(
      '(b) a subscriber sees the lifetime upgrade only, and is told to cancel',
      (tester) async {
        final gateway = FakePurchaseGateway(
          offerings: _allThree,
          snapshot: EntitlementSnapshot.active(
            planKind: ProPlanKind.annual,
            expiresAt: DateTime(2027, 10, 5),
            willRenew: true,
            purchasedAt: _purchasedAt,
          ),
        );
        await _pumpPaywall(tester, gateway: gateway);

        // Never a second subscription.
        expect(_anyPlanRow, findsOneWidget);
        expect(
          find.byKey(const ValueKey('paywall-plan-$_lifetimeProductId')),
          findsOneWidget,
        );
        expect(find.text('Buy lifetime for \$79.99'), findsOneWidget);

        await _tapPurchase(tester);

        expect(find.text(kLifetimeAfterSubscriptionLine), findsOneWidget);
        expect(
          find.byKey(const ValueKey('paywall-manage-subscription')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('paywall-manage-subscription')),
        );
        await tester.pumpAndSettle();
        expect(gateway.showManageSubscriptionsCount, 1);
      },
    );

    testWidgets('an ordinary purchase does not offer the management page', (
      tester,
    ) async {
      final gateway = FakePurchaseGateway(offerings: _allThree);
      await _pumpPaywall(tester, gateway: gateway);

      await _tapPurchase(tester);

      expect(
        find.byKey(const ValueKey('paywall-manage-subscription')),
        findsNothing,
      );
    });

    testWidgets('an unknown entitlement is treated as free, not as Pro', (
      tester,
    ) async {
      final gateway = FakePurchaseGateway(offerings: _allThree)
        ..entitlementThrows = true;
      await _pumpPaywall(tester, gateway: gateway);

      expect(find.byKey(const ValueKey('paywall-owned')), findsNothing);
      expect(_anyPlanRow, findsNWidgets(3));
    });
  });

  group(
    'S-284: the paywall is dismissable and sells nothing on the way out',
    () {
      testWidgets('"Not now" pops the route and buys nothing', (tester) async {
        final gateway = FakePurchaseGateway(offerings: _allThree);
        await _pumpPaywall(tester, gateway: gateway);

        await tester.tap(find.byKey(const ValueKey('paywall-not-now')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('open-paywall')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('paywall-trigger-line')),
          findsNothing,
        );
        expect(gateway.purchaseCount, 0);
        expect(gateway.restoreCount, 0);
      });

      testWidgets('the close icon pops the route and buys nothing', (
        tester,
      ) async {
        final gateway = FakePurchaseGateway(offerings: _allThree);
        await _pumpPaywall(tester, gateway: gateway);

        await tester.tap(find.byKey(const ValueKey('paywall-close')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('open-paywall')), findsOneWidget);
        expect(gateway.purchaseCount, 0);
      });

      testWidgets(
        'restoring from the paywall asks the store and reports the answer',
        (tester) async {
          final gateway = FakePurchaseGateway(offerings: _allThree)
            ..restoreOutcome = const PurchaseCancelled();
          await _pumpPaywall(tester, gateway: gateway);

          await tester.tap(find.byKey(const ValueKey('paywall-restore')));
          await tester.pumpAndSettle();

          expect(gateway.restoreCount, 1);
          expect(find.text(kNothingToRestoreLine), findsOneWidget);
        },
      );
    },
  );
}
