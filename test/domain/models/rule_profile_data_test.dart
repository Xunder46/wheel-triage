import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/rule_profile_data.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';

void main() {
  group('RuleProfileData round-trip (S-030)', () {
    // Identity only since Iteration 5 (D-3) — the 14 threshold values live
    // on RuleProfileVersionData
    // (see rule_profile_version_data_test.dart).
    test('round-trips exactly', () {
      const profile = RuleProfileData(id: RuleProfileIds.standard, name: 'Standard');

      final json = profile.toJson();
      final restored = RuleProfileData.fromJson(json);

      expect(restored, profile);
    });
  });
}
