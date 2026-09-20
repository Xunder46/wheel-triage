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
}
