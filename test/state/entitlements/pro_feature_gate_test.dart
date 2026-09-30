import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/domain/models/entitlement_status.dart';
import 'package:wheel_triage/state/entitlements/entitlement_controller.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/entitlements/pro_feature_gate.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_purchase_gateway.dart';

/// S-290: Portfolio is Pro, decided in exactly one place.
///
/// The gate is the only decider, so the three entitlement states are the whole
/// fixture: `active` opens, and `inactive` **and** `unknown` both lock (D-26 —
/// Pro is never forged from a store that has not answered).
void main() {
  ProviderContainer containerWith(EntitlementStatus status) {
    final container = ProviderContainer(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository()),
        entitlementControllerProvider.overrideWith(
          (ref) => _FixedEntitlementController(EntitlementState(status: status)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('S-290: Portfolio is Pro, decided in exactly one place', () {
    test('active opens', () {
      final container = containerWith(EntitlementStatus.active);
      final access = container.read(proFeatureGateProvider).evaluate(kPortfolioFeatureName);
      expect(access, isA<ProFeatureOpen>());
    });

    for (final status in [EntitlementStatus.inactive, EntitlementStatus.unknown]) {
      test('$status locks, and carries the finished line', () {
        final container = containerWith(status);
        final access = container.read(proFeatureGateProvider).evaluate(kPortfolioFeatureName);

        expect(access, isA<ProFeatureLocked>());
        final locked = access as ProFeatureLocked;
        expect(locked.feature, 'Portfolio');
        expect(locked.line, proFeatureLine('Portfolio'));
        expect(
          locked.line,
          'Portfolio is part of Pro. Everything you\'ve already recorded stays '
          'available on every plan.',
        );
      });
    }

    test('the feature name is the one constant, not a literal at the call site', () {
      expect(kPortfolioFeatureName, 'Portfolio');
    });

    test('no file under lib/features/ reads the gateway, and .isActive is display-only', () {
      // D-40: the gate is the only *decider*. A screen reads the verdict and
      // nothing else, so a widget can never forge Pro or lock a free user out
      // of something already recorded.
      expect(_filesMentioning(RegExp(r'purchaseGatewayProvider')), isEmpty);

      // Two pre-existing reads survive, both rendering a row rather than
      // deciding access: Settings' billing-issue note and the paywall's
      // "you own this" line. Neither opens, closes or gates anything, and
      // neither is a route or a feature. Pinned by path so a third one has to
      // be argued for here rather than appearing silently.
      expect(_filesMentioning(RegExp(r'\.isActive')), [
        'lib/features/paywall/paywall_screen.dart',
        'lib/features/settings/pro_plan_section.dart',
      ]);
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

/// A controller whose state is fixed, so the gate's read is the only thing
/// under test. `EntitlementController`'s own store wiring is S-265's subject.
class _FixedEntitlementController extends EntitlementController {
  _FixedEntitlementController(EntitlementState state)
    : super(FakePurchaseGateway(), InMemoryWheelRepository()) {
    this.state = state;
  }
}
