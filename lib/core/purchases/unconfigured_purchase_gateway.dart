import 'purchase_gateway.dart';

/// The gateway used when the app was built without a store key, and the
/// provider's default in every test that does not override it (D-27).
///
/// It answers every call honestly and inertly: no offerings, an `unknown`
/// entitlement (which behaves as the free tier — Pro is never forged from an
/// absent answer, D-26), and every purchase `unavailable` rather than
/// pretending to have tried. This is what keeps the many existing suites that
/// pump Settings or Record working unchanged, exactly as
/// `NoOpNotificationGateway` does for notifications.
///
/// It never throws, and it never emits an entitlement update: there is no
/// store behind it to hear from.
class UnconfiguredPurchaseGateway implements PurchaseGateway {
  const UnconfiguredPurchaseGateway();

  @override
  Future<void> configure() async {}

  @override
  Future<ProOfferings?> loadOfferings() async => null;

  @override
  Future<EntitlementSnapshot> currentEntitlement() async =>
      const EntitlementSnapshot.unknown();

  @override
  Future<PurchaseOutcome> purchase(String productId) async =>
      const PurchaseOutcome.unavailable();

  @override
  Future<PurchaseOutcome> restore() async => const PurchaseOutcome.unavailable();

  @override
  Future<void> showManageSubscriptions() async {}

  @override
  void addEntitlementListener(void Function(EntitlementSnapshot) listener) {}
}
