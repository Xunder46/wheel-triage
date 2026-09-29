import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/domain/rules/classify.dart';
import 'package:wheel_triage/domain/rules/formulas.dart' as formulas;
import 'package:wheel_triage/domain/rules/iv_resolution.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';
import 'package:wheel_triage/domain/rules/snapshot_preview.dart';
import 'package:wheel_triage/domain/rules/triage_input.dart';

import '../../support/rule_profile_fixtures.dart';

/// S-238's fixture: T \$28 call, credit \$0.30, 4 DTE at Mon 2026-09-28, opened
/// at IV 22 so the IV-blank variant has a leg-level fallback to fall back to.
final _now = DateTime(2026, 9, 28, 10);
final _expiration = DateTime(2026, 10, 2); // exactly 4 DTE from `_now`.

Future<(Leg, RuleProfile)> _makeLeg(
  WheelRepository repo, {
  OptionType side = OptionType.call,
  String ticker = 'T',
  String? versionId,
  double? ivAtOpen = 22,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: side,
      strike: Decimal.parse('28'),
      expiration: _expiration,
      contracts: 1,
      openedAt: DateTime(2026, 9, 24),
      openCreditPerShare: Decimal.parse('0.30'),
      ivAtOpen: ivAtOpen,
      ruleProfileVersionId: versionId ?? RuleProfileVersionIds.standardV1,
    ),
  );
  final leg = (await repo.getLeg(result.leg.id))!;
  final profile = await _profileFor(repo, leg);
  return (leg, profile);
}

Future<RuleProfile> _profileFor(WheelRepository repo, Leg leg) async {
  final version = await repo.getRuleProfileVersion(leg.ruleProfileVersionId);
  if (version == null) return RuleProfile.standard;
  final data = await repo.getRuleProfile(version.profileId);
  return RuleProfile.fromVersion(version, profileName: data?.name ?? 'Standard');
}

/// Saves a reading through the real repository (the "existing save path"),
/// so the preview is compared against a *persisted* snapshot's classification
/// rather than a hand-built one.
Future<Snapshot> _saveReading(
  WheelRepository repo, {
  required String legId,
  required String mark,
  required String spot,
  required double delta,
  double? iv = 21,
  DateTime? takenAt,
}) => repo.appendSnapshot(
  NewSnapshotInput(
    legId: legId,
    takenAt: takenAt ?? _now,
    optionMark: Decimal.parse(mark),
    underlyingPrice: Decimal.parse(spot),
    deltaAsEntered: delta,
    deltaConvention: DeltaConvention.position,
    iv: iv,
  ),
);

/// The classification the app's own live path produces for a persisted
/// reading — `triageInputFor` + `classify()`, exactly as
/// `position_detail_controller.dart` does it.
Bucket _liveBucket(Leg leg, Snapshot? snapshot, RuleProfile profile) => classify(
  triageInputFor(leg: leg, snapshot: snapshot, dte: formulas.dte(leg.expiration, _now)),
  profile,
);

void main() {
  group('S-238: the snapshot preview matches classify()', () {
    late InMemoryWheelRepository repo;
    late Leg leg;
    late RuleProfile profile;

    setUp(() async {
      repo = InMemoryWheelRepository();
      final made = await _makeLeg(repo);
      leg = made.$1;
      profile = made.$2;
    });

    // Each row: the reading's numbers, and the bucket it must produce. The
    // *comparison* is against classify()'s own output — the row names below
    // only document which gate the row is expected to exercise.
    const rows = <(String, String, String, double, Type, String)>[
      ('mark 0.12 / spot 27.05 / delta -0.21', '0.12', '27.05', -0.21, BucketClose,
          '60% of credit captured'),
      ('mark 0.20 / spot 27.05 / delta -0.35', '0.20', '27.05', -0.35, BucketRoll,
          'the 0.35 delta crossed the roll band'),
      ('mark 0.25 / spot 27.05 / delta -0.72', '0.25', '27.05', -0.72, BucketAssign,
          'Delta 0.72 at or above 0.70'),
      // S-238's own row reads "mark 0.10 ... (Leave)", but 0.10 against a
      // $0.30 credit is 66.7% captured, which Gate 1 closes on before any
      // other gate is reached. The *outcome* is what the row exists to pin,
      // so the mark is 0.18 (40% captured) -- see A-9 in the plan.
      ('mark 0.18 / spot 27.05 / delta -0.10', '0.18', '27.05', -0.10, BucketLeave,
          'nothing fired'),
    ];

    for (final (label, mark, spot, delta, bucketType, why) in rows) {
      test('$label -> ${bucketType.toString()} ($why), identical to classify()', () async {
        final saved = await _saveReading(repo, legId: leg.id, mark: mark, spot: spot, delta: delta);
        final live = _liveBucket(leg, saved, profile);
        expect(live.runtimeType, bucketType, reason: 'the fixture itself must land on $bucketType');

        final preview = buildSnapshotPreview(
          leg: leg,
          profile: profile,
          now: _now,
          optionMark: Decimal.parse(mark),
          underlyingPrice: Decimal.parse(spot),
          deltaAsEntered: delta,
          deltaConvention: DeltaConvention.position,
          iv: 21,
        );

        expect(preview.bucket.runtimeType, live.runtimeType);
        expect(preview.bucket.reason, live.reason);
        expect(preview.capturedPct, formulas.capturedPct(openCredit: leg.openCreditPerShare, currentMark: Decimal.parse(mark)));
        expect(preview.rollBand, profile.rollBandFor(21));
        expect(preview.resolvedIv.source, IvSource.snapshotIv);
        expect(preview.resolvedIv.value, 21);
        expect(
          preview.extrinsic,
          formulas.extrinsic(
            currentMark: Decimal.parse(mark),
            intrinsic: formulas.intrinsic(optionType: leg.optionType, strike: leg.strike, spot: Decimal.parse(spot)),
          ),
        );
        expect(preview.rollBandLabelText, contains("from this snapshot's IV (21%)"));
      });
    }

    test('an IV-blank reading falls the band back to IV at open and says so', () async {
      final saved = await _saveReading(repo, legId: leg.id, mark: '0.20', spot: '27.05', delta: -0.35, iv: null);
      final live = _liveBucket(leg, saved, profile);

      final preview = buildSnapshotPreview(
        leg: leg,
        profile: profile,
        now: _now,
        optionMark: Decimal.parse('0.20'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.35,
        deltaConvention: DeltaConvention.position,
        // Cleared IV on the form -- the same null the field produces.
      );

      expect(preview.resolvedIv.source, IvSource.legIvAtOpen);
      expect(preview.resolvedIv.value, 22);
      expect(preview.bucket.runtimeType, live.runtimeType);
      expect(preview.bucket.reason, live.reason);
      expect(preview.rollBand, profile.rollBandFor(22));
      expect(preview.rollBandLabelText, contains('from IV at open (22%)'));
    });

    test('with no IV anywhere the band line says there is no IV on file', () async {
      final bare = await _makeLeg(repo, ticker: 'Z', ivAtOpen: null);
      final preview = buildSnapshotPreview(
        leg: bare.$1,
        profile: bare.$2,
        now: _now,
        optionMark: Decimal.parse('0.20'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.35,
        deltaConvention: DeltaConvention.position,
      );
      expect(preview.resolvedIv.source, IvSource.profileDefault);
      expect(preview.rollBandLabelText, contains('no IV on file'));
    });
  });

  group('S-240: the preview uses the leg\u2019s pinned version', () {
    test('an old leg previews under v1 after Standard is edited to v2; a new leg previews under v2', () async {
      final repo = InMemoryWheelRepository();
      final old = await _makeLeg(repo, ticker: 'OLD');
      final oldProfile = old.$2;

      // The edit: v2 moves the profit target well above 60%, so the same
      // reading that closes under v1 must NOT close under v2.
      await repo.appendRuleProfileVersion(
        profileId: 'rule-profile-standard',
        effectiveAt: DateTime(2026, 9, 28),
        values: standardVersionInput(profitTargetPct: 95),
      );

      final fresh = await _makeLeg(repo, ticker: 'NEW', versionId: RuleProfileVersionIds.forVersion('rule-profile-standard', 2));
      final freshProfile = fresh.$2;
      expect(freshProfile.versionId, isNot(oldProfile.versionId));

      SnapshotPreview previewFor(Leg l, RuleProfile p) => buildSnapshotPreview(
        leg: l,
        profile: p,
        now: _now,
        optionMark: Decimal.parse('0.12'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.21,
        deltaConvention: DeltaConvention.position,
        iv: 21,
      );

      expect(previewFor(old.$1, oldProfile).bucket.runtimeType, BucketClose);
      expect(previewFor(fresh.$1, freshProfile).bucket.runtimeType, isNot(BucketClose));

      // And the old leg's own pinned profile still resolves to v1's numbers
      // -- never the profile's current version.
      expect(oldProfile.profitTargetPct, isNot(freshProfile.profitTargetPct));
    });
  });

  group('S-241: the change line', () {
    late InMemoryWheelRepository repo;
    late Leg leg;
    late RuleProfile profile;

    setUp(() async {
      repo = InMemoryWheelRepository();
      final made = await _makeLeg(repo);
      leg = made.$1;
      profile = made.$2;
    });

    test('a new reading that produces Close says which bucket and which reading it replaces', () async {
      final previous = await _saveReading(
        repo,
        legId: leg.id,
        mark: '0.18',
        spot: '27.05',
        delta: -0.10,
        takenAt: DateTime(2026, 9, 17),
      );
      final live = _liveBucket(leg, previous, profile);
      expect(live.runtimeType, BucketLeave, reason: 'the Sep 17 reading is the Leave this replaces');

      final preview = buildSnapshotPreview(
        leg: leg,
        profile: profile,
        now: _now,
        optionMark: Decimal.parse('0.12'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.21,
        deltaConvention: DeltaConvention.position,
        iv: 21,
        latestSnapshot: previous,
      );

      expect(preview.bucket.runtimeType, BucketClose);
      expect(preview.changeLine, 'Was Leave on the Sep 17 reading');
    });

    test('a reading that matches the current bucket has no change line', () async {
      final previous = await _saveReading(repo, legId: leg.id, mark: '0.18', spot: '27.05', delta: -0.10);

      final preview = buildSnapshotPreview(
        leg: leg,
        profile: profile,
        now: _now,
        optionMark: Decimal.parse('0.18'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.10,
        deltaConvention: DeltaConvention.position,
        iv: 21,
        latestSnapshot: previous,
      );

      expect(preview.bucket.runtimeType, BucketLeave);
      expect(preview.changeLine, isNull);
    });

    test('a leg with no reading yet has no change line', () async {
      final preview = buildSnapshotPreview(
        leg: leg,
        profile: profile,
        now: _now,
        optionMark: Decimal.parse('0.12'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.21,
        deltaConvention: DeltaConvention.position,
        iv: 21,
      );
      expect(preview.bucket.runtimeType, BucketClose);
      expect(preview.changeLine, isNull);
    });

    test('the reading date is the previous reading\u2019s own takenAt, not today', () async {
      final previous = await _saveReading(
        repo,
        legId: leg.id,
        mark: '0.18',
        spot: '27.05',
        delta: -0.10,
        takenAt: DateTime(2026, 9, 3),
      );
      final preview = buildSnapshotPreview(
        leg: leg,
        profile: profile,
        now: _now,
        optionMark: Decimal.parse('0.12'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.21,
        deltaConvention: DeltaConvention.position,
        iv: 21,
        latestSnapshot: previous,
      );
      expect(preview.changeLine, 'Was Leave on the Sep 3 reading');
    });
  });

  group('the preview never persists anything', () {
    test('building a preview writes no snapshot', () async {
      final repo = InMemoryWheelRepository();
      final made = await _makeLeg(repo);
      final before = await repo.getSnapshotsForLeg(made.$1.id);

      buildSnapshotPreview(
        leg: made.$1,
        profile: made.$2,
        now: _now,
        optionMark: Decimal.parse('0.12'),
        underlyingPrice: Decimal.parse('27.05'),
        deltaAsEntered: -0.21,
        deltaConvention: DeltaConvention.position,
        iv: 21,
      );

      expect(await repo.getSnapshotsForLeg(made.$1.id), before);
      expect(await repo.getSnapshotsForLeg(made.$1.id), isEmpty);
    });
  });
}
