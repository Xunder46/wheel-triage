import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/domain/rules/classify.dart';
import 'package:wheel_triage/domain/rules/formulas.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';
import 'package:wheel_triage/domain/rules/triage_input.dart';

void main() {
  final standard = RuleProfile.standard;

  test('S-001: Gate 1 fires in isolation', () {
    final input = TriageInput(
      capturedPct: Decimal.parse('55'),
      deltaMagnitude: 0.10,
      iv: null,
      dte: 30,
      extrinsic: Decimal.parse('0.20'),
    );
    expect(classify(input, standard), Bucket.close(reason: '55% of credit captured'));
  });

  test('S-002: Gate 2 fires in isolation', () {
    final input = TriageInput(
      capturedPct: Decimal.parse('20'),
      deltaMagnitude: 0.75,
      iv: null,
      dte: 30,
      extrinsic: Decimal.parse('0.20'),
    );
    expect(
      classify(input, standard),
      Bucket.assign(reason: 'Delta 0.75 at or above 0.70'),
    );
  });

  test(
    'S-100: Gate 2 branches to assign when acceptsAssignment: true '
    '(unchanged from S-002/S-006, now proven to survive the new field\'s default)',
    () {
      final input = TriageInput(
        capturedPct: Decimal.parse('20'),
        deltaMagnitude: 0.85,
        iv: null,
        dte: 30,
        extrinsic: Decimal.parse('0.20'),
        acceptsAssignment: true,
      );
      expect(classify(input, standard), Bucket.assign(reason: 'Delta 0.85 at or above 0.70'));
    },
  );

  test(
    'S-101: Gate 2 branches to roll when acceptsAssignment: false, exact reason string '
    '(the coordinator\'s overridden string, Feature Invariant 30 -- not the brief\'s verbatim '
    '"...and you\'d rather keep this position -- roll it out or buy it back")',
    () {
      final input = TriageInput(
        capturedPct: Decimal.parse('20'),
        deltaMagnitude: 0.85,
        iv: null,
        dte: 30,
        extrinsic: Decimal.parse('0.20'),
        acceptsAssignment: false,
      );
      expect(
        classify(input, standard),
        Bucket.roll(reason: "Delta 0.85 at or above 0.70, and assignment isn't wanted here"),
      );
    },
  );

  test('S-003: Gate 3 fires in isolation', () {
    final input = TriageInput(
      capturedPct: Decimal.parse('20'),
      deltaMagnitude: 0.32,
      iv: null, // -> base band 0.30
      dte: 30,
      extrinsic: Decimal.parse('0.20'),
    );
    expect(
      classify(input, standard),
      Bucket.roll(reason: 'Delta 0.32 at or above the 0.30 band'),
    );
  });

  test('S-004: Gate 4 fires in isolation', () {
    final input = TriageInput(
      capturedPct: Decimal.parse('20'),
      deltaMagnitude: 0.10,
      iv: null,
      dte: 2,
      extrinsic: Decimal.parse('0.03'),
    );
    expect(
      classify(input, standard),
      Bucket.close(reason: 'Only \$0.03 of time value left'),
    );
  });

  test('S-005: fallback leave, valid data, no gate fires', () {
    final input = TriageInput(
      capturedPct: Decimal.parse('20'),
      deltaMagnitude: 0.15,
      iv: null, // -> base band 0.30
      dte: 30,
      extrinsic: Decimal.parse('0.20'),
    );
    expect(
      classify(input, standard),
      Bucket.leave(reason: 'Delta 0.15 below the 0.30 band'),
    );
  });

  test(
    'S-006: gate precedence -- delta 0.85 with 10% captured -> assign, not roll '
    '(required test #2 from brief §8; the naive gate order gets this wrong)',
    () {
      final input = TriageInput(
        capturedPct: Decimal.parse('10'),
        deltaMagnitude: 0.85,
        iv: null,
        dte: 30,
        extrinsic: Decimal.parse('0.20'),
      );
      final result = classify(input, standard);
      expect(result, isA<BucketAssign>());
      expect(result, isNot(isA<BucketRoll>()));
    },
  );

  test('S-007: Gate 1 wins over everything (required test #3 from brief §8)', () {
    final input = TriageInput(
      capturedPct: Decimal.parse('60'),
      deltaMagnitude: 0.90,
      iv: null,
      dte: 30,
      extrinsic: Decimal.parse('0.20'),
    );
    expect(classify(input, standard), Bucket.close(reason: '60% of credit captured'));
  });

  // Supersedes the original S-010 test (which asserted Bucket.leave for this
  // identical fixture): brief-followup A4 frames the original brief's
  // classify() returning Bucket.leave for the null-input case as a spec
  // error, not an implementation bug. This test's --plain-name tag is
  // S-042, not S-010 -- it no longer asserts S-010's superseded expectation.
  test(
    'S-042: no-snapshot leg classifies as unknown, not leave, no crash',
    () {
      const input = TriageInput(
        capturedPct: null,
        deltaMagnitude: null,
        iv: null,
        dte: 30, // always computable, even with zero snapshots (Feature Invariant 7)
        extrinsic: null,
      );
      expect(
        classify(input, standard),
        Bucket.unknown(reason: 'No snapshot yet'),
      );
    },
  );

  group('S-011: dte == 0 and dte < 0 guard division by zero (required test #7)', () {
    test('row A: dte == 0 -> oneSigmaMove is exactly zero, cushionSigmas is null', () {
      final oneSigma = oneSigmaMove(spot: Decimal.parse('50'), iv: 30, dte: 0);
      expect(oneSigma, Decimal.zero);

      final cushion = cushionSigmas(
        strike: Decimal.parse('50'),
        spot: Decimal.parse('48'),
        oneSigmaMove: oneSigma,
      );
      expect(cushion, isNull);
    });

    test(
      'row B: dte < 0 (expired, not yet recorded) -> treated identically to dte == 0, '
      'no exception',
      () {
        final oneSigma = oneSigmaMove(spot: Decimal.parse('50'), iv: 30, dte: -3);
        expect(oneSigma, Decimal.zero);

        final cushion = cushionSigmas(
          strike: Decimal.parse('50'),
          spot: Decimal.parse('48'),
          oneSigmaMove: oneSigma,
        );
        expect(cushion, isNull);
      },
    );
  });

  test(
    'S-046: behavioral flip -- resolved IV changes the actual bucket, not just the label '
    '(Q9 addition #1: pins the A3 fix as classification behavior, not cosmetic)',
    () {
      // Pre-fix path: feeding TriageInput.iv = snapshot.iv directly (null,
      // since the snapshot has no IV recorded) drops straight to the base
      // 0.30 band.
      final preFixInput = TriageInput(
        capturedPct: Decimal.parse('20'), // below the 50% target, Gate 1 doesn't fire
        deltaMagnitude: 0.35,
        iv: null,
        dte: 30, // above tailDteDays=3, Gate 4 doesn't fire regardless of extrinsic
        extrinsic: Decimal.parse('0.20'),
      );
      final preFixResult = classify(preFixInput, standard);
      expect(preFixResult, isA<BucketRoll>()); // 0.35 >= 0.30

      // Post-fix path: feeding the resolved IV (leg.ivAtOpen = 83.0, since
      // the snapshot's own IV is null) into TriageInput.iv.
      final postFixInput = TriageInput(
        capturedPct: Decimal.parse('20'),
        deltaMagnitude: 0.35,
        iv: 83.0,
        dte: 30,
        extrinsic: Decimal.parse('0.20'),
      );
      final postFixResult = classify(postFixInput, standard);
      expect(postFixResult, isA<BucketLeave>()); // 0.35 < 0.40

      // The two paths disagree on this fixture -- that disagreement IS the
      // point of the scenario.
      expect(preFixResult.runtimeType, isNot(postFixResult.runtimeType));
    },
  );
}
