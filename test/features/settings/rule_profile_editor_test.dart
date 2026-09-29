// S-199, S-200, S-201 at the widget level: the Active-profile section's
// rendered shape, a save's cross-screen effect (a new cycle picks up v2, an
// open position does not), and both violations shown at once with nothing
// written. The controller-level halves live in
// `test/state/rule_profiles/rule_profile_editor_controller_test.dart`.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/features/settings/rule_profile_section.dart';
import 'package:wheel_triage/features/settings/settings_screen.dart';
import 'package:wheel_triage/state/positions/position_detail_controller.dart';
import 'package:wheel_triage/state/today/today_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/rule_profiles/rule_profile_providers.dart';

final _now = DateTime(2026, 9, 19, 12);

/// The editor field carrying [label] — how every test below drives the form
/// (by what the user sees, not by widget index).
Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

/// What [label]'s field currently holds. Several thresholds share a display
/// value (0.30 is both the base band and the target delta), so a bare
/// `find.text` cannot tell which field it found.
String _valueOf(WidgetTester tester, String label) => tester
    .widget<EditableText>(find.descendant(of: _field(label), matching: find.byType(EditableText)))
    .controller
    .text;

Finder get _saveButton => find.widgetWithText(FilledButton, 'Save as new version');

/// The header's `Version <n> -- effective <date>` line.
Pattern _versionLine(int n) => RegExp(r'^Version ' + n.toString() + r' -- effective \d{4}-\d{2}-\d{2}$');

/// One history entry's `v<n> -- <date>` title.
Pattern _historyLine(int n) => RegExp(r'^v' + n.toString() + r' -- \d{4}-\d{2}-\d{2}$');

/// Leg A: 55% captured under v1's 50% target — the S-196 fixture, so a v2
/// with a 60% target flips this leg's verdict if resolution ever stops
/// honouring the pin.
Future<String> _openPinnedLeg(WheelRepository repo, {required String versionId}) async {
  final underlying = await repo.getOrCreateUnderlying('PIN');
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('50'),
      expiration: _now.add(const Duration(days: 30)),
      contracts: 1,
      openedAt: _now,
      openCreditPerShare: Decimal.parse('1.00'),
      ruleProfileVersionId: versionId,
    ),
  );
  await repo.appendSnapshot(
    NewSnapshotInput(
      legId: result.leg.id,
      takenAt: _now,
      optionMark: Decimal.parse('0.45'),
      underlyingPrice: Decimal.parse('50'),
      deltaAsEntered: -0.20,
      deltaConvention: DeltaConvention.position,
    ),
  );
  return result.leg.id;
}

void main() {
  late InMemoryWheelRepository repo;

  setUp(() => repo = InMemoryWheelRepository());

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    ProviderContainer? reuse,
  }) async {
    // Tall enough that the whole Settings list is built: `ListView(children:)`
    // is lazy, so a default-sized viewport would hide half the form.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = reuse ??
        ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
    if (reuse == null) addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('S-199: the Active-profile section renders the current values as editable fields', () {
    testWidgets('name, version, effective date, one-entry history, 14 pre-filled editable fields',
        (tester) async {
      await pumpSettings(tester);

      // Active-profile header, from the seeded v1 row. The widget's own
      // provider does not pin a clock, so the date is matched by shape
      // (`yyyy-MM-dd`) rather than by today's value.
      expect(find.text('Active profile'), findsOneWidget);
      expect(find.text('Standard'), findsWidgets);
      expect(find.textContaining(_versionLine(1)), findsOneWidget);

      // One-entry history: the seeded v1, with its date.
      expect(find.text('Version history'), findsOneWidget);
      expect(find.textContaining(_historyLine(1)), findsOneWidget);

      // All 14 fields are real inputs, pre-filled from the current version.
      // Scoped to the section: Settings carries other fields now (D-6's
      // wheel capital and concentration limit, S-248).
      expect(
        find.descendant(
          of: find.byType(RuleProfileSection),
          matching: find.byType(TextFormField),
        ),
        findsNWidgets(14),
      );
      for (final label in const [
        'Profit target (%)',
        'Assign threshold (delta)',
        'Roll band -- base',
        'Roll band -- mid IV',
        'Roll band -- high IV',
        'Mid IV cutoff',
        'High IV cutoff',
        'Tail window (days)',
        'Tail extrinsic threshold (\$)',
        'Minimum IV rank',
        'Minimum annualised yield (%)',
        'Target DTE minimum (days)',
        'Target DTE maximum (days)',
        'Target delta',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(tester.widget<TextFormField>(_field(label)).enabled, isNot(false), reason: label);
      }
      expect(_valueOf(tester, 'Profit target (%)'), '50');
      expect(_valueOf(tester, 'Assign threshold (delta)'), '0.70');
      expect(_valueOf(tester, 'Roll band -- base'), '0.30');
      expect(_valueOf(tester, 'Roll band -- mid IV'), '0.35');
      expect(_valueOf(tester, 'Roll band -- high IV'), '0.40');
      expect(_valueOf(tester, 'Mid IV cutoff'), '40');
      expect(_valueOf(tester, 'High IV cutoff'), '70');
      expect(_valueOf(tester, 'Tail window (days)'), '3');
      expect(_valueOf(tester, 'Tail extrinsic threshold (\$)'), '0.05');
      expect(_valueOf(tester, 'Minimum IV rank'), '30');
      expect(_valueOf(tester, 'Minimum annualised yield (%)'), '20');
      expect(_valueOf(tester, 'Target DTE minimum (days)'), '30');
      expect(_valueOf(tester, 'Target DTE maximum (days)'), '45');
      expect(_valueOf(tester, 'Target delta'), '0.30');

      // Inert until a value changes (D-2).
      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);

      // D-5's mandatory statement, where the save action lives.
      expect(
        find.textContaining('keep the rules they were opened under'),
        findsOneWidget,
      );
    });
  });

  group('S-197: a no-op save at the widget level', () {
    testWidgets(
      're-typing an equal value leaves the action inert and reports no error; a real '
      'edit saves and says so',
      (tester) async {
        await pumpSettings(tester);
        expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);

        // '50.0' over the stored 50 -- value equality is numeric equality
        // (D-2), so there is nothing to save and the UI says nothing about
        // errors.
        await tester.enterText(_field('Profit target (%)'), '50.0');
        await tester.pump();
        expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);
        expect(find.textContaining('must be'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(await repo.getRuleProfileVersions(RuleProfileIds.standard), hasLength(1));

        // A real change enables the action and reports the completed save.
        await tester.enterText(_field('Profit target (%)'), '60');
        await tester.pump();
        await tester.tap(_saveButton);
        await tester.pumpAndSettle();

        expect(find.text('Saved as v2.'), findsOneWidget);
        expect(find.textContaining('must be'), findsNothing);
        expect(await repo.getRuleProfileVersions(RuleProfileIds.standard), hasLength(2));
      },
    );
  });

  group('S-200: save -> v2 -> a new cycle uses it, an open position does not', () {
    testWidgets('the edit lands as v2, the header and history update, and leg A is untouched',
        (tester) async {
      final legAId = await _openPinnedLeg(repo, versionId: RuleProfileVersionIds.standardV1);
      final container = await pumpSettings(tester);

      await tester.enterText(_field('Profit target (%)'), '60');
      await tester.pump();
      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNotNull);

      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      // Exactly one new version, and the section now shows it as active.
      expect(await repo.getRuleProfileVersions(RuleProfileIds.standard), hasLength(2));
      expect(find.textContaining(_versionLine(2)), findsOneWidget);

      // History: both entries, newest first (v2 above v1 in the list).
      expect(find.textContaining(_historyLine(2)), findsOneWidget);
      expect(find.textContaining(_historyLine(1)), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining(_historyLine(2))).dy,
        lessThan(tester.getTopLeft(find.textContaining(_historyLine(1))).dy),
      );

      // Cross-screen: the profile a new cycle resolves is now v2.
      final current = await container.read(currentRuleProfileProvider.future);
      expect(current.versionId, RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 2));
      expect(current.profitTargetPct, 60.0);

      // ...while leg A keeps classifying under the 50% it was opened under.
      container.listen(positionDetailControllerProvider(legAId), (previous, next) {});
      await container.read(positionDetailControllerProvider(legAId).notifier).load(now: _now);
      final detail = container.read(positionDetailControllerProvider(legAId));
      expect(detail.profile.versionId, RuleProfileVersionIds.standardV1);
      expect(detail.bucket, isA<BucketClose>());

      container.listen(todayControllerProvider, (previous, next) {});
      await container.read(todayControllerProvider.notifier).load(now: _now);
      final items = container.read(todayControllerProvider).items;
      expect(items.single.leg.id, legAId);
      expect(items.single.bucket, isA<BucketClose>());
    });
  });

  group('S-201: invalid input shows every violation and writes nothing', () {
    testWidgets('two messages at once, no append; correcting the values saves once',
        (tester) async {
      await pumpSettings(tester);

      await tester.enterText(_field('Profit target (%)'), '0');
      await tester.enterText(_field('Roll band -- base'), '0.9');
      await tester.enterText(_field('Roll band -- mid IV'), '0.3');
      await tester.pump();

      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      // Both visible simultaneously -- not first-only.
      expect(find.text('Profit target must be greater than 0 and at most 100.'), findsOneWidget);
      expect(
        find.text('The base roll band must not exceed the mid roll band.'),
        findsOneWidget,
      );
      expect(await repo.getRuleProfileVersions(RuleProfileIds.standard), hasLength(1));

      await tester.enterText(_field('Profit target (%)'), '60');
      await tester.enterText(_field('Roll band -- base'), '0.30');
      await tester.pump();
      expect(find.text('Profit target must be greater than 0 and at most 100.'), findsNothing);

      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(await repo.getRuleProfileVersions(RuleProfileIds.standard), hasLength(2));
      expect(find.textContaining(_versionLine(2)), findsOneWidget);
    });
  });
}
