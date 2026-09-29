import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/core/disclaimer.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/features/onboarding/first_run_explainer.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';

void main() {
  group('S-072: first-run explainer -- shows once, skippable', () {
    testWidgets('the 3 cards are reachable, and skipping sets firstRunExplainerShown=true', (
      tester,
    ) async {
      final repo = InMemoryWheelRepository();
      final router = GoRouter(
        initialLocation: '/first-run',
        routes: [
          GoRoute(path: '/first-run', builder: (context, state) => const FirstRunExplainerScreen()),
          GoRoute(
            path: '/positions',
            builder: (context, state) => const Scaffold(body: Text('Positions Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What this does'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('The loop'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('The rules are yours'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final prefs = await repo.getPreferences();
      expect(prefs.firstRunExplainerShown, isTrue);
      // No route to pop back to (this was the initial route) -- lands on
      // /positions.
      expect(find.text('Positions Screen'), findsOneWidget);
    });

    testWidgets('skipping from the first card also sets the flag and exits', (tester) async {
      final repo = InMemoryWheelRepository();
      final router = GoRouter(
        initialLocation: '/first-run',
        routes: [
          GoRoute(path: '/first-run', builder: (context, state) => const FirstRunExplainerScreen()),
          GoRoute(
            path: '/positions',
            builder: (context, state) => const Scaffold(body: Text('Positions Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final prefs = await repo.getPreferences();
      expect(prefs.firstRunExplainerShown, isTrue);
      expect(find.text('Positions Screen'), findsOneWidget);
    });
  });

  group('S-073: first-run explainer reachable again from Settings', () {
    testWidgets(
      'reopening via Settings shows the same explainer; dismissing it does not '
      're-arm the automatic trigger (flag stays true, unchanged)',
      (tester) async {
        // Tall enough that Settings' whole list -- the profile section, D-6's
        // "Your book", the export block, the milestone editor, the explainer
        // button and D-18's disclaimer -- is built without scrolling.
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryWheelRepository();
        final defaults = await repo.getPreferences();
        await repo.updatePreferences(defaults.copyWith(firstRunExplainerShown: true));

        final container = ProviderContainer(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        container.listen(preferencesControllerProvider, (previous, next) {});
        await container.read(preferencesControllerProvider.notifier).ready;

        // The full app router -- Settings pushes '/first-run' on top,
        // exactly as the real "How this app works" button does.
        final router = buildAppRouter();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('How this app works'), findsOneWidget);

        await tester.tap(find.text('How this app works'));
        await tester.pumpAndSettle();
        expect(find.text('What this does'), findsOneWidget);

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        final prefs = await repo.getPreferences();
        expect(prefs.firstRunExplainerShown, isTrue); // unchanged -- was already true

        // Popped back to Settings (this entry was pushed, so it can pop),
        // not dumped onto /positions -- proving this path never behaves
        // like the automatic first-launch trigger.
        expect(find.text('How this app works'), findsOneWidget);
      },
    );
  });

  group('S-249: the disclaimer is on every card of the explainer', () {
    testWidgets('it is present on the first card and survives a page turn', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: FirstRunExplainerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Outside the PageView, so it is not one card's body: the first card
      // and the second both show it, unchanged.
      expect(find.text(kAppDisclaimer), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('The loop'), findsOneWidget);
      expect(find.text(kAppDisclaimer), findsOneWidget);
    });
  });
}
