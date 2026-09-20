import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/rule_profile_defaults.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/rules/roll_band.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';

void main() {
  group('S-008: rollBand boundary matrix', () {
    // iv -> expected band. The 70.0 row is the one a naive symmetric
    // implementation gets wrong (Feature Invariant 3: `>` on the high
    // cutoff, `>=` on the mid cutoff).
    const rows = <(double, double)>[
      (39.9, 0.30),
      (40.0, 0.35),
      (40.1, 0.35),
      (69.9, 0.35),
      (70.0, 0.35),
      (70.1, 0.40),
    ];

    for (final (iv, expectedBand) in rows) {
      test('standalone rollBandFor($iv) -> $expectedBand', () {
        final band = rollBandFor(
          iv: iv,
          baseBand: 0.30,
          midBand: 0.35,
          highBand: 0.40,
          midCutoff: 40,
          highCutoff: 70,
        );
        expect(band, expectedBand);
      });

      test('RuleProfile.standard.rollBandFor($iv) -> $expectedBand', () {
        expect(RuleProfile.standard.rollBandFor(iv), expectedBand);
      });
    }

    test('null iv falls back to the base band', () {
      expect(RuleProfile.standard.rollBandFor(null), 0.30);
    });
  });

  group('D-12 (Iteration 5): the asymmetry survives editing — moved cutoffs', () {
    // An edited version with mid/high cutoffs at 30/60 and bands
    // 0.25/0.33/0.45. Every row is a boundary of the *new* numbers, and the
    // 60.0 row pins the strict high cutoff (`>`, not `>=`) — the same
    // asymmetry S-008 pins for the §4.4 defaults, proven against values the
    // user typed rather than constants.
    final custom = RuleProfile(
      versionId: RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 2),
      profileId: RuleProfileIds.standard,
      name: 'Standard',
      version: 2,
      profitTargetPct: StandardProfileDefaults.profitTargetPct,
      assignThreshold: StandardProfileDefaults.assignThreshold,
      baseRollBand: 0.25,
      midIvRollBand: 0.33,
      highIvRollBand: 0.45,
      midIvCutoff: 30,
      highIvCutoff: 60,
      tailDteDays: StandardProfileDefaults.tailDteDays,
      tailExtrinsicThreshold: StandardProfileDefaults.tailExtrinsicThreshold,
      minIvRank: StandardProfileDefaults.minIvRank,
      minAnnualisedYield: StandardProfileDefaults.minAnnualisedYield,
      targetDteMin: StandardProfileDefaults.targetDteMin,
      targetDteMax: StandardProfileDefaults.targetDteMax,
      targetDelta: StandardProfileDefaults.targetDelta,
    );

    const movedRows = <(double, double)>[
      (29.9, 0.25),
      (30.0, 0.33),
      (59.9, 0.33),
      (60.0, 0.33),
      (60.1, 0.45),
    ];

    for (final (iv, expectedBand) in movedRows) {
      test('custom version rollBandFor($iv) -> $expectedBand', () {
        expect(custom.rollBandFor(iv), expectedBand);
      });
    }

    test('null iv still falls back to the custom base band', () {
      expect(custom.rollBandFor(null), 0.25);
    });
  });
}
