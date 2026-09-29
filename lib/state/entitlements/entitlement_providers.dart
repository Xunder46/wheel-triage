import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/purchase_gateway.dart';
import '../../core/purchases/unconfigured_purchase_gateway.dart';
import '../repository_providers.dart';
import 'entitlement_controller.dart';
import 'new_cycle_gate.dart';

/// The single source of a [PurchaseGateway] for the whole app (Pro Wave 2,
/// D-27), mirroring `notificationGatewayProvider`.
///
/// It has a real, safe default ([UnconfiguredPurchaseGateway]) rather than
/// throwing when nobody overrides it: an app built without a store key must
/// show the free tier and sell nothing, not fail to start, and every existing
/// test that pumps Settings or Record keeps working unchanged. Pro is never
/// forged from an absent answer (D-26).
///
/// `lib/main.dart` **always** overrides it — one override that exists on both
/// branches, so a missing wire-up cannot ship silently.
final purchaseGatewayProvider = Provider<PurchaseGateway>(
  (ref) => const UnconfiguredPurchaseGateway(),
);

/// The app's single source of entitlement truth (Pro Wave 2, D-28), and the
/// only reader of [purchaseGatewayProvider] anywhere in the app.
///
/// Deliberately **not** `.autoDispose`: it registers the store's
/// entitlement-update listener once, in its constructor, and a controller
/// that came and went with a screen would re-register that listener (and
/// re-read the store) every time the user navigated. It holds no trade data
/// — only the store's own report about the user's purchase — so keeping it
/// alive for the process costs nothing.
///
/// Nothing is loaded in the constructor: `EntitlementLifecycleScope` calls
/// `initialize()` once at launch, after which the cache makes Pro work
/// offline and the resume/listener paths keep it fresh (D-29).
final entitlementControllerProvider =
    StateNotifierProvider<EntitlementController, EntitlementState>((ref) {
      return EntitlementController(
        ref.watch(purchaseGatewayProvider),
        ref.watch(wheelRepositoryProvider),
      );
    });

/// How many cycles are open, for the Settings row's count display (D-34).
///
/// A **count, not a gate evaluation**: nothing reads this to decide anything.
/// The free tier's limit is evaluated in exactly one place,
/// `NewCycleGate.evaluate()` (D-28), which does its own read — this provider
/// exists only so the row can print "2 of 3 open cycles" without a widget
/// reaching into the repository itself.
final openCycleCountProvider = FutureProvider<int>((ref) async {
  final cycles = await ref.watch(wheelRepositoryProvider).getOpenCycles();
  return cycles.length;
});

/// D-P2's free-tier limit, as the one object that evaluates it (D-23, D-28).
///
/// It lives here rather than beside its class so that the whole app's
/// entitlement story — the gateway, the state, and the single evaluation of
/// the limit — is reachable from one import, and so a structural test can
/// assert that exactly one non-test file reads this provider.
final newCycleGateProvider = Provider(newCycleGate);
