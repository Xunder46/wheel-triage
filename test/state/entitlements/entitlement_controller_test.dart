// Pro Wave 2, Phase 4 (S-269 … S-275): the entitlement controller, the cache
// it writes and the three refresh points. The controller is the app's only
// reader of `PurchaseGateway` (D-28), so everything the app knows about Pro is
// asserted here rather than through a screen.
//
// S-270's launch/resume half lives in
// `test/widgets/entitlement_lifecycle_scope_test.dart` -- the scope is what
// makes the launch and resume reads happen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/domain/models/entitlement_cache.dart';
import 'package:wheel_triage/domain/models/entitlement_status.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/state/entitlements/entitlement_controller.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_purchase_gateway.dart';

void main() {
  late InMemoryWheelRepository repo;
  late FakePurchaseGateway gateway;

  /// A fixed clock so `checkedAt` is a fact the test can assert on rather
  /// than a moving value it can only bound.
  var now = DateTime.utc(2026, 6, 1, 12);

  setUp(() {
    repo = InMemoryWheelRepository();
    gateway = FakePurchaseGateway();
    now = DateTime.utc(2026, 6, 1, 12);
  });

  /// Builds the container the app itself builds: the gateway and the
  /// repository are the only things overridden, and the controller comes from
  /// the provider -- so a provider that forgot to wire either one fails here.
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
    return container;
  }

  EntitlementController controllerOf(ProviderContainer container) =>
      container.read(entitlementControllerProvider.notifier);

  EntitlementState stateOf(ProviderContainer container) =>
      container.read(entitlementControllerProvider);

  Future<void> seedCache(EntitlementCacheData cache) => repo.saveEntitlementCache(cache);

  group('S-269: the cache makes Pro work offline', () {
    test('a failed read keeps the cached entitlement, the plan and the expiry', () async {
      final cachedCheckedAt = DateTime.utc(2026, 5, 30, 9);
      await seedCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 5, 30),
          willRenew: true,
          purchasedAt: DateTime.utc(2025, 5, 30),
          checkedAt: cachedCheckedAt,
        ),
      );
      // Offline: the store answers nothing at all.
      gateway.entitlementThrows = true;

      final container = buildContainer();
      await controllerOf(container).initialize();

      final state = stateOf(container);
      expect(state.status, EntitlementStatus.active);
      expect(state.planKind, ProPlanKind.annual);
      expect(state.expiresAt, DateTime.utc(2027, 5, 30));
      expect(state.willRenew, isTrue);

      // The failed read did not clear the cache, and did not re-stamp it:
      // `checkedAt` is still the old successful read's.
      final cache = await repo.getEntitlementCache();
      expect(cache.isActive, isTrue);
      expect(cache.planKind, ProPlanKind.annual);
      expect(cache.checkedAt, cachedCheckedAt);
      expect(state.offeringsAvailable, isFalse);
    });

    test('a second failed refresh still does not clear the cache', () async {
      await seedCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 5, 30),
          willRenew: true,
          checkedAt: DateTime.utc(2026, 5, 30, 9),
        ),
      );
      gateway.entitlementThrows = true;

      final container = buildContainer();
      await controllerOf(container).initialize();
      now = DateTime.utc(2026, 6, 2, 12);
      await controllerOf(container).refresh();

      expect(stateOf(container).status, EntitlementStatus.active);
      expect((await repo.getEntitlementCache()).checkedAt, DateTime.utc(2026, 5, 30, 9));
    });
  });

  group('S-270: the launch read and the cache write', () {
    test('initialize() configures once, loads the cache, then reads once', () async {
      final container = buildContainer();
      await controllerOf(container).initialize();

      expect(gateway.configureCount, 1);
      expect(gateway.currentEntitlementCount, 1);
      expect(gateway.calls.first, 'configure');
    });

    test('initialize() is idempotent: a second call reads nothing again', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      await controller.initialize();

      expect(gateway.configureCount, 1);
      expect(gateway.currentEntitlementCount, 1);
    });

    test('a successful read writes the cache, and only a successful read does', () async {
      // No answer at all: nothing is written, so the row stays `unknown`.
      gateway.entitlementThrows = true;
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();

      // The fresh-install cache row is `unknown` -- no successful read yet.
      expect((await repo.getEntitlementCache()).checkedAt, isNull);

      gateway.entitlementThrows = false;
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.annual,
        expiresAt: DateTime.utc(2027, 6, 1),
        willRenew: true,
        purchasedAt: DateTime.utc(2026, 6, 1),
      );
      await controller.refresh();

      final cache = await repo.getEntitlementCache();
      expect(cache.isActive, isTrue);
      expect(cache.planKind, ProPlanKind.annual);
      expect(cache.expiresAt, DateTime.utc(2027, 6, 1));
      expect(cache.willRenew, isTrue);
      expect(cache.purchasedAt, DateTime.utc(2026, 6, 1));
      expect(cache.checkedAt, now);
      expect(gateway.currentEntitlementCount, 2);
    });

    test('refresh() never throws, even when the gateway does', () async {
      gateway.entitlementThrows = true;
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      await controller.refresh();
      await controller.refresh();

      expect(stateOf(container).status, EntitlementStatus.unknown);
    });

    test('overlapping refreshes collapse into one read', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      final before = gateway.currentEntitlementCount;

      await Future.wait([controller.refresh(), controller.refresh()]);

      expect(gateway.currentEntitlementCount, before + 1);
    });
  });

  group('S-271: the store\'s own entitlement update reaches the state', () {
    test('one listener is registered, and an emission needs no refresh()', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      expect(gateway.listenerCount, 1);

      final readsAfterLaunch = gateway.currentEntitlementCount;
      gateway.emit(
        EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 6, 1),
          willRenew: true,
          purchasedAt: DateTime.utc(2026, 6, 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).status, EntitlementStatus.active);
      expect(stateOf(container).expiresAt, DateTime.utc(2027, 6, 1));
      expect((await repo.getEntitlementCache()).expiresAt, DateTime.utc(2027, 6, 1));
      // The emission was applied as given -- no extra read was needed.
      expect(gateway.currentEntitlementCount, readsAfterLaunch);
      expect(controller.state.willRenew, isTrue);
    });

    test('a cancellation keeps Pro until the paid period ends', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();

      gateway.emit(
        EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 6, 1),
          willRenew: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      gateway.emit(
        EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 6, 1),
          willRenew: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).status, EntitlementStatus.active);
      expect(stateOf(container).willRenew, isFalse);
      expect(stateOf(container).expiresAt, DateTime.utc(2027, 6, 1));
      expect((await repo.getEntitlementCache()).willRenew, isFalse);
    });
  });

  group('S-272: expiry and cancellation without renewal', () {
    test('the store now reporting nothing lapses the entitlement and rewrites the cache', () async {
      await seedCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2026, 5, 1),
          willRenew: true,
          purchasedAt: DateTime.utc(2025, 5, 1),
          checkedAt: DateTime.utc(2026, 4, 1),
        ),
      );
      gateway.snapshot = const EntitlementSnapshot.inactive();

      final container = buildContainer();
      await controllerOf(container).initialize();

      expect(stateOf(container).status, EntitlementStatus.inactive);
      final cache = await repo.getEntitlementCache();
      expect(cache.isActive, isFalse);
      expect(cache.planKind, ProPlanKind.none);
      expect(cache.expiresAt, isNull);
      expect(cache.willRenew, isFalse);
      expect(cache.checkedAt, now);
    });

    test('a lapse clears the expiry and the purchase date from the state', () async {
      await seedCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2026, 5, 1),
          willRenew: true,
          purchasedAt: DateTime.utc(2025, 5, 1),
          checkedAt: DateTime.utc(2026, 4, 1),
        ),
      );
      gateway.snapshot = const EntitlementSnapshot.inactive();

      final container = buildContainer();
      await controllerOf(container).initialize();

      final state = stateOf(container);
      expect(state.status, EntitlementStatus.inactive);
      // The cached Pro fields are gone from the state, not left behind it: a
      // free tier has no expiry and no purchase date, and a stale one would
      // outlive the entitlement it described.
      expect(state.expiresAt, isNull);
      expect(state.purchasedAt, isNull);
      expect(state.planKind, ProPlanKind.none);
      expect(state.willRenew, isFalse);
    });
  });

  group('S-273: grace period and billing retry', () {
    test('a billing issue stays active and is carried to the cache', () async {
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.monthly,
        expiresAt: DateTime.utc(2026, 5, 20),
        willRenew: true,
        billingIssue: true,
        purchasedAt: DateTime.utc(2026, 1, 20),
      );

      final container = buildContainer();
      await controllerOf(container).initialize();

      final state = stateOf(container);
      expect(state.status, EntitlementStatus.active);
      expect(state.billingIssue, isTrue);
      expect(state.planKind, ProPlanKind.monthly);

      final cache = await repo.getEntitlementCache();
      expect(cache.isActive, isTrue);
      expect(cache.billingIssue, isTrue);
    });

    test('a later read reporting nothing applies S-272', () async {
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.monthly,
        expiresAt: DateTime.utc(2026, 5, 20),
        willRenew: true,
        billingIssue: true,
      );
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      expect(stateOf(container).status, EntitlementStatus.active);

      gateway.snapshot = const EntitlementSnapshot.inactive();
      await controller.refresh();

      expect(stateOf(container).status, EntitlementStatus.inactive);
      expect(stateOf(container).billingIssue, isFalse);
      expect((await repo.getEntitlementCache()).isActive, isFalse);
    });
  });

  group('S-274: refund and revocation', () {
    test('a revoked lifetime entitlement lapses like any other', () async {
      await seedCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.lifetime,
          purchasedAt: DateTime.utc(2026, 3, 3),
          checkedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      gateway.snapshot = const EntitlementSnapshot.inactive();

      final container = buildContainer();
      await controllerOf(container).initialize();

      expect(stateOf(container).status, EntitlementStatus.inactive);
      final cache = await repo.getEntitlementCache();
      expect(cache.isActive, isFalse);
      expect(cache.planKind, ProPlanKind.none);
      expect(cache.expiresAt, isNull);
      expect(cache.checkedAt, now);
    });

    test('a revoked annual subscription lapses and the paywall is reachable again', () async {
      await seedCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 1, 1),
          willRenew: true,
          checkedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      gateway.snapshot = const EntitlementSnapshot.inactive();

      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();

      expect(stateOf(container).isActive, isFalse);
      // Reachable again, not merely "not Pro": an offer loads.
      gateway.offerings = ProOfferings(plans: const []);
      await controller.loadOfferings();
      expect(stateOf(container).offeringsAvailable, isTrue);
    });

    test('no successful read ever leaves the state unknown, not inactive', () async {
      gateway.entitlementThrows = true;
      final container = buildContainer();
      await controllerOf(container).initialize();

      expect(stateOf(container).status, EntitlementStatus.unknown);
      expect(stateOf(container).isActive, isFalse);
      expect((await repo.getEntitlementCache()).checkedAt, isNull);
    });

    test('an unknown answer from the gateway is not a successful read', () async {
      await seedCache(
        EntitlementCacheData(
          isActive: true,
          planKind: ProPlanKind.annual,
          expiresAt: DateTime.utc(2027, 1, 1),
          willRenew: true,
          checkedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      gateway.snapshot = const EntitlementSnapshot.unknown();

      final container = buildContainer();
      await controllerOf(container).initialize();

      expect(stateOf(container).status, EntitlementStatus.active);
      expect((await repo.getEntitlementCache()).checkedAt, DateTime.utc(2026, 5, 1));
    });
  });

  group('S-275: lifetime has no expiry, no renewal and never lapses', () {
    test('two reads a year apart both report lifetime, with no expiry', () async {
      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.lifetime,
        purchasedAt: DateTime.utc(2026, 3, 3),
      );

      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();

      expect(stateOf(container).status, EntitlementStatus.active);
      expect(stateOf(container).planKind, ProPlanKind.lifetime);
      expect(stateOf(container).expiresAt, isNull);
      expect(stateOf(container).willRenew, isFalse);
      expect(stateOf(container).purchasedAt, DateTime.utc(2026, 3, 3));

      now = DateTime.utc(2027, 3, 3);
      await controller.refresh();

      expect(stateOf(container).status, EntitlementStatus.active);
      expect(stateOf(container).expiresAt, isNull);
      expect(stateOf(container).planKind, ProPlanKind.lifetime);
      final cache = await repo.getEntitlementCache();
      expect(cache.isActive, isTrue);
      expect(cache.expiresAt, isNull);
      expect(cache.checkedAt, DateTime.utc(2027, 3, 3));
    });
  });

  group('offers, purchase, restore and manage', () {
    test('loadOfferings reports availability and never throws', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      expect(stateOf(container).offeringsAvailable, isFalse);

      gateway.offerings = const ProOfferings(plans: []);
      expect(await controller.loadOfferings(), isNotNull);
      expect(stateOf(container).offeringsAvailable, isTrue);

      gateway.offeringsThrows = true;
      expect(await controller.loadOfferings(), isNull);
      expect(stateOf(container).offeringsAvailable, isFalse);
    });

    test('a purchased outcome re-reads the entitlement and writes the cache', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();

      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.annual,
        expiresAt: DateTime.utc(2027, 6, 1),
        willRenew: true,
      );
      final outcome = await controller.purchase('wheel_triage_pro_annual');

      expect(outcome, const PurchasePurchased());
      expect(gateway.purchasedProductIds, ['wheel_triage_pro_annual']);
      expect(stateOf(container).status, EntitlementStatus.active);
      expect((await repo.getEntitlementCache()).isActive, isTrue);
    });

    test('pending, cancelled and failed all leave the entitlement and cache alone', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      final stateBefore = stateOf(container);
      final cacheBefore = await repo.getEntitlementCache();

      gateway.purchaseOutcomes = const [
        PurchasePending(),
        PurchaseCancelled(),
        PurchaseFailed(),
      ];
      expect(await controller.purchase('a'), const PurchasePending());
      expect(await controller.purchase('a'), const PurchaseCancelled());
      expect(await controller.purchase('a'), const PurchaseFailed());

      expect(stateOf(container).status, stateBefore.status);
      expect(await repo.getEntitlementCache(), cacheBefore);
      // A retry is possible: each tap reached the store.
      expect(gateway.purchaseCount, 3);
    });

    test('a throwing gateway degrades to unavailable rather than propagating', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      final stateBefore = stateOf(container);
      final cacheBefore = await repo.getEntitlementCache();
      gateway.purchaseThrows = true;

      expect(await controller.purchase('a'), const PurchaseUnavailable());
      expect(await controller.restore(), const PurchaseUnavailable());
      expect(stateOf(container).status, stateBefore.status);
      expect(await repo.getEntitlementCache(), cacheBefore);
    });

    test('a restore that reports a purchase becomes active and writes the cache', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();

      gateway.snapshot = EntitlementSnapshot.active(
        planKind: ProPlanKind.annual,
        expiresAt: DateTime.utc(2027, 6, 1),
        willRenew: true,
      );
      final outcome = await controller.restore();

      expect(outcome, const PurchasePurchased());
      expect(gateway.restoreCount, 1);
      expect(stateOf(container).status, EntitlementStatus.active);
      expect((await repo.getEntitlementCache()).planKind, ProPlanKind.annual);
    });

    test('a restore that reports nothing leaves the state and the cache unchanged', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();
      final stateBefore = stateOf(container);
      gateway.restoreOutcome = const PurchaseCancelled();
      final cacheBefore = await repo.getEntitlementCache();

      expect(await controller.restore(), const PurchaseCancelled());
      expect(stateOf(container).status, stateBefore.status);
      expect(await repo.getEntitlementCache(), cacheBefore);
    });

    test('manageSubscription reaches the store and never throws', () async {
      final container = buildContainer();
      final controller = controllerOf(container);
      await controller.initialize();

      await controller.manageSubscription();
      expect(gateway.showManageSubscriptionsCount, 1);
    });
  });
}
