import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'pro_plans.dart';
import 'purchase_configuration.dart';
import 'purchase_gateway.dart';

/// The real store adapter (Pro Wave 2, D-27) — **the only file in `lib/` that
/// imports `purchases_flutter`**, which the permanent structural guard in
/// `test/core/purchases/network_boundary_test.dart` asserts.
///
/// It is deliberately a *translator*, not a decider:
///
/// * It imports nothing from `lib/data/` and nothing from `lib/domain/models/`
///   — the seam's own value types are the whole vocabulary it speaks, so the
///   SDK cannot be handed a leg, a snapshot or a ledger row even by mistake.
/// * It never throws out of any method. A store that cannot be reached, a
///   plugin that is not registered and a platform that has no store all
///   degrade to `null` offerings, an `unknown` entitlement and an
///   `unavailable` purchase, which the app renders honestly (D-26/D-32).
/// * It decides nothing about Pro. Which entitlement identifier matters, which
///   plans exist and how much they cost are all the store's answers; the
///   free-tier limit and the paywall copy live in `lib/state/` (D-28).
///
/// Off iOS every method is inert and the SDK is never touched (D-27, D-P9
/// defers Android). That is also what makes this class testable on the host,
/// where `defaultTargetPlatform` is `android`.
class RevenueCatPurchaseGateway implements PurchaseGateway {
  RevenueCatPurchaseGateway({
    String apiKey = kRevenueCatIosApiKey,
    TargetPlatform? platform,
  }) : _apiKey = apiKey,
       _platform = platform ?? defaultTargetPlatform;

  /// Where the "open the store's own management page" request goes. The app
  /// side of this channel is a few lines in `ios/Runner/AppDelegate.swift`;
  /// it exists because the SDK has no method for opening the page (see the
  /// phase's Assumption Log). A build without the handler makes
  /// [showManageSubscriptions] a no-op rather than a crash.
  static const MethodChannel _storePageChannel = MethodChannel('wheel_triage/store_page');

  final String _apiKey;
  final TargetPlatform _platform;

  /// One attempt, ever: `configure()` is idempotent by contract (D-27) and a
  /// failed attempt must not retry-loop behind the user's back.
  bool _configureAttempted = false;
  bool _configured = false;
  bool _storeListenerRegistered = false;

  /// The `StoreProduct`s the store has already handed over, so a purchase does
  /// not have to fetch the product again. Populated by [loadOfferings].
  final Map<String, StoreProduct> _productsById = {};

  final List<void Function(EntitlementSnapshot)> _listeners = [];

  @override
  Future<void> configure() async {
    if (_configureAttempted) return;
    _configureAttempted = true;
    if (_platform != TargetPlatform.iOS) return;
    try {
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      _configured = true;
      _registerStoreListener();
    } catch (_) {
      _configured = false;
    }
  }

  @override
  Future<ProOfferings?> loadOfferings() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return ProOfferings(plans: _plansFrom(offerings));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<EntitlementSnapshot> currentEntitlement() async {
    if (!_configured) return const EntitlementSnapshot.unknown();
    try {
      return _snapshotFrom(await Purchases.getCustomerInfo());
    } catch (_) {
      return const EntitlementSnapshot.unknown();
    }
  }

  @override
  Future<PurchaseOutcome> purchase(String productId) async {
    if (!_configured) return const PurchaseOutcome.unavailable();
    try {
      final product = await _productFor(productId);
      if (product == null) return const PurchaseOutcome.failed();
      await Purchases.purchase(PurchaseParams.storeProduct(product));
      return const PurchaseOutcome.purchased();
    } on PlatformException catch (error) {
      return _outcomeFor(PurchasesErrorHelper.getErrorCode(error));
    } catch (_) {
      return const PurchaseOutcome.failed();
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!_configured) return const PurchaseOutcome.unavailable();
    try {
      final customerInfo = await Purchases.restorePurchases();
      // The store answered, and the answer is what the app reports: an active
      // entitlement restored, or nothing to restore. Both are successes of
      // the *call* — the caller reads the resulting entitlement either way
      // (D-32's two restore lines).
      return _snapshotFrom(customerInfo).isActive
          ? const PurchaseOutcome.purchased()
          : const PurchaseOutcome.cancelled();
    } on PlatformException catch (error) {
      return _outcomeFor(PurchasesErrorHelper.getErrorCode(error));
    } catch (_) {
      return const PurchaseOutcome.failed();
    }
  }

  @override
  Future<void> showManageSubscriptions() async {
    if (!_configured) return;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final url = customerInfo.managementURL;
      if (url == null || url.isEmpty) return;
      await _storePageChannel.invokeMethod<void>('open', url);
    } catch (_) {
      // Nothing to do and nothing to say: the row that calls this is a
      // convenience, and the store's own page is reachable from the App Store
      // app regardless.
    }
  }

  @override
  void addEntitlementListener(void Function(EntitlementSnapshot) listener) {
    _listeners.add(listener);
    _registerStoreListener();
  }

  /// One store listener, fanned out to every registered listener, so the
  /// SDK's own "here is the new customer info" event (a renewal, a
  /// cancellation, a refund made outside the app) reaches the app without any
  /// polling (S-271).
  void _registerStoreListener() {
    if (!_configured || _storeListenerRegistered) return;
    _storeListenerRegistered = true;
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final snapshot = _snapshotFrom(customerInfo);
      for (final listener in List.of(_listeners)) {
        listener(snapshot);
      }
    });
  }

  Future<StoreProduct?> _productFor(String productId) async {
    final cached = _productsById[productId];
    if (cached != null) return cached;
    // `productCategory` is Android-only and ignored on iOS (D-P9 defers
    // Android), so the default subscription category is left alone.
    final products = await Purchases.getProducts([productId]);
    if (products.isEmpty) return null;
    _productsById[productId] = products.first;
    return products.first;
  }

  List<ProPlanOffer> _plansFrom(Offerings offerings) {
    final offering =
        offerings.current ?? (offerings.all.isEmpty ? null : offerings.all.values.first);
    if (offering == null) return const [];
    final plans = <ProPlanOffer>[];
    for (final package in offering.availablePackages) {
      final product = package.storeProduct;
      // Only the three plans `pro_plans.dart` names are offered: the app knows
      // the period for a plan it can name, and D-31 forbids inventing a label
      // (or a price) for anything else. An unrecognised product is a
      // misconfiguration, and it renders as "no plans" rather than as a row
      // the app cannot describe.
      if (!isKnownProProductId(product.identifier)) continue;
      _productsById[product.identifier] = product;
      plans.add(
        ProPlanOffer(
          productId: product.identifier,
          priceString: product.priceString,
          price: Decimal.parse(product.price.toString()),
          currencyCode: product.currencyCode,
          trial: _trialFrom(product.introductoryPrice),
        ),
      );
    }
    return plans;
  }

  TrialOffer? _trialFrom(IntroductoryPrice? price) {
    if (price == null) return null;
    return TrialOffer(units: price.periodNumberOfUnits, unit: _unitFrom(price.periodUnit));
  }

  TrialPeriodUnit _unitFrom(PeriodUnit unit) => switch (unit) {
    PeriodUnit.day => TrialPeriodUnit.day,
    PeriodUnit.week => TrialPeriodUnit.week,
    PeriodUnit.month => TrialPeriodUnit.month,
    PeriodUnit.year => TrialPeriodUnit.year,
    PeriodUnit.unknown => TrialPeriodUnit.unknown,
  };

  EntitlementSnapshot _snapshotFrom(CustomerInfo customerInfo) {
    final info = customerInfo.entitlements.active[kProEntitlementId];
    if (info == null) return const EntitlementSnapshot.inactive();
    return EntitlementSnapshot.active(
      planKind: kindForProductId(info.productIdentifier),
      expiresAt: _dateFrom(info.expirationDate),
      willRenew: info.willRenew,
      billingIssue: info.billingIssueDetectedAt != null,
      purchasedAt: _dateFrom(info.originalPurchaseDate),
    );
  }

  /// The SDK hands dates over as ISO-8601 strings (or an empty string, or
  /// null). Parsed defensively and converted to local time, because every
  /// date this app shows is a calendar date in the user's own day.
  DateTime? _dateFrom(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  /// Only the error codes that change what the app *says* are distinguished;
  /// everything else is a failure the user can retry (D-32).
  PurchaseOutcome _outcomeFor(PurchasesErrorCode code) => switch (code) {
    PurchasesErrorCode.purchaseCancelledError => const PurchaseOutcome.cancelled(),
    PurchasesErrorCode.paymentPendingError => const PurchaseOutcome.pending(),
    PurchasesErrorCode.networkError ||
    PurchasesErrorCode.offlineConnectionError ||
    PurchasesErrorCode.apiEndpointBlocked => const PurchaseOutcome.unavailable(),
    _ => const PurchaseOutcome.failed(),
  };
}
