import 'package:decimal/decimal.dart';

import '../models/rule_profile_defaults.dart';
import '../models/rule_profile_ids.dart';
import '../models/rule_profile_version_data.dart';
import 'roll_band.dart' as roll_band;

/// The pure value type `classify()` and the rest of `lib/domain/rules/`
/// actually use — as opposed to `lib/domain/models/rule_profile_version_data.dart`,
/// the plain persistence DTO owned by @data-architect. [RuleProfile.fromVersion]
/// is the *only* place the two are reconciled (Feature Invariant 11, as
/// reshaped by Iteration 5's D-10); nothing else in this codebase
/// re-derives a `RuleProfile` from persisted values independently.
///
/// Four identity fields (Iteration 5, D-10): [versionId] names the
/// threshold *version* the values came from (`<profileId>-v<n>`),
/// [profileId] the owning profile row, [name] that row's displayed name
/// (a version row deliberately carries only the id), and [version] the
/// 1-based edit count. There is deliberately no bare `id` field — every
/// consumer has to say which id it means.
///
/// Deliberately a plain immutable class, not `@freezed` — this type is
/// never persisted or JSON-serialized (the version DTO is), so the
/// codegen machinery freezed pulls in buys nothing here. See
/// `docs/plans/wheel-triage-plan.md`'s Phase 3 Assumption Log for the full
/// reasoning.
class RuleProfile {
  final String versionId;
  final String profileId;
  final String name;
  final int version;
  final double profitTargetPct;
  final double assignThreshold;
  final double baseRollBand;
  final double midIvRollBand;
  final double highIvRollBand;
  final double midIvCutoff;
  final double highIvCutoff;
  final int tailDteDays;
  final Decimal tailExtrinsicThreshold;
  final double minIvRank;
  final double minAnnualisedYield;
  final int targetDteMin;
  final int targetDteMax;
  final double targetDelta;

  const RuleProfile({
    required this.versionId,
    required this.profileId,
    required this.name,
    required this.version,
    required this.profitTargetPct,
    required this.assignThreshold,
    required this.baseRollBand,
    required this.midIvRollBand,
    required this.highIvRollBand,
    required this.midIvCutoff,
    required this.highIvCutoff,
    required this.tailDteDays,
    required this.tailExtrinsicThreshold,
    required this.minIvRank,
    required this.minAnnualisedYield,
    required this.targetDteMin,
    required this.targetDteMax,
    required this.targetDelta,
  });

  /// The single bridge from a persisted threshold version to this pure
  /// value type (Feature Invariant 11). Takes the owning profile's name as
  /// a parameter because a version row deliberately carries only its
  /// `profileId`.
  factory RuleProfile.fromVersion(RuleProfileVersionData v, {required String profileName}) =>
      RuleProfile(
        versionId: v.id,
        profileId: v.profileId,
        name: profileName,
        version: v.version,
        profitTargetPct: v.profitTargetPct,
        assignThreshold: v.assignThreshold,
        baseRollBand: v.baseRollBand,
        midIvRollBand: v.midIvRollBand,
        highIvRollBand: v.highIvRollBand,
        midIvCutoff: v.midIvCutoff,
        highIvCutoff: v.highIvCutoff,
        tailDteDays: v.tailDteDays,
        tailExtrinsicThreshold: v.tailExtrinsicThreshold,
        minIvRank: v.minIvRank,
        minAnnualisedYield: v.minAnnualisedYield,
        targetDteMin: v.targetDteMin,
        targetDteMax: v.targetDteMax,
        targetDelta: v.targetDelta,
      );

  /// Delegates to `roll_band.dart`'s standalone `rollBandFor` with this
  /// profile's own band/cutoff fields — the one place that comparison chain
  /// is expressed for a given profile.
  double rollBandFor(double? iv) => roll_band.rollBandFor(
        iv: iv,
        baseBand: baseRollBand,
        midBand: midIvRollBand,
        highBand: highIvRollBand,
        midCutoff: midIvCutoff,
        highCutoff: highIvCutoff,
      );

  /// True when [other] carries the same 14 threshold values as this profile
  /// — the D-2 no-op rule ("a save whose values equal the current version
  /// creates no version"). The identity fields are deliberately excluded:
  /// the editor's draft carries the current version's identity alongside
  /// whatever numbers the form holds, and only the numbers decide whether
  /// there is an edit to record. Comparison is numeric equality (`50` and
  /// `50.0` are the same double; `Decimal.parse('0.05')` equals
  /// `Decimal.parse('0.0500')`), never an epsilon.
  bool hasSameThresholdsAs(RuleProfile other) {
    final mine = _thresholdValues;
    final theirs = other._thresholdValues;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  /// [hasSameThresholdsAs]'s comparison list — one entry per threshold
  /// field, so a future 15th threshold is added here once rather than to a
  /// chain of `&&` expressions.
  List<Object> get _thresholdValues => [
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
      ];

  /// The built-in v1 of a seeded profile, assembled directly from
  /// `StandardProfileDefaults` (D-13) — no DTO round trip, since this type
  /// is never persisted. [versionId] is the version id
  /// (`<profileId>-v1`), so the constant and the seeded v1 row describe the
  /// same thing and are interchangeable as D-7 fallbacks.
  static RuleProfile _builtInV1({required String profileId, required String name}) => RuleProfile(
        versionId: RuleProfileVersionIds.forVersion(profileId, 1),
        profileId: profileId,
        name: name,
        version: 1,
        profitTargetPct: StandardProfileDefaults.profitTargetPct,
        assignThreshold: StandardProfileDefaults.assignThreshold,
        baseRollBand: StandardProfileDefaults.baseRollBand,
        midIvRollBand: StandardProfileDefaults.midIvRollBand,
        highIvRollBand: StandardProfileDefaults.highIvRollBand,
        midIvCutoff: StandardProfileDefaults.midIvCutoff,
        highIvCutoff: StandardProfileDefaults.highIvCutoff,
        tailDteDays: StandardProfileDefaults.tailDteDays,
        tailExtrinsicThreshold: StandardProfileDefaults.tailExtrinsicThreshold,
        minIvRank: StandardProfileDefaults.minIvRank,
        minAnnualisedYield: StandardProfileDefaults.minAnnualisedYield,
        targetDteMin: StandardProfileDefaults.targetDteMin,
        targetDteMax: StandardProfileDefaults.targetDteMax,
        targetDelta: StandardProfileDefaults.targetDelta,
      );

  static final RuleProfile standard = _builtInV1(
    profileId: RuleProfileIds.standard,
    name: 'Standard',
  );

  static final RuleProfile conservative = _builtInV1(
    profileId: RuleProfileIds.conservative,
    name: 'Conservative',
  );

  static final RuleProfile aggressive = _builtInV1(
    profileId: RuleProfileIds.aggressive,
    name: 'Aggressive',
  );
}
