import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/entitlements/new_cycle_gate.dart';
import 'package:wheel_triage/state/export/export_controller.dart';
import 'package:wheel_triage/state/paywall/paywall_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_purchase_gateway.dart';

/// Records what crossed the purchase seam and, separately, the *shape* of
/// every argument it was handed (S-288).
///
/// It is a decorator around the app's own gateway double rather than a
/// replacement, so the calls it records are the calls the real wiring makes —
/// the point of the scenario is that the app's own paths never hand the seam a
/// trade.
class RecordingPurchaseGateway implements PurchaseGateway {
  RecordingPurchaseGateway(this._inner);

  final FakePurchaseGateway _inner;

  /// Every argument ever passed to a seam method, by method name. `purchase`
  /// is the only method that takes one, and a `String` is the only thing that
  /// can appear here.
  final List<({String method, Object? argument})> arguments = [];

  List<String> get calls => _inner.calls;

  List<String> get purchasedProductIds => _inner.purchasedProductIds;

  @override
  Future<void> configure() {
    arguments.add((method: 'configure', argument: null));
    return _inner.configure();
  }

  @override
  Future<ProOfferings?> loadOfferings() {
    arguments.add((method: 'loadOfferings', argument: null));
    return _inner.loadOfferings();
  }

  @override
  Future<EntitlementSnapshot> currentEntitlement() {
    arguments.add((method: 'currentEntitlement', argument: null));
    return _inner.currentEntitlement();
  }

  @override
  Future<PurchaseOutcome> purchase(String productId) {
    arguments.add((method: 'purchase', argument: productId));
    return _inner.purchase(productId);
  }

  @override
  Future<PurchaseOutcome> restore() {
    arguments.add((method: 'restore', argument: null));
    return _inner.restore();
  }

  @override
  Future<void> showManageSubscriptions() {
    arguments.add((method: 'showManageSubscriptions', argument: null));
    return _inner.showManageSubscriptions();
  }

  @override
  void addEntitlementListener(void Function(EntitlementSnapshot) listener) {
    _inner.addEntitlementListener(listener);
  }
}

/// The six method names the seam is allowed to expose, in the order the
/// driven flow reaches them.
const List<String> _allowedCalls = [
  'configure',
  'currentEntitlement',
  'loadOfferings',
  'purchase',
  'restore',
  'showManageSubscriptions',
];

Future<Leg> _seedBook(InMemoryWheelRepository repo, String ticker) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final cycle = await repo.createCycle(
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
  await repo.appendSnapshot(
    NewSnapshotInput(
      legId: cycle.leg.id,
      takenAt: DateTime(2026, 9, 10),
      optionMark: Decimal.parse('0.90'),
      underlyingPrice: Decimal.parse('29.00'),
      deltaAsEntered: -0.32,
      deltaConvention: DeltaConvention.position,
      iv: 45,
    ),
  );
  return cycle.leg;
}

void main() {
  group('S-288: a recording gateway sees no trade, snapshot or ledger data', () {
    late InMemoryWheelRepository repo;
    late FakePurchaseGateway inner;
    late RecordingPurchaseGateway gateway;
    late ProviderContainer container;

    setUp(() async {
      repo = InMemoryWheelRepository();
      inner = FakePurchaseGateway();
      gateway = RecordingPurchaseGateway(inner);
      // Three open cycles and no entitlement: the fourth-cycle refusal is
      // reachable, which is the one app path that *does* consult Pro.
      for (var i = 0; i < kFreeTierOpenCycles; i++) {
        await _seedBook(repo, 'T$i');
      }
      inner.snapshot = const EntitlementSnapshot.inactive();
      inner.offerings = ProOfferings(
        plans: [
          ProPlanOffer(
            productId: kProMonthlyProductId,
            priceString: '\$4.99',
            price: Decimal.parse('4.99'),
            currencyCode: 'USD',
          ),
        ],
      );

      container = ProviderContainer(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(repo),
          purchaseGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
    });

    test('the log holds only the six store methods, and only a product id ever crosses', () async {
      // The launch path, then the five things the scenario drives.
      await container.read(entitlementControllerProvider.notifier).initialize();
      final decision = await container.read(newCycleGateProvider).evaluate();
      expect(decision, isA<NewCycleBlocked>());

      final paywall = container.read(paywallControllerProvider.notifier);
      await paywall.load();
      await paywall.purchase();
      await paywall.restore();
      await paywall.manageSubscription();

      // A full export, the other path a ticker could leak through.
      final files = await container.read(exportControllerProvider).buildExportFiles();
      final payload = utf8.decode(await files.first.readAsBytes());

      expect(gateway.calls, [
        'configure',
        'currentEntitlement',
        'loadOfferings',
        'purchase',
        'currentEntitlement',
        'restore',
        'currentEntitlement',
        'showManageSubscriptions',
      ]);
      expect(gateway.calls.toSet(), _allowedCalls.toSet());
      expect(gateway.purchasedProductIds, [kProMonthlyProductId]);

      // The export carried the book, and the seam saw none of it.
      expect(payload, contains('T0'));
      for (final argument in gateway.arguments) {
        expect(
          argument.argument,
          anyOf(isNull, isA<String>()),
          reason: '${argument.method} was handed something that is not a string',
        );
        if (argument.argument case final String value) {
          expect(
            value,
            isNot(contains('T0')),
            reason: 'a ticker crossed the purchase seam',
          );
          expect(value, anyOf(kProMonthlyProductId, kProAnnualProductId, kProLifetimeProductId));
        }
      }
    });

    test('the seam cannot express a trade type: it imports no model but two enums', () {
      final source = File('lib/core/purchases/purchase_gateway.dart').readAsStringSync();
      final imports = RegExp(r"""^(?:import|export)\s+'([^']+)'""", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1)!)
          .toList();

      expect(imports, [
        'package:decimal/decimal.dart',
        '../../domain/models/entitlement_status.dart',
        '../../domain/models/pro_plan_kind.dart',
      ]);
      // No `lib/data/` path, and none of the trade models the app persists.
      for (final forbidden in const [
        'leg.dart',
        'snapshot.dart',
        'wheel_cycle.dart',
        'share_lot.dart',
        'underlying.dart',
        'ledger',
        'wheel_repository',
      ]) {
        expect(imports.where((uri) => uri.contains(forbidden)), isEmpty);
      }
    });

    test('the only seam method that takes an argument takes one String', () {
      final source = File('lib/core/purchases/purchase_gateway.dart').readAsStringSync();
      final signatures = RegExp(r'^\s{2}(?:Future<[^>]*>|void) (\w+)\(([^()]*)\);', multiLine: true)
          .allMatches(source)
          .map((match) => (name: match.group(1)!, params: match.group(2)!.trim()))
          .toList();

      expect(signatures, [
        (name: 'configure', params: ''),
        (name: 'loadOfferings', params: ''),
        (name: 'currentEntitlement', params: ''),
        (name: 'purchase', params: 'String productId'),
        (name: 'restore', params: ''),
        (name: 'showManageSubscriptions', params: ''),
      ]);
    });
  });
}
