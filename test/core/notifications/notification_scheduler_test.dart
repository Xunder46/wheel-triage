import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/notifications/notification_scheduler.dart';
import 'package:wheel_triage/domain/models/leg.dart';

import '../../support/fake_notification_gateway.dart';

void main() {
  group('S-170: deterministic notification ids', () {
    test('same legId + milestone always produces the same id', () {
      final first = notificationIdFor(legId: 'leg-1', milestoneDte: 21);
      final second = notificationIdFor(legId: 'leg-1', milestoneDte: 21);
      expect(first, second);
    });

    test('a different milestone or a different leg produces a different id', () {
      final base = notificationIdFor(legId: 'leg-1', milestoneDte: 21);
      expect(notificationIdFor(legId: 'leg-1', milestoneDte: 7), isNot(base));
      expect(notificationIdFor(legId: 'leg-2', milestoneDte: 21), isNot(base));
    });

    test('ids are always non-negative (valid platform notification ids)', () {
      for (final legId in ['a', 'leg-with-a-very-long-uuid-like-identifier-123456', '']) {
        for (final milestone in kSupportedNotificationMilestones) {
          expect(notificationIdFor(legId: legId, milestoneDte: milestone), greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('S-173: notification copy is date-only, never market-condition language', () {
    test('title names ticker/strike/side only', () {
      final title = notificationTitleFor(ticker: 'SBET', optionType: OptionType.call, strike: Decimal.parse('11'));
      expect(title, 'SBET \$11 call');
    });

    test('a whole-dollar strike drops the trailing .00', () {
      final title = notificationTitleFor(
        ticker: 'SBET',
        optionType: OptionType.put,
        strike: Decimal.parse('11.00'),
      );
      expect(title, 'SBET \$11 put');
    });

    test('a fractional strike keeps two decimals', () {
      final title = notificationTitleFor(
        ticker: 'SBET',
        optionType: OptionType.put,
        strike: Decimal.parse('11.50'),
      );
      expect(title, 'SBET \$11.50 put');
    });

    test('body at a positive DTE milestone reads "At N DTE"', () {
      expect(notificationBodyFor(milestoneDte: 21), 'At 21 DTE — worth a look.');
      expect(notificationBodyFor(milestoneDte: 7), 'At 7 DTE — worth a look.');
    });

    test('body at the expiration-morning milestone reads "Expires today"', () {
      expect(notificationBodyFor(milestoneDte: 0), 'Expires today.');
    });

    test(
      'grep: no banned advisory/action-plus-position phrase anywhere in the generated copy',
      () {
        final banned = RegExp(
          r'recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should|needs rolling|position needs',
          caseSensitive: false,
        );
        for (final optionType in OptionType.values) {
          final title = notificationTitleFor(ticker: 'SBET', optionType: optionType, strike: Decimal.parse('11'));
          for (final milestone in kSupportedNotificationMilestones) {
            final body = notificationBodyFor(milestoneDte: milestone);
            expect(banned.hasMatch(title), isFalse, reason: title);
            expect(banned.hasMatch(body), isFalse, reason: body);
          }
        }
      },
    );
  });

  group('scheduledDateTimeFor', () {
    test('milestone 21 is 21 calendar days before expiration, at 8am', () {
      final when = scheduledDateTimeFor(expiration: DateTime(2026, 3, 1), milestoneDte: 21);
      expect(when, DateTime(2026, 2, 8, 8));
    });

    test('milestone 0 (expiration morning) is the expiration date itself, at 8am', () {
      final when = scheduledDateTimeFor(expiration: DateTime(2026, 3, 1), milestoneDte: 0);
      expect(when, DateTime(2026, 3, 1, 8));
    });
  });

  group('NotificationScheduler.scheduleForLeg', () {
    test('S-170: schedules exactly one notification per milestone, with deterministic ids', () async {
      final gateway = FakeNotificationGateway();
      final scheduler = NotificationScheduler(gateway);
      final expiration = DateTime(2026, 3, 1);
      final now = DateTime(2026, 1, 1); // 40 days before expiration -- every default milestone is future

      await scheduler.scheduleForLeg(
        legId: 'leg-1',
        ticker: 'SBET',
        optionType: OptionType.call,
        strike: Decimal.parse('11'),
        expiration: expiration,
        milestones: const [21, 7, 0],
        now: now,
      );

      expect(gateway.scheduled.keys, hasLength(3));
      for (final milestone in [21, 7, 0]) {
        final id = notificationIdFor(legId: 'leg-1', milestoneDte: milestone);
        expect(gateway.scheduled.containsKey(id), isTrue, reason: 'milestone $milestone');
      }
      // Computing the same ids again matches (S-170's own "verified by
      // computing it twice").
      expect(notificationIdFor(legId: 'leg-1', milestoneDte: 21), notificationIdFor(legId: 'leg-1', milestoneDte: 21));
    });

    test('skips a milestone whose computed date has already passed relative to now', () async {
      final gateway = FakeNotificationGateway();
      final scheduler = NotificationScheduler(gateway);
      final expiration = DateTime(2026, 3, 1);
      final now = DateTime(2026, 2, 20); // 9 days out -- 21 DTE has already passed, 7 and 0 have not

      await scheduler.scheduleForLeg(
        legId: 'leg-1',
        ticker: 'SBET',
        optionType: OptionType.put,
        strike: Decimal.parse('11'),
        expiration: expiration,
        milestones: const [21, 7, 0],
        now: now,
      );

      expect(gateway.scheduled.keys, hasLength(2));
      expect(gateway.scheduled.containsKey(notificationIdFor(legId: 'leg-1', milestoneDte: 21)), isFalse);
      expect(gateway.scheduled.containsKey(notificationIdFor(legId: 'leg-1', milestoneDte: 7)), isTrue);
      expect(gateway.scheduled.containsKey(notificationIdFor(legId: 'leg-1', milestoneDte: 0)), isTrue);
    });

    test('S-176: requesting permission happens lazily, only on the first schedule call', () async {
      final gateway = FakeNotificationGateway();
      final scheduler = NotificationScheduler(gateway);
      expect(gateway.requestPermissionCallCount, 0);

      await scheduler.scheduleForLeg(
        legId: 'leg-1',
        ticker: 'SBET',
        optionType: OptionType.call,
        strike: Decimal.parse('11'),
        expiration: DateTime(2026, 3, 1),
        milestones: const [21],
        now: DateTime(2026, 1, 1),
      );
      expect(gateway.requestPermissionCallCount, 1);

      await scheduler.scheduleForLeg(
        legId: 'leg-2',
        ticker: 'SBET',
        optionType: OptionType.call,
        strike: Decimal.parse('11'),
        expiration: DateTime(2026, 3, 1),
        milestones: const [21],
        now: DateTime(2026, 1, 1),
      );
      // Still 1 -- a second leg-creation call in the same session does not
      // re-prompt (Feature Invariant 32: only the first one ever does).
      expect(gateway.requestPermissionCallCount, 1);
    });

    test('S-174: a denied permission no-ops scheduling entirely, without throwing', () async {
      final gateway = FakeNotificationGateway()..permissionGranted = false;
      final scheduler = NotificationScheduler(gateway);

      await scheduler.scheduleForLeg(
        legId: 'leg-1',
        ticker: 'SBET',
        optionType: OptionType.call,
        strike: Decimal.parse('11'),
        expiration: DateTime(2026, 3, 1),
        milestones: const [21, 7, 0],
        now: DateTime(2026, 1, 1),
      );

      expect(gateway.scheduled, isEmpty);
      expect(gateway.requestPermissionCallCount, 1);
    });
  });

  group('NotificationScheduler.cancelForLeg', () {
    test('S-171: cancels every id in the supported candidate universe for that leg only', () async {
      final gateway = FakeNotificationGateway();
      final scheduler = NotificationScheduler(gateway);

      await scheduler.cancelForLeg('leg-1');

      expect(gateway.cancelledIds, hasLength(kSupportedNotificationMilestones.length));
      for (final milestone in kSupportedNotificationMilestones) {
        expect(gateway.cancelledIds, contains(notificationIdFor(legId: 'leg-1', milestoneDte: milestone)));
      }
      // A different, unrelated leg's ids are never touched.
      for (final milestone in kSupportedNotificationMilestones) {
        expect(gateway.cancelledIds, isNot(contains(notificationIdFor(legId: 'leg-2', milestoneDte: milestone))));
      }
    });

    test(
      'S-174: cancelling a leg that was never scheduled (permission was denied) is a harmless no-op',
      () async {
        final gateway = FakeNotificationGateway();
        final scheduler = NotificationScheduler(gateway);
        // Never scheduled -- cancelForLeg must still complete without error.
        await expectLater(scheduler.cancelForLeg('never-scheduled-leg'), completes);
      },
    );
  });
}
