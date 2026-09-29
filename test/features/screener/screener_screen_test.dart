import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/features/paywall/paywall_screen.dart';
import 'package:wheel_triage/features/screener/screener_screen.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/screener/screener_controller.dart';

import '../../support/fake_purchase_gateway.dart';

void main() {
  testWidgets(
    '"Sorting score" label is used verbatim, and is not the largest element on screen '
    '(Acceptance Criteria; docs/conventions.md §4)',
    (tester) async {
      // A tall test surface so the whole scrollable form -- including the
      // outputs card at the bottom -- is actually built (a `ListView`'s
      // sliver mechanics only build children within the viewport/cache
      // extent, list-backed or not), not just scrolled-to.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
          child: const MaterialApp(home: ScreenerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sorting score'), findsOneWidget);
      // Never "rating" or "grade" -- see docs/conventions.md §4.
      expect(find.textContaining('rating', findRichText: true), findsNothing);
      expect(find.textContaining('grade', findRichText: true), findsNothing);

      final scoreLabelSize = tester.getSize(find.text('Sorting score'));
      final titleSize = tester.getSize(find.text('Outputs'));
      // The score label's own text is not larger than a plain section
      // title elsewhere on the same screen -- a crude but effective check
      // that it isn't the visually dominant element.
      expect(scoreLabelSize.height, lessThanOrEqualTo(titleSize.height + 4));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'S-236(b): a refused call save shows the refusal line in place, not a "Position tracked." '
    'confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: ScreenerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // The screen's fields write into the controller, so setting the
      // controller directly is the same state the fields would have produced.
      ProviderScope.containerOf(tester.element(find.byType(ScreenerScreen)))
          .read(screenerControllerProvider.notifier)
        ..setTicker('ccl')
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('19'))
        ..setSpot(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setDteConvenience(18);
      await tester.pump();

      await tester.tap(find.text('Track this position'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Calls are recorded against shares held from an assignment, and there '
          'are no CCL shares on record.',
        ),
        findsOneWidget,
      );
      expect(find.text('Position tracked.'), findsNothing);
      expect(await repo.getOpenLegs(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  group('S-276: a fourth-cycle refusal is answered on the screen', () {
    testWidgets('the D-24 line renders and the paywall opens carrying it', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      for (var i = 0; i < kFreeTierOpenCycles; i++) {
        final underlying = await repo.getOrCreateUnderlying('T$i');
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
      final gateway = FakePurchaseGateway(snapshot: const EntitlementSnapshot.inactive());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            purchaseGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp.router(routerConfig: buildAppRouter(initialLocation: '/screener')),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(ScreenerScreen)));
      await container.read(entitlementControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

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

      final refusal = newCycleRefusalLine(count: kFreeTierOpenCycles, limit: kFreeTierOpenCycles);
      expect(await repo.getOpenCycles(), hasLength(kFreeTierOpenCycles));
      expect(find.text(refusal), findsWidgets);
      expect(find.text('Position tracked.'), findsNothing);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('paywall-trigger-line'))).data,
        refusal,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a later, unrelated failure after the paywall is dismissed does not reopen it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = InMemoryWheelRepository();
      for (var i = 0; i < kFreeTierOpenCycles; i++) {
        final underlying = await repo.getOrCreateUnderlying('T$i');
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
      final gateway = FakePurchaseGateway(snapshot: const EntitlementSnapshot.inactive());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            purchaseGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp.router(routerConfig: buildAppRouter(initialLocation: '/screener')),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(ScreenerScreen)));
      await container.read(entitlementControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      final controller = container.read(screenerControllerProvider.notifier)
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setSpot(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setDteConvenience(18);
      await tester.pump();

      await tester.tap(find.text('Track this position'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('paywall-not-now')));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);

      // A second tap now fails for an unrelated reason: the trigger was
      // consumed by the paywall, so it must not reopen (R12).
      controller.setTicker('');
      await tester.pump();
      await tester.tap(find.text('Track this position'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsNothing);
      expect(
        find.text('Enter ticker, strike, stock price, credit, and expiration first.'),
        findsOneWidget,
      );
      expect(controller.state.paywallTrigger, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
