import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/wheel_repository.dart';
import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/rule_profile_version_data.dart';
import '../../domain/rules/rule_profile.dart';
import '../../domain/rules/rule_profile_validation.dart';
import '../repository_providers.dart';
import 'rule_profile_providers.dart';

/// What a save attempt did — the widget decides how to report each case,
/// the controller never shows anything itself.
enum RuleProfileSaveOutcome {
  /// A new immutable version was appended.
  saved,

  /// The draft's values equal the current version's: nothing to record
  /// (D-2 / S-197). Not an error.
  noChange,

  /// At least one field is unparseable or out of D-9 bounds; nothing was
  /// written (S-201).
  invalid,

  /// The write itself failed (repository error). The draft is preserved.
  failed,
}

/// The editor's whole surface: what is currently persisted ([current],
/// [history]), what the form holds ([draft]), and what is wrong with it
/// ([violations]).
class RuleProfileEditorState {
  final bool isLoading;

  /// A load or save failure, in display form. Never a validation message —
  /// those live in [violations], keyed by field.
  final String? error;

  /// The version new cycles open under (D-5), or `null` until loaded.
  final RuleProfile? current;

  /// Every version of the profile, newest first (D-11).
  final List<RuleProfileVersionData> history;

  /// The form's raw text, one entry per [RuleProfileField] — text rather
  /// than parsed values so an in-progress entry is never impossible.
  final Map<RuleProfileField, String> draft;

  /// Every reason the draft cannot be saved, in D-9 field order.
  final List<RuleProfileViolation> violations;

  /// True when the draft's values differ from [current] — the D-2 gate that
  /// keeps the save action inert until there is an edit to record.
  final bool isDirty;

  /// False until a save has been asked for, so errors appear when the user
  /// acts rather than while they are still typing (S-201).
  final bool hasAttemptedSave;

  final bool isSaving;

  const RuleProfileEditorState({
    this.isLoading = false,
    this.error,
    this.current,
    this.history = const [],
    this.draft = const {},
    this.violations = const [],
    this.isDirty = false,
    this.hasAttemptedSave = false,
    this.isSaving = false,
  });

  RuleProfileEditorState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    RuleProfile? current,
    List<RuleProfileVersionData>? history,
    Map<RuleProfileField, String>? draft,
    List<RuleProfileViolation>? violations,
    bool? isDirty,
    bool? hasAttemptedSave,
    bool? isSaving,
  }) => RuleProfileEditorState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    current: current ?? this.current,
    history: history ?? this.history,
    draft: draft ?? this.draft,
    violations: violations ?? this.violations,
    isDirty: isDirty ?? this.isDirty,
    hasAttemptedSave: hasAttemptedSave ?? this.hasAttemptedSave,
    isSaving: isSaving ?? this.isSaving,
  );

  /// The current version's effective date, or `null` when the built-in
  /// fallback constant is in use (no row to date it from).
  DateTime? get currentEffectiveAt => history.isEmpty ? null : history.first.effectiveAt;

  /// The single reason [field] is currently rejected, if any.
  RuleProfileViolation? violationFor(RuleProfileField field) {
    for (final violation in violations) {
      if (violation.field == field) return violation;
    }
    return null;
  }

  /// Whether asking to save could do anything: there is an edit to record
  /// and no save already in flight. Deliberately true with violations
  /// present — tapping save is how they get shown (S-201).
  bool get canSave => current != null && isDirty && !isSaving;
}

/// The single-profile threshold editor (D-1: `Standard` is the one editable
/// profile; there is no picker). Seeds a draft from the current version,
/// validates it through `lib/domain/rules/rule_profile_validation.dart`,
/// suppresses no-op saves (D-2), and appends a version through the
/// repository — never an update, because no such method exists (D-3).
class RuleProfileEditorController extends StateNotifier<RuleProfileEditorState> {
  RuleProfileEditorController(this._ref, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const RuleProfileEditorState()) {
    _ready = _load();
  }

  final Ref _ref;

  /// Read at save time, not at construction: `effectiveAt` records when the
  /// edit was made, and a Settings screen can sit open for a while.
  final DateTime Function() _now;

  late final Future<void> _ready;

  /// Settles once the first load has completed.
  Future<void> get ready => _ready;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // The versions provider is the canonical accessor for this list (the
      // history UI watches the same one), so a save's invalidation
      // refreshes both readers from a single fetch.
      final versions = await _ref.read(
        ruleProfileVersionsProvider(RuleProfileIds.standard).future,
      );
      final profile = await _ref.read(wheelRepositoryProvider).getRuleProfile(
        RuleProfileIds.standard,
      );
      // D-7: no seeded rows (a damaged database) degrades to the built-in
      // constant rather than throwing where the user can do nothing.
      final current = versions.isEmpty
          ? RuleProfile.standard
          : RuleProfile.fromVersion(versions.last, profileName: profile?.name ?? 'Standard');
      state = RuleProfileEditorState(
        current: current,
        history: versions.reversed.toList(),
        draft: {
          for (final field in RuleProfileField.values) field: _draftTextFor(current, field),
        },
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Could not load the profile.');
    }
  }

  void setField(RuleProfileField field, String text) {
    final current = state.current;
    if (current == null) return;
    final draft = {...state.draft, field: text};
    final parsed = _parseDraft(draft, current);
    state = state.copyWith(
      draft: draft,
      violations: _violationsOf(parsed),
      isDirty: parsed.proposed == null || !parsed.proposed!.hasSameThresholdsAs(current),
    );
  }

  /// Appends the draft as a new version, unless it is invalid or a no-op.
  Future<RuleProfileSaveOutcome> save() async {
    final current = state.current;
    if (current == null) return RuleProfileSaveOutcome.failed;

    final parsed = _parseDraft(state.draft, current);
    final violations = _violationsOf(parsed);
    if (violations.isEmpty && parsed.proposed!.hasSameThresholdsAs(current)) {
      // D-2: value equality is numeric equality, so re-typing "50" over a
      // stored 50.0 records nothing.
      state = state.copyWith(hasAttemptedSave: true, violations: violations, isDirty: false);
      return RuleProfileSaveOutcome.noChange;
    }
    if (violations.isNotEmpty) {
      state = state.copyWith(hasAttemptedSave: true, violations: violations);
      return RuleProfileSaveOutcome.invalid;
    }

    state = state.copyWith(isSaving: true, hasAttemptedSave: true, clearError: true);
    try {
      await _ref
          .read(wheelRepositoryProvider)
          .appendRuleProfileVersion(
            profileId: RuleProfileIds.standard,
            effectiveAt: _now(),
            values: _valuesOf(parsed.proposed!),
          );
    } catch (_) {
      state = state.copyWith(isSaving: false, error: 'Could not save the new version.');
      return RuleProfileSaveOutcome.failed;
    }
    // The pinned-resolution read sites are untouched by design (D-5); what
    // changes is the version a *new* cycle resolves, plus the history.
    _ref.invalidate(currentRuleProfileProvider);
    _ref.invalidate(ruleProfileVersionsProvider(RuleProfileIds.standard));
    await _load();
    return RuleProfileSaveOutcome.saved;
  }
}

/// The persistence DTOs a save writes, taken from the validated candidate.
NewRuleProfileVersionInput _valuesOf(RuleProfile p) => NewRuleProfileVersionInput(
  profitTargetPct: p.profitTargetPct,
  assignThreshold: p.assignThreshold,
  baseRollBand: p.baseRollBand,
  midIvRollBand: p.midIvRollBand,
  highIvRollBand: p.highIvRollBand,
  midIvCutoff: p.midIvCutoff,
  highIvCutoff: p.highIvCutoff,
  tailDteDays: p.tailDteDays,
  tailExtrinsicThreshold: p.tailExtrinsicThreshold,
  minIvRank: p.minIvRank,
  minAnnualisedYield: p.minAnnualisedYield,
  targetDteMin: p.targetDteMin,
  targetDteMax: p.targetDteMax,
  targetDelta: p.targetDelta,
);

/// Each draft field parsed, plus one violation per field that is not a
/// number yet. [proposed] carries [base]'s identity — `hasSameThresholdsAs`
/// compares values only, so the identity is never what makes a draft dirty.
({RuleProfile? proposed, List<RuleProfileViolation> failures}) _parseDraft(
  Map<RuleProfileField, String> draft,
  RuleProfile base,
) {
  final failures = <RuleProfileViolation>[];

  double? asDouble(RuleProfileField field, String label) {
    final parsed = double.tryParse((draft[field] ?? '').trim());
    if (parsed == null) {
      failures.add(RuleProfileViolation(field: field, message: 'Enter a number for $label.'));
    }
    return parsed;
  }

  int? asWhole(RuleProfileField field, String label) {
    final parsed = int.tryParse((draft[field] ?? '').trim());
    if (parsed == null) {
      failures.add(RuleProfileViolation(field: field, message: 'Enter a whole number for $label.'));
    }
    return parsed;
  }

  Decimal? asMoney(RuleProfileField field, String label) {
    final parsed = Decimal.tryParse((draft[field] ?? '').trim());
    if (parsed == null) {
      failures.add(RuleProfileViolation(field: field, message: 'Enter a dollar amount for $label.'));
    }
    return parsed;
  }

  final profitTargetPct = asDouble(RuleProfileField.profitTargetPct, 'the profit target');
  final assignThreshold = asDouble(RuleProfileField.assignThreshold, 'the assign threshold');
  final baseRollBand = asDouble(RuleProfileField.baseRollBand, 'the base roll band');
  final midIvRollBand = asDouble(RuleProfileField.midIvRollBand, 'the mid roll band');
  final highIvRollBand = asDouble(RuleProfileField.highIvRollBand, 'the high roll band');
  final midIvCutoff = asDouble(RuleProfileField.midIvCutoff, 'the mid IV cutoff');
  final highIvCutoff = asDouble(RuleProfileField.highIvCutoff, 'the high IV cutoff');
  final tailDteDays = asWhole(RuleProfileField.tailDteDays, 'the tail window');
  final tailExtrinsicThreshold = asMoney(
    RuleProfileField.tailExtrinsicThreshold,
    'the tail extrinsic threshold',
  );
  final minIvRank = asDouble(RuleProfileField.minIvRank, 'the minimum IV rank');
  final minAnnualisedYield = asDouble(
    RuleProfileField.minAnnualisedYield,
    'the minimum annualised yield',
  );
  final targetDteMin = asWhole(RuleProfileField.targetDteMin, 'the target DTE minimum');
  final targetDteMax = asWhole(RuleProfileField.targetDteMax, 'the target DTE maximum');
  final targetDelta = asDouble(RuleProfileField.targetDelta, 'the target delta');

  if ([
    profitTargetPct,
    assignThreshold,
    baseRollBand,
    midIvRollBand,
    highIvRollBand,
    midIvCutoff,
    highIvCutoff,
    tailDteDays,
    tailExtrinsicThreshold,
    minIvRank,
    minAnnualisedYield,
    targetDteMin,
    targetDteMax,
    targetDelta,
  ].contains(null)) {
    return (proposed: null, failures: failures);
  }

  return (
    proposed: RuleProfile(
      versionId: base.versionId,
      profileId: base.profileId,
      name: base.name,
      version: base.version,
      profitTargetPct: profitTargetPct!,
      assignThreshold: assignThreshold!,
      baseRollBand: baseRollBand!,
      midIvRollBand: midIvRollBand!,
      highIvRollBand: highIvRollBand!,
      midIvCutoff: midIvCutoff!,
      highIvCutoff: highIvCutoff!,
      tailDteDays: tailDteDays!,
      tailExtrinsicThreshold: tailExtrinsicThreshold!,
      minIvRank: minIvRank!,
      minAnnualisedYield: minAnnualisedYield!,
      targetDteMin: targetDteMin!,
      targetDteMax: targetDteMax!,
      targetDelta: targetDelta!,
    ),
    failures: failures,
  );
}

/// A field is never reported by both a parse failure and a bound check: an
/// unparseable draft yields no candidate, so the validator cannot run.
///
/// Consequence, accepted deliberately (Phase 28 review): a typo in *any*
/// field suppresses the other fields' bound messages until it is fixed, so a
/// typo plus an out-of-range value takes two save attempts. Substituting the
/// baseline value for an unparseable field would report both at once, at the
/// cost of running cross-field ordering rules against a value the user did
/// not type — worse, because it can attribute a violation to a field they
/// never touched.
List<RuleProfileViolation> _violationsOf(
  ({RuleProfile? proposed, List<RuleProfileViolation> failures}) parsed,
) {
  final violations = [
    ...parsed.failures,
    if (parsed.proposed != null) ...validateRuleProfile(parsed.proposed!),
  ];
  violations.sort((a, b) => a.field.index.compareTo(b.field.index));
  return violations;
}

/// How each threshold is written into the draft. Two decimals for the
/// dimensionless ratios (the register's S-199 names them as `0.30`), none
/// for the point-valued ones (`50`, `70`), and never a rounding that would
/// change the number — a stored 55.5 must not display as `56`.
String _draftTextFor(RuleProfile p, RuleProfileField field) => switch (field) {
  RuleProfileField.profitTargetPct => _fixed(p.profitTargetPct, 0),
  RuleProfileField.assignThreshold => _fixed(p.assignThreshold, 2),
  RuleProfileField.baseRollBand => _fixed(p.baseRollBand, 2),
  RuleProfileField.midIvRollBand => _fixed(p.midIvRollBand, 2),
  RuleProfileField.highIvRollBand => _fixed(p.highIvRollBand, 2),
  RuleProfileField.midIvCutoff => _fixed(p.midIvCutoff, 0),
  RuleProfileField.highIvCutoff => _fixed(p.highIvCutoff, 0),
  RuleProfileField.tailDteDays => '${p.tailDteDays}',
  RuleProfileField.tailExtrinsicThreshold => p.tailExtrinsicThreshold.toString(),
  RuleProfileField.minIvRank => _fixed(p.minIvRank, 0),
  RuleProfileField.minAnnualisedYield => _fixed(p.minAnnualisedYield, 0),
  RuleProfileField.targetDteMin => '${p.targetDteMin}',
  RuleProfileField.targetDteMax => '${p.targetDteMax}',
  RuleProfileField.targetDelta => _fixed(p.targetDelta, 2),
};

String _fixed(double value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  return double.parse(text) == value ? text : value.toString();
}

/// App-wide singleton: the draft survives leaving and returning to
/// Settings, and `autoDispose` would drop it whenever the section scrolls
/// out of the screen's lazy list. Import replaces the profile rows, so that
/// path invalidates this provider explicitly.
final ruleProfileEditorProvider =
    StateNotifierProvider<RuleProfileEditorController, RuleProfileEditorState>(
      (ref) => RuleProfileEditorController(ref),
    );
