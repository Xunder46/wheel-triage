import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/rule_profile_version_data.dart';

void main() {
  group('RuleProfileVersionData round-trip (S-030 extension)', () {
    // Every field is required, so one fully-populated case covers the whole
    // shape — including the two that need special serialization handling:
    // `effectiveAt` (DateTime) and `tailExtrinsicThreshold` (Decimal,
    // Feature Invariant 9).
    test('round-trips exactly, including effectiveAt and the Decimal field', () {
      final version = RuleProfileVersionData(
        id: RuleProfileVersionIds.standardV1,
        profileId: RuleProfileIds.standard,
        version: 1,
        effectiveAt: DateTime.utc(2026, 9, 19, 12, 30),
        profitTargetPct: 60.0,
        assignThreshold: 0.70,
        baseRollBand: 0.30,
        midIvRollBand: 0.35,
        highIvRollBand: 0.40,
        midIvCutoff: 40.0,
        highIvCutoff: 70.0,
        tailDteDays: 3,
        tailExtrinsicThreshold: Decimal.parse('0.1234'),
        minIvRank: 30.0,
        minAnnualisedYield: 20.0,
        targetDteMin: 30,
        targetDteMax: 45,
        targetDelta: 0.30,
      );

      final json = version.toJson();
      final restored = RuleProfileVersionData.fromJson(json);

      expect(restored, version);
      expect(restored.effectiveAt, DateTime.utc(2026, 9, 19, 12, 30));
      expect(restored.tailExtrinsicThreshold, Decimal.parse('0.1234'));
      expect(restored.version, 1);
      expect(restored.profileId, RuleProfileIds.standard);
    });
  });
}
