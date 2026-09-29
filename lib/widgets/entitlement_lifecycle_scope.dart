import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/entitlements/entitlement_providers.dart';

/// The two lifecycle refresh points of the entitlement (Pro Wave 2, D-29),
/// and nothing else: a `ConsumerStatefulWidget` that passes its child through
/// untouched, plus a `WidgetsBindingObserver`.
///
/// * **Launch** — `initState` calls `EntitlementController.initialize()`,
///   which configures the store, loads the cached entitlement and then reads
///   the store once. That order matters: the cached read is what makes a
///   lapsed-connection launch show the right plan instead of the free tier.
/// * **Resume** — `AppLifecycleState.resumed` calls `refresh()`. A renewal or
///   a refund that happened while the app was backgrounded lands here.
///
/// It deliberately does **not** refresh on `inactive`, `hidden`, `paused` or
/// `detached`: leaving the foreground is not a fact about the user's
/// entitlement, and reading the store on every app switch would spend
/// network calls on nothing (S-270). It holds no state, decides nothing and
/// renders nothing — the store's own pushes arrive through the controller's
/// listener, not through here.
class EntitlementLifecycleScope extends ConsumerStatefulWidget {
  const EntitlementLifecycleScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EntitlementLifecycleScope> createState() => _EntitlementLifecycleScopeState();
}

class _EntitlementLifecycleScopeState extends ConsumerState<EntitlementLifecycleScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(entitlementControllerProvider.notifier).initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(entitlementControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
