import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/core/purchases/revenuecat_purchase_gateway.dart';
import 'package:wheel_triage/core/purchases/unconfigured_purchase_gateway.dart';
import 'package:wheel_triage/domain/models/entitlement_status.dart';

void main() {
  group('the seam', () {
    test('every purchase outcome is representable and distinct', () {
      const outcomes = <PurchaseOutcome>[
        PurchasePurchased(),
        PurchasePending(),
        PurchaseCancelled(),
        PurchaseFailed(),
        PurchaseUnavailable(),
      ];
      final labels = outcomes.map(_label).toSet();
      expect(labels, hasLength(5));
      expect(labels, containsAll(<String>[
        'purchased',
        'pending',
        'cancelled',
        'failed',
        'unavailable',
      ]));
    });

    test('an entitlement snapshot carries the tri-valued status', () {
      expect(const EntitlementSnapshot.unknown().status, EntitlementStatus.unknown);
      expect(const EntitlementSnapshot.inactive().status, EntitlementStatus.inactive);
      expect(
        const EntitlementSnapshot(status: EntitlementStatus.active).status,
        EntitlementStatus.active,
      );
    });
  });

  group('UnconfiguredPurchaseGateway', () {
    final gateway = const UnconfiguredPurchaseGateway();

    test('answers every call without throwing', () async {
      await gateway.configure();
      expect(await gateway.loadOfferings(), isNull);
      expect((await gateway.currentEntitlement()).status, EntitlementStatus.unknown);
      expect(await gateway.purchase('wheel_triage_pro_annual'), isA<PurchaseUnavailable>());
      expect(await gateway.restore(), isA<PurchaseUnavailable>());
      await gateway.showManageSubscriptions();
    });

    test('configure() is idempotent', () async {
      await gateway.configure();
      await gateway.configure();
      expect(await gateway.loadOfferings(), isNull);
    });

    test('never emits an entitlement update', () async {
      var emissions = 0;
      gateway.addEntitlementListener((_) => emissions++);
      await gateway.configure();
      expect(emissions, 0);
    });
  });

  group('RevenueCatPurchaseGateway', () {
    test('off iOS it is inert: no offerings, unknown entitlement, every '
        'purchase unavailable', () async {
      final gateway = RevenueCatPurchaseGateway(platform: TargetPlatform.android);
      await gateway.configure();
      await gateway.configure();
      expect(await gateway.loadOfferings(), isNull);
      expect((await gateway.currentEntitlement()).status, EntitlementStatus.unknown);
      expect(await gateway.purchase('wheel_triage_pro_annual'), isA<PurchaseUnavailable>());
      expect(await gateway.restore(), isA<PurchaseUnavailable>());
      await gateway.showManageSubscriptions();
    });

    test('off iOS it never registers a store listener', () async {
      final gateway = RevenueCatPurchaseGateway(platform: TargetPlatform.android);
      var emissions = 0;
      gateway.addEntitlementListener((_) => emissions++);
      await gateway.configure();
      expect(emissions, 0);
    });

    test('configure() never throws even where the SDK cannot answer', () async {
      // The test host has no RevenueCat platform implementation, so this is
      // the harshest case the adapter can meet: it must degrade, not throw.
      final gateway = RevenueCatPurchaseGateway(platform: TargetPlatform.iOS);
      await gateway.configure();
      await gateway.configure();
      expect(await gateway.loadOfferings(), isNull);
      expect(await gateway.restore(), isA<PurchaseUnavailable>());
      expect(await gateway.purchase('wheel_triage_pro_annual'), isA<PurchaseUnavailable>());
      await gateway.showManageSubscriptions();
    });
  });
}

String _label(PurchaseOutcome outcome) => switch (outcome) {
  PurchasePurchased() => 'purchased',
  PurchasePending() => 'pending',
  PurchaseCancelled() => 'cancelled',
  PurchaseFailed() => 'failed',
  PurchaseUnavailable() => 'unavailable',
};
