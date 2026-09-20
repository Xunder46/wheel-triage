import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'core/app_router.dart';
import 'core/notifications/notification_scheduler.dart';
import 'data/db/app_database.dart';
import 'data/db/drift_wheel_repository.dart';
import 'state/notifications/notification_providers.dart';
import 'state/repository_providers.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repository),
        notificationGatewayProvider.overrideWithValue(notificationGateway),
      ],
      child: WheelTriageApp(router: router),
    ),
  );
}

/// App shell: `ProviderScope` (overridden above with the real
/// `DriftWheelRepository`) + `MaterialApp.router` wired to [router] (the
/// full route graph in `lib/core/app_router.dart`, with its initial
/// location already resolved by `main()`).
class WheelTriageApp extends StatelessWidget {
  const WheelTriageApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wheel Triage',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      routerConfig: router,
    );
  }
}
