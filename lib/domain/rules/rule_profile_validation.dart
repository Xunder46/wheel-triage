import 'package:decimal/decimal.dart';

import 'rule_profile.dart';

/// The 14 threshold fields of a rule-profile version, in the order
/// `docs/plans/rule-versioning-plan.md`'s D-9 bound table lists them —
/// which is also the declaration order [validateRuleProfile] reports
/// violations in, and the order the Settings editor renders its fields.
enum RuleProfileField {
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
}

/// One rejected value: machine-readable identity in [field] (the editor
/// keys its error display off this, never off parsing [message]) plus the
/// human-facing sentence to show beside it.
class RuleProfileViolation {
  final RuleProfileField field;
  final String message;

  const RuleProfileViolation({required this.field, required this.message});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleProfileViolation && other.field == field && other.message == message);

  @override
  int get hashCode => Object.hash(field, message);

  @override
  String toString() => '${field.name}: $message';
}

/// Checks all 14 of [candidate]'s threshold values against D-9's bounds and
/// returns **every** violation — never just the first — so the editor can
/// show them simultaneously (S-201). An empty result means valid.
///
/// Pure and total (zero Flutter imports, like everything in this
/// directory): no clamping, no defaults, no I/O; the caller decides what a
/// rejection means. This is a user-*entry* gate, not a file-format
/// contract — import validation (D-8) deliberately does not call it.
///
/// Bounds are inclusive on both ends unless noted (D-9), and every
/// predicate requires a finite value, so NaN/±∞ are rejected by their own
/// field's rule. Cross-field rules — `baseRollBand ≤ midIvRollBand ≤
/// highIvRollBand`, `midIvCutoff ≤ highIvCutoff` (equal is legal: D-12
/// keeps the strict/inclusive roll-band asymmetry meaningful at the
/// boundary), and `targetDteMin ≤ targetDteMax` — are each evaluated only
/// when both values involved are individually valid, so one bad number
/// never reads as two problems.
List<RuleProfileViolation> validateRuleProfile(RuleProfile candidate) {
  final violations = <RuleProfileViolation>[];

  void check(RuleProfileField field, bool isValid, String message) {
    if (!isValid) {
      violations.add(RuleProfileViolation(field: field, message: message));
    }
  }

  // --- Per-field bounds (D-9) --------------------------------------------

  check(
    RuleProfileField.profitTargetPct,
    _inOpenClosedRange(candidate.profitTargetPct, 0, 100),
    'Profit target must be greater than 0 and at most 100.',
  );
  check(
    RuleProfileField.assignThreshold,
    _inOpenClosedRange(candidate.assignThreshold, 0, 1),
    'Assign threshold must be greater than 0 and at most 1.',
  );
  check(
    RuleProfileField.baseRollBand,
    _inClosedRange(candidate.baseRollBand, 0, 1),
    'Base roll band must be between 0 and 1.',
  );
  check(
    RuleProfileField.midIvRollBand,
    _inClosedRange(candidate.midIvRollBand, 0, 1),
    'Mid roll band must be between 0 and 1.',
  );
  check(
    RuleProfileField.highIvRollBand,
    _inClosedRange(candidate.highIvRollBand, 0, 1),
    'High roll band must be between 0 and 1.',
  );
  check(
    RuleProfileField.midIvCutoff,
    _inClosedRange(candidate.midIvCutoff, 0, 500),
    'Mid IV cutoff must be between 0 and 500.',
  );
  check(
    RuleProfileField.highIvCutoff,
    _inClosedRange(candidate.highIvCutoff, 0, 500),
    'High IV cutoff must be between 0 and 500.',
  );
  check(
    RuleProfileField.tailDteDays,
    _inClosedRange(candidate.tailDteDays, 0, 365),
    'Tail window must be between 0 and 365 days.',
  );
  check(
    RuleProfileField.tailExtrinsicThreshold,
    candidate.tailExtrinsicThreshold >= Decimal.zero,
    'Tail extrinsic threshold cannot be negative.',
  );
  check(
    RuleProfileField.minIvRank,
    _inClosedRange(candidate.minIvRank, 0, 100),
    'Minimum IV rank must be between 0 and 100.',
  );
  check(
    RuleProfileField.minAnnualisedYield,
    _atLeast(candidate.minAnnualisedYield, 0),
    'Minimum annualised yield cannot be negative.',
  );
  check(
    RuleProfileField.targetDteMin,
    _inClosedRange(candidate.targetDteMin, 0, 3650),
    'Target DTE minimum must be between 0 and 3650 days.',
  );
  check(
    RuleProfileField.targetDteMax,
    _inClosedRange(candidate.targetDteMax, 0, 3650),
    'Target DTE maximum must be between 0 and 3650 days.',
  );
  check(
    RuleProfileField.targetDelta,
    _inOpenClosedRange(candidate.targetDelta, 0, 1),
    'Target delta must be greater than 0 and at most 1.',
  );

  // --- Cross-field ordering (D-9) ----------------------------------------

  if (_inClosedRange(candidate.baseRollBand, 0, 1) &&
      _inClosedRange(candidate.midIvRollBand, 0, 1) &&
      candidate.baseRollBand > candidate.midIvRollBand) {
    violations.add(
      const RuleProfileViolation(
        field: RuleProfileField.baseRollBand,
        message: 'The base roll band must not exceed the mid roll band.',
      ),
    );
  }
  if (_inClosedRange(candidate.midIvRollBand, 0, 1) &&
      _inClosedRange(candidate.highIvRollBand, 0, 1) &&
      candidate.midIvRollBand > candidate.highIvRollBand) {
    violations.add(
      const RuleProfileViolation(
        field: RuleProfileField.midIvRollBand,
        message: 'The mid roll band must not exceed the high roll band.',
      ),
    );
  }
  if (_inClosedRange(candidate.midIvCutoff, 0, 500) &&
      _inClosedRange(candidate.highIvCutoff, 0, 500) &&
      candidate.midIvCutoff > candidate.highIvCutoff) {
    violations.add(
      const RuleProfileViolation(
        field: RuleProfileField.midIvCutoff,
        message: 'The mid IV cutoff must not exceed the high IV cutoff.',
      ),
    );
  }
  if (_inClosedRange(candidate.targetDteMin, 0, 3650) &&
      _inClosedRange(candidate.targetDteMax, 0, 3650) &&
      candidate.targetDteMin > candidate.targetDteMax) {
    violations.add(
      const RuleProfileViolation(
        field: RuleProfileField.targetDteMin,
        message: 'The target DTE minimum must not exceed the maximum.',
      ),
    );
  }

  // Reported in field order, never check order. Safe because each field
  // appears at most once: a value failing its own bound is excluded from
  // every cross-field rule above, and each cross-field rule reports on a
  // distinct field.
  violations.sort((a, b) => a.field.index.compareTo(b.field.index));
  return violations;
}

bool _inClosedRange(num value, num min, num max) =>
    value.isFinite && value >= min && value <= max;

bool _inOpenClosedRange(num value, num min, num max) =>
    value.isFinite && value > min && value <= max;

bool _atLeast(num value, num min) => value.isFinite && value >= min;
