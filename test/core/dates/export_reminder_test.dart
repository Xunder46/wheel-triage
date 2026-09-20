import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/dates/export_reminder.dart';

void main() {
  group('S-160: 30-day export reminder -- lifetime flag, not recurring', () {
    test('never exported, an open position opened 31 days ago -> due', () {
      final now = DateTime(2026, 2, 1);
      final due = exportReminderDue(
        lastExportAt: null,
        earliestOpenPositionOpenedAt: DateTime(2026, 1, 1),
        hasOpenPositions: true,
        exportReminderDismissed: false,
        now: now,
      );
      expect(due, isTrue);
    });

    test('never exported, an open position opened only 10 days ago -> not yet due', () {
      final now = DateTime(2026, 1, 11);
      final due = exportReminderDue(
        lastExportAt: null,
        earliestOpenPositionOpenedAt: DateTime(2026, 1, 1),
        hasOpenPositions: true,
        exportReminderDismissed: false,
        now: now,
      );
      expect(due, isFalse);
    });

    test('last export was 31 days ago -> due, regardless of when the position opened', () {
      final now = DateTime(2026, 2, 1);
      final due = exportReminderDue(
        lastExportAt: DateTime(2026, 1, 1),
        earliestOpenPositionOpenedAt: DateTime(2025, 6, 1),
        hasOpenPositions: true,
        exportReminderDismissed: false,
        now: now,
      );
      expect(due, isTrue);
    });

    test('no open positions -> never due, no matter how long since export', () {
      final now = DateTime(2026, 2, 1);
      final due = exportReminderDue(
        lastExportAt: DateTime(2025, 1, 1),
        earliestOpenPositionOpenedAt: null,
        hasOpenPositions: false,
        exportReminderDismissed: false,
        now: now,
      );
      expect(due, isFalse);
    });

    test('dismissed -> never due again, even 31+ more days later', () {
      final now = DateTime(2026, 3, 15); // well over another 30 days past the 31-day mark
      final due = exportReminderDue(
        lastExportAt: null,
        earliestOpenPositionOpenedAt: DateTime(2026, 1, 1),
        hasOpenPositions: true,
        exportReminderDismissed: true,
        now: now,
      );
      expect(due, isFalse);
    });

    test('exactly 30 days is due (>=, not >)', () {
      final now = DateTime(2026, 1, 31);
      final due = exportReminderDue(
        lastExportAt: DateTime(2026, 1, 1),
        earliestOpenPositionOpenedAt: null,
        hasOpenPositions: true,
        exportReminderDismissed: false,
        now: now,
      );
      expect(due, isTrue);
    });

    test('29 days is not yet due', () {
      final now = DateTime(2026, 1, 30);
      final due = exportReminderDue(
        lastExportAt: DateTime(2026, 1, 1),
        earliestOpenPositionOpenedAt: null,
        hasOpenPositions: true,
        exportReminderDismissed: false,
        now: now,
      );
      expect(due, isFalse);
    });
  });
}
