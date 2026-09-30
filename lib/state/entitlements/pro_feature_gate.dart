/// D-40's one gate for a Pro *feature* (as opposed to D-P2's free-tier limit,
/// which `new_cycle_gate.dart` owns).
///
/// This is the *only* code that decides whether a Pro surface opens. A screen
/// reads the verdict and nothing else: it never asks the store, never reads
/// `entitlementControllerProvider.isActive`, and never names a gateway type.
/// That is what makes "the entitlement is read in exactly one place" true by
/// construction rather than by review.
///
/// The locked variant carries **both** the feature name and the finished line,
/// so the calling screen never names the feature twice and never builds copy.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/paywall_copy.dart';
import '../entitlements/entitlement_providers.dart';

/// What the gate decided. Sealed, so a caller cannot read a locked decision's
/// line off an open one or forget the feature on a lock.
sealed class ProFeatureAccess {
  const ProFeatureAccess();
}

/// The feature may be opened.
final class ProFeatureOpen extends ProFeatureAccess {
  const ProFeatureOpen();

  @override
  bool operator ==(Object other) => other is ProFeatureOpen;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The feature may not be opened. [feature] is the name to hand to
/// `ProFeaturePaywallTrigger`; [line] is the finished sentence, built here so
/// no screen has to know the wording.
final class ProFeatureLocked extends ProFeatureAccess {
  const ProFeatureLocked({required this.feature, required this.line});

  final String feature;
  final String line;

  @override
  bool operator ==(Object other) =>
      other is ProFeatureLocked && other.feature == feature && other.line == line;

  @override
  int get hashCode => Object.hash(feature, line);
}

/// D-40:
///
/// ```
/// open   ⇔ entitlement.status == active
/// locked ⇔ otherwise
/// ```
///
/// Only `active` unlocks: `inactive` **and** `unknown` both lock, matching
/// D-26 — Pro is never forged from a store that has not answered. Everything
/// already recorded stays readable on every plan (D-41); this gate decides
/// whether a *view* opens, never whether data survives.
class ProFeatureGate {
  ProFeatureGate(this._ref);

  final Ref _ref;

  ProFeatureAccess evaluate(String feature) {
    final active = _ref.read(entitlementControllerProvider).isActive;
    if (active) return const ProFeatureOpen();
    return ProFeatureLocked(feature: feature, line: proFeatureLine(feature));
  }
}

/// The provider's factory, kept here rather than written inline at the
/// provider so that `entitlement_providers.dart` — where the whole entitlement
/// story is reachable from one import — never has to name the type. The two
/// files import each other for exactly this reason, mirroring
/// `new_cycle_gate.dart`.
ProFeatureGate proFeatureGate(Ref ref) => ProFeatureGate(ref);
