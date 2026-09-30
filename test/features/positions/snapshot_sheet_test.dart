import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/haptics/haptics.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/features/positions/snapshot_sheet.dart';
import 'package:wheel_triage/state/positions/position_detail_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/recording_haptics.dart';

/// D-17's fixture: a put with a previous reading that carries both a stock
/// price and an IV, so clearing the IV visibly changes the band's *source*
/// (21% from the snapshot vs 40% at open).
const _markLabel = 'Option mark (\$)';
const _spotLabel = 'Stock price (\$)';
const _deltaLabel = 'Delta, as shown on your broker screen';
const _ivLabel = 'IV (%, optional)';

final _now = DateTime(2026, 1, 20);

Future<String> _makeLeg(
  InMemoryWheelRepository repo, {
  String ticker = 'AAA',
  double? ivAtOpen = 40,
  bool withPreviousSnapshot = true,
  double previousIv = 21,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('45'),
      expiration: DateTime(2026, 3, 1),
      contracts: 1,
      openedAt: DateTime(2026, 1, 1),
      openCreditPerShare: Decimal.parse('0.60'),
      ivAtOpen: ivAtOpen,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  if (withPreviousSnapshot) {
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: result.leg.id,
        takenAt: DateTime(2026, 1, 1),
        optionMark: Decimal.parse('0.30'),
        underlyingPrice: Decimal.parse('46'),
        deltaAsEntered: -0.25,
        deltaConvention: DeltaConvention.position,
        iv: previousIv,
      ),
    );
  }
  return result.leg.id;
}

/// Renders the extracted sheet on a phone-tall surface, since the preview
/// card makes the form taller than the default 800x600 test surface.
Future<void> _pumpSheet(
  WidgetTester tester,
  InMemoryWheelRepository repo, {
  required String legId,
}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: SnapshotSheet(legId: legId, now: _now),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await tester.pumpAndSettle();
}

/// A repository whose append throws once [armed], for S-326(c): the fixture
/// reading is seeded first, then the store is made to fail.
class _ThrowingRepository extends InMemoryWheelRepository {
  bool armed = false;

  @override
  Future<Snapshot> appendSnapshot(NewSnapshotInput input) async {
    if (armed) throw StateError('the store is unavailable');
    return super.appendSnapshot(input);
  }
}

/// A leg whose dates are relative to the wall clock.
///
/// `updateSnapshot` reclassifies through `load()` with **real** `now`
/// (S-140), so a fixed calendar fixture would leave the tail window as the
/// clock moves -- and the pre-save bucket (real `now`) would then differ
/// from the preview's (`widget.now`) for reasons that have nothing to do
/// with the numbers under test.
Future<String> _makeWallLeg(
  InMemoryWheelRepository repo, {
  bool withPreviousReading = true,
  DateTime? wallNow,
}) async {
  final now = wallNow ?? DateTime.now();
  final underlying = await repo.getOrCreateUnderlying('WALL');
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('45'),
      expiration: now.add(const Duration(days: 40)),
      contracts: 1,
      openedAt: now.subtract(const Duration(days: 20)),
      openCreditPerShare: Decimal.parse('0.60'),
      ivAtOpen: 40,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  if (withPreviousReading) {
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: result.leg.id,
        takenAt: now.subtract(const Duration(days: 20)),
        optionMark: Decimal.parse('0.30'),
        underlyingPrice: Decimal.parse('46'),
        deltaAsEntered: -0.25,
        deltaConvention: DeltaConvention.position,
        iv: 21,
      ),
    );
  }
  return result.leg.id;
}

/// Pumps a host page whose only button opens the real modal sheet, so the
/// save's `Navigator.pop(true)` has a route to close (S-322 asserts the sheet
/// closed) and `RecordingHaptics` can be read from the container.
Future<ProviderContainer> _pumpHost(
  WidgetTester tester,
  InMemoryWheelRepository repo, {
  required String legId,
  required RecordingHaptics haptics,
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        hapticsProvider.overrideWithValue(haptics),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    showSnapshotSheet(context: context, legId: legId, now: now),
                child: const Text('Open snapshot sheet'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  // `positionDetailControllerProvider` is `autoDispose`: without a listener
  // the sheet's own pop disposes it, and the state the assertions read would
  // be a fresh, empty one.
  final sub = container.listen(
    positionDetailControllerProvider(legId),
    (previous, next) {},
  );
  addTearDown(sub.close);
  await tester.tap(find.text('Open snapshot sheet'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('S-239: carried-forward marking and sign handling survive', () {
    testWidgets(
      'both carried fields arrive prefilled and marked, mark and delta arrive blank',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeLeg(repo);
        await _pumpSheet(tester, repo, legId: legId);

        expect(
          find.text('Carried forward from last snapshot'),
          findsNWidgets(2),
        );
        expect(find.widgetWithText(TextField, '46'), findsOneWidget);
        expect(find.widgetWithText(TextField, '21'), findsOneWidget);
        // Option mark and delta are never carried (C4).
        expect(find.widgetWithText(TextField, '0.30'), findsNothing);
        expect(find.widgetWithText(TextField, '-0.25'), findsNothing);
      },
    );

    testWidgets(
      'each carried mark clears when its own field is edited, and only that field',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeLeg(repo);
        await _pumpSheet(tester, repo, legId: legId);

        await _enter(tester, _spotLabel, '47');
        expect(find.text('Carried forward from last snapshot'), findsOneWidget);
        expect(find.widgetWithText(TextField, '21'), findsOneWidget);

        await _enter(tester, _ivLabel, '25');
        expect(find.text('Carried forward from last snapshot'), findsNothing);
      },
    );

    testWidgets('a leg with no previous reading carries nothing', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      final legId = await _makeLeg(repo, withPreviousSnapshot: false);
      await _pumpSheet(tester, repo, legId: legId);

      expect(find.text('Carried forward from last snapshot'), findsNothing);
    });

    testWidgets(
      'the delta field shows the live magnitude and stores the value as typed',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeLeg(repo);
        await _pumpSheet(tester, repo, legId: legId);

        expect(find.textContaining('Magnitude:'), findsNothing);
        await _enter(tester, _deltaLabel, '-0.35');
        expect(find.text('Magnitude: 0.3500'), findsOneWidget);

        await _enter(tester, _markLabel, '0.40');
        await _enter(tester, _spotLabel, '46');
        await tester.tap(find.text('Save snapshot'));
        await tester.pumpAndSettle();

        final saved = (await repo.getSnapshotsForLeg(legId)).last;
        expect(saved.deltaAsEntered, -0.35);
        expect(saved.deltaConvention, DeltaConvention.position);
      },
    );

    testWidgets('backdating bounds stay [openedAt, expiration]', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      final legId = await _makeLeg(repo);
      await _pumpSheet(tester, repo, legId: legId);

      expect(find.text('Snapshot date: 2026-01-20'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The calendar is bounded to the leg's own range -- the leg's own
      // openedAt is inside it, and `showDatePicker` would have asserted
      // otherwise (S-142 covers the out-of-range default).
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('January 2026'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group(
    'S-238: the preview card matches classify() for the entered numbers',
    () {
      testWidgets(
        'entering mark, stock price and delta renders the verdict before saving',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeLeg(repo);
          await _pumpSheet(tester, repo, legId: legId);

          expect(find.text('Before you save'), findsNothing);
          expect(find.textContaining('Fill in the mark'), findsOneWidget);

          await _enter(tester, _markLabel, '0.40');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.35');

          expect(find.text('Before you save'), findsOneWidget);
          expect(find.text('Roll'), findsOneWidget);
          expect(
            find.text('Delta 0.35 at or above the 0.30 band'),
            findsOneWidget,
          );
          expect(find.text('33%'), findsOneWidget);
          expect(
            find.textContaining("0.30 — from this snapshot's IV (21%)"),
            findsOneWidget,
          );
          expect(find.text('\$0.40'), findsOneWidget);
          // Still nothing written: the preview is a preview.
          expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
        },
      );

      testWidgets(
        'clearing the IV falls the band back to IV at open and says so',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeLeg(repo);
          await _pumpSheet(tester, repo, legId: legId);

          await _enter(tester, _markLabel, '0.40');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.35');
          expect(
            find.textContaining("from this snapshot's IV (21%)"),
            findsOneWidget,
          );

          await _enter(tester, _ivLabel, '');
          expect(find.textContaining('from IV at open (40%)'), findsOneWidget);
        },
      );

      testWidgets('a reading that lands on Assign names the delta threshold', (
        tester,
      ) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeLeg(repo);
        await _pumpSheet(tester, repo, legId: legId);

        await _enter(tester, _markLabel, '0.50');
        await _enter(tester, _spotLabel, '46');
        await _enter(tester, _deltaLabel, '-0.72');

        expect(find.text('Assign'), findsOneWidget);
        expect(
          find.textContaining('Delta 0.72 at or above 0.70'),
          findsOneWidget,
        );
      });

      testWidgets(
        'a reading past the profit target names the captured percentage',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeLeg(repo);
          await _pumpSheet(tester, repo, legId: legId);

          await _enter(tester, _markLabel, '0.12');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.21');

          expect(find.text('Close'), findsOneWidget);
          expect(find.textContaining('80% of credit captured'), findsOneWidget);
          expect(find.text('80%'), findsOneWidget);
        },
      );

      testWidgets(
        'with no IV anywhere the band line says there is no IV on file',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeLeg(
            repo,
            ivAtOpen: null,
            withPreviousSnapshot: false,
          );
          await _pumpSheet(tester, repo, legId: legId);

          await _enter(tester, _markLabel, '0.40');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.35');

          expect(find.textContaining('no IV on file'), findsOneWidget);
        },
      );
    },
  );

  group('S-241: the change line', () {
    testWidgets(
      'a reading that changes the bucket names the bucket it replaces and its date',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeLeg(repo);
        await _pumpSheet(tester, repo, legId: legId);

        await _enter(tester, _markLabel, '0.40');
        await _enter(tester, _spotLabel, '46');
        await _enter(tester, _deltaLabel, '-0.35');

        expect(find.text('Roll'), findsOneWidget);
        expect(find.text('Was Close on the Jan 1 reading'), findsOneWidget);
      },
    );

    testWidgets(
      'a reading that matches the current bucket has no change line',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeLeg(repo);
        await _pumpSheet(tester, repo, legId: legId);

        // The previous reading's own numbers: 50% captured -> Close, again.
        await _enter(tester, _markLabel, '0.30');
        await _enter(tester, _spotLabel, '46');
        await _enter(tester, _deltaLabel, '-0.25');

        expect(find.text('Close'), findsOneWidget);
        expect(find.textContaining('Was '), findsNothing);
      },
    );
  });

  group('the sheet never dereferences an unloaded leg', () {
    testWidgets(
      'an unknown leg shows a loader and then the error, not an exception',
      (tester) async {
        final repo = InMemoryWheelRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: Scaffold(body: SnapshotSheet(legId: 'missing', now: null)),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('This position no longer exists.'), findsOneWidget);
        expect(find.text('Save snapshot'), findsNothing);
      },
    );
  });

  group('typing never writes', () {
    testWidgets(
      'filling the form in and not saving leaves the history untouched',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeLeg(repo);
        await _pumpSheet(tester, repo, legId: legId);

        await _enter(tester, _markLabel, '0.40');
        await _enter(tester, _spotLabel, '46');
        await _enter(tester, _deltaLabel, '-0.35');
        await _enter(tester, _ivLabel, '25');

        expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
      },
    );
  });

  group(
    'S-322-S-326/S-335: the one haptic, and every path that must not play it',
    () {
      final wallNow = DateTime.now();

      PositionDetailState stateOf(ProviderContainer container, String legId) =>
          container.read(positionDetailControllerProvider(legId));

      testWidgets(
        'S-322: a save that changes the bucket plays it exactly once',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeWallLeg(repo);
          final haptics = RecordingHaptics();
          final container = await _pumpHost(
            tester,
            repo,
            legId: legId,
            haptics: haptics,
            now: wallNow,
          );

          expect(stateOf(container, legId).bucket, isA<BucketClose>());

          await _enter(tester, _markLabel, '0.40');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.35');
          await tester.tap(find.text('Save snapshot'));
          await tester.pumpAndSettle();

          expect(haptics.calls, ['bucketChanged']);
          expect(
            find.text('Save snapshot'),
            findsNothing,
            reason: 'the sheet closed',
          );
          expect(stateOf(container, legId).bucket, isA<BucketRoll>());
          expect(stateOf(container, legId).lastSnapshotChangedBucket, isTrue);
          expect(await repo.getSnapshotsForLeg(legId), hasLength(2));
        },
      );

      testWidgets(
        'S-323: a save that does not change the bucket plays nothing',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeWallLeg(repo);
          final haptics = RecordingHaptics();
          final container = await _pumpHost(
            tester,
            repo,
            legId: legId,
            haptics: haptics,
            now: wallNow,
          );

          await _enter(tester, _markLabel, '0.12');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.21');
          await tester.tap(find.text('Save snapshot'));
          await tester.pumpAndSettle();

          expect(haptics.calls, isEmpty);
          expect(stateOf(container, legId).lastSnapshotChangedBucket, isFalse);
          // The absence of a haptic is not a failed save: the reading is in, and
          // its captured % is the new one (80% of 0.60 at a 0.12 mark).
          final snapshots = await repo.getSnapshotsForLeg(legId);
          expect(snapshots, hasLength(2));
          expect(snapshots.last.optionMark, Decimal.parse('0.12'));
          expect(find.text('Save snapshot'), findsNothing);
        },
      );

      testWidgets(
        'S-324: loading, opening, typing and dismissing all play nothing',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeWallLeg(repo);
          final haptics = RecordingHaptics();
          final container = await _pumpHost(
            tester,
            repo,
            legId: legId,
            haptics: haptics,
            now: wallNow,
          );

          // (a) the host pumped and settled; (b) the sheet opened and settled.
          expect(haptics.calls, isEmpty);

          // (c) the changing numbers, one field at a time, never saved. The
          // preview's sentence and the haptic are deliberately different events:
          // the sentence is a preview, the haptic is a write.
          await _enter(tester, _markLabel, '0.40');
          expect(haptics.calls, isEmpty);
          await _enter(tester, _spotLabel, '46');
          expect(haptics.calls, isEmpty);
          await _enter(tester, _deltaLabel, '-0.35');
          expect(haptics.calls, isEmpty);
          // The preview's sentence, in its shipped wording (S-241 pins it; D-74
          // forbids touching copy). The plan's prose calls this "the changes the
          // bucket line".
          expect(find.textContaining('Was Close on the'), findsOneWidget);

          // (d) dismiss.
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          expect(haptics.calls, isEmpty);
          expect(find.text('Save snapshot'), findsNothing);

          // (e) a direct reload.
          await container
              .read(positionDetailControllerProvider(legId).notifier)
              .load();
          await tester.pumpAndSettle();
          expect(haptics.calls, isEmpty);
        },
      );

      testWidgets('S-325: the first reading on a leg plays nothing', (
        tester,
      ) async {
        final repo = InMemoryWheelRepository();
        final legId = await _makeWallLeg(repo, withPreviousReading: false);
        final haptics = RecordingHaptics();
        final container = await _pumpHost(
          tester,
          repo,
          legId: legId,
          haptics: haptics,
          now: wallNow,
        );

        expect(stateOf(container, legId).bucket, isA<BucketUnknown>());

        await _enter(tester, _markLabel, '0.12');
        await _enter(tester, _spotLabel, '46');
        await _enter(tester, _deltaLabel, '-0.21');
        // The same save renders no change line, which is the consistency D-66
        // exists to hold: No data -> Close is not a change in either place.
        expect(find.textContaining('Was '), findsNothing);

        await tester.tap(find.text('Save snapshot'));
        await tester.pumpAndSettle();

        expect(haptics.calls, isEmpty);
        expect(stateOf(container, legId).bucket, isA<BucketClose>());
        expect(stateOf(container, legId).lastSnapshotChangedBucket, isFalse);
        expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
      });

      testWidgets(
        'S-326(a): a hard-rejected mark plays nothing and writes nothing',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeWallLeg(repo);
          final haptics = RecordingHaptics();
          final container = await _pumpHost(
            tester,
            repo,
            legId: legId,
            haptics: haptics,
            now: wallNow,
          );

          // A put's mark above its strike is impossible (Feature Invariant 20).
          await _enter(tester, _markLabel, '46');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.35');
          await tester.tap(find.text('Save snapshot'));
          await tester.pumpAndSettle();

          expect(haptics.calls, isEmpty);
          expect(stateOf(container, legId).snapshotError, isNotNull);
          expect(
            find.textContaining("A premium can't exceed the strike price"),
            findsOneWidget,
          );
          expect(
            stateOf(container, legId).lastSnapshotChangedBucket,
            isNot(isTrue),
          );
          expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
          expect(
            find.text('Save snapshot'),
            findsOneWidget,
            reason: 'a rejected save keeps the sheet open',
          );
        },
      );

      testWidgets(
        'S-326(b): a reading dated before the leg opened plays nothing',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeWallLeg(repo);
          final haptics = RecordingHaptics();
          // The sheet's own date picker is bounded to [openedAt, expiration], so
          // the only way this save can carry an out-of-range date is the sheet's
          // `now` seam -- which is what the fixture is: the rejection is the
          // controller's, not the picker's.
          final container = await _pumpHost(
            tester,
            repo,
            legId: legId,
            haptics: haptics,
            now: wallNow.subtract(const Duration(days: 30)),
          );

          await _enter(tester, _markLabel, '0.40');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.35');
          await tester.tap(find.text('Save snapshot'));
          await tester.pumpAndSettle();

          expect(haptics.calls, isEmpty);
          expect(
            stateOf(container, legId).snapshotError,
            contains('Snapshot date must be between'),
          );
          expect(
            stateOf(container, legId).lastSnapshotChangedBucket,
            isNot(isTrue),
          );
          expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
          expect(find.text('Save snapshot'), findsOneWidget);
        },
      );

      testWidgets('S-326(c): a repository that throws plays nothing', (
        tester,
      ) async {
        final repo = _ThrowingRepository();
        final legId = await _makeWallLeg(repo);
        repo.armed = true;
        final haptics = RecordingHaptics();
        final container = await _pumpHost(
          tester,
          repo,
          legId: legId,
          haptics: haptics,
          now: wallNow,
        );

        await _enter(tester, _markLabel, '0.40');
        await _enter(tester, _spotLabel, '46');
        await _enter(tester, _deltaLabel, '-0.35');
        await tester.tap(find.text('Save snapshot'));
        await tester.pumpAndSettle();

        expect(haptics.calls, isEmpty);
        expect(stateOf(container, legId).snapshotError, isNotNull);
        expect(find.textContaining('Could not save snapshot'), findsOneWidget);
        expect(
          stateOf(container, legId).lastSnapshotChangedBucket,
          isNot(isTrue),
        );
      });

      testWidgets(
        'S-335 widget half: a settle and a rebuild after the save add no calls',
        (tester) async {
          final repo = InMemoryWheelRepository();
          final legId = await _makeWallLeg(repo);
          final haptics = RecordingHaptics();
          final container = await _pumpHost(
            tester,
            repo,
            legId: legId,
            haptics: haptics,
            now: wallNow,
          );

          await _enter(tester, _markLabel, '0.40');
          await _enter(tester, _spotLabel, '46');
          await _enter(tester, _deltaLabel, '-0.35');
          await tester.tap(find.text('Save snapshot'));
          await tester.pumpAndSettle();
          expect(haptics.calls, hasLength(1));

          await tester.pumpAndSettle();
          await tester.pump();
          await container
              .read(positionDetailControllerProvider(legId).notifier)
              .load();
          await tester.pumpAndSettle();

          expect(
            haptics.calls,
            hasLength(1),
            reason: 'nothing re-fires the flag',
          );
          expect(stateOf(container, legId).lastSnapshotChangedBucket, isNull);
        },
      );
    },
  );
}
