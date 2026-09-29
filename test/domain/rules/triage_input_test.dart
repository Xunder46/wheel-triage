import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/triage_input.dart';

Leg _leg({double? ivAtOpen}) => Leg(
  id: 'leg-1',
  cycleId: 'cycle-1',
  sequence: 0,
  optionType: OptionType.put,
  strike: Decimal.parse('50.00'),
  expiration: DateTime.utc(2026, 10, 16),
  contracts: 1,
  openedAt: DateTime.utc(2026, 9, 1),
  openCreditPerShare: Decimal.parse('1.00'),
  ruleProfileVersionId: 'rule-profile-standard-v1',
  ivAtOpen: ivAtOpen,
);

Snapshot _snapshot({double? iv}) => Snapshot(
  id: 'snap-1',
  legId: 'leg-1',
  takenAt: DateTime.utc(2026, 9, 20),
  optionMark: Decimal.parse('0.40'),
  underlyingPrice: Decimal.parse('48.00'),
  deltaAsEntered: -0.25,
  deltaConvention: DeltaConvention.position,
  iv: iv,
);

void main() {
  group('S-227: one TriageInput assembly, three callers', () {
    test('a persisted snapshot and an identical transient snapshot agree', () {
      final leg = _leg();
      final persisted = _snapshot(iv: 21.0);
      final transient = _snapshot(iv: 21.0);

      final a = triageInputFor(leg: leg, snapshot: persisted, dte: 26);
      final b = triageInputFor(leg: leg, snapshot: transient, dte: 26);

      expect(a.capturedPct, b.capturedPct);
      expect(a.deltaMagnitude, b.deltaMagnitude);
      expect(a.iv, b.iv);
      expect(a.dte, b.dte);
      expect(a.extrinsic, b.extrinsic);
      expect(a.acceptsAssignment, b.acceptsAssignment);
    });

    test('the assembled values are the documented ones', () {
      final input = triageInputFor(leg: _leg(), snapshot: _snapshot(iv: 21.0), dte: 26);
      // (1.00 - 0.40) / 1.00 * 100 = 60.
      expect(input.capturedPct, Decimal.parse('60'));
      expect(input.deltaMagnitude, 0.25);
      expect(input.iv, 21.0);
      expect(input.dte, 26);
      // intrinsic = max(0, 50 - 48) = 2.00; extrinsic = 0.40 - 2.00 = -1.60.
      expect(input.extrinsic, Decimal.parse('-1.60'));
      expect(input.acceptsAssignment, isTrue);
    });

    test('a null snapshot yields the "no snapshot yet" input', () {
      final input = triageInputFor(leg: _leg(), snapshot: null, dte: 26);
      expect(input.capturedPct, isNull);
      expect(input.deltaMagnitude, isNull);
      expect(input.iv, isNull);
      expect(input.dte, 26);
      expect(input.extrinsic, isNull);
      expect(input.acceptsAssignment, isTrue);
    });

    test('a null snapshot still resolves IV from the leg when it has one', () {
      // Feature Invariant 18: the resolution order is snapshot -> leg's
      // ivAtOpen -> profile default, and it is a classification input, not a
      // display-only one. With no snapshot the leg's own IV is what Gate 3
      // must see.
      final input = triageInputFor(leg: _leg(ivAtOpen: 22.0), snapshot: null, dte: 26);
      expect(input.iv, 22.0);
    });

    test('a blank IV on a real snapshot falls back to IV at open', () {
      final input = triageInputFor(leg: _leg(ivAtOpen: 22.0), snapshot: _snapshot(), dte: 26);
      expect(input.iv, 22.0);
    });

    test('acceptsAssignment is carried from the leg', () {
      final leg = Leg(
        id: 'leg-1',
        cycleId: 'cycle-1',
        sequence: 0,
        optionType: OptionType.put,
        strike: Decimal.parse('50.00'),
        expiration: DateTime.utc(2026, 10, 16),
        contracts: 1,
        openedAt: DateTime.utc(2026, 9, 1),
        openCreditPerShare: Decimal.parse('1.00'),
        ruleProfileVersionId: 'rule-profile-standard-v1',
        acceptsAssignment: false,
      );
      expect(triageInputFor(leg: leg, snapshot: _snapshot(iv: 21.0), dte: 26).acceptsAssignment, isFalse);
      expect(triageInputFor(leg: leg, snapshot: null, dte: 26).acceptsAssignment, isFalse);
    });

    test('a call leg computes intrinsic the other way round', () {
      final call = Leg(
        id: 'leg-2',
        cycleId: 'cycle-1',
        sequence: 1,
        optionType: OptionType.call,
        strike: Decimal.parse('50.00'),
        expiration: DateTime.utc(2026, 10, 16),
        contracts: 1,
        openedAt: DateTime.utc(2026, 9, 1),
        openCreditPerShare: Decimal.parse('1.00'),
        ruleProfileVersionId: 'rule-profile-standard-v1',
      );
      final input = triageInputFor(leg: call, snapshot: _snapshot(iv: 21.0), dte: 26);
      // intrinsic = max(0, 48 - 50) = 0; extrinsic = 0.40.
      expect(input.extrinsic, Decimal.parse('0.40'));
    });
  });
}
