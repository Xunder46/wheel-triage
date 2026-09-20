import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_scheduler.dart';

/// The single source of a [NotificationGateway] for the whole app.
///
/// Unlike `wheelRepositoryProvider`, this one has a real, safe default
/// ([NoOpNotificationGateway]) rather than throwing when nobody overrides
/// it -- notifications are the one feature in this app where a missing
/// wire-up must silently no-op rather than break anything (S-174's own
/// principle, applied to every caller, not just a denied OS permission).
/// This also means the many existing state-layer tests that predate Phase
/// 21 and never override this provider keep working unchanged.
///
/// * `lib/main.dart` overrides it with `DarwinNotificationGateway`.
/// * Any test that specifically exercises scheduling/cancelling overrides
///   it with a recording fake.
final notificationGatewayProvider = Provider<NotificationGateway>((ref) => NoOpNotificationGateway());

/// The one [NotificationScheduler] instance for the app's lifetime --
/// deliberately NOT `.autoDispose`, since its own "has permission been
/// requested this session yet" flag (Feature Invariant 32) must survive
/// across every screen's provider being disposed and rebuilt.
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  final gateway = ref.watch(notificationGatewayProvider);
  return NotificationScheduler(gateway);
});

/// The OS's current notification-permission decision, re-read (never
/// prompted) every time something watches this -- Settings' milestone
/// editor uses it to show an honest "reminders won't fire" note when
/// permission has been denied, rather than looking active when it can't be
/// (see the phase's Assumption Log on this judgment call). Watching this
/// provider never itself triggers a permission prompt (S-176).
final notificationPermissionStatusProvider = FutureProvider.autoDispose<NotificationPermissionStatus>((
  ref,
) {
  final scheduler = ref.watch(notificationSchedulerProvider);
  return scheduler.refreshPermissionStatus();
});
