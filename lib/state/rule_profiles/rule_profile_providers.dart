import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/rule_profile_version_data.dart';
import '../../domain/rules/rule_profile.dart';
import '../repository_providers.dart';

/// Every threshold version of [profileId], ascending by the integer
/// `version` — the append-only edit history the Settings screen renders
/// (D-11). Deliberately the persistence DTO rather than `RuleProfile`:
/// each entry carries its `effectiveAt`, which the pure value type does
/// not, and the history UI shows it.
final ruleProfileVersionsProvider =
    FutureProvider.family<List<RuleProfileVersionData>, String>((ref, profileId) async {
  final repo = ref.watch(wheelRepositoryProvider);
  return repo.getRuleProfileVersions(profileId);
});

/// The profile new legs default to (Feature Invariant 8 — no profile-picker
/// UI exists; multiple named profiles are dropped, D-1). Resolves the
/// standard profile's **current** version via `RuleProfile.fromVersion` —
/// the only place that mapping happens (Feature Invariant 11, reshaped by
/// Iteration 5's D-10) — so after an edit a new cycle opens under the
/// newest version while every existing leg keeps its pinned one (D-5).
/// Falls back to the built-in `RuleProfile.standard` constant (same values
/// as the seeded v1 row) if the seeded rows are somehow missing, so a
/// screen never crashes on a lookup failure it can't do anything about
/// (D-7).
final currentRuleProfileProvider = FutureProvider<RuleProfile>((ref) async {
  final repo = ref.watch(wheelRepositoryProvider);
  final versions = await repo.getRuleProfileVersions(RuleProfileIds.standard);
  if (versions.isEmpty) return RuleProfile.standard;
  final profile = await repo.getRuleProfile(RuleProfileIds.standard);
  return RuleProfile.fromVersion(versions.last, profileName: profile?.name ?? 'Standard');
});
