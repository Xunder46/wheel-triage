import 'package:drift/drift.dart';

import '../type_converters.dart';

/// One immutable, append-only threshold version of a rule profile
/// (Iteration 5, D-3). Mirrors `RuleProfileVersionData` 1:1. The 14
/// threshold columns moved here from `rule_profile`, which now carries
/// identity (`id`, `name`) only — there is deliberately no denormalized
/// "current version" copy anywhere, so an edited value can exist in exactly
/// one place.
///
/// `id` is deterministic (`<profileId>-v<version>`), stored rather than
/// derived at read time so a leg's pin is a plain string lookup;
/// `(profileId, version)` is unique so the format stays a faithful
/// representation of the number. All fields `double` except
/// `tailExtrinsicThreshold`, the one money-denominated field (Feature
/// Invariant 9), stored as integer ten-thousandths.
@DataClassName('RuleProfileVersionRow')
class RuleProfileVersionTable extends Table {
  @override
  String get tableName => 'rule_profile_version';

  TextColumn get id => text()();
  TextColumn get profileId => text()();
  IntColumn get version => integer()();
  IntColumn get effectiveAtMs => integer().map(const DateTimeMsConverter())();
  RealColumn get profitTargetPct => real()();
  RealColumn get assignThreshold => real()();
  RealColumn get baseRollBand => real()();
  RealColumn get midIvRollBand => real()();
  RealColumn get highIvRollBand => real()();
  RealColumn get midIvCutoff => real()();
  RealColumn get highIvCutoff => real()();
  IntColumn get tailDteDays => integer()();
  IntColumn get tailExtrinsicThreshold => integer().map(const TenThousandthsConverter())();
  RealColumn get minIvRank => real()();
  RealColumn get minAnnualisedYield => real()();
  IntColumn get targetDteMin => integer()();
  IntColumn get targetDteMax => integer()();
  RealColumn get targetDelta => real()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, version},
      ];
}
