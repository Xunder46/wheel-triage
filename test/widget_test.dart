// Smoke test: the app boots without throwing and reaches its documented
// initial route (`/positions`, see lib/core/app_router.dart) without a red
// error screen. Uses `InMemoryWheelRepository` — the app's own
// `ProviderScope` override (in `main()`) is not exercised by a widget test,
// since that would require a real Drift/sqlite native library.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/main.dart';
import 'package:wheel_triage/state/repository_providers.dart';

void main() {
  testWidgets('App launches without throwing, reaches the Positions screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
        child: WheelTriageApp(router: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Positions'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'App launches to the first-run explainer on a fresh install '
    '(!firstRunExplainerShown), never throwing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
          child: WheelTriageApp(router: buildAppRouter(initialLocation: '/first-run')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What this does'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
