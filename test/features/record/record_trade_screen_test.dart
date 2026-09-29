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
import 'package:wheel_triage/features/record/record_trade_screen.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/record/record_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/widgets/help_chip.dart';

import '../../support/fake_purchase_gateway.dart';

final _now = DateTime(2026, 9, 28, 10); // a Monday

Future<Leg> _openCycle(
  InMemoryWheelRepository repo, {
  required String ticker,
  required DateTime openedAt,
  bool assigned = false,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('30'),
      expiration: DateTime(2026, 11, 20),
      contracts: 1,
      openedAt: openedAt,
      openCreditPerShare: Decimal.parse('1.00'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  if (assigned) {
    await repo.recordAssignment(
      legId: result.leg.id,
      shareLot: NewShareLotInput(
        assignedAt: openedAt.add(const Duration(days: 5)),
        assignmentStrike: Decimal.parse('30'),
        contracts: 1,
      ),
    );
  }
  return result.leg;
}

void main() {
  late InMemoryWheelRepository repo;

  setUp(() => repo = InMemoryWheelRepository());

  List<Override> overrides() => [
    wheelRepositoryProvider.overrideWithValue(repo),
    recordControllerProvider.overrideWith((ref) => RecordController(ref, now: _now)),
  ];

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const MaterialApp(home: RecordTradeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  RecordController controllerOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(RecordTradeScreen)),
  ).read(recordControllerProvider.notifier);

  group('S-229: recently used ticker chips', () {
    testWidgets('render most-recent-first and tapping one sets the ticker field', (
      tester,
    ) async {
      await _openCycle(repo, ticker: 'CCL', openedAt: _now.subtract(const Duration(days: 10)));
      await _openCycle(repo, ticker: 'KO', openedAt: _now.subtract(const Duration(days: 6)));
      await pumpScreen(tester);

      expect(find.widgetWithText(ActionChip, 'CCL'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'KO'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'KO'));
      await tester.pumpAndSettle();

      expect(controllerOf(tester).state.ticker, 'KO');
      expect(find.widgetWithText(TextFormField, 'KO'), findsOneWidget);
    });
  });

  group('S-230: expiration chips', () {
    testWidgets('the next four Fridays are chips, the farthest is selected, DTE is shown', (
      tester,
    ) async {
      await pumpScreen(tester);

      for (final label in ['Oct 2', 'Oct 9', 'Oct 16', 'Oct 23']) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
      expect(find.text('Other date…'), findsOneWidget);
      // Today is Monday 2026-09-28, so the farthest chip (Oct 23) is 25 days out.
      expect(find.text('DTE: 25 days'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Oct 23')).selected,
        isTrue,
      );
    });

    testWidgets('tapping a chip moves the expiration and the DTE', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Oct 9'));
      await tester.pumpAndSettle();

      expect(controllerOf(tester).state.expiration, DateTime(2026, 10, 9));
      expect(find.text('DTE: 11 days'), findsOneWidget);
    });
  });

  group('S-231: the credit bound on Record', () {
    testWidgets('a put above its strike shows the bound message, with no stock price', (
      tester,
    ) async {
      await pumpScreen(tester);
      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('34'));
      await tester.pumpAndSettle();

      expect(find.textContaining("A premium can't exceed the strike price"), findsOneWidget);
    });

    testWidgets('a call with no stock price shows no bound message', (tester) async {
      await pumpScreen(tester);
      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('50'));
      await tester.pumpAndSettle();

      expect(find.textContaining("A premium can't exceed"), findsNothing);
    });
  });

  group('S-232: total per contract on Record', () {
    testWidgets('the credit label follows the preference', (tester) async {
      await pumpScreen(tester);
      expect(find.widgetWithText(TextFormField, 'Credit (\$ per share)'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Credit (\$ total for contract)'),
        findsOneWidget,
      );
    });
  });

  group('S-233: a call explains the cycle it will attach to', () {
    testWidgets('the pre-save line names the shares and the wheel-adjusted basis', (
      tester,
    ) async {
      await _openCycle(
        repo,
        ticker: 'T',
        openedAt: _now.subtract(const Duration(days: 40)),
        assigned: true,
      );
      await pumpScreen(tester);
      final controller = controllerOf(tester);
      controller
        ..setTicker('T')
        ..setSide(OptionType.call);
      await tester.pumpAndSettle();

      expect(find.textContaining('100 shares'), findsOneWidget);
      expect(find.textContaining('29.00'), findsOneWidget);
    });
  });

  group('S-234: a call with no shares on record is refused', () {
    testWidgets('the D-12 line renders and the form keeps its values', (tester) async {
      await _openCycle(repo, ticker: 'CCL', openedAt: _now.subtract(const Duration(days: 10)));
      await pumpScreen(tester);
      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('28'))
        ..setCredit(Decimal.parse('0.30'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Calls are recorded against shares held from an assignment, and there '
          'are no CCL shares on record.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Record trade'));
      await tester.pumpAndSettle();

      expect(controller.state.ticker, 'CCL');
      expect(controller.state.strike, Decimal.parse('28'));
      expect(controller.state.credit, Decimal.parse('0.30'));
      expect(await repo.getOpenLegs(), hasLength(1));
    });
  });

  group('S-237: Record\'s preview figures', () {
    testWidgets('yield, capital committed, definitions, semantics and the screener link', (
      tester,
    ) async {
      await pumpScreen(tester);
      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 16))
        ..setContracts(2);
      await tester.pumpAndSettle();

      expect(find.text('36%'), findsOneWidget);
      expect(find.text('\$3,800'), findsOneWidget);
      expect(find.text('credit ÷ strike × 365 ÷ DTE'), findsOneWidget);
      expect(find.text('strike × 100 × contracts'), findsOneWidget);
      expect(find.text('Run the numbers first in the screener'), findsOneWidget);

      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label)
          .whereType<String>()
          .toList();
      expect(labels, contains('Annualised yield 36 percent'));
      expect(labels, contains('Capital committed \$3,800 dollars'));
    });

    testWidgets('the reminder line names the milestones that will fire', (tester) async {
      await pumpScreen(tester);
      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 16));
      await tester.pumpAndSettle();

      // 18 days out, so 21 has already passed for a Monday-10:00 "now".
      expect(find.text('Reminders: 7 and 0 days before expiration.'), findsOneWidget);
    });
  });

  group('S-228: the minimum path saves and lands back on the list', () {
    testWidgets('one underlying, one cycle, one leg and a confirmation', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp.router(
            routerConfig: buildAppRouter(initialLocation: '/record'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 16))
        ..setContracts(2);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record trade'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Recorded \$19.00 CCL put'), findsOneWidget);
      expect(find.byType(RecordTradeScreen), findsNothing);

      final leg = (await repo.getOpenLegs()).single;
      expect(leg.strike, Decimal.parse('19'));
      expect(leg.contracts, 2);
      expect(leg.openCreditPerShare, Decimal.parse('0.34'));
      expect(leg.acceptsAssignment, isTrue);
    });
  });

  group('S-082: record_trade_screen.dart chips', () {
    testWidgets('every §C2 topic this screen shows is present', (tester) async {
      await pumpScreen(tester);
      final controller = controllerOf(tester);
      controller
        ..setSide(OptionType.call)
        ..setShowOptional(true);
      await tester.pumpAndSettle();

      final present = tester
          .widgetList<HelpChip>(find.byType(HelpChip))
          .map((c) => c.topicId)
          .toSet();
      final missing = const [
        'ticker',
        'side',
        'strike',
        'expiration',
        'credit',
        'contracts',
        'stock_price',
        'iv',
        'iv_rank',
        'annualised_yield',
      ].where((id) => !present.contains(id)).toList();
      expect(missing, isEmpty, reason: 'missing HelpChip(s) for: $missing');
    });
  });

  group('S-276: a fourth-cycle refusal is answered on the screen', () {
    testWidgets('the D-24 line renders and the paywall opens carrying it', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // The free tier, at its limit.
      for (var i = 0; i < kFreeTierOpenCycles; i++) {
        await _openCycle(repo, ticker: 'T$i', openedAt: _now.subtract(const Duration(days: 10)));
      }
      final gateway = FakePurchaseGateway(snapshot: const EntitlementSnapshot.inactive());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(),
            purchaseGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp.router(routerConfig: buildAppRouter(initialLocation: '/record')),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(RecordTradeScreen)));
      await container.read(entitlementControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 16))
        ..setContracts(2);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record trade'));
      await tester.pumpAndSettle();

      final refusal = newCycleRefusalLine(count: kFreeTierOpenCycles, limit: kFreeTierOpenCycles);
      // Nothing was recorded, and the reason is on the screen it was refused
      // on -- not only on the paywall.
      expect(await repo.getOpenLegs(), hasLength(kFreeTierOpenCycles));
      expect(find.text(refusal), findsWidgets);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('paywall-trigger-line'))).data,
        refusal,
      );
      // The screen itself decided nothing about Pro: it read a trigger the
      // state layer produced, and it consumed it -- the paywall owns the
      // trigger from here, so it must not fire again (R12).
      expect(controller.state.paywallTrigger, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a later, unrelated failure after the paywall is dismissed does not reopen it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (var i = 0; i < kFreeTierOpenCycles; i++) {
        await _openCycle(repo, ticker: 'T$i', openedAt: _now.subtract(const Duration(days: 10)));
      }
      final gateway = FakePurchaseGateway(snapshot: const EntitlementSnapshot.inactive());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(),
            purchaseGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp.router(routerConfig: buildAppRouter(initialLocation: '/record')),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(RecordTradeScreen)));
      await container.read(entitlementControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      final controller = controllerOf(tester);
      controller
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 16))
        ..setContracts(2);
      await tester.pumpAndSettle();

      // The gate refuses, and the paywall opens.
      await tester.tap(find.text('Record trade'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      // The user declines and comes back to the form...
      await tester.tap(find.byKey(const ValueKey('paywall-not-now')));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);

      // ...then fails for an unrelated reason. The trigger was consumed, so
      // the paywall must not reopen on a failure that has nothing to do with
      // the free tier (R12).
      controller.setTicker('');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record trade'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsNothing);
      expect(
        find.text('Enter ticker, strike, credit, expiration, and contracts first.'),
        findsOneWidget,
      );
      expect(controller.state.paywallTrigger, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
