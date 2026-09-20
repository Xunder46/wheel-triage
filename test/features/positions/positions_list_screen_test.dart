import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/features/positions/positions_list_screen.dart';
import 'package:wheel_triage/state/repository_providers.dart';

void main() {
  testWidgets('S-023: empty positions list renders an empty state, not a blank screen', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/positions',
      routes: [GoRoute(path: '/positions', builder: (context, state) => const PositionsListScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No open positions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('S-160: 30-day export reminder on the positions list', () {
    Widget buildApp(InMemoryWheelRepository repo) {
      final router = GoRouter(
        initialLocation: '/positions',
        routes: [GoRoute(path: '/positions', builder: (context, state) => const PositionsListScreen())],
      );
      return ProviderScope(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('shows once when an open position is 31+ days old and never exported', (tester) async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('OLD');
      await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: DateTime.now().add(const Duration(days: 20)),
          contracts: 1,
          openedAt: DateTime.now().subtract(const Duration(days: 40)),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsNothing);
      final prefs = await repo.getPreferences();
      expect(prefs.exportReminderDismissed, isTrue);
    });

    testWidgets('dismissing is permanent -- rebuilding the screen never shows it again', (tester) async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('OLD');
      await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: DateTime.now().add(const Duration(days: 20)),
          contracts: 1,
          openedAt: DateTime.now().subtract(const Duration(days: 400)), // "another 31+ days" and then some
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          openCreditPerShare: Decimal.parse('0.60'),
        ),
      );
      final prefs = await repo.getPreferences();
      await repo.updatePreferences(prefs.copyWith(exportReminderDismissed: true));

      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('does not show when an open position is fewer than 30 days old', (tester) async {
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('NEW');
      await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: DateTime.now().add(const Duration(days: 20)),
          contracts: 1,
          openedAt: DateTime.now().subtract(const Duration(days: 5)),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsNothing);
    });
  });

  testWidgets('S-205: returning to /positions reloads the list, no manual reload needed', (tester) async {
    final repo = InMemoryWheelRepository();
    final router = GoRouter(
      initialLocation: '/positions',
      routes: [
        GoRoute(path: '/positions', builder: (context, state) => const PositionsListScreen()),
        GoRoute(path: '/screener', builder: (context, state) => _TrackingScreenerStub(repo: repo)),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No open positions'), findsOneWidget);

    // Push the screener the way the app does, so the list stays alive
    // underneath rather than being rebuilt from scratch.
    await tester.tap(find.byTooltip('Screener'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track this position'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No open positions'), findsNothing);
    expect(find.textContaining('NEWT'), findsOneWidget);
  });
}

/// Stands in for the screener's "Track this position" (S-120): it writes the
/// cycle + first leg and returns to the list the way the real screen does —
/// a push-then-pop that leaves the list alive underneath, so only a
/// refresh-on-arrival can show the new position.
class _TrackingScreenerStub extends StatelessWidget {
  const _TrackingScreenerStub({required this.repo});

  final InMemoryWheelRepository repo;

  Future<void> _trackAndReturn(BuildContext context) async {
    final underlying = await repo.getOrCreateUnderlying('NEWT');
    await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('40'),
        expiration: DateTime.now().add(const Duration(days: 30)),
        contracts: 1,
        openedAt: DateTime.now(),
        openCreditPerShare: Decimal.parse('0.75'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => _trackAndReturn(context),
        child: const Text('Track this position'),
      ),
    ),
  );
}
