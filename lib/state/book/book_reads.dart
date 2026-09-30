/// The book reads Today and Portfolio share (Pro Wave 3 D-45).
///
/// Both screens need the same two things — one capital input per cycle, and
/// the rule profile a leg was opened under — and both must get them the same
/// way, or the two screens can disagree about what the book commits and how a
/// leg classifies. These are the *only* implementations of either read.
///
/// Lifted verbatim out of `TodayController._capitalInputs` and its profile
/// resolution; the behaviour is unchanged, including the `holdingShares`-only
/// share-lot read.
library;

import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/capital_committed.dart' as capital;
import '../../domain/rules/rule_profile.dart';

/// One [capital.CycleCapitalInput] per cycle the book has legs for.
///
/// The cycle list is derived from the legs rather than read from the
/// repository: `WheelRepository` has no `getAllCycles`, and a cycle with no
/// legs at all commits nothing anyway. A leg whose cycle or underlying the
/// repository cannot resolve is skipped rather than guessed at.
Future<List<capital.CycleCapitalInput>> capitalInputsFor(
  WheelRepository repo,
  List<Leg> allLegs,
) async {
  final legsByCycle = <String, List<Leg>>{};
  for (final leg in allLegs) {
    legsByCycle.putIfAbsent(leg.cycleId, () => []).add(leg);
  }

  final inputs = <capital.CycleCapitalInput>[];
  for (final entry in legsByCycle.entries) {
    final cycle = await repo.getCycle(entry.key);
    if (cycle == null) continue;
    final underlying = await repo.getUnderlying(cycle.underlyingId);
    if (underlying == null) continue;
    inputs.add(
      capital.CycleCapitalInput(
        cycle: cycle,
        ticker: underlying.ticker,
        legs: entry.value,
        // Only a `holdingShares` cycle has an active lot; reading it for any
        // other status would be reading a lot that is no longer the book's.
        shareLot: cycle.status == WheelCycleStatus.holdingShares
            ? await repo.getShareLotForCycle(cycle.id)
            : null,
      ),
    );
  }
  return inputs;
}

/// The rule profile a leg was opened under, resolved from its **pinned**
/// version id — never the profile's current one (Iteration 5 D-5): an edit
/// must not reclassify what an open position was opened under. A dangling pin
/// degrades to the built-in defaults (D-7).
Future<RuleProfile> profileForLeg(WheelRepository repo, String ruleProfileVersionId) async {
  final versionData = await repo.getRuleProfileVersion(ruleProfileVersionId);
  if (versionData == null) return RuleProfile.standard;
  final profileData = await repo.getRuleProfile(versionData.profileId);
  return RuleProfile.fromVersion(versionData, profileName: profileData?.name ?? 'Standard');
}
