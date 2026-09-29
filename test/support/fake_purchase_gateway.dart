import 'package:wheel_triage/core/purchases/purchase_gateway.dart';

/// A recording, scriptable [PurchaseGateway] test double -- the purchases
/// analogue of `FakeNotificationGateway`, shared by every Pro Wave 2 test
/// that needs to observe what the app asked the store and to script what the
/// store answered, without touching a platform channel.
///
/// Every call is recorded in [calls] (the method name only) so S-288 can
/// assert that nothing but a store product identifier ever crossed the seam,
/// and each call has its own counter for the scenarios that count calls
/// (S-270, S-286).
class FakePurchaseGateway implements PurchaseGateway {
  FakePurchaseGateway({this.offerings, EntitlementSnapshot? snapshot})
    : snapshot = snapshot ?? const EntitlementSnapshot.inactive();

  /// What [loadOfferings] answers. `null` is the store being unreachable.
  ProOfferings? offerings;

  /// What [currentEntitlement] answers.
  EntitlementSnapshot snapshot;

  /// When `true`, [currentEntitlement] throws instead of answering -- the
  /// offline case (S-269, S-280).
  bool entitlementThrows = false;

  /// When `true`, [loadOfferings] throws (S-280's offline offering fetch).
  bool offeringsThrows = false;

  /// What [purchase] answers, per call. The last entry repeats for any
  /// further call, so a test can script `[pending, cancelled, failed]` and
  /// tap three times (S-281).
  List<PurchaseOutcome> purchaseOutcomes = const [PurchasePurchased()];

  /// What [restore] answers.
  PurchaseOutcome restoreOutcome = const PurchasePurchased();

  /// When `true`, [purchase] and [restore] throw (a store error the seam
  /// cannot classify).
  bool purchaseThrows = false;

  int configureCount = 0;
  int loadOfferingsCount = 0;
  int currentEntitlementCount = 0;
  int purchaseCount = 0;
  int restoreCount = 0;
  int showManageSubscriptionsCount = 0;

  /// Every [purchase] argument, in order.
  final List<String> purchasedProductIds = [];

  /// Every method name the gateway was called with, in order (S-288).
  final List<String> calls = [];

  final List<void Function(EntitlementSnapshot)> _listeners = [];

  /// How many listeners are currently registered (S-271's "one listener").
  int get listenerCount => _listeners.length;

  /// Pushes [snapshot] to every registered listener, exactly as the store's
  /// own customer-info update does (S-271).
  void emit(EntitlementSnapshot next) {
    snapshot = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }

  @override
  Future<void> configure() async {
    configureCount++;
    calls.add('configure');
  }

  @override
  Future<ProOfferings?> loadOfferings() async {
    loadOfferingsCount++;
    calls.add('loadOfferings');
    if (offeringsThrows) throw StateError('the store is unreachable');
    return offerings;
  }

  @override
  Future<EntitlementSnapshot> currentEntitlement() async {
    currentEntitlementCount++;
    calls.add('currentEntitlement');
    if (entitlementThrows) throw StateError('offline');
    return snapshot;
  }

  @override
  Future<PurchaseOutcome> purchase(String productId) async {
    purchaseCount++;
    calls.add('purchase');
    purchasedProductIds.add(productId);
    if (purchaseThrows) throw StateError('store error');
    final index = purchaseCount - 1;
    return index < purchaseOutcomes.length
        ? purchaseOutcomes[index]
        : purchaseOutcomes.last;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    restoreCount++;
    calls.add('restore');
    if (purchaseThrows) throw StateError('store error');
    return restoreOutcome;
  }

  @override
  Future<void> showManageSubscriptions() async {
    showManageSubscriptionsCount++;
    calls.add('showManageSubscriptions');
  }

  @override
  void addEntitlementListener(void Function(EntitlementSnapshot) listener) {
    _listeners.add(listener);
  }
}
