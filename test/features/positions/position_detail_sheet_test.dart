import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/formulas.dart' as formulas;
import 'package:wheel_triage/features/positions/position_detail_sheet.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/widgets/bucket_badge.dart';

import '../../support/rule_profile_fixtures.dart';

Future<String> _makeLegWithSnapshot(WheelRepository repo, String ticker) async {
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
  return result.leg.id;
}

void main() {
  group('S-060: "Stock price" replaces "Underlying price" in the snapshot sheet', () {
    testWidgets('the snapshot-sheet field label reads "Stock price"', (tester) async {
      final repo = InMemoryWheelRepository();
      final legId = await _makeLegWithSnapshot(repo, 'AAA');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: legId)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update snapshot'));
      await tester.pumpAndSettle();

      expect(find.text('Stock price (\$)'), findsOneWidget);
      expect(find.textContaining('Underlying price'), findsNothing);
    });
  });

  group('S-062: one-time IV-resolution dismissable note', () {
    testWidgets('shows once, dismissing it hides it for every subsequent detail sheet', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      final legIdA = await _makeLegWithSnapshot(repo, 'AAA');
      final legIdB = await _makeLegWithSnapshot(repo, 'BBB');

      final container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: PositionDetailSheet(legId: legIdA)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('roll band now falls back'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.textContaining('roll band now falls back'), findsNothing);

      // A second, different position's detail sheet does not show it again --
      // it's a global flag, not per-leg (Feature Invariant 24).
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: PositionDetailSheet(legId: legIdB)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('roll band now falls back'), findsNothing);
    });
  });

  group('S-084: snapshot sheet (C4) -- chips, inline hint, live delta magnitude', () {
    testWidgets('inline hint under Delta is visible, and typing shows the live magnitude', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      final legId = await _makeLegWithSnapshot(repo, 'AAA');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: legId)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update snapshot'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter it exactly as your broker shows it, minus sign included.'),
        findsOneWidget,
      );
      // No magnitude readout before anything is typed.
      expect(find.textContaining('Magnitude:'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Delta, as shown on your broker screen'),
        '-0.35',
      );
      await tester.pump();

      expect(find.text('Magnitude: 0.3500'), findsOneWidget);
    });
  });

  group('S-085: snapshot sheet prefill from the previous snapshot', () {
    testWidgets(
      'Stock price and IV prefill from the prior snapshot, marked carried forward; '
      'Option mark and Delta stay blank',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final underlying = await repo.getOrCreateUnderlying('PFL');
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
            iv: 40,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(home: PositionDetailSheet(legId: result.leg.id)),
          ),
        );
        await tester.pumpAndSettle();
        // Second time opening "Update snapshot" on this leg (the first
        // snapshot -- appended directly above -- already exists).
        await tester.tap(find.text('Update snapshot'));
        await tester.pumpAndSettle();

        final stockPriceField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Stock price (\$)'),
        );
        expect(stockPriceField.controller!.text, '46');
        final ivField = tester.widget<TextField>(find.widgetWithText(TextField, 'IV (%, optional)'));
        expect(ivField.controller!.text, '40');

        // Visibly marked as carried forward, twice (Stock price + IV).
        expect(find.text('Carried forward from last snapshot'), findsNWidgets(2));

        // Option mark and Delta are NOT prefilled.
        final markField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Option mark (\$)'),
        );
        expect(markField.controller!.text, isEmpty);
        final deltaField = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Delta, as shown on your broker screen'),
        );
        expect(deltaField.controller!.text, isEmpty);
      },
    );
  });

  group('S-143: arithmetic card formats percentages/money -- no raw Decimal reaches the UI', () {
    testWidgets(
      'capturedPct renders to zero decimals, oneSigmaMove renders to two, matching the '
      "screener's _pctText/_moneyText shape",
      (tester) async {
        final repo = InMemoryWheelRepository();
        final underlying = await repo.getOrCreateUnderlying('FMT');
        final expiration = DateTime(2026, 3, 1);
        final takenAt = DateTime(2026, 1, 1);
        final result = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45'),
            expiration: expiration,
            contracts: 1,
            openedAt: takenAt,
            openCreditPerShare: Decimal.parse('0.31'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );
        await repo.appendSnapshot(
          NewSnapshotInput(
            legId: result.leg.id,
            takenAt: takenAt,
            optionMark: Decimal.parse('0.45'), // loss -- capturedPct lands on a long repeating decimal
            underlyingPrice: Decimal.parse('46.10'),
            deltaAsEntered: -0.20,
            deltaConvention: DeltaConvention.position,
            iv: 40,
          ),
        );

        // The exact same pure computations the sheet performs internally --
        // not hand-picked numbers -- so this pins the real raw/formatted
        // strings rather than a guess at them.
        final captured = formulas.capturedPct(
          openCredit: Decimal.parse('0.31'),
          currentMark: Decimal.parse('0.45'),
        )!;
        final dteAtTaken = formulas.dte(expiration, takenAt);
        final oneSigma = formulas.oneSigmaMove(spot: Decimal.parse('46.10'), iv: 40, dte: dteAtTaken)!;

        // Sanity: both raw values genuinely carry more precision than the
        // fixed display should show -- otherwise this test would pass
        // vacuously regardless of whether the fix landed.
        expect(captured.toStringAsFixed(0), isNot('$captured'));
        expect(oneSigma.toStringAsFixed(2), isNot('$oneSigma'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(home: PositionDetailSheet(legId: result.leg.id)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('$captured%'), findsNothing); // raw, unformatted -- S-143's fixture shape
        expect(find.text('\$$oneSigma'), findsNothing); // raw, unformatted -- S-143's fixture shape
        expect(find.text('${captured.toStringAsFixed(0)}%'), findsOneWidget);
        expect(find.text('\$${oneSigma.toStringAsFixed(2)}'), findsOneWidget);
      },
    );
  });

  group('Freshness indicator wiring (step 4, Feature Invariant 33) -- the pure function is pinned '
      'separately in test/domain/rules/snapshot_freshness_test.dart', () {
    Future<String> makeLegWithSnapshotTakenAt(WheelRepository repo, DateTime takenAt) async {
      final wallNow = DateTime.now();
      final underlying = await repo.getOrCreateUnderlying('FRESH');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: wallNow.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: wallNow.subtract(const Duration(days: 60)),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.appendSnapshot(
        NewSnapshotInput(
          legId: result.leg.id,
          takenAt: takenAt,
          optionMark: Decimal.parse('0.30'),
          underlyingPrice: Decimal.parse('46'),
          deltaAsEntered: -0.10,
          deltaConvention: DeltaConvention.position,
        ),
      );
      return result.leg.id;
    }

    testWidgets('a stale snapshot shows "Stale" and names which snapshot the verdict came from', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      final legId = await makeLegWithSnapshotTakenAt(repo, DateTime.now().subtract(const Duration(days: 5)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: legId)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stale'), findsOneWidget);
      expect(find.textContaining('Computed from the snapshot taken on'), findsOneWidget);
    });

    testWidgets('a fresh snapshot shows "Fresh" and no source-naming line', (tester) async {
      final repo = InMemoryWheelRepository();
      final legId = await makeLegWithSnapshotTakenAt(repo, DateTime.now());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: legId)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fresh'), findsOneWidget);
      expect(find.textContaining('Computed from the snapshot taken on'), findsNothing);
    });
  });

  group('S-142: backdating field in the snapshot sheet', () {
    testWidgets(
      'defaults to today; opening the calendar on a leg whose own range is entirely in the past '
      'does not crash (clamped), and saving with that out-of-range default is blocked, range named',
      (tester) async {
        final repo = InMemoryWheelRepository();
        // openedAt 2026-01-01, expiration 2026-03-01 -- both long before real
        // wall-clock "now", so the unmodified default `takenAt` (today) falls
        // outside this leg's own range.
        final legId = await _makeLegWithSnapshot(repo, 'BACK');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(home: PositionDetailSheet(legId: legId)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Update snapshot'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Snapshot date:'), findsOneWidget);

        // Flutter's own `showDatePicker` asserts `initialDate` falls inside
        // `[firstDate, lastDate]` -- opening it here must not crash even
        // though real "now" sits outside this leg's own range, which is
        // exactly why the sheet clamps the initial value before opening it.
        await tester.tap(find.text('Change'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, 'Option mark (\$)'), '0.30');
        await tester.enterText(find.widgetWithText(TextField, 'Stock price (\$)'), '46');
        await tester.enterText(
          find.widgetWithText(TextField, 'Delta, as shown on your broker screen'),
          '-0.20',
        );
        await tester.tap(find.text('Save snapshot'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Snapshot date must be between'), findsOneWidget);
        // Still just the one snapshot from setup -- the out-of-range submit
        // never reached the repository.
        expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
      },
    );

    testWidgets('picking a date inside the leg\'s own range persists it on the saved snapshot', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      final wallNow = DateTime.now();
      final underlying = await repo.getOrCreateUnderlying('LIVEBACK');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: wallNow.add(const Duration(days: 30)),
          contracts: 1,
          openedAt: wallNow.subtract(const Duration(days: 10)),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: result.leg.id)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update snapshot'));
      await tester.pumpAndSettle();

      // Left untouched (default takenAt = now, inside this leg's own range).
      await tester.enterText(find.widgetWithText(TextField, 'Option mark (\$)'), '0.30');
      await tester.enterText(find.widgetWithText(TextField, 'Stock price (\$)'), '46');
      await tester.enterText(
        find.widgetWithText(TextField, 'Delta, as shown on your broker screen'),
        '-0.20',
      );
      await tester.tap(find.text('Save snapshot'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Snapshot date must be between'), findsNothing);
      expect(await repo.getSnapshotsForLeg(result.leg.id), hasLength(1));
    });
  });

  group('S-144: roll-band row stacks instead of truncating its label at a realistic phone width', () {
    testWidgets('label renders at its natural width, not squeezed by the long value beside it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844); // realistic phone width (iPhone-class)
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('BAND');
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
          optionMark: Decimal.parse('0.55'),
          underlyingPrice: Decimal.parse('46'),
          deltaAsEntered: -0.20,
          deltaConvention: DeltaConvention.position,
          iv: 85, // > highIvCutoff 70 -- produces the long "... from this snapshot's IV (85%)" label
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: result.leg.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("from this snapshot's IV (85%)"), findsOneWidget);
      expect(find.text('Roll band in use'), findsOneWidget);
      final rolledOutWidth = tester.getSize(find.text('Roll band in use')).width;

      // Reference: the same label text rendered with plenty of width
      // available, as its own natural (unsqueezed) size.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Align(alignment: Alignment.topLeft, child: Text('Roll band in use'))),
        ),
      );
      await tester.pumpAndSettle();
      final naturalWidth = tester.getSize(find.text('Roll band in use')).width;

      expect(
        rolledOutWidth,
        greaterThanOrEqualTo(naturalWidth - 1.0),
        reason: 'the label should render at its natural width, not be shrunk to fit beside the value',
      );
    });
  });

  group('S-202: provenance names the pinned version, including the fallback', () {
    Future<String> makePinnedLeg(
      InMemoryWheelRepository repo,
      String ticker,
      String versionId,
    ) async {
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
          ruleProfileVersionId: versionId,
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
      return result.leg.id;
    }

    testWidgets(
      'a v2-pinned leg reads "Standard v2", a v1-pinned leg "Standard v1", and a '
      'dangling pin renders the built-in fallback instead of crashing',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final v2 = await repo.appendRuleProfileVersion(
          profileId: RuleProfileIds.standard,
          effectiveAt: DateTime(2026, 1, 2),
          values: standardVersionInput(profitTargetPct: 60.0),
        );
        final v2LegId = await makePinnedLeg(repo, 'PVA', v2.id);
        final v1LegId = await makePinnedLeg(repo, 'PVB', RuleProfileVersionIds.standardV1);
        final danglingLegId = await makePinnedLeg(repo, 'PVC', 'rule-profile-standard-v9');

        Future<void> openSheet(String legId) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
              child: MaterialApp(home: PositionDetailSheet(legId: legId)),
            ),
          );
          await tester.pumpAndSettle();
        }

        await openSheet(v2LegId);
        expect(find.text('Rules: Standard v2'), findsOneWidget);
        expect(find.byType(BucketBadge), findsOneWidget);
        // 50% captured clears v1's target and misses v2's, so the verdict
        // difference *is* the pin -- asserted through the rendered verdict,
        // which is the path the provenance line alone cannot guard.
        expect(find.text('Delta 0.25 below the 0.30 band'), findsOneWidget);

        await openSheet(v1LegId);
        expect(find.text('Rules: Standard v1'), findsOneWidget);
        expect(find.text('50% of credit captured'), findsOneWidget);

        // D-7: a pin that resolves to nothing degrades to the built-in
        // defaults -- which is what actually classified the leg -- and the
        // sheet still renders a verdict.
        await openSheet(danglingLegId);
        expect(find.text('Rules: Standard v1'), findsOneWidget);
        expect(find.text('50% of credit captured'), findsOneWidget);
        expect(find.byType(BucketBadge), findsOneWidget);
      },
    );
  });

  group('R18: the FAB opens the extracted sheet, preview and all', () {
    testWidgets('two taps reach the preview card for the entered numbers', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      final legId = await _makeLegWithSnapshot(repo, 'FAB');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: legId)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap one: the FAB. Tap two: a field, which must light the preview.
      await tester.tap(find.text('Update snapshot'));
      await tester.pumpAndSettle();
      expect(find.text('Before you save'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Option mark (\$)'), '0.40');
      await tester.enterText(find.widgetWithText(TextField, 'Stock price (\$)'), '46');
      await tester.enterText(
        find.widgetWithText(TextField, 'Delta, as shown on your broker screen'),
        '-0.35',
      );
      await tester.pumpAndSettle();

      expect(find.text('Before you save'), findsOneWidget);
      expect(find.text('Delta 0.35 at or above the 0.30 band'), findsOneWidget);
      expect(find.text('Was Close on the Jan 1 reading'), findsOneWidget);
      // Nothing saved: the preview is a preview, and the history is still one.
      expect(await repo.getSnapshotsForLeg(legId), hasLength(1));
    });
  });
}
