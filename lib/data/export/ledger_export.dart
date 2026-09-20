import 'dart:convert';

import '../../domain/models/leg.dart';
import '../../domain/models/rule_profile_data.dart';
import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/rule_profile_version_data.dart';
import '../../domain/models/share_lot.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/models/underlying.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/models/wheel_cycle.dart';

/// Thrown by [LedgerExport.fromJsonString]/[LedgerExport.fromJson] whenever
/// an import file fails hard validation (`docs/brief-ledger.md` §5: "Refuse
/// the whole file rather than partially applying it"). Both
/// `DriftWheelRepository.restoreFromJson` and
/// `InMemoryWheelRepository.restoreFromJson` parse and validate the entire
/// file through this class *before* touching any stored row, so this
/// exception is always thrown before a single write happens (S-152).
class LedgerImportFormatException implements Exception {
  LedgerImportFormatException(this.message);

  final String message;

  @override
  String toString() => 'LedgerImportFormatException: $message';
}

/// The full-fidelity export envelope (`docs/brief-ledger.md` §5): every
/// [Underlying], [WheelCycle], [Leg] (fees/`acceptsAssignment` included),
/// [Snapshot], [ShareLot], [RuleProfileData] and every
/// [RuleProfileVersionData], and the single [UserPreferencesData] row. This
/// is the ONLY place `restoreFromJson`'s parsing and hard validation live --
/// `DriftWheelRepository` and `InMemoryWheelRepository` both call
/// [LedgerExport.fromJsonString] and never re-implement any of this
/// themselves, so the two can never silently diverge on what counts as a
/// valid file (docs/conventions.md §6's "one canonical type per concept").
///
/// Format 2 (Iteration 5, D-8) carries the threshold version split:
/// `ruleProfiles` is identity-only, `ruleProfileVersions` holds every
/// append-only version, and legs pin `ruleProfileVersionId`. **Format-1
/// files are still accepted** and converted in memory by
/// [_convertFormat1] before validation -- the audit feature must not brick
/// the only backup the app has. Import validates grammar and references
/// only, never the value ranges the threshold editor enforces on input
/// (D-9 is a UI gate, not a file-format contract).
///
/// Every field here is a plain domain model already carrying its own
/// symmetric `toJson`/`fromJson` (`lib/domain/models/`) -- this class only
/// assembles/disassembles the envelope around them; it adds no
/// serialization logic of its own beyond the envelope shape and the
/// validation below.
class LedgerExport {
  const LedgerExport({
    required this.formatVersion,
    required this.underlyings,
    required this.cycles,
    required this.legs,
    required this.snapshots,
    required this.shareLots,
    required this.ruleProfiles,
    required this.ruleProfileVersions,
    required this.preferences,
  });

  /// Bumped whenever this envelope's own shape changes in a way an older
  /// parser could misread. Deliberately independent of
  /// `AppDatabase.schemaVersion` (the on-disk SQLite schema) -- the export
  /// file format and the storage schema are free to evolve on different
  /// timelines.
  static const currentFormatVersion = 2;

  final int formatVersion;
  final List<Underlying> underlyings;
  final List<WheelCycle> cycles;
  final List<Leg> legs;
  final List<Snapshot> snapshots;
  final List<ShareLot> shareLots;
  final List<RuleProfileData> ruleProfiles;
  final List<RuleProfileVersionData> ruleProfileVersions;
  final UserPreferencesData preferences;

  /// Decodes and validates a raw JSON string in one step -- the entry point
  /// both repository implementations' `restoreFromJson` call. Throws
  /// [LedgerImportFormatException] (never a raw `FormatException`/
  /// `TypeError`) for every way [source] can fail to be a valid export,
  /// including plain invalid JSON syntax. [now] is only consulted for a
  /// format-1 file's synthesized v1 versions (it becomes their
  /// `effectiveAt`); tests pin it, the UI passes nothing.
  factory LedgerExport.fromJsonString(String source, {DateTime? now}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw LedgerImportFormatException('Not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw LedgerImportFormatException('Top-level JSON value must be an object');
    }
    return LedgerExport.fromJson(decoded, now: now);
  }

  /// Structural + referential hard validation (§5 "validate hard on
  /// import"). Every required key is type-checked, every list element is
  /// parsed through its own model's `fromJson` (so a missing/mistyped field
  /// on any single row fails the whole import), every id within a list is
  /// checked for uniqueness, and every cross-table reference (`cycleId`,
  /// `underlyingId`, `legId`, `rolledFromLegId`, `ruleProfileVersionId`,
  /// a version's `profileId`) is checked against the ids actually present
  /// in this same file. The version split adds three rules: every profile
  /// has at least one version, `(profileId, version)` is unique, and each
  /// leg's pinned version exists. Nothing is returned unless every one of
  /// these checks passes -- there is no partial/best-effort result.
  ///
  /// A format-1 file is converted to the format-2 shape first (D-8), so
  /// everything below runs against exactly one shape. The returned object
  /// is normalized: [formatVersion] is always [currentFormatVersion],
  /// because its lists are v2-shaped regardless of which form arrived.
  factory LedgerExport.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final formatVersion = json['formatVersion'];
    if (formatVersion is! int) {
      throw LedgerImportFormatException("Missing or invalid 'formatVersion' (expected an integer)");
    }
    if (formatVersion != 1 && formatVersion != currentFormatVersion) {
      throw LedgerImportFormatException(
        'Unsupported export formatVersion $formatVersion '
        '(this app reads formatVersion 1 and $currentFormatVersion)',
      );
    }

    final v2Json = formatVersion == 1
        ? _convertFormat1(json, conversionTime: now ?? DateTime.now())
        : json;

    final underlyings = _parseList('underlyings', v2Json['underlyings'], Underlying.fromJson);
    final cycles = _parseList('cycles', v2Json['cycles'], WheelCycle.fromJson);
    final legs = _parseList('legs', v2Json['legs'], Leg.fromJson);
    final snapshots = _parseList('snapshots', v2Json['snapshots'], Snapshot.fromJson);
    final shareLots = _parseList('shareLots', v2Json['shareLots'], ShareLot.fromJson);
    final ruleProfiles = _parseList('ruleProfiles', v2Json['ruleProfiles'], RuleProfileData.fromJson);
    final ruleProfileVersions = _parseList(
      'ruleProfileVersions',
      v2Json['ruleProfileVersions'],
      RuleProfileVersionData.fromJson,
    );

    final preferencesJson = v2Json['preferences'];
    if (preferencesJson is! Map<String, dynamic>) {
      throw LedgerImportFormatException("Missing or invalid 'preferences' (expected an object)");
    }
    final UserPreferencesData preferences;
    try {
      preferences = UserPreferencesData.fromJson(preferencesJson);
    } catch (e) {
      throw LedgerImportFormatException("'preferences' is invalid: $e");
    }

    _requireUniqueIds(underlyings.map((u) => u.id), 'underlyings');
    _requireUniqueIds(cycles.map((c) => c.id), 'cycles');
    _requireUniqueIds(legs.map((l) => l.id), 'legs');
    _requireUniqueIds(snapshots.map((s) => s.id), 'snapshots');
    _requireUniqueIds(shareLots.map((s) => s.id), 'shareLots');
    _requireUniqueIds(ruleProfiles.map((r) => r.id), 'ruleProfiles');
    _requireUniqueIds(ruleProfileVersions.map((v) => v.id), 'ruleProfileVersions');

    final underlyingIds = underlyings.map((u) => u.id).toSet();
    final cycleIds = cycles.map((c) => c.id).toSet();
    final legIds = legs.map((l) => l.id).toSet();
    final ruleProfileIds = ruleProfiles.map((r) => r.id).toSet();
    final ruleProfileVersionIds = ruleProfileVersions.map((v) => v.id).toSet();

    for (final profile in ruleProfiles) {
      if (!ruleProfileVersions.any((v) => v.profileId == profile.id)) {
        throw LedgerImportFormatException("ruleProfile '${profile.id}' has no versions");
      }
    }
    final seenProfileVersions = <String>{};
    for (final version in ruleProfileVersions) {
      if (!ruleProfileIds.contains(version.profileId)) {
        throw LedgerImportFormatException(
          "ruleProfileVersion '${version.id}' references unknown profileId '${version.profileId}'",
        );
      }
      if (!seenProfileVersions.add('${version.profileId}#${version.version}')) {
        throw LedgerImportFormatException(
          'Duplicate (profileId, version) pair in ruleProfileVersions: '
          "'${version.profileId}' v${version.version}",
        );
      }
    }

    for (final cycle in cycles) {
      if (!underlyingIds.contains(cycle.underlyingId)) {
        throw LedgerImportFormatException(
          "cycle '${cycle.id}' references unknown underlyingId '${cycle.underlyingId}'",
        );
      }
    }
    for (final leg in legs) {
      if (!cycleIds.contains(leg.cycleId)) {
        throw LedgerImportFormatException("leg '${leg.id}' references unknown cycleId '${leg.cycleId}'");
      }
      if (!ruleProfileVersionIds.contains(leg.ruleProfileVersionId)) {
        throw LedgerImportFormatException(
          "leg '${leg.id}' references unknown ruleProfileVersionId '${leg.ruleProfileVersionId}'",
        );
      }
      final rolledFromLegId = leg.rolledFromLegId;
      if (rolledFromLegId != null && !legIds.contains(rolledFromLegId)) {
        throw LedgerImportFormatException(
          "leg '${leg.id}' references unknown rolledFromLegId '$rolledFromLegId'",
        );
      }
    }
    for (final snapshot in snapshots) {
      if (!legIds.contains(snapshot.legId)) {
        throw LedgerImportFormatException(
          "snapshot '${snapshot.id}' references unknown legId '${snapshot.legId}'",
        );
      }
    }
    for (final lot in shareLots) {
      if (!cycleIds.contains(lot.cycleId)) {
        throw LedgerImportFormatException(
          "shareLot '${lot.id}' references unknown cycleId '${lot.cycleId}'",
        );
      }
    }

    return LedgerExport(
      formatVersion: currentFormatVersion,
      underlyings: underlyings,
      cycles: cycles,
      legs: legs,
      snapshots: snapshots,
      shareLots: shareLots,
      ruleProfiles: ruleProfiles,
      ruleProfileVersions: ruleProfileVersions,
      preferences: preferences,
    );
  }

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'underlyings': underlyings.map((u) => u.toJson()).toList(),
    'cycles': cycles.map((c) => c.toJson()).toList(),
    'legs': legs.map((l) => l.toJson()).toList(),
    'snapshots': snapshots.map((s) => s.toJson()).toList(),
    'shareLots': shareLots.map((s) => s.toJson()).toList(),
    'ruleProfiles': ruleProfiles.map((r) => r.toJson()).toList(),
    'ruleProfileVersions': ruleProfileVersions.map((v) => v.toJson()).toList(),
    'preferences': preferences.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());
}

List<T> _parseList<T>(String fieldName, Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) {
    throw LedgerImportFormatException("Missing or invalid '$fieldName' (expected a JSON array)");
  }
  final result = <T>[];
  for (var i = 0; i < raw.length; i++) {
    final element = raw[i];
    if (element is! Map<String, dynamic>) {
      throw LedgerImportFormatException("'$fieldName[$i]' must be a JSON object");
    }
    try {
      result.add(fromJson(element));
    } catch (e) {
      throw LedgerImportFormatException("'$fieldName[$i]' is invalid: $e");
    }
  }
  return result;
}

void _requireUniqueIds(Iterable<String> ids, String label) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw LedgerImportFormatException('Duplicate $label id in import: $id');
    }
  }
}

/// The 14 threshold field names a format-1 profile row carried inline
/// (D-8) — the same names the format-2 version model uses, so no renaming
/// happens during conversion.
const _v1ThresholdFields = [
  'profitTargetPct',
  'assignThreshold',
  'baseRollBand',
  'midIvRollBand',
  'highIvRollBand',
  'midIvCutoff',
  'highIvCutoff',
  'tailDteDays',
  'tailExtrinsicThreshold',
  'minIvRank',
  'minAnnualisedYield',
  'targetDteMin',
  'targetDteMax',
  'targetDelta',
];

/// Normalizes a decoded format-1 export map to the format-2 shape (D-8).
/// Pure map surgery, deliberately no model parsing: each profile row keeps
/// its identity and its inline threshold values become a synthesized v1
/// version row (`<profileId>-v1`, `version: 1`, `effectiveAt` =
/// [conversionTime]), and each leg's `ruleProfileId` value is rewritten to
/// the matching version id. Anything malformed is passed through unchanged
/// so the parser below reports it with its usual precise error instead of
/// this function inventing a second, vaguer one.
Map<String, dynamic> _convertFormat1(
  Map<String, dynamic> json, {
  required DateTime conversionTime,
}) {
  final effectiveAt = conversionTime.toUtc().toIso8601String();

  final rawProfiles = json['ruleProfiles'];
  final profiles = <Object?>[];
  final versions = <Map<String, dynamic>>[];
  if (rawProfiles is List) {
    for (final raw in rawProfiles) {
      if (raw is! Map<String, dynamic>) {
        profiles.add(raw);
        continue;
      }
      final id = raw['id'];
      if (id is! String) {
        profiles.add(raw);
        continue;
      }
      profiles.add({'id': id, 'name': raw['name']});
      versions.add({
        'id': RuleProfileVersionIds.forVersion(id, 1),
        'profileId': id,
        'version': 1,
        'effectiveAt': effectiveAt,
        for (final field in _v1ThresholdFields) field: raw[field],
      });
    }
  }

  final rawLegs = json['legs'];
  final legs = <Object?>[];
  if (rawLegs is List) {
    for (final raw in rawLegs) {
      if (raw is! Map<String, dynamic>) {
        legs.add(raw);
        continue;
      }
      final pinned = raw['ruleProfileId'];
      if (pinned is! String) {
        legs.add(raw);
        continue;
      }
      legs.add(
        {...raw, 'ruleProfileVersionId': RuleProfileVersionIds.forVersion(pinned, 1)}
          ..remove('ruleProfileId'),
      );
    }
  }

  return {
    ...json,
    'formatVersion': LedgerExport.currentFormatVersion,
    if (rawProfiles is List) 'ruleProfiles': profiles,
    if (rawProfiles is List) 'ruleProfileVersions': versions,
    if (rawLegs is List) 'legs': legs,
  };
}
