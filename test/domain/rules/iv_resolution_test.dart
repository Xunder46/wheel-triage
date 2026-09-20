import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/iv_resolution.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';

Leg _leg({double? ivAtOpen}) => Leg(
  id: 'l1',
  cycleId: 'c1',
  sequence: 0,
  optionType: OptionType.call,
  strike: Decimal.parse('11.00'),
  expiration: DateTime.utc(2026, 4, 17),
  contracts: 1,
  openedAt: DateTime.utc(2026, 3, 1),
  openCreditPerShare: Decimal.parse('0.35'),
  ruleProfileVersionId: 'rule-profile-standard-v1',
  ivAtOpen: ivAtOpen,
);

Snapshot _snapshot({double? iv}) => Snapshot(
  id: 's1',
  legId: 'l1',
  takenAt: DateTime.utc(2026, 3, 22),
  optionMark: Decimal.parse('0.27'),
  underlyingPrice: Decimal.parse('9.29'),
  deltaAsEntered: -0.2534,
  deltaConvention: DeltaConvention.position,
  iv: iv,
);

void main() {
  test('S-043: resolveIv -- snapshot IV present, wins over leg.ivAtOpen', () {
    final result = resolveIv(snapshot: _snapshot(iv: 45.0), leg: _leg(ivAtOpen: 20.0));
    expect(result.value, 45.0);
    expect(result.source, IvSource.snapshotIv);
    expect(RuleProfile.standard.rollBandFor(result.value), 0.35);
  });

  test('S-044: resolveIv -- snapshot IV null, leg IV at open present', () {
    final result = resolveIv(snapshot: _snapshot(iv: null), leg: _leg(ivAtOpen: 83.0));
    expect(result.value, 83.0);
    expect(result.source, IvSource.legIvAtOpen);
    expect(RuleProfile.standard.rollBandFor(result.value), 0.40);
  });

  test('S-045: resolveIv -- both null -> profileDefault', () {
    final result = resolveIv(snapshot: _snapshot(iv: null), leg: _leg(ivAtOpen: null));
    expect(result.value, isNull);
    expect(result.source, IvSource.profileDefault);
    expect(RuleProfile.standard.rollBandFor(result.value), 0.30);
  });

  test('resolveIv -- no snapshot at all falls through to leg.ivAtOpen', () {
    final result = resolveIv(snapshot: null, leg: _leg(ivAtOpen: 60.0));
    expect(result.value, 60.0);
    expect(result.source, IvSource.legIvAtOpen);
  });

  group('rollBandLabel -- Feature Invariant 18 verbatim templates', () {
    test('snapshotIv', () {
      final resolved = resolveIv(snapshot: _snapshot(iv: 45.0), leg: _leg(ivAtOpen: 20.0));
      expect(
        rollBandLabel(band: 0.35, resolvedIv: resolved),
        "0.35 — from this snapshot's IV (45%)",
      );
    });

    test('legIvAtOpen (the brief\'s own example, kept verbatim)', () {
      final resolved = resolveIv(snapshot: _snapshot(iv: null), leg: _leg(ivAtOpen: 83.0));
      expect(
        rollBandLabel(band: 0.40, resolvedIv: resolved),
        '0.40 — from IV at open (83%)',
      );
    });

    test('profileDefault (the brief\'s own example, kept verbatim)', () {
      final resolved = resolveIv(snapshot: _snapshot(iv: null), leg: _leg(ivAtOpen: null));
      expect(rollBandLabel(band: 0.30, resolvedIv: resolved), '0.30 — no IV on file');
    });
  });
}
