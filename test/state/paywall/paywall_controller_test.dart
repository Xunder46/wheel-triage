// Pro Wave 2, Phase 6 (S-278 … S-283): the paywall's state layer.
//
// The controller reads `entitlementControllerProvider` and nothing else about
// Pro (D-28) -- it never decides whether the user is Pro, it renders what the
// store and the entitlement state already said. The store's own answer is
// scripted through `FakePurchaseGateway`, so every assertion here is about the
// app's behaviour rather than about a platform channel.

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/entitlement_status.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/state/entitlements/entitlement_controller.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/entitlements/new_cycle_gate.dart';
import 'package:wheel_triage/state/paywall/paywall_controller.dart';
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

/// S-278(a): the store's own trial, in the store's own units.
final _annualWithTrial = _offer(
  kProAnnualProductId,
  '\$29.99',
  'USD',
  '29.99',
  trial: const TrialOffer(units: 7, unit: TrialPeriodUnit.day),
);

/// S-278(c): the same plan, configured without a trial.
final _annualNoTrial = _offer(kProAnnualProductId, '\$29.99', 'USD', '29.99');

final _monthly = _offer(kProMonthlyProductId, '\$4.99', 'USD', '4.99');

final _lifetime = _offer(kProLifetimeProductId, '\$79.99', 'USD', '79.99');

/// A product the app cannot describe -- a store misconfiguration (D-31).
final _unknownProduct = _offer('wheel_triage_pro_weekly', '\$1.99', 'USD', '1.99');

void main() {
  late InMemoryWheelRepository repo;
  late FakePurchaseGateway gateway;

  /// A fixed clock, so `checkedAt` is a fact the test asserts on rather than a
  /// moving value it can only bound.
  var now = DateTime.utc(2026, 6, 1, 12);

  setUp(() {
    repo = InMemoryWheelRepository();
    gateway = FakePurchaseGateway();
    now = DateTime.utc(2026, 6, 1, 12);
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        purchaseGatewayProvider.overrideWithValue(gateway),
        entitlementControllerProvider.overrideWith(
          (ref) => EntitlementController(
            ref.watch(purchaseGatewayProvider),
            ref.watch(wheelRepositoryProvider),
            now: () => now,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(entitlementControllerProvider, (previous, next) {});
    container.listen(paywallControllerProvider, (previous, next) {});
    return container;
  }

  PaywallController paywallOf(ProviderContainer container) =>
      container.read(paywallControllerProvider.notifier);

  PaywallState paywallStateOf(ProviderContainer container) =>
      container.read(paywallControllerProvider);

  EntitlementState entitlementOf(ProviderContainer container) =>
      container.read(entitlementControllerProvider);

  /// The row a user would actually see selected, resolved through the D-33
  /// filter rather than read off the raw selection.
  ProPlanOffer? selectedVisibleOffer(ProviderContainer container) {
    final state = paywallStateOf(container);
    return state.selectedOfferIn(state.visibleOffers(entitlementOf(container)));
  }

  Future<void> seedOpenCycle(String ticker) async {
    final underlying = await repo.getOrCreateUnderlying(ticker);
    await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('30'),
        expiration: DateTime(2026, 7, 17),
        contracts: 1,
        openedAt: DateTime(2026, 5, 1),
        openCreditPerShare: Decimal.parse('1.20'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
  }

  group('S-278: the plans come from the store and annual is preselected', () {
    test('(a) three plans render in display order with annual selected', () async {
      // Deliberately shuffled: the display order is the app's, not the store's.
      gateway.offerings = ProOfferings(plans: [_lifetime, _monthly, _annualWithTrial]);

      final container = buildContainer();
      await paywallOf(container).load();

      final state = paywallStateOf(container);
      expect(state.offers.map((offer) => offer.productId).toList(), [
        kProAnnualProductId,
        kProMonthlyProductId,
        kProLifetimeProductId,
      ]);
      expect(state.selectedProductId, kProAnnualProductId);
      expect(state.selectedKind, ProPlanKind.annual);
      expect(
        selectedVisibleOffer(container)?.trial,
        const TrialOffer(units: 7, unit: TrialPeriodUnit.day),
      );
      expect(state.offersLoaded, isTrue);
      expect(state.offersUnavailable, isFalse);
    });

    test('(b) only monthly: one plan, and it is the selected one', () async {
      gateway.offerings = ProOfferings(plans: [_monthly]);

      final container = buildContainer();
      await paywallOf(container).load();

      final state = paywallStateOf(container);
      expect(state.offers, [_monthly]);
      expect(state.selectedProductId, kProMonthlyProductId);
      expect(state.selectedKind, ProPlanKind.monthly);
    });

    test('(c) annual without a trial: selected, and the offer carries no trial', () async {
      gateway.offerings = ProOfferings(plans: [_annualNoTrial, _monthly]);

      final container = buildContainer();
      await paywallOf(container).load();

      expect(paywallStateOf(container).selectedProductId, kProAnnualProductId);
      expect(selectedVisibleOffer(container)?.trial, isNull);
    });

    test('(d) a null answer is the unavailable state, not a fallback price', () async {
      gateway.offerings = null;

      final container = buildContainer();
      await paywallOf(container).load();

      final state = paywallStateOf(container);
      expect(state.offers, isEmpty);
      expect(state.offersLoaded, isTrue);
      expect(state.offersUnavailable, isTrue);
      expect(state.selectedProductId, isNull);
      expect(selectedVisibleOffer(container), isNull);
    });

    test('a product the app cannot describe is not offered for sale', () async {
      gateway.offerings = ProOfferings(plans: [_annualNoTrial, _unknownProduct]);

      final container = buildContainer();
      await paywallOf(container).load();

      expect(paywallStateOf(container).offers, [_annualNoTrial]);
    });

    test('the store is asked exactly once per load', () async {
      gateway.offerings = ProOfferings(plans: [_annualNoTrial]);

      final container = buildContainer();
      await paywallOf(container).load();
      await paywallOf(container).load();

      expect(gateway.loadOfferingsCount, 2);
    });
  });

  group('S-279: the selected plan is what the button buys', () {
    test('selecting another plan changes the selection and its kind', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial, _monthly, _lifetime]);

      final container = buildContainer();
      await paywallOf(container).load();
      paywallOf(container).select(kProMonthlyProductId);

      expect(paywallStateOf(container).selectedKind, ProPlanKind.monthly);
      expect(selectedVisibleOffer(container)?.productId, kProMonthlyProductId);

      paywallOf(container).select(kProLifetimeProductId);
      expect(paywallStateOf(container).selectedKind, ProPlanKind.lifetime);
    });

    test('a product that is not on offer cannot be selected', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial, _monthly]);

      final container = buildContainer();
      await paywallOf(container).load();
      paywallOf(container).select(_unknownProduct.productId);

      expect(paywallStateOf(container).selectedProductId, kProAnnualProductId);
    });

    test('the purchase carries the selected product identifier and nothing else', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial, _monthly]);

      final container = buildContainer();
      await paywallOf(container).load();
      paywallOf(container).select(kProMonthlyProductId);
      await paywallOf(container).purchase();

      expect(gateway.purchasedProductIds, [kProMonthlyProductId]);
      // One load, one purchase, and one entitlement read to settle what the
      // purchase did — the refresh D-32 requires, and nothing else.
      expect(gateway.calls, ['loadOfferings', 'purchase', 'currentEntitlement']);
    });

    test('a purchase with nothing selected is not attempted', () async {
      gateway.offerings = null;

      final container = buildContainer();
      await paywallOf(container).load();
      await paywallOf(container).purchase();

      expect(gateway.purchaseCount, 0);
    });
  });

  group('S-280: an unreachable store is an honest unavailable state', () {
    test('the retry asks the store again', () async {
      gateway.offerings = null;
      gateway.entitlementThrows = true;

      final container = buildContainer();
      await paywallOf(container).load();
      expect(paywallStateOf(container).offersUnavailable, isTrue);

      await paywallOf(container).load();

      expect(gateway.loadOfferingsCount, 2);
      expect(paywallStateOf(container).offersUnavailable, isTrue);
      expect(paywallStateOf(container).isBusy, isFalse);
    });

    test('a load that throws is not a crash', () async {
      gateway.offeringsThrows = true;

      final container = buildContainer();
      await paywallOf(container).load();

      expect(paywallStateOf(container).offersUnavailable, isTrue);
      expect(paywallStateOf(container).isBusy, isFalse);
    });
  });

  group('S-281: pending, cancelled and failed leave the entitlement alone', () {
    test('each outcome has its own line and none of them grants Pro', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);
      gateway.purchaseOutcomes = const [PurchasePending(), PurchaseCancelled(), PurchaseFailed()];

      final container = buildContainer();
      await paywallOf(container).load();

      await paywallOf(container).purchase();
      expect(paywallStateOf(container).message, kPurchasePendingLine);
      expect(paywallStateOf(container).isBusy, isFalse);
      expect(entitlementOf(container).status, EntitlementStatus.unknown);

      await paywallOf(container).purchase();
      expect(paywallStateOf(container).message, isNull);
      expect(entitlementOf(container).status, EntitlementStatus.unknown);

      await paywallOf(container).purchase();
      expect(paywallStateOf(container).message, kPurchaseFailedLine);
      expect(entitlementOf(container).status, EntitlementStatus.unknown);

      // Three attempts, and the paywall is still usable: the store was asked
      // three times and no attempt was swallowed.
      expect(gateway.purchaseCount, 3);
      expect(paywallStateOf(container).selectedProductId, kProAnnualProductId);
    });

    test('no outcome other than purchased writes the cache', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);
      gateway.purchaseOutcomes = const [PurchasePending(), PurchaseFailed()];

      final container = buildContainer();
      await paywallOf(container).load();
      await paywallOf(container).purchase();
      await paywallOf(container).purchase();

      final cache = await repo.getEntitlementCache();
      expect(cache.checkedAt, isNull);
    });

    test('a throw from the store is reported as unavailable, not as a failure', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);
      gateway.purchaseThrows = true;

      final container = buildContainer();
      await paywallOf(container).load();
      await paywallOf(container).purchase();

      expect(paywallStateOf(container).message, kPurchaseUnavailableLine);
      expect(paywallStateOf(container).isBusy, isFalse);
    });
  });

  group('S-282: restore, both outcomes', () {
    test('(a) a restored purchase becomes Pro, writes the cache, and unlocks a fourth cycle',
        () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);
      gateway.restoreOutcome = const PurchasePurchased();
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.annual,
        expiresAt: DateTime.utc(2027, 5, 30),
        willRenew: true,
        purchasedAt: DateTime.utc(2025, 5, 30),
      );

      final container = buildContainer();
      // At the free limit before the restore, so the fourth cycle is the thing
      // the restore actually changes.
      await seedOpenCycle('AAA');
      await seedOpenCycle('BBB');
      await seedOpenCycle('CCC');
      expect(
        await container.read(newCycleGateProvider).evaluate(),
        isA<NewCycleBlocked>(),
      );

      await paywallOf(container).load();
      await paywallOf(container).restore();

      expect(paywallStateOf(container).message, kRestoredLine);
      expect(gateway.restoreCount, 1);

      final entitlement = entitlementOf(container);
      expect(entitlement.status, EntitlementStatus.active);
      expect(entitlement.planKind, ProPlanKind.annual);
      expect(entitlement.expiresAt, DateTime.utc(2027, 5, 30));

      final cache = await repo.getEntitlementCache();
      expect(cache.isActive, isTrue);
      expect(cache.planKind, ProPlanKind.annual);
      expect(cache.checkedAt, now);

      expect(await container.read(newCycleGateProvider).evaluate(), isA<NewCycleAllowed>());
    });

    test('(b) nothing to restore leaves the state and the cache exactly as they were', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);
      // The adapter's own answer for "the store replied and there is nothing
      // on this account" (D-32's two restore lines).
      gateway.restoreOutcome = const PurchaseCancelled();

      final container = buildContainer();
      await paywallOf(container).load();
      await paywallOf(container).restore();

      expect(paywallStateOf(container).message, kNothingToRestoreLine);
      expect(gateway.restoreCount, 1);
      expect(entitlementOf(container).status, EntitlementStatus.unknown);

      final cache = await repo.getEntitlementCache();
      expect(cache.checkedAt, isNull);
      expect(cache.isActive, isFalse);
    });

    test('a restore the store cannot reach says so', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);
      gateway.restoreOutcome = const PurchaseUnavailable();

      final container = buildContainer();
      await paywallOf(container).load();
      await paywallOf(container).restore();

      expect(paywallStateOf(container).message, kPurchaseUnavailableLine);
    });
  });

  group('S-283: lifetime rules', () {
    test('(a) a lifetime owner is offered nothing to buy', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial, _monthly, _lifetime]);
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.lifetime,
        purchasedAt: DateTime.utc(2026, 3, 3),
      );

      final container = buildContainer();
      await container.read(entitlementControllerProvider.notifier).refresh();
      await paywallOf(container).load();

      final state = paywallStateOf(container);
      // Every plan is known, and none of them is visible: a lifetime owner is
      // never shown a subscription prompt (D-33).
      expect(state.offers, hasLength(3));
      expect(state.visibleOffers(entitlementOf(container)), isEmpty);
      expect(selectedVisibleOffer(container), isNull);
      expect(entitlementOf(container).planKind, ProPlanKind.lifetime);
      expect(entitlementOf(container).expiresAt, isNull);
    });

    test('(b) a subscriber is offered lifetime only, and buying it tells them to cancel', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial, _monthly, _lifetime]);
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.annual,
        expiresAt: DateTime.utc(2027, 5, 30),
        willRenew: true,
      );

      final container = buildContainer();
      await container.read(entitlementControllerProvider.notifier).refresh();
      await paywallOf(container).load();

      final visible = paywallStateOf(container).visibleOffers(entitlementOf(container));
      expect(visible.map((offer) => offer.productId).toList(), [kProLifetimeProductId]);
      expect(paywallStateOf(container).selectedProductId, kProLifetimeProductId);

      // The store grants lifetime while the subscription stays active, which is
      // the case D-33 exists for: there is no backend to cancel the
      // subscription on, so the app has to say so.
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.lifetime,
        purchasedAt: DateTime.utc(2026, 3, 3),
      );
      await paywallOf(container).purchase();

      final state = paywallStateOf(container);
      expect(state.message, kLifetimeAfterSubscriptionLine);
      expect(state.showManageSubscription, isTrue);
      expect(gateway.purchasedProductIds, [kProLifetimeProductId]);
      expect(entitlementOf(container).planKind, ProPlanKind.lifetime);
    });

    test('an ordinary purchase does not offer the management page', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.annual,
        expiresAt: DateTime.utc(2027, 5, 30),
        willRenew: true,
      );

      final container = buildContainer();
      await paywallOf(container).load();
      await paywallOf(container).purchase();

      expect(paywallStateOf(container).message, kPurchaseSucceededLine);
      expect(paywallStateOf(container).showManageSubscription, isFalse);
    });

    test('manage subscription goes through the entitlement controller', () async {
      final container = buildContainer();
      await paywallOf(container).manageSubscription();

      expect(gateway.showManageSubscriptionsCount, 1);
    });
  });

  group('the free tier is the default the paywall renders for', () {
    test('an inactive entitlement sees every plan', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial, _monthly, _lifetime]);
      gateway.snapshot = const EntitlementSnapshot.inactive();

      final container = buildContainer();
      await container.read(entitlementControllerProvider.notifier).refresh();
      await paywallOf(container).load();

      final state = paywallStateOf(container);
      expect(state.visibleOffers(entitlementOf(container)), hasLength(3));
      expect(state.selectedProductId, kProAnnualProductId);
      expect(entitlementOf(container).isActive, isFalse);
    });

    test('the paywall never writes the entitlement cache itself', () async {
      gateway.offerings = ProOfferings(plans: [_annualWithTrial]);

      final container = buildContainer();
      await paywallOf(container).load();

      // Only a successful store *read* writes the cache (D-26), and the
      // paywall's own load is not one.
      expect((await repo.getEntitlementCache()).checkedAt, isNull);
    });
  });

  group('the state layer owns no copy of the copy', () {
    test('a fresh paywall state is empty, idle and unlocked', () {
      const state = PaywallState();

      expect(state.offers, isEmpty);
      expect(state.selectedProductId, isNull);
      expect(state.isBusy, isFalse);
      expect(state.message, isNull);
      expect(state.offersLoaded, isFalse);
      expect(state.showManageSubscription, isFalse);
      expect(state.offersUnavailable, isFalse);
      expect(state.selectedKind, ProPlanKind.none);
    });
  });
}
