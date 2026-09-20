import 'package:wheel_triage/core/notifications/notification_scheduler.dart';

/// A recording, in-memory [NotificationGateway] test double -- the
/// notifications analogue of `InMemoryWheelRepository`, shared across every
/// Phase 21 test that needs to observe what was scheduled/cancelled without
/// touching a real platform channel.
class FakeNotificationGateway implements NotificationGateway {
  /// When `false`, [requestPermission] reports denial (S-174) and
  /// [scheduleAt] is never actually reached by `NotificationScheduler`
  /// (which checks permission first) -- but this fake still records
  /// [requestPermissionCallCount] regardless, so a test can assert
  /// permission was requested exactly once even when denied.
  bool permissionGranted = true;

  int requestPermissionCallCount = 0;

  /// Overrides [checkPermissionStatus]'s return value directly, independent
  /// of [requestPermissionCallCount] -- lets a test simulate "the OS
  /// already recorded a denial in an earlier session" without first having
  /// to call [requestPermission] itself.
  NotificationPermissionStatus? forcedStatus;

  /// id -> (title, body, when) for every currently-scheduled notification.
  /// A [cancel] call removes the entry; scheduling the same id again
  /// overwrites it -- matching how a real OS notification store behaves.
  final Map<int, ({String title, String body, DateTime when})> scheduled = {};

  /// Every id ever passed to [cancel], including ones that were never
  /// actually scheduled (recording this, rather than silently ignoring it,
  /// is what lets a test prove cancellation swept the whole candidate
  /// universe -- S-171).
  final List<int> cancelledIds = [];

  @override
  Future<bool> requestPermission() async {
    requestPermissionCallCount++;
    return permissionGranted;
  }

  @override
  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    if (forcedStatus != null) return forcedStatus!;
    if (requestPermissionCallCount == 0) return NotificationPermissionStatus.notDetermined;
    return permissionGranted ? NotificationPermissionStatus.granted : NotificationPermissionStatus.denied;
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    scheduled[id] = (title: title, body: body, when: when);
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    scheduled.remove(id);
  }
}
