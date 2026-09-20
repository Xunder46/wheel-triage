// S-195: the D-9 threshold-bound table, enforced exactly, with every
// violation reported — plus S-197's core no-op comparison ("is there an
// edit to record?"), which shares this module's concern. The
// controller-level half of S-197 (no repository append fired) lands with
// the editor in Iteration 5's Phase 26.

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';
import 'package:wheel_triage/domain/rules/rule_profile_validation.dart';

/// A candidate profile at the §4.4 defaults, with any field overridable so
/// each table row varies exactly one value.
RuleProfile _profile({
  String? versionId,
  String? profileId,
  String? name,
  int version = 1,
  double profitTargetPct = StandardProfileDefaults.profitTargetPct,
  double assignThreshold = StandardProfileDefaults.assignThreshold,
  double baseRollBand = StandardProfileDefaults.baseRollBand,
  double midIvRollBand = StandardProfileDefaults.midIvRollBand,
  double highIvRollBand = StandardProfileDefaults.highIvRollBand,
  double midIvCutoff = StandardProfileDefaults.midIvCutoff,
  double highIvCutoff = StandardProfileDefaults.highIvCutoff,
  int tailDteDays = StandardProfileDefaults.tailDteDays,
  Decimal? tailExtrinsicThreshold,
  double minIvRank = StandardProfileDefaults.minIvRank,
  double minAnnualisedYield = StandardProfileDefaults.minAnnualisedYield,
  int targetDteMin = StandardProfileDefaults.targetDteMin,
  int targetDteMax = StandardProfileDefaults.targetDteMax,
  double targetDelta = StandardProfileDefaults.targetDelta,
}) => RuleProfile(
      versionId: versionId ?? RuleProfileVersionIds.forVersion(profileId ?? RuleProfileIds.standard, version),
      profileId: profileId ?? RuleProfileIds.standard,
      name: name ?? 'Standard',
      version: version,
      profitTargetPct: profitTargetPct,
      assignThreshold: assignThreshold,
      baseRollBand: baseRollBand,
      midIvRollBand: midIvRollBand,
      highIvRollBand: highIvRollBand,
      midIvCutoff: midIvCutoff,
      highIvCutoff: highIvCutoff,
      tailDteDays: tailDteDays,
      tailExtrinsicThreshold: tailExtrinsicThreshold ?? StandardProfileDefaults.tailExtrinsicThreshold,
      minIvRank: minIvRank,
      minAnnualisedYield: minAnnualisedYield,
      targetDteMin: targetDteMin,
      targetDteMax: targetDteMax,
      targetDelta: targetDelta,
    );

void main() {
  group('S-195: validateRuleProfile — D-9 bound table', () {
    test('the §4.4 defaults are valid', () {
      expect(validateRuleProfile(RuleProfile.standard), isEmpty);
      expect(validateRuleProfile(_profile()), isEmpty);
    });

    // One row per double-valued field: the field, a builder varying only
    // it, and its boundary values with whether each is inside the bound.
    final doubleFieldRows =
        <(RuleProfileField, RuleProfile Function(double), List<(double, bool)>)>[
      (
        RuleProfileField.profitTargetPct,
        (v) => _profile(profitTargetPct: v),
        [(0, false), (0.01, true), (100, true), (100.01, false)],
      ),
      (
        RuleProfileField.assignThreshold,
        (v) => _profile(assignThreshold: v),
        [(0, false), (0.01, true), (1, true), (1.01, false)],
      ),
      (
        RuleProfileField.baseRollBand,
        (v) => _profile(baseRollBand: v),
        // Upper boundary rows stay at/below the default mid band, so only
        // the field's own bound is under test.
        [(-0.01, false), (0, true), (0.35, true), (1.01, false)],
      ),
      (
        RuleProfileField.midIvRollBand,
        (v) => _profile(midIvRollBand: v),
        [(-0.01, false), (0.30, true), (0.40, true), (1.01, false)],
      ),
      (
        RuleProfileField.highIvRollBand,
        (v) => _profile(highIvRollBand: v),
        [(-0.01, false), (0.35, true), (1, true), (1.01, false)],
      ),
      (
        RuleProfileField.midIvCutoff,
        (v) => _profile(midIvCutoff: v),
        [(-0.01, false), (0, true), (70, true), (500.01, false)],
      ),
      (
        RuleProfileField.highIvCutoff,
        (v) => _profile(highIvCutoff: v),
        [(-0.01, false), (40, true), (500, true), (500.01, false)],
      ),
      (
        RuleProfileField.minIvRank,
        (v) => _profile(minIvRank: v),
        [(-0.01, false), (0, true), (100, true), (100.01, false)],
      ),
      (
        RuleProfileField.minAnnualisedYield,
        (v) => _profile(minAnnualisedYield: v),
        // No upper bound (D-9): only the floor is checked.
        [(-0.01, false), (0, true), (1000000, true)],
      ),
      (
        RuleProfileField.targetDelta,
        (v) => _profile(targetDelta: v),
        [(0, false), (0.01, true), (1, true), (1.01, false)],
      ),
    ];

    for (final (field, build, rows) in doubleFieldRows) {
      test('${field.name}: boundary values', () {
        for (final (value, isValid) in rows) {
          final violations = validateRuleProfile(build(value));
          if (isValid) {
            expect(violations, isEmpty, reason: '${field.name} = $value');
          } else {
            expect(violations, hasLength(1), reason: '${field.name} = $value');
            expect(violations.single.field, field, reason: '${field.name} = $value');
            expect(violations.single.message, isNotEmpty);
          }
        }
      });
    }

    test('NaN and ±infinity are rejected for every double-valued field', () {
      const badValues = [double.nan, double.infinity, double.negativeInfinity];
      for (final (field, build, _) in doubleFieldRows) {
        for (final value in badValues) {
          final violations = validateRuleProfile(build(value));
          expect(violations, hasLength(1), reason: '${field.name} = $value');
          expect(violations.single.field, field, reason: '${field.name} = $value');
        }
      }
    });

    test('tailDteDays: 0 and 365 accepted, -1 and 366 rejected', () {
      for (final (value, isValid) in [(-1, false), (0, true), (365, true), (366, false)]) {
        final violations = validateRuleProfile(_profile(tailDteDays: value));
        if (isValid) {
          expect(violations, isEmpty, reason: 'tailDteDays = $value');
        } else {
          expect(violations.single.field, RuleProfileField.tailDteDays, reason: 'tailDteDays = $value');
        }
      }
    });

    test('tailExtrinsicThreshold: Decimal ≥ 0 — negative rejected, zero and default accepted', () {
      for (final (value, isValid) in [
        (Decimal.parse('-0.01'), false),
        (Decimal.zero, true),
        (StandardProfileDefaults.tailExtrinsicThreshold, true),
      ]) {
        final violations = validateRuleProfile(_profile(tailExtrinsicThreshold: value));
        if (isValid) {
          expect(violations, isEmpty, reason: 'tailExtrinsicThreshold = $value');
        } else {
          expect(
            violations.single.field,
            RuleProfileField.tailExtrinsicThreshold,
            reason: 'tailExtrinsicThreshold = $value',
          );
        }
      }
    });

    test('bands: base > mid is one violation on baseRollBand', () {
      final violations = validateRuleProfile(_profile(baseRollBand: 0.9, midIvRollBand: 0.3));
      expect(violations, hasLength(1));
      expect(violations.single.field, RuleProfileField.baseRollBand);
    });

    test('bands: mid > high is one violation on midIvRollBand', () {
      final violations = validateRuleProfile(_profile(midIvRollBand: 0.45, highIvRollBand: 0.40));
      expect(violations, hasLength(1));
      expect(violations.single.field, RuleProfileField.midIvRollBand);
    });

    test('bands: base == mid and mid == high are both legal', () {
      expect(
        validateRuleProfile(_profile(baseRollBand: 0.3, midIvRollBand: 0.3, highIvRollBand: 0.3)),
        isEmpty,
      );
    });

    test('cutoffs: mid > high is one violation; mid == high is legal (D-12)', () {
      expect(
        validateRuleProfile(_profile(midIvCutoff: 71, highIvCutoff: 70)).single.field,
        RuleProfileField.midIvCutoff,
      );
      // Equal cutoffs keep the strict/inclusive asymmetry meaningful at
      // the boundary -- the boundary row still belongs to the mid band.
      expect(validateRuleProfile(_profile(midIvCutoff: 70, highIvCutoff: 70)), isEmpty);
    });

    test('DTE: min > max is one violation on targetDteMin; equal is legal', () {
      expect(
        validateRuleProfile(_profile(targetDteMin: 45, targetDteMax: 30)).single.field,
        RuleProfileField.targetDteMin,
      );
      expect(validateRuleProfile(_profile(targetDteMin: 30, targetDteMax: 30)), isEmpty);
    });

    test('a cross-field rule never double-reports a field that failed its own bound', () {
      // base is 1.5 (out of range) and also greater than mid: only the
      // range violation is reported.
      final violations = validateRuleProfile(_profile(baseRollBand: 1.5, midIvRollBand: 0.3));
      expect(violations, hasLength(1));
      expect(violations.single.field, RuleProfileField.baseRollBand);
    });

    test('multi-violation: exactly 3 bad fields -> 3 violations, in field order', () {
      final violations = validateRuleProfile(
        _profile(profitTargetPct: 0, baseRollBand: 1.5, minIvRank: 150),
      );
      expect(
        violations.map((v) => v.field).toList(),
        [
          RuleProfileField.profitTargetPct,
          RuleProfileField.baseRollBand,
          RuleProfileField.minIvRank,
        ],
      );
    });

    test('S-201\'s fixture (2 bad fields, one cross-field) reports both', () {
      final violations = validateRuleProfile(
        _profile(profitTargetPct: 0, baseRollBand: 0.9, midIvRollBand: 0.3),
      );
      expect(
        violations.map((v) => v.field).toList(),
        [RuleProfileField.profitTargetPct, RuleProfileField.baseRollBand],
      );
    });
  });

  group('S-197 core: hasSameThresholdsAs — the D-2 no-op rule', () {
    test('equal-valued candidates compare equal, whatever their identity fields', () {
      final renamed = _profile(
        versionId: RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 7),
        profileId: RuleProfileIds.standard,
        name: 'Standard',
        version: 7,
      );
      expect(RuleProfile.standard.hasSameThresholdsAs(_profile()), isTrue);
      expect(RuleProfile.standard.hasSameThresholdsAs(renamed), isTrue);
      expect(renamed.hasSameThresholdsAs(RuleProfile.standard), isTrue);
    });

    test('numeric representation does not matter (0.05 vs 0.0500)', () {
      final a = _profile(tailExtrinsicThreshold: Decimal.parse('0.05'));
      final b = _profile(tailExtrinsicThreshold: Decimal.parse('0.0500'));
      expect(a.hasSameThresholdsAs(b), isTrue);
      expect(b.hasSameThresholdsAs(a), isTrue);
    });

    test('any single changed value breaks equality', () {
      expect(RuleProfile.standard.hasSameThresholdsAs(_profile(profitTargetPct: 60)), isFalse);
      expect(RuleProfile.standard.hasSameThresholdsAs(_profile(midIvCutoff: 41)), isFalse);
      expect(RuleProfile.standard.hasSameThresholdsAs(_profile(tailDteDays: 4)), isFalse);
      expect(RuleProfile.standard.hasSameThresholdsAs(_profile(targetDelta: 0.31)), isFalse);
      expect(
        RuleProfile.standard.hasSameThresholdsAs(
          _profile(tailExtrinsicThreshold: Decimal.parse('0.06')),
        ),
        isFalse,
      );
    });
  });
}
