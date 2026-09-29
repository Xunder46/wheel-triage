// Pro Wave 2, Phase 4 (D-29, S-270): the three refresh points. This file owns
// the launch and resume halves -- the controller's own tests
// (`test/state/entitlements/entitlement_controller_test.dart`) own the read
// itself and the store-listener half.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/domain/models/entitlement_status.dart';
import 'package:wheel_triage/domain/models/pro_plan_kind.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/widgets/entitlement_lifecycle_scope.dart';

import '../support/fake_purchase_gateway.dart';

void main() {
  late InMemoryWheelRepository repo;
  late FakePurchaseGateway gateway;

  setUp(() {
    repo = InMemoryWheelRepository();
    gateway = FakePurchaseGateway();
  });

  Widget harness() => ProviderScope(
    overrides: [
      wheelRepositoryProvider.overrideWithValue(repo),
      purchaseGatewayProvider.overrideWithValue(gateway),
    ],
    child: const EntitlementLifecycleScope(child: SizedBox()),
  );

  /// Dispatches a lifecycle change exactly as the engine does -- through the
  /// platform channel, so the observer path (not a direct call to a protected
  /// method) is what the test exercises.
  Future<void> dispatch(WidgetTester tester, AppLifecycleState state) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (ByteData? data) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('S-270: exactly one read at launch', (tester) async {
    await tester.pumpWidget(harness());

    expect(gateway.configureCount, 1);
    expect(gateway.currentEntitlementCount, 1);
    // The successful read was written to the cache.
    expect((await repo.getEntitlementCache()).checkedAt, isNotNull);
  });

  testWidgets('S-270: one more read on each resume, and none on inactive or paused', (tester) async {
    gateway.snapshot = const EntitlementSnapshot.inactive();
    await tester.pumpWidget(harness());
    expect(gateway.currentEntitlementCount, 1);

    // The store turns Pro on between the launch read and the next resume.
    gateway.snapshot = EntitlementSnapshot.active(
      planKind: ProPlanKind.annual,
      expiresAt: DateTime.utc(2027, 6, 1),
      willRenew: true,
    );

    await dispatch(tester, AppLifecycleState.inactive);
    expect(gateway.currentEntitlementCount, 1, reason: 'leaving the foreground is not a refresh point');

    await dispatch(tester, AppLifecycleState.resumed);
    expect(gateway.currentEntitlementCount, 2);

    final container = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
    expect(container.read(entitlementControllerProvider).status, EntitlementStatus.active);
    expect((await repo.getEntitlementCache()).planKind, ProPlanKind.annual);

    await dispatch(tester, AppLifecycleState.paused);
    expect(gateway.currentEntitlementCount, 2);

    await dispatch(tester, AppLifecycleState.resumed);
    expect(gateway.currentEntitlementCount, 3);
  });

  testWidgets('S-270: a disposed scope stops observing', (tester) async {
    await tester.pumpWidget(harness());
    expect(gateway.currentEntitlementCount, 1);

    await tester.pumpWidget(const SizedBox());
    await dispatch(tester, AppLifecycleState.resumed);

    expect(gateway.currentEntitlementCount, 1);
  });
}
