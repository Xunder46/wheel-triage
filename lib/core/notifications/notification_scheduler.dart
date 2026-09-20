import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/leg.dart';

/// Expiration notifications (`docs/brief-ledger.md` §6). Every symbol this
/// file touches from `flutter_local_notifications` is either cross-platform
/// Dart (`FlutterLocalNotificationsPlugin`, `NotificationDetails`,
/// `zonedSchedule`) or the Darwin/iOS-specific implementation
/// (`DarwinInitializationSettings`, `IOSFlutterLocalNotificationsPlugin`) --
/// no `android/` file is ever touched, no Android manifest entry is added,
/// and no Android behavior is implemented or claimed (Feature Invariant
/// 35). `androidScheduleMode` below is a required parameter of the
/// package's own shared `zonedSchedule` signature, not Android-specific
/// code this app introduces -- it is never read on iOS.

/// The DTE values a leg's notifications can ever be scheduled under. Fixed
/// and small on purpose: [NotificationScheduler.cancelForLeg] cancels by
/// recomputing this exact candidate set's ids and calling `cancel` on each
/// (a cancel on an id nothing was ever scheduled under is a harmless
/// no-op) -- "deterministic ids ... so cancellation is possible without a
/// lookup table" (Phase 21 step 1) only works if both scheduling and
/// cancelling agree on one bounded universe of possible milestones. The
/// Settings milestone editor (S-175) only ever lets the user choose a
/// subset of this same list, so a leg's own scheduled subset is always
/// contained in it.
const List<int> kSupportedNotificationMilestones = [21, 14, 7, 3, 1, 0];

/// Where the milestone marking "the morning of expiration" lives in
/// [kSupportedNotificationMilestones] -- DTE 0, not a separate concept.
const int kExpirationMorningMilestone = 0;

enum NotificationPermissionStatus {
  /// Never asked yet this install (or the OS has never answered) -- **not**
  /// the same as [denied]. Settings must not imply a reminder is broken
  /// when nothing has ever asked for one yet (see the phase's Assumption
  /// Log on the "false promise" judgment call).
  notDetermined,
  granted,
  denied,
}

/// Deterministic notification id from [legId] + [milestoneDte] alone --
/// same inputs always produce the same id (S-170), with no per-leg lookup
/// table anywhere. A simple FNV-1a-style hash over the two inputs together,
/// masked to a non-negative 31-bit range (notification ids must be a plain
/// `int`, and negative/overflowing values are rejected or misbehave on some
/// platforms) -- deliberately NOT `Object.hashCode` (Dart does not
/// guarantee `String.hashCode` is stable across SDK versions, and this id
/// must keep meaning the same thing for as long as a scheduled notification
/// might be sitting in the OS's queue).
int notificationIdFor({required String legId, required int milestoneDte}) {
  final input = '$legId:$milestoneDte';
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// The wall-clock moment a given milestone fires: the morning ([hour],
/// default 8am) of the calendar date `milestoneDte` days before
/// [expiration]. Pure and deterministic -- no `DateTime.now()` here.
DateTime scheduledDateTimeFor({required DateTime expiration, required int milestoneDte, int hour = 8}) {
  final expirationDate = DateTime(expiration.year, expiration.month, expiration.day);
  return expirationDate.subtract(Duration(days: milestoneDte)).add(Duration(hours: hour));
}

/// Notification copy (`docs/brief-ledger.md` §6, S-173): describes a date
/// arriving, never a market condition, never an instruction. No sentence
/// here pairs an action verb with the named security or the user's own
/// position -- "worth a look" is an observation about the calendar, not a
/// directive about the position.
String notificationTitleFor({required String ticker, required OptionType optionType, required Decimal strike}) {
  final side = optionType == OptionType.call ? 'call' : 'put';
  return '$ticker \$${_strikeText(strike)} $side';
}

String notificationBodyFor({required int milestoneDte}) {
  if (milestoneDte <= kExpirationMorningMilestone) {
    return 'Expires today.';
  }
  return 'At $milestoneDte DTE — worth a look.';
}

String _strikeText(Decimal strike) {
  final fixed = strike.toStringAsFixed(2);
  return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
}

/// The injectable seam between [NotificationScheduler] (pure orchestration:
/// which ids, which dates, when to skip) and the real
/// `flutter_local_notifications` plugin -- matching this project's
/// established pattern of depending on an interface, never a concrete
/// implementation (`docs/conventions.md` §6), so a test can substitute a
/// recording fake the same way every other test substitutes
/// `InMemoryWheelRepository` for `DriftWheelRepository`.
abstract class NotificationGateway {
  /// Prompts for permission if the OS hasn't already recorded a decision.
  /// Never call this outside of the deliberately-lazy trigger point
  /// (Feature Invariant 32) -- [NotificationScheduler] is what enforces
  /// "only ever once, only at the first schedule call."
  Future<bool> requestPermission();

  /// Reads the OS's current permission decision WITHOUT prompting -- safe
  /// to call at any time (e.g. every time Settings renders).
  Future<NotificationPermissionStatus> checkPermissionStatus();

  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  });

  Future<void> cancel(int id);
}

/// The real, iOS-only implementation, wrapping
/// `FlutterLocalNotificationsPlugin`/`IOSFlutterLocalNotificationsPlugin`.
class DarwinNotificationGateway implements NotificationGateway {
  DarwinNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true; // set first -- a failed init must never retry-loop
    try {
      // requestAlertPermission/Sound/Badge are all false here on purpose:
      // permission is requested lazily via requestPermission(), never at
      // plugin-initialize time (Feature Invariant 32).
      const settings = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
    } catch (e) {
      debugPrint('NotificationGateway: initialize failed, degrading gracefully: $e');
    }
  }

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    try {
      final granted = await _ios?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    } catch (e) {
      debugPrint('NotificationGateway: requestPermission failed, degrading gracefully: $e');
      return false;
    }
  }

  @override
  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    await _ensureInitialized();
    try {
      final options = await _ios?.checkPermissions();
      if (options == null) return NotificationPermissionStatus.notDetermined;
      return options.isEnabled ? NotificationPermissionStatus.granted : NotificationPermissionStatus.denied;
    } catch (e) {
      debugPrint('NotificationGateway: checkPermissionStatus failed, degrading gracefully: $e');
      return NotificationPermissionStatus.notDetermined;
    }
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await _ensureInitialized();
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('NotificationGateway: scheduleAt($id) failed, degrading gracefully: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    await _ensureInitialized();
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('NotificationGateway: cancel($id) failed, degrading gracefully: $e');
    }
  }
}

/// A safe, entirely inert [NotificationGateway] -- schedules/cancels
/// nothing, always reports permission as not granted/not determined. This
/// is [NotificationScheduler]'s default so that every existing call site
/// that creates/closes/rolls a leg keeps working exactly as before for any
/// caller that hasn't deliberately wired up a real gateway (S-174's own
/// principle -- a missing/misconfigured notification layer must never be
/// the thing that breaks leg creation, closing, or rolling -- applies just
/// as much to "nobody wired this up yet" as it does to "the OS said no").
class NoOpNotificationGateway implements NotificationGateway {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<NotificationPermissionStatus> checkPermissionStatus() async =>
      NotificationPermissionStatus.notDetermined;

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

/// The state layer's one entry point for expiration notifications: derives
/// ids/copy/dates, decides what to skip, and requests permission lazily
/// exactly once per app run (Feature Invariant 32) -- every method here is
/// safe to call unconditionally from every leg-creation/close/roll site
/// (S-174: a denied or revoked permission, or any gateway failure, degrades
/// to a silent no-op and never throws into the caller's own write).
class NotificationScheduler {
  NotificationScheduler(this._gateway);

  final NotificationGateway _gateway;
  bool _permissionRequestedThisSession = false;
  bool _lastPermissionGranted = false;

  Future<bool> _ensurePermission() async {
    if (_permissionRequestedThisSession) return _lastPermissionGranted;
    _permissionRequestedThisSession = true;
    try {
      _lastPermissionGranted = await _gateway.requestPermission();
    } catch (e) {
      debugPrint('NotificationScheduler: requestPermission failed, degrading gracefully: $e');
      _lastPermissionGranted = false;
    }
    return _lastPermissionGranted;
  }

  /// Re-reads the OS's current permission decision without prompting --
  /// for Settings to honestly reflect a denied/revoked permission next to
  /// the milestone editor (see the phase's Assumption Log) rather than
  /// implying a reminder is scheduled when none will fire. Never counts as
  /// the lazy "first Track this position" trigger (S-176).
  Future<NotificationPermissionStatus> refreshPermissionStatus() async {
    try {
      return await _gateway.checkPermissionStatus();
    } catch (e) {
      debugPrint('NotificationScheduler: checkPermissionStatus failed, degrading gracefully: $e');
      return NotificationPermissionStatus.notDetermined;
    }
  }

  /// Schedules one notification per milestone in [milestones] for [legId]
  /// (S-170), skipping any milestone whose computed time has already
  /// passed relative to [now] (never scheduling into the past). Requests
  /// permission first if this session hasn't yet (Feature Invariant 32);
  /// a denied/failed permission request no-ops the whole call (S-174) --
  /// the caller's own leg-creation write has already succeeded by the time
  /// this runs and must never be affected by a notification failure.
  Future<void> scheduleForLeg({
    required String legId,
    required String ticker,
    required OptionType optionType,
    required Decimal strike,
    required DateTime expiration,
    required List<int> milestones,
    DateTime? now,
  }) async {
    final granted = await _ensurePermission();
    if (!granted) return;
    final effectiveNow = now ?? DateTime.now();
    final title = notificationTitleFor(ticker: ticker, optionType: optionType, strike: strike);
    for (final milestone in milestones) {
      final when = scheduledDateTimeFor(expiration: expiration, milestoneDte: milestone);
      if (!when.isAfter(effectiveNow)) continue;
      await _gateway.scheduleAt(
        id: notificationIdFor(legId: legId, milestoneDte: milestone),
        title: title,
        body: notificationBodyFor(milestoneDte: milestone),
        when: when,
      );
    }
  }

  /// Cancels every notification [legId] could possibly have scheduled
  /// (S-171) -- iterates [kSupportedNotificationMilestones] and cancels
  /// each derived id, never requiring a record of which subset was
  /// actually used at schedule time. Safe to call on a leg that was never
  /// scheduled at all (e.g. permission was denied when it was created) --
  /// every cancel is a harmless no-op in that case.
  Future<void> cancelForLeg(String legId) async {
    for (final milestone in kSupportedNotificationMilestones) {
      await _gateway.cancel(notificationIdFor(legId: legId, milestoneDte: milestone));
    }
  }
}
