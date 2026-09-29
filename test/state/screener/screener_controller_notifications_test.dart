// Phase 21: S-170 (deterministic ids scheduled at leg creation), S-175
// (a Settings milestone change before tracking only ever affects the new
// leg -- there is no earlier leg here to leave untouched, but this proves
// the "reads the CURRENT preference at creation time" half of that rule;
// S-171/S-172 cover the "an existing leg is never re-touched" half),
// S-176 (permission requested lazily, never merely from filling the form).

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/notifications/notification_scheduler.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/state/notifications/notification_providers.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/screener/screener_controller.dart';

import '../../support/fake_notification_gateway.dart';

final _fixedNow = DateTime(2026, 1, 1);

void main() {
  late InMemoryWheelRepository repo;
  late FakeNotificationGateway gateway;
  late ProviderContainer container;

  setUp(() {
    repo = InMemoryWheelRepository();
    gateway = FakeNotificationGateway();
    container = ProviderContainer(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        notificationGatewayProvider.overrideWithValue(gateway),
        screenerControllerProvider.overrideWith((ref) => ScreenerController(ref, now: _fixedNow)),
      ],
    );
    container.listen(screenerControllerProvider, (previous, next) {});
    container.listen(preferencesControllerProvider, (previous, next) {});
  });

  tearDown(() => container.dispose());

  void fillForm() {
    final controller = container.read(screenerControllerProvider.notifier);
    // Put-side since D-12: a call on a ticker with no shares on record is now
    // refused before anything is written, and these scenarios are about the
    // scheduling, not the side.
    controller
      ..setTicker('sbet')
      ..setSide(OptionType.put)
      ..setStrike(Decimal.parse('11'))
      ..setSpot(Decimal.parse('9'))
      ..setCredit(Decimal.parse('0.35'))
      ..setDteConvenience(40)
      ..setContracts(1);
  }

  test('S-176: filling the screener form without submitting never requests permission', () async {
    fillForm();
    await container.read(preferencesControllerProvider.notifier).ready;
    expect(gateway.requestPermissionCallCount, 0);
  });

  test('S-170: "Track this position" schedules three notifications with deterministic ids', () async {
    fillForm();
    final ok = await container
        .read(screenerControllerProvider.notifier)
        .trackThisPosition(now: _fixedNow);
    expect(ok, isTrue);
    expect(gateway.requestPermissionCallCount, 1);

    final leg = (await repo.getOpenLegs()).single;
    expect(gateway.scheduled.keys, hasLength(3));
    for (final milestone in [21, 7, 0]) {
      final id = notificationIdFor(legId: leg.id, milestoneDte: milestone);
      expect(gateway.scheduled.containsKey(id), isTrue, reason: 'milestone $milestone');
    }
    // Computed twice, same result (S-170's own determinism check).
    expect(
      notificationIdFor(legId: leg.id, milestoneDte: 21),
      notificationIdFor(legId: leg.id, milestoneDte: 21),
    );
  });

  test('S-175: the CURRENT preferences milestone list is what a newly-tracked leg uses', () async {
    await container
        .read(preferencesControllerProvider.notifier)
        .update((p) => p.copyWith(notificationMilestones: const [14, 3]));

    fillForm();
    final ok = await container
        .read(screenerControllerProvider.notifier)
        .trackThisPosition(now: _fixedNow);
    expect(ok, isTrue);

    final leg = (await repo.getOpenLegs()).single;
    expect(gateway.scheduled.keys, hasLength(2));
    for (final milestone in [14, 3]) {
      final id = notificationIdFor(legId: leg.id, milestoneDte: milestone);
      expect(gateway.scheduled.containsKey(id), isTrue, reason: 'milestone $milestone');
    }
  });

  test('S-174: a denied permission still lets "Track this position" succeed', () async {
    gateway.permissionGranted = false;
    fillForm();
    final ok = await container
        .read(screenerControllerProvider.notifier)
        .trackThisPosition(now: _fixedNow);
    expect(ok, isTrue);
    expect(await repo.getOpenLegs(), hasLength(1));
    expect(gateway.scheduled, isEmpty);
  });
}
