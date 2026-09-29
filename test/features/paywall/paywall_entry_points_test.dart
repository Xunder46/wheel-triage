import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/features/paywall/paywall_route.dart';
import 'package:wheel_triage/features/paywall/paywall_screen.dart';
import 'package:wheel_triage/features/settings/settings_screen.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/screener/screener_controller.dart';

import '../../support/fake_purchase_gateway.dart';

/// The trigger line the open paywall is displaying, read off the one widget
/// that carries it. This is what "pushes `/paywall` with the right trigger"
/// means in observable terms: the route arrived, and the sentence it arrived
/// with is the one the entry point had.
String? _renderedTriggerLine(WidgetTester tester) {
  final finder = find.byKey(const ValueKey('paywall-trigger-line'));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

Future<void> _openCycle(InMemoryWheelRepository repo, String ticker) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('30'),
      expiration: DateTime(2027, 1, 15),
      contracts: 1,
      openedAt: DateTime(2026, 9, 1),
      openCreditPerShare: Decimal.parse('1.00'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
}

/// A tall surface so a whole screen is built, not just its first viewport.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The app's own router, on [location], over a book of [openCycles] cycles and
/// a store that reports no entitlement — the free tier at its limit, which is
/// the state that would tempt an app to sell something at launch.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required String location,
  int openCycles = 0,
}) async {
  final repo = InMemoryWheelRepository();
  for (var i = 0; i < openCycles; i++) {
    await _openCycle(repo, 'T$i');
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        purchaseGatewayProvider.overrideWithValue(
          FakePurchaseGateway(snapshot: const EntitlementSnapshot.inactive()),
        ),
      ],
      child: MaterialApp.router(routerConfig: buildAppRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  await container.read(entitlementControllerProvider.notifier).refresh();
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('S-277(a): a fourth-cycle refusal is an entry point', () {
    testWidgets('the screener pushes /paywall carrying the D-24 refusal line', (tester) async {
      _tallSurface(tester);
      final container = await _pumpApp(tester, location: '/screener', openCycles: 3);
      expect(find.byType(PaywallScreen), findsNothing);

      // The screen's fields write into the controller, so setting the
      // controller directly is the same state the fields would have produced.
      container.read(screenerControllerProvider.notifier)
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setSpot(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setDteConvenience(18);
      await tester.pump();

      await tester.tap(find.text('Track this position'));
      await tester.pumpAndSettle();

      final refusal = newCycleRefusalLine(count: 3, limit: kFreeTierOpenCycles);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(_renderedTriggerLine(tester), refusal);
      // The refusal line is still on the screen underneath, so the user can
      // read why they were sent here without dismissing anything.
      expect(find.text(refusal), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-277(b): the Settings row is an entry point', () {
    testWidgets('"See Pro plans" pushes /paywall with the Settings trigger', (tester) async {
      _tallSurface(tester);
      await _pumpApp(tester, location: '/settings');
      expect(find.byType(PaywallScreen), findsNothing);

      await tester.tap(find.text(kSeeProPlansLabel));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(_renderedTriggerLine(tester), kPaywallSettingsLine);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-277(c): a Pro feature is an entry point', () {
    testWidgets('a directly constructed Pro-feature trigger names that feature', (tester) async {
      _tallSurface(tester);
      final router = GoRouter(
        initialLocation: '/probe',
        routes: [
          GoRoute(
            path: '/probe',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showPaywall(context, trigger: const ProFeaturePaywallTrigger('Screenshot scan')),
                  child: const Text('probe'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/paywall',
            builder: (context, state) => PaywallScreen(trigger: paywallTriggerFrom(state.extra)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository()),
            purchaseGatewayProvider.overrideWithValue(FakePurchaseGateway()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('probe'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(_renderedTriggerLine(tester), proFeatureLine('Screenshot scan'));
      expect(tester.takeException(), isNull);
    });
  });

  group('S-277(d): the paywall never opens on launch', () {
    testWidgets('a launch on /positions shows no paywall', (tester) async {
      _tallSurface(tester);
      await _pumpApp(tester, location: '/positions', openCycles: 3);

      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a launch on /first-run shows no paywall', (tester) async {
      _tallSurface(tester);
      await _pumpApp(tester, location: '/first-run', openCycles: 3);

      expect(find.byType(PaywallScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-277: the paywall route itself', () {
    testWidgets('a /paywall reached with no trigger falls back and does not throw', (
      tester,
    ) async {
      _tallSurface(tester);
      await _pumpApp(tester, location: '/paywall');

      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(_renderedTriggerLine(tester), kPaywallSettingsLine);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a /paywall reached with an unexpected extra falls back too', (tester) async {
      _tallSurface(tester);
      final router = GoRouter(
        initialLocation: '/paywall',
        routes: [
          GoRoute(
            path: '/paywall',
            builder: (context, state) => PaywallScreen(trigger: paywallTriggerFrom(state.extra)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository()),
            purchaseGatewayProvider.overrideWithValue(FakePurchaseGateway()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(_renderedTriggerLine(tester), kPaywallSettingsLine);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-277: only the three entry points can open the paywall', () {
    test('context.push(\'/paywall\' occurs in exactly one file', () {
      expect(_filesMentioning(RegExp(r"context\.push\('/paywall'")), [
        'lib/features/paywall/paywall_route.dart',
      ]);
    });

    test('showPaywall( is called from the route helper and the three entry points', () {
      expect(_filesMentioning(RegExp(r'showPaywall\(')), [
        'lib/features/paywall/paywall_route.dart',
        'lib/features/record/record_trade_screen.dart',
        'lib/features/screener/screener_screen.dart',
        'lib/features/settings/pro_plan_section.dart',
      ]);
    });

    test('no screen reads the entitlement or the gateway to decide anything', () {
      // D-28: the paywall is opened because a *state* said so, never because a
      // screen asked the store. The two refusal entry points learn it from
      // `paywallTrigger`; the Settings section reads the entitlement only to
      // render the row, and names no gateway type at all.
      expect(_filesMentioning(RegExp(r'purchaseGatewayProvider')), isEmpty);
      expect(_filesMentioning(RegExp(r'purchases_flutter')), isEmpty);
    });
  });
}

/// Every `.dart` file under `lib/features/` whose text matches [pattern],
/// sorted, so an expectation reads as a list of paths rather than a set.
List<String> _filesMentioning(RegExp pattern) {
  final files = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => pattern.hasMatch(file.readAsStringSync()))
      .map((file) => file.path)
      .toList();
  files.sort();
  return files;
}
