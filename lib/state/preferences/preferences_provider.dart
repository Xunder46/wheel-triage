import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/wheel_repository.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/rules/capital_committed.dart';
import '../repository_providers.dart';

/// The single shared source of [UserPreferencesData] for the whole app
/// (Feature Invariants 20, 21, 24). Every reader of "total per contract",
/// the delta-convention default, the first-run-explainer flag, or the
/// IV-resolution-notice flag watches this **one** provider — never a
/// per-screen copy — so those preferences are genuinely one value each, not
/// four independently drifting ones.
class PreferencesController extends StateNotifier<AsyncValue<UserPreferencesData>> {
  PreferencesController(this._repo) : super(const AsyncValue.loading()) {
    ready = _load();
  }

  final WheelRepository _repo;

  /// Completes once the initial preferences fetch has settled — same
  /// pattern as `RollPlannerController.ready`/`AssignmentFlowController.ready`
  /// (see `docs/plans/wheel-triage-plan.md`'s Phases 4-6 Assumption Log for
  /// why a bare `container.read()` isn't reliable enough on its own once a
  /// constructor's fire-and-forget load involves more than one `await`).
  late final Future<void> ready;

  Future<void> _load() async {
    try {
      final prefs = await _repo.getPreferences();
      state = AsyncValue.data(prefs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Applies [updater] to the current preferences and persists the result.
  /// Awaits [ready] first — a caller that reaches for this notifier and
  /// calls `update` immediately (nothing upstream necessarily `watch`ed
  /// this provider long enough for its initial load to have settled)
  /// must never have the write silently dropped just because the initial
  /// fetch was still in flight at the moment of the call.
  Future<void> update(UserPreferencesData Function(UserPreferencesData current) updater) async {
    await ready;
    final current = state.valueOrNull;
    if (current == null) return; // only reachable if the initial load itself failed
    final next = updater(current);
    state = AsyncValue.data(next); // optimistic -- every reader updates immediately
    try {
      final saved = await _repo.updatePreferences(next);
      state = AsyncValue.data(saved);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// The 30-day export reminder's own dismiss action (Feature Invariant 34,
  /// S-160): flips the lifetime flag permanently -- never re-armed, even
  /// after another 30-plus days elapse with no further export.
  Future<void> dismissExportReminder() => update((p) => p.copyWith(exportReminderDismissed: true));

  /// D-6's wheel capital. `null` is a real state -- "not set" -- and clears
  /// the field; the concentration readout is simply absent until a value
  /// exists, which is why this is not a write of zero.
  ///
  /// A value outside [wheelCapitalInRange] is **ignored rather than
  /// clamped**: the figure feeds a percentage the user reads as a fact about
  /// their own book, and a silently rewritten one would be a different fact.
  /// The refusal message itself belongs to the field that refused the entry
  /// (S-248), so a caller that validates first sees no difference.
  Future<void> setWheelCapital(Decimal? value) {
    if (!wheelCapitalInRange(value)) return Future.value();
    return update((p) => p.copyWith(wheelCapital: value));
  }

  /// D-6's concentration limit, in `(0, 100]`. Refused outside the range for
  /// the same reason as [setWheelCapital].
  Future<void> setConcentrationLimit(double limitPct) {
    if (!concentrationLimitInRange(limitPct)) return Future.value();
    return update((p) => p.copyWith(concentrationLimitPct: limitPct));
  }
}

final preferencesControllerProvider =
    StateNotifierProvider<PreferencesController, AsyncValue<UserPreferencesData>>((ref) {
      final repo = ref.watch(wheelRepositoryProvider);
      return PreferencesController(repo);
    });
