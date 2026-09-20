import 'snapshot.dart';

/// Default values for the seeded `user_preferences` row (mirrors
/// `rule_profile_defaults.dart`'s pattern exactly), so
/// `InMemoryWheelRepository` never imports `app_database.dart` to reproduce
/// the same default values, and `AppDatabase.seedDefaultPreferences()` (the
/// `onCreate` seed step and the `1 -> 2` migration's insert) has exactly one
/// place to read them from.
///
/// Pure Dart, no Drift/Flutter import.
abstract final class UserPreferencesDefaults {
  /// The one, fixed storage-row id (Phase 8 step 3: "single fixed-id row").
  /// A `lib/data/` implementation detail only — never exposed through
  /// `WheelRepository`'s signatures or carried on `UserPreferencesData`.
  static const rowId = 'default';

  static const totalPerContractToggle = false;
  static const deltaConventionDefault = DeltaConvention.position;
  static const firstRunExplainerShown = false;
  static const ivResolutionNoticeDismissed = false;

  // --- Schema v3 (Phase 15) ----------------------------------------------

  static const exportReminderDismissed = false;
  static const DateTime? lastExportAt = null;
  static const notificationMilestones = [21, 7, 0];
}
