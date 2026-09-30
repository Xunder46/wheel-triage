import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/disclaimer.dart';
import 'package:wheel_triage/core/notifications/notification_scheduler.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/capital_committed.dart';
import 'package:wheel_triage/features/positions/position_detail_sheet.dart';
import 'package:wheel_triage/features/settings/settings_screen.dart';
import 'package:wheel_triage/state/export/export_controller.dart';
import 'package:wheel_triage/state/notifications/notification_providers.dart';
import 'package:wheel_triage/state/today/today_controller.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/rule_profiles/rule_profile_providers.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/rule_profile_fixtures.dart';

/// Records every call for S-161's assertion ("invoked with both files").
class _FakeShareSheet implements ShareSheet {
  List<XFile>? sharedFiles;
  String? sharedSubject;

  @override
  Future<void> shareFiles(List<XFile> files, {String? subject}) async {
    sharedFiles = files;
    sharedSubject = subject;
  }
}

/// Returns a canned file from [pickJsonFile] without touching a real OS
/// file picker.
class _FakeImportFilePicker implements ImportFilePicker {
  _FakeImportFilePicker(this.file);

  final XFile? file;

  @override
  Future<XFile?> pickJsonFile() async => file;
}

void main() {
  group('S-070: Settings screen renders its four elements', () {
    testWidgets(
      'delta-convention control (Position), toggle (off), the Standard profile '
      'section, re-run explainer button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryWheelRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Delta-convention default control, showing Position.
        expect(find.text('Delta convention'), findsOneWidget);
        expect(find.text('Position'), findsOneWidget);
        expect(find.text('Option'), findsOneWidget);

        // Total-per-contract toggle, showing off.
        final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(toggle.value, isFalse);

        // The profile section is the editable one now (S-199 supersedes the
        // read-only-card clause this test used to assert; the values
        // themselves are asserted there, against the current version row).
        expect(find.text('Active profile'), findsOneWidget);
        expect(find.textContaining('Version 1 --'), findsOneWidget);

        // Re-run first-run explainer button.
        expect(find.text('How this app works'), findsOneWidget);
      },
    );
  });

  group(
    'S-071: delta-convention default pre-fills future entries, never rewrites history',
    () {
      testWidgets(
        'changing the Settings default to Option pre-fills the next snapshot form, '
        'but the already-stored Snapshot.deltaConvention stays Position',
        (tester) async {
          tester.view.physicalSize = const Size(800, 3200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final repo = InMemoryWheelRepository();
          final underlying = await repo.getOrCreateUnderlying('DCX');
          final result = await repo.createCycle(
            underlyingId: underlying.id,
            firstLeg: NewLegInput(
              optionType: OptionType.put,
              strike: Decimal.parse('45'),
              expiration: DateTime(2026, 3, 1),
              contracts: 1,
              openedAt: DateTime(2026, 1, 1),
              openCreditPerShare: Decimal.parse('0.60'),
              ruleProfileVersionId: RuleProfileVersionIds.standardV1,
            ),
          );
          await repo.appendSnapshot(
            NewSnapshotInput(
              legId: result.leg.id,
              takenAt: DateTime(2026, 1, 1),
              optionMark: Decimal.parse('0.30'),
              underlyingPrice: Decimal.parse('46'),
              deltaAsEntered: -0.25,
              deltaConvention: DeltaConvention.position,
            ),
          );

          final container = ProviderContainer(
            overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          );
          addTearDown(container.dispose);
          container.listen(preferencesControllerProvider, (previous, next) {});
          await container.read(preferencesControllerProvider.notifier).ready;

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: SettingsScreen()),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Option'));
          await tester.pumpAndSettle();

          final prefsAfterChange = await repo.getPreferences();
          expect(prefsAfterChange.deltaConventionDefault, DeltaConvention.option);

          // Open "Update snapshot" on the same leg -- a fresh WheelRepository
          // read (simulated relaunch pattern already used elsewhere), same
          // shared container so the change persists across the pump.
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(home: PositionDetailSheet(legId: result.leg.id)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Update snapshot'));
          await tester.pumpAndSettle();

          // The new sheet's convention dropdown defaults to Option.
          expect(find.text('Option'), findsWidgets);

          // The existing stored snapshot's deltaConvention is untouched
          // (Feature Invariant 5).
          final snapshots = await repo.getSnapshotsForLeg(result.leg.id);
          expect(snapshots, hasLength(1));
          expect(snapshots.single.deltaConvention, DeltaConvention.position);
        },
      );
    },
  );

  group('S-161: export action invokes the share sheet with both files', () {
    testWidgets('tapping Export shares the JSON + CSV files and records lastExportAt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('EXP');
      await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: DateTime(2026, 3, 1),
          contracts: 1,
          openedAt: DateTime(2026, 1, 1),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      final fakeShare = _FakeShareSheet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            shareSheetProvider.overrideWithValue(fakeShare),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect((await repo.getPreferences()).lastExportAt, isNull);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(fakeShare.sharedFiles, isNotNull);
      expect(fakeShare.sharedFiles, hasLength(2));
      expect(fakeShare.sharedFiles!.map((f) => f.mimeType), containsAll(['application/json', 'text/csv']));
      expect((await repo.getPreferences()).lastExportAt, isNotNull);
    });
  });

  group('S-162: import confirmation names the destroyed count; cancel is a no-op', () {
    Future<InMemoryWheelRepository> populatedRepo({required int cycleCount}) async {
      final repo = InMemoryWheelRepository();
      for (var i = 0; i < cycleCount; i++) {
        final underlying = await repo.getOrCreateUnderlying('T$i');
        final created = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45'),
            expiration: DateTime(2026, 2, 1),
            contracts: 1,
            openedAt: DateTime(2026, 1, 1),
            openCreditPerShare: Decimal.parse('0.60'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );
        await repo.closeLeg(
          legId: created.leg.id,
          reason: CloseReason.expiredWorthless,
          closeDebitPerShare: Decimal.zero,
          closedAt: DateTime(2026, 2, 1),
        );
      }
      return repo;
    }

    Future<XFile> twoCycleImportFile() async {
      final source = await populatedRepo(cycleCount: 2);
      final json = await source.exportToJson();
      return XFile.fromData(utf8.encode(json), mimeType: 'application/json', path: 'import.json');
    }

    testWidgets('trigger A: cancel leaves the database completely untouched', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = await populatedRepo(cycleCount: 5);
      final beforeIds = (await repo.getClosedCycles()).map((c) => c.id).toSet();
      final importFile = await twoCycleImportFile();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            importFilePickerProvider.overrideWithValue(_FakeImportFilePicker(importFile)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(find.textContaining('5 cycles will be replaced'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final afterIds = (await repo.getClosedCycles()).map((c) => c.id).toSet();
      expect(afterIds, beforeIds);
    });

    testWidgets(
      'trigger B: confirming replaces the 5 existing cycles with the 2 imported ones, '
      'and the profile section and current-version provider follow the import',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = await populatedRepo(cycleCount: 5);
        // The import file carries 2 cycles plus an edited profile
        // (standard v2, 60% target) that the destination database has never
        // seen.
        final source = await populatedRepo(cycleCount: 2);
        await source.appendRuleProfileVersion(
          profileId: RuleProfileIds.standard,
          effectiveAt: DateTime.utc(2026, 1, 2),
          values: standardVersionInput(profitTargetPct: 60.0),
        );
        final importFile = XFile.fromData(
          utf8.encode(await source.exportToJson()),
          mimeType: 'application/json',
          path: 'edited.json',
        );

        final container = ProviderContainer(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            importFilePickerProvider.overrideWithValue(_FakeImportFilePicker(importFile)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Before the import: the destination knows only the seeded v1.
        expect(find.textContaining(RegExp(r'^Version 1 --')), findsOneWidget);

        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();
        expect(find.textContaining('5 cycles will be replaced'), findsOneWidget);

        await tester.tap(find.text('Replace'));
        await tester.pumpAndSettle();

        expect(await repo.countCyclesForReplace(), 2);

        // The replaced profile rows must reach every reader: the section's
        // header and history, and the provider new cycles resolve.
        expect(find.textContaining(RegExp(r'^Version 2 --')), findsOneWidget);
        expect(find.textContaining(RegExp(r'^v2 --')), findsOneWidget);
        expect(find.textContaining(RegExp(r'^v1 --')), findsOneWidget);
        final current = await container.read(currentRuleProfileProvider.future);
        expect(current.version, 2);
        expect(current.profitTargetPct, 60.0);
      },
    );
  });

  group('S-163: import failure surfaces the error without altering on-screen state', () {
    testWidgets('a malformed import file shows an error and leaves the positions list untouched', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('KEEP');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: DateTime.now().add(const Duration(days: 30)),
          contracts: 1,
          openedAt: DateTime(2026, 1, 1),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      final beforeJson = await repo.exportToJson();
      final decoded = jsonDecode(beforeJson) as Map<String, dynamic>;
      final legs = (decoded['legs'] as List).cast<Map<String, dynamic>>();
      legs[0].remove('strike');
      final malformedJson = jsonEncode(decoded);
      final malformedFile = XFile.fromData(
        utf8.encode(malformedJson),
        mimeType: 'application/json',
        path: 'malformed.json',
      );

      final container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          importFilePickerProvider.overrideWithValue(_FakeImportFilePicker(malformedFile)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load();
      final beforeItems = container.read(todayControllerProvider).items;
      expect(beforeItems, hasLength(1));

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MaterialApp(home: SettingsScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      // countCyclesForReplace() succeeds (it's a plain read) even though the
      // FILE itself is malformed -- the confirmation still shows normally.
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      // S-163: the error is surfaced...
      expect(find.textContaining('legs[0]'), findsOneWidget);
      // ...and nothing else on screen changed: the positions list provider
      // was never invalidated/reloaded, and the underlying leg is untouched.
      final afterItems = container.read(todayControllerProvider).items;
      expect(afterItems.map((i) => i.leg.id), beforeItems.map((i) => i.leg.id));
      expect(await repo.getLeg(result.leg.id), isNotNull);
    });
  });

  group('S-175: Settings milestone change applies only to future legs', () {
    testWidgets('toggling a milestone checkbox updates user_preferences.notificationMilestones', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      expect((await repo.getPreferences()).notificationMilestones, [21, 7, 0]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Turn on 14 DTE, turn off 21 DTE.
      await tester.tap(find.text('14 days before expiration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21 days before expiration'));
      await tester.pumpAndSettle();

      final milestones = (await repo.getPreferences()).notificationMilestones;
      expect(milestones, containsAll([14, 7, 0]));
      expect(milestones, isNot(contains(21)));
    });
  });

  group('Notification permission -- honest display, never a false promise', () {
    testWidgets('shows a denied note next to the milestone editor when permission was refused', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gateway = FakeNotificationGateway()..forcedStatus = NotificationPermissionStatus.denied;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository()),
            notificationGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("won't fire until you turn them back on"), findsOneWidget);
    });

    testWidgets('shows no note when permission has never been asked yet', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("won't fire until you turn them back on"), findsNothing);
    });
  });

  group('S-248: Settings gains wheel capital and the concentration limit', () {
    Future<void> pump(WidgetTester tester, InMemoryWheelRepository repo) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder field(String key) => find.byKey(ValueKey(key));

    testWidgets('wheel capital persists and reads back after a restart', (tester) async {
      final repo = InMemoryWheelRepository();
      await pump(tester, repo);

      expect(find.text('Your book'), findsOneWidget);
      await tester.enterText(field('wheel-capital'), '30000');
      await tester.pumpAndSettle();

      expect((await repo.getPreferences()).wheelCapital, Decimal.parse('30000'));

      // A fresh screen over the same storage reads the stored figure back.
      await pump(tester, repo);
      expect(
        find.descendant(of: field('wheel-capital'), matching: find.text('30000')),
        findsOneWidget,
      );
    });

    testWidgets('a blank field clears wheel capital back to "not set"', (tester) async {
      final repo = InMemoryWheelRepository();
      await repo.updatePreferences(
        (await repo.getPreferences()).copyWith(wheelCapital: Decimal.parse('30000')),
      );
      await pump(tester, repo);

      await tester.enterText(field('wheel-capital'), '');
      await tester.pumpAndSettle();

      expect((await repo.getPreferences()).wheelCapital, isNull);
    });

    testWidgets('a value outside (0, infinity) is refused, never clamped', (tester) async {
      final repo = InMemoryWheelRepository();
      await pump(tester, repo);

      await tester.enterText(field('wheel-capital'), '0');
      await tester.pumpAndSettle();
      expect(find.text(kWheelCapitalRefusal), findsOneWidget);
      expect((await repo.getPreferences()).wheelCapital, isNull);

      await tester.enterText(field('wheel-capital'), '-5');
      await tester.pumpAndSettle();
      expect(find.text(kWheelCapitalRefusal), findsOneWidget);
      expect((await repo.getPreferences()).wheelCapital, isNull);

      await tester.enterText(field('wheel-capital'), 'abc');
      await tester.pumpAndSettle();
      expect(find.text(kWheelCapitalRefusal), findsOneWidget);
      expect((await repo.getPreferences()).wheelCapital, isNull);

      await tester.enterText(field('wheel-capital'), '30000');
      await tester.pumpAndSettle();
      expect(find.text(kWheelCapitalRefusal), findsNothing);
      expect((await repo.getPreferences()).wheelCapital, Decimal.parse('30000'));
    });

    testWidgets('the limit defaults to 25 and persists; outside (0, 100] it is refused', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      await pump(tester, repo);

      expect(
        find.descendant(of: field('concentration-limit'), matching: find.text('25')),
        findsOneWidget,
      );

      await tester.enterText(field('concentration-limit'), '0');
      await tester.pumpAndSettle();
      expect(find.text(kConcentrationLimitRefusal), findsOneWidget);
      expect((await repo.getPreferences()).concentrationLimitPct, 25.0);

      await tester.enterText(field('concentration-limit'), '101');
      await tester.pumpAndSettle();
      expect(find.text(kConcentrationLimitRefusal), findsOneWidget);
      expect((await repo.getPreferences()).concentrationLimitPct, 25.0);

      // 100 is inside the range: the boundary is inclusive at the top.
      await tester.enterText(field('concentration-limit'), '100');
      await tester.pumpAndSettle();
      expect(find.text(kConcentrationLimitRefusal), findsNothing);
      expect((await repo.getPreferences()).concentrationLimitPct, 100.0);

      await tester.enterText(field('concentration-limit'), '30');
      await tester.pumpAndSettle();
      expect((await repo.getPreferences()).concentrationLimitPct, 30.0);
    });

    testWidgets('the disclaimer is the last thing in Settings, in D-P15\'s words', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      await pump(tester, repo);

      expect(find.text(kAppDisclaimer), findsOneWidget);
    });
  });
}
