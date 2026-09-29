import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'core/app_router.dart';
import 'core/notifications/notification_scheduler.dart';
import 'core/purchases/purchase_configuration.dart';
import 'core/purchases/purchase_gateway.dart';
import 'core/purchases/revenuecat_purchase_gateway.dart';
import 'core/purchases/unconfigured_purchase_gateway.dart';
import 'core/theme/app_theme.dart';
import 'data/db/app_database.dart';
import 'data/db/drift_wheel_repository.dart';
import 'state/entitlements/entitlement_providers.dart';
import 'state/notifications/notification_providers.dart';
import 'state/repository_providers.dart';
import 'widgets/entitlement_lifecycle_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phase 21: `zonedSchedule` needs the `timezone` database loaded once,
  // before anything ever schedules a notification.
  tz_data.initializeTimeZones();
  final database = AppDatabase();
  final repository = DriftWheelRepository(database);
  final notificationGateway = DarwinNotificationGateway();
  // Loaded once, before the first frame, so the router's initial route can
  // be chosen synchronously (Feature Invariant/S-072: the first-run
  // explainer auto-shows exactly once, on `!firstRunExplainerShown`) —
  // simpler and more robust than an async-aware `redirect` callback for a
  // decision made exactly once per process lifetime.
  final preferences = await repository.getPreferences();
  final router = buildAppRouter(
    initialLocation: preferences.firstRunExplainerShown ? '/positions' : '/first-run',
  );
  // D-27: the gateway is chosen from the build-time key and overridden on
  // **both** branches, so no build can reach a screen with the wrong gateway
  // or with no gateway at all.
  final PurchaseGateway purchaseGateway = kRevenueCatIosApiKey.isEmpty
      ? const UnconfiguredPurchaseGateway()
      : RevenueCatPurchaseGateway();

  runApp(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repository),
        notificationGatewayProvider.overrideWithValue(notificationGateway),
        purchaseGatewayProvider.overrideWithValue(purchaseGateway),
      ],
      child: WheelTriageApp(router: router),
    ),
  );
}

/// App shell: `ProviderScope` (overridden above with the real
/// `DriftWheelRepository`) + `MaterialApp.router` wired to [router] (the
/// full route graph in `lib/core/app_router.dart`, with its initial
/// location already resolved by `main()`).
///
/// It also hosts `EntitlementLifecycleScope` (D-29), which is what makes the
/// launch read and the resume read happen — the entitlement is refreshed by
/// the app's lifecycle, never by a screen.
class WheelTriageApp extends StatelessWidget {
  const WheelTriageApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return EntitlementLifecycleScope(
      child: MaterialApp.router(
        title: 'Wheel Triage',
        theme: lightTheme,
        darkTheme: darkTheme,
        // D-3: the dark set is the design's primary palette, so a device in dark
        // mode sees the reference and a device in light mode gets the light one.
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
