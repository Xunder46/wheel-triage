import 'package:freezed_annotation/freezed_annotation.dart';

import 'snapshot.dart';

part 'user_preferences.freezed.dart';
part 'user_preferences.g.dart';

/// Global, singleton application preferences (Iteration 3 — schema v2,
/// brief-followup A2/§C3/Q9). Exactly one row is ever persisted, and it is
/// never addressed by id through `WheelRepository`'s signatures
/// (`getPreferences()` / `updatePreferences(prefs)` take/return no id) — the
/// fixed storage-row id lives only in `lib/data/` (see
/// `UserPreferencesDefaults.rowId`), matching docs/conventions.md §6's rule
/// that storage mechanics never leak into the interface.
@freezed
abstract class UserPreferencesData with _$UserPreferencesData {
  const factory UserPreferencesData({
    /// "Total per contract" toggle (Feature Invariant 21): one global
    /// preference applied uniformly at all four no-arbitrage-bound entry
    /// points (screener credit, snapshot option mark, roll planner's
    /// `newCredit`/`buybackDebit`, assignment covered-call credit) —
    /// never a per-field or per-screen setting.
    @Default(false) bool totalPerContractToggle,

    /// Pre-fills the delta-convention control on the *next* snapshot-entry
    /// form only (Feature Invariant 5) — never rewrites a `Snapshot`
    /// already written, since `deltaConvention` is stored per snapshot,
    /// immutable after write.
    @Default(DeltaConvention.position) DeltaConvention deltaConventionDefault,

    /// First-run explainer (brief-followup §C3) shows once, automatically,
    /// then this flips permanently — re-opening it from Settings never
    /// re-arms the automatic trigger.
    @Default(false) bool firstRunExplainerShown,

    /// One-time IV-resolution note (Feature Invariant 24, Q9): a single
    /// global, app-wide, not per-leg, dismissable banner flag.
    @Default(false) bool ivResolutionNoticeDismissed,

    /// The 30-day export reminder (Feature Invariant 34): a single
    /// lifetime flag, matching `firstRunExplainerShown`'s pattern — shown
    /// once, ever, never a rolling per-30-days re-arm.
    @Default(false) bool exportReminderDismissed,

    /// When the export was last run, or `null` if never. Read by the
    /// Phase 20 reminder to decide whether 30+ days have elapsed since the
    /// last export; writing it is that phase's job, not the repository's.
    DateTime? lastExportAt,

    /// DTE milestones at which an expiration notification fires (Phase 21).
    /// A Settings change here only pre-fills the *next* leg's schedule
    /// (Feature Invariant 31) — it never reschedules an already-open leg's
    /// already-scheduled notifications.
    @Default([21, 7, 0]) List<int> notificationMilestones,
  }) = _UserPreferencesData;

  factory UserPreferencesData.fromJson(Map<String, Object?> json) =>
      _$UserPreferencesDataFromJson(json);
}
