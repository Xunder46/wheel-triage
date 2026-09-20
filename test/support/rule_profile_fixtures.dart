import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';

/// A [NewRuleProfileVersionInput] at the §4.4 defaults with
/// [profitTargetPct] overridden — the shared "append a distinguishable v2"
/// fixture for Iteration 5's S-196/S-198 tests, which need a newer version
/// in existence without caring about any other value.
///
/// Lives in `test/support/` because several suites need the same 14-field
/// literal; a per-file copy would be the same fixture maintained N times.
NewRuleProfileVersionInput standardVersionInput({
  double profitTargetPct = StandardProfileDefaults.profitTargetPct,
}) => NewRuleProfileVersionInput(
      profitTargetPct: profitTargetPct,
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
