/// D-P2's free-tier limit, evaluated in exactly one place (D-23, D-28).
///
/// This is the *only* code that decides whether a new cycle is allowed. The
/// Settings row's "2 of 3 open cycles" is a count display, not an evaluation,
/// and no screen or widget is permitted to ask the question another way: the
/// two save screens react to the outcome of a save
/// (`RecordSaveOutcome.paywallRequired`), never to a boolean.
///
/// The book is read **before** the entitlement is consulted. That ordering is
/// deliberate rather than incidental — it makes "the gate was consulted" an
/// observable side effect for tests (S-259) and it keeps the one decision on
/// one code path, so there is no early return that skips the count.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/paywall_copy.dart';
import '../../core/purchases/pro_plans.dart';
import '../repository_providers.dart';
import 'entitlement_providers.dart';

/// What the gate decided. Sealed, so a caller cannot read a blocked decision's
/// line off an allowed one or forget the count on a block.
sealed class NewCycleDecision {
  const NewCycleDecision();
}

/// A new cycle may be recorded.
final class NewCycleAllowed extends NewCycleDecision {
  const NewCycleAllowed();

  @override
  bool operator ==(Object other) => other is NewCycleAllowed;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// A new cycle may not be recorded. [line] is the D-24 sentence to show, built
/// here so the save result carries finished copy and no screen has to know the
/// limit; [openCycleCount] is the count that fired it, for the caller's own
/// diagnostics and the Settings-style displays.
final class NewCycleBlocked extends NewCycleDecision {
  const NewCycleBlocked({required this.line, required this.openCycleCount});

  final String line;
  final int openCycleCount;

  @override
  bool operator ==(Object other) =>
      other is NewCycleBlocked && other.line == line && other.openCycleCount == openCycleCount;

  @override
  int get hashCode => Object.hash(line, openCycleCount);
}

/// D-23:
///
/// ```
/// allowed ⇔ entitlement.status == active
///           ∨ getOpenCycles().length < kFreeTierOpenCycles
/// blocked ⇔ otherwise
/// ```
///
/// Only `active` unlocks: `inactive` **and** `unknown` both behave as free, so
/// Pro is never forged from a store that has not answered (D-26). Everything
/// that is not a *new cycle* — rolls, assignments, called-away, covered calls
/// on an existing cycle, and every read — never reaches this class at all.
class NewCycleGate {
  NewCycleGate(this._ref);

  final Ref _ref;

  Future<NewCycleDecision> evaluate() async {
    final openCycles = await _ref.read(wheelRepositoryProvider).getOpenCycles();
    final entitlement = _ref.read(entitlementControllerProvider);
    if (entitlement.isActive || openCycles.length < kFreeTierOpenCycles) {
      return const NewCycleAllowed();
    }
    return NewCycleBlocked(
      line: newCycleRefusalLine(
        count: openCycles.length,
        limit: kFreeTierOpenCycles,
      ),
      openCycleCount: openCycles.length,
    );
  }
}

/// The provider's factory, kept here rather than written inline at the
/// provider so that `entitlement_providers.dart` — where S-265's structural
/// guard requires `newCycleGateProvider` to live — never has to name the type.
/// The two files import each other for exactly this reason: the class and its
/// one evaluation belong together, the provider belongs with the rest of the
/// app's entitlement story.
NewCycleGate newCycleGate(Ref ref) => NewCycleGate(ref);
