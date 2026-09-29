import 'package:decimal/decimal.dart';
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
      // Schema v5 (Pro Wave 1, D-6): unset capital, 25% concentration limit.
      expect(restored.wheelCapital, isNull);
      expect(restored.concentrationLimitPct, 25.0);
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
        wheelCapital: Decimal.parse('30000.00'),
        concentrationLimitPct: 20.0,
      );

      final json = prefs.toJson();
      final restored = UserPreferencesData.fromJson(json);

      expect(restored, prefs);
      expect(restored.deltaConventionDefault, DeltaConvention.option);
      expect(restored.exportReminderDismissed, isTrue);
      expect(restored.lastExportAt, DateTime.utc(2026, 3, 1));
      expect(restored.notificationMilestones, [14, 3]);
      expect(restored.wheelCapital, Decimal.parse('30000.00'));
      expect(restored.concentrationLimitPct, 20.0);
    });

    // S-215(b): a format-2 export captured before this wave carries neither
    // new key. Both must fall back to their defaults rather than throwing.
    test('S-215: a pre-v5 preferences object without the new keys reads as defaults', () {
      final legacy = <String, Object?>{
        'totalPerContractToggle': true,
        'deltaConventionDefault': 'option',
        'firstRunExplainerShown': true,
        'ivResolutionNoticeDismissed': true,
        'exportReminderDismissed': true,
        'lastExportAt': DateTime.utc(2026, 3, 1).toIso8601String(),
        'notificationMilestones': [7, 0],
      };

      final restored = UserPreferencesData.fromJson(legacy);

      expect(restored.wheelCapital, isNull);
      expect(restored.concentrationLimitPct, 25.0);
      expect(restored.totalPerContractToggle, isTrue);
      expect(restored.notificationMilestones, [7, 0]);
    });
  });
}
