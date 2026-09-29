import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/features/paywall/paywall_screen.dart';
import 'package:wheel_triage/features/settings/settings_screen.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_purchase_gateway.dart';

/// The free tier's count display is `getOpenCycles().length`, so the fixture
/// is a real book of open cycles rather than a stubbed number.
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

/// Everything a section test needs to reach into afterwards.
class _Harness {
  _Harness(this.repo, this.gateway, this.container);

  final InMemoryWheelRepository repo;
  final FakePurchaseGateway gateway;
  final ProviderContainer container;
}

/// Pumps the real Settings screen on the real router, with [snapshot] as the
/// store's answer and a book of [openCycles] open cycles.
Future<_Harness> _pumpSettings(
  WidgetTester tester, {
  required EntitlementSnapshot snapshot,
  int openCycles = 2,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = InMemoryWheelRepository();
  for (var i = 0; i < openCycles; i++) {
    await _openCycle(repo, 'T$i');
  }
  final gateway = FakePurchaseGateway(snapshot: snapshot);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        purchaseGatewayProvider.overrideWithValue(gateway),
        ...extraOverrides,
      ],
      child: MaterialApp.router(routerConfig: buildAppRouter(initialLocation: '/settings')),
    ),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
  await container.read(entitlementControllerProvider.notifier).refresh();
  await tester.pumpAndSettle();

  return _Harness(repo, gateway, container);
}

void main() {
  group('S-285: the Settings plan section, in all six D-34 states', () {
    testWidgets('active annual: the plan, the renewal line, and the two rows', (tester) async {
      await _pumpSettings(
        tester,
        snapshot: EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime(2027, 10, 5),
          willRenew: true,
          purchasedAt: DateTime(2026, 10, 5),
        ),
      );

      expect(find.text('Pro · Annual'), findsOneWidget);
      expect(find.text('Renews Oct 5, 2027'), findsOneWidget);
      expect(find.text(kManageSubscriptionLabel), findsOneWidget);
      expect(find.text(kRestorePurchasesLabel), findsOneWidget);
      // A subscriber is not shown the free tier's count or the pitch to it.
      expect(find.textContaining('open cycles'), findsNothing);
      expect(find.text(kSeeProPlansLabel), findsNothing);
      expect(find.text(kBillingIssueLine), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cancelled subscription reads "Cancels", and is still Pro', (tester) async {
      await _pumpSettings(
        tester,
        snapshot: EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime(2026, 11, 3),
          willRenew: false,
          purchasedAt: DateTime(2026, 10, 5),
        ),
      );

      expect(find.text('Pro · Annual'), findsOneWidget);
      expect(find.text('Cancels Nov 3, 2026'), findsOneWidget);
      expect(find.textContaining('Renews'), findsNothing);
      expect(find.text(kManageSubscriptionLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a billing issue adds the D-34 line without removing Pro', (tester) async {
      await _pumpSettings(
        tester,
        snapshot: EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime(2027, 10, 5),
          willRenew: true,
          billingIssue: true,
          purchasedAt: DateTime(2026, 10, 5),
        ),
      );

      expect(find.text('Pro · Annual'), findsOneWidget);
      expect(find.text('Renews Oct 5, 2027'), findsOneWidget);
      expect(find.text(kBillingIssueLine), findsOneWidget);
      // Still Pro: the management rows stay.
      expect(find.text(kManageSubscriptionLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('active lifetime: no renewal line, no expiry, and no management row', (
      tester,
    ) async {
      await _pumpSettings(
        tester,
        snapshot: EntitlementSnapshot.active(
          planKind: ProPlanKind.lifetime,
          purchasedAt: DateTime(2026, 3, 3),
        ),
      );

      expect(find.text('Pro · Lifetime'), findsOneWidget);
      expect(find.text('Purchased Mar 3, 2026'), findsOneWidget);
      expect(find.textContaining('Renews'), findsNothing);
      expect(find.textContaining('Cancels'), findsNothing);
      // There is no subscription to manage, so the row is absent entirely.
      expect(find.text(kManageSubscriptionLabel), findsNothing);
      expect(find.text(kRestorePurchasesLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inactive with 2 open cycles: "Free · 2 of 3 open cycles"', (tester) async {
      await _pumpSettings(
        tester,
        snapshot: const EntitlementSnapshot.inactive(),
        openCycles: 2,
      );

      expect(find.text('Free · 2 of 3 open cycles'), findsOneWidget);
      expect(find.text(kFreePlanDetailLine), findsOneWidget);
      expect(find.text(kSeeProPlansLabel), findsOneWidget);
      expect(find.text(kRestorePurchasesLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inactive past the limit: "Free · 5 open cycles"', (tester) async {
      await _pumpSettings(
        tester,
        snapshot: const EntitlementSnapshot.inactive(),
        openCycles: 5,
      );

      expect(find.text('Free · 5 open cycles'), findsOneWidget);
      expect(find.text(kFreePlanDetailLine), findsOneWidget);
      expect(find.text(kSeeProPlansLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unknown: an honest "Pro status unavailable", never a free claim', (
      tester,
    ) async {
      await _pumpSettings(tester, snapshot: const EntitlementSnapshot.unknown());

      expect(find.text(kProStatusUnavailableLine), findsOneWidget);
      expect(find.text(kProStatusUnavailableDetailLine), findsOneWidget);
      expect(find.text(kRestorePurchasesLabel), findsOneWidget);
      // Never inferred as free, so no count and no pitch.
      expect(find.textContaining('open cycles'), findsNothing);
      expect(find.text(kSeeProPlansLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the section sits above "Defaults for new entries"', (tester) async {
      await _pumpSettings(tester, snapshot: const EntitlementSnapshot.inactive());

      final sectionTop = tester.getTopLeft(find.text('Wheel Triage Pro')).dy;
      final defaultsTop = tester.getTopLeft(find.text('Defaults for new entries')).dy;
      expect(sectionTop, lessThan(defaultsTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unresolved book shows no count, rather than an invented zero', (
      tester,
    ) async {
      // A read that has not answered yet. The row must not print "0 of 3":
      // that is a claim about the user's book that nothing has verified.
      await _pumpSettings(
        tester,
        snapshot: const EntitlementSnapshot.inactive(),
        extraOverrides: [
          openCycleCountProvider.overrideWith((ref) => Completer<int>().future),
        ],
      );

      expect(find.textContaining('0 of 3'), findsNothing);
      expect(find.text(kFreePlanCountPendingLine), findsOneWidget);
      expect(find.text(kFreePlanDetailLine), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-285: "See Pro plans" opens the paywall from Settings', () {
    testWidgets('it pushes /paywall with the generic Settings trigger', (tester) async {
      await _pumpSettings(tester, snapshot: const EntitlementSnapshot.inactive());

      await tester.tap(find.text(kSeeProPlansLabel));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsOneWidget);
      final line = tester.widget<Text>(find.byKey(const ValueKey('paywall-trigger-line'))).data;
      expect(line, kPaywallSettingsLine);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-286: Manage subscription and Restore purchases from Settings', () {
    testWidgets('Manage subscription asks the store once and opens nothing else', (
      tester,
    ) async {
      final harness = await _pumpSettings(
        tester,
        snapshot: EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime(2027, 10, 5),
          willRenew: true,
        ),
      );

      await tester.tap(find.text(kManageSubscriptionLabel));
      await tester.pumpAndSettle();

      expect(harness.gateway.showManageSubscriptionsCount, 1);
      expect(harness.gateway.restoreCount, 0);
      expect(harness.gateway.purchaseCount, 0);
      // The section never configures the store -- launch did, and this test
      // pumps no launch path -- and managing is a single store call.
      expect(harness.gateway.calls, ['currentEntitlement', 'showManageSubscriptions']);
      // Nothing navigated, and the plan row is untouched.
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.text('Pro · Annual'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Restore purchases asks the store once and shows the D-32 answer', (
      tester,
    ) async {
      final harness = await _pumpSettings(
        tester,
        snapshot: EntitlementSnapshot.active(
          planKind: ProPlanKind.annual,
          expiresAt: DateTime(2027, 10, 5),
          willRenew: true,
        ),
      );
      harness.gateway.restoreOutcome = const PurchasePurchased();

      await tester.tap(find.text(kRestorePurchasesLabel));
      await tester.pumpAndSettle();

      expect(harness.gateway.restoreCount, 1);
      expect(harness.gateway.showManageSubscriptionsCount, 0);
      expect(find.text(kRestoredLine), findsOneWidget);
      // The store's answer was the same entitlement, so the row is unchanged.
      expect(find.text('Pro · Annual'), findsOneWidget);
      expect(find.text('Renews Oct 5, 2027'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a restore that finds nothing says so, and stays on the free tier', (
      tester,
    ) async {
      final harness = await _pumpSettings(
        tester,
        snapshot: const EntitlementSnapshot.inactive(),
        openCycles: 2,
      );
      // RevenueCat's own "nothing to offer up" answer.
      harness.gateway.restoreOutcome = const PurchaseCancelled();

      await tester.tap(find.text(kRestorePurchasesLabel));
      await tester.pumpAndSettle();

      expect(harness.gateway.restoreCount, 1);
      expect(find.text(kNothingToRestoreLine), findsOneWidget);
      expect(find.text('Free · 2 of 3 open cycles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
