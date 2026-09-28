import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/features/roll/roll_planner_screen.dart';
import 'package:wheel_triage/state/repository_providers.dart';

Future<String> _makeLeg(WheelRepository repo, DateTime expiration) async {
  final underlying = await repo.getOrCreateUnderlying('WRN');
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('45'),
      expiration: expiration,
      contracts: 1,
      openedAt: DateTime(2026, 1, 1),
      openCreditPerShare: Decimal.parse('0.60'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  return result.leg.id;
}

Future<void> _pumpRollPlanner(WidgetTester tester, WheelRepository repo, String legId) async {
  final router = GoRouter(
    initialLocation: '/roll',
    routes: [GoRoute(path: '/roll', builder: (context, state) => RollPlannerScreen(legId: legId))],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add candidate'));
  await tester.pumpAndSettle();
}

Future<void> _enterCandidate(
  WidgetTester tester, {
  required String strike,
  required String debit,
  required String credit,
}) async {
  await tester.enterText(find.byType(TextField).at(0), strike);
  await tester.enterText(find.byType(TextField).at(1), debit);
  await tester.enterText(find.byType(TextField).at(2), credit);
  await tester.tap(find.widgetWithText(FilledButton, 'Add'));
  await tester.pumpAndSettle();
}

void main() {
  group('S-056: roll planner\'s existing picker gains the non-Friday warning', () {
    testWidgets('outcome A: default candidate date on a Friday leg -> no warning', (tester) async {
      final repo = InMemoryWheelRepository();
      // 2026-01-02 is a Friday; +14 days lands on another Friday.
      final legId = await _makeLeg(repo, DateTime(2026, 1, 2));
      await _pumpRollPlanner(tester, repo, legId);

      expect(find.textContaining('Not a Friday'), findsNothing);
    });

    testWidgets('outcome B: default candidate date on a non-Friday leg -> warns, not blocked', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      // 2026-01-07 is a Wednesday; +14 days lands on another Wednesday.
      final legId = await _makeLeg(repo, DateTime(2026, 1, 7));
      await _pumpRollPlanner(tester, repo, legId);

      expect(find.textContaining('Not a Friday'), findsOneWidget);
      // Not blocked -- the "Add" action is still present and enabled.
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
    });
  });

  group('S-205/S-206: roll planner can add multiple candidates through the UI', () {
    testWidgets('S-205: after the first add, the dialog can be reopened and a second candidate added', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      final legId = await _makeLeg(repo, DateTime(2026, 1, 2));

      await _pumpRollPlanner(tester, repo, legId);
      await _enterCandidate(tester, strike: '46', debit: '0.25', credit: '0.80');

      expect(find.text('New candidate'), findsNothing);
      expect(find.text('New strike \$46 · exp 2026-01-16'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add candidate'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Add candidate')).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add candidate'));
      await tester.pumpAndSettle();

      expect(find.text('New candidate'), findsOneWidget);

      await _enterCandidate(tester, strike: '47', debit: '0.30', credit: '0.95');

      expect(find.text('New strike \$46 · exp 2026-01-16'), findsOneWidget);
      expect(find.text('New strike \$47 · exp 2026-01-16'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add candidate'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Add candidate')).onPressed, isNotNull);
    });

    testWidgets('S-206: the add button disables only after the third candidate is added', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      final legId = await _makeLeg(repo, DateTime(2026, 1, 2));

      await _pumpRollPlanner(tester, repo, legId);
      await _enterCandidate(tester, strike: '46', debit: '0.25', credit: '0.80');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add candidate'));
      await tester.pumpAndSettle();
      await _enterCandidate(tester, strike: '47', debit: '0.30', credit: '0.95');

      final addButton = find.widgetWithText(OutlinedButton, 'Add candidate');
      expect(addButton, findsOneWidget);
      expect(tester.widget<OutlinedButton>(addButton).onPressed, isNotNull);

      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await _enterCandidate(tester, strike: '48', debit: '0.35', credit: '1.05');

      await tester.scrollUntilVisible(find.text('New strike \$48 · exp 2026-01-16'), 200);
      await tester.pumpAndSettle();

      expect(find.text('New strike \$48 · exp 2026-01-16'), findsOneWidget);
      await tester.fling(find.byType(ListView), const Offset(0, 600), 1000);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(addButton).onPressed, isNull);
    });
  });
}
