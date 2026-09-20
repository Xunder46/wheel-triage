import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/models/user_preferences.dart';

void main() {
  group('UserPreferencesData round-trip (S-030)', () {
    // UserPreferencesData has no optional fields (every field has a
    // @Default) — two cases still cover the meaningful shape: the all-
    // defaults case, and every field flipped away from its default.
    test('defaults', () {
      const prefs = UserPreferencesData();

      final json = prefs.toJson();
      final restored = UserPreferencesData.fromJson(json);

      expect(restored, prefs);
      expect(restored.totalPerContractToggle, isFalse);
      expect(restored.deltaConventionDefault, DeltaConvention.position);
      expect(restored.firstRunExplainerShown, isFalse);
      expect(restored.ivResolutionNoticeDismissed, isFalse);
      expect(restored.exportReminderDismissed, isFalse);
      expect(restored.lastExportAt, isNull);
      expect(restored.notificationMilestones, [21, 7, 0]);
    });

    test('every field flipped away from its default', () {
      final prefs = UserPreferencesData(
        totalPerContractToggle: true,
        deltaConventionDefault: DeltaConvention.option,
        firstRunExplainerShown: true,
        ivResolutionNoticeDismissed: true,
        exportReminderDismissed: true,
        lastExportAt: DateTime.utc(2026, 3, 1),
        notificationMilestones: const [14, 3],
      );

      final json = prefs.toJson();
      final restored = UserPreferencesData.fromJson(json);

      expect(restored, prefs);
      expect(restored.deltaConventionDefault, DeltaConvention.option);
      expect(restored.exportReminderDismissed, isTrue);
      expect(restored.lastExportAt, DateTime.utc(2026, 3, 1));
      expect(restored.notificationMilestones, [14, 3]);
    });
  });
}
