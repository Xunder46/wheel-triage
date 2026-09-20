import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/rules/formulas.dart';

void main() {
  group('capturedPct', () {
    test('basic capture (not a boundary case -- see S-012 for the exact-50 one)', () {
      final result = capturedPct(
        openCredit: Decimal.parse('1.00'),
        currentMark: Decimal.parse('0.50'),
      );
      expect(result, Decimal.parse('50'));
    });

    test('null openCredit -> null, no crash', () {
      expect(capturedPct(openCredit: null, currentMark: Decimal.parse('0.10')), isNull);
    });

    test('null currentMark -> null, no crash', () {
      expect(capturedPct(openCredit: Decimal.parse('1.00'), currentMark: null), isNull);
    });

    test('openCredit == 0 -> null (division guard, never a crash)', () {
      expect(
        capturedPct(openCredit: Decimal.zero, currentMark: Decimal.parse('0.10')),
        isNull,
      );
    });
  });

  group('dte(expiration, referenceDate)', () {
    test('future expiration -> positive day count', () {
      expect(dte(DateTime(2026, 3, 20), DateTime(2026, 2, 1)), 47);
    });

    test('expiration today -> zero', () {
      expect(dte(DateTime(2026, 3, 20), DateTime(2026, 3, 20)), 0);
    });

    test('expired -> negative day count', () {
      expect(dte(DateTime(2026, 3, 20), DateTime(2026, 3, 23)), -3);
    });

    test('ignores time-of-day on both sides', () {
      expect(
        dte(DateTime(2026, 3, 20, 23, 59), DateTime(2026, 3, 18, 0, 1)),
        2,
      );
    });
  });

  group('intrinsic / extrinsic', () {
    test('call ITM: spot above strike', () {
      final result = intrinsic(
        optionType: OptionType.call,
        strike: Decimal.parse('50.00'),
        spot: Decimal.parse('53.00'),
      );
      expect(result, Decimal.parse('3.00'));
    });

    test('call OTM: spot below strike -> zero, never negative', () {
      final result = intrinsic(
        optionType: OptionType.call,
        strike: Decimal.parse('50.00'),
        spot: Decimal.parse('48.00'),
      );
      expect(result, Decimal.zero);
    });

    test('put ITM: spot below strike', () {
      final result = intrinsic(
        optionType: OptionType.put,
        strike: Decimal.parse('50.00'),
        spot: Decimal.parse('47.00'),
      );
      expect(result, Decimal.parse('3.00'));
    });

    test('put OTM: spot above strike -> zero', () {
      final result = intrinsic(
        optionType: OptionType.put,
        strike: Decimal.parse('50.00'),
        spot: Decimal.parse('52.00'),
      );
      expect(result, Decimal.zero);
    });

    test('null spot -> intrinsic null, no crash (no snapshot yet)', () {
      expect(
        intrinsic(optionType: OptionType.put, strike: Decimal.parse('50.00'), spot: null),
        isNull,
      );
    });

    test('extrinsic = mark - intrinsic', () {
      final result = extrinsic(currentMark: Decimal.parse('0.27'), intrinsic: Decimal.zero);
      expect(result, Decimal.parse('0.27'));
    });

    test('extrinsic null when mark missing', () {
      expect(extrinsic(currentMark: null, intrinsic: Decimal.zero), isNull);
    });
  });

  group('S-040: oneSigmaMove uses stock price, invariant to strike', () {
    test(
      'identical spot/iv/dte -> identical oneSigmaMove at strikes \$8, \$11, \$15 '
      '(exercised via the cushionSigmas pipeline at each strike, per the fixture)',
      () {
        final spot = Decimal.parse('9.29');
        const iv = 87.61;
        const dte = 21;
        final strikes = [Decimal.fromInt(8), Decimal.fromInt(11), Decimal.fromInt(15)];

        Decimal? firstOneSigma;
        for (final strike in strikes) {
          // The corrected signature no longer accepts `strike` at all -- the
          // invariance is structural. `cushionSigmas` is still exercised per
          // strike (its own value legitimately differs), but the thing under
          // test, oneSigmaMove's return value, must be identical every time.
          final oneSigma = oneSigmaMove(spot: spot, iv: iv, dte: dte);
          cushionSigmas(strike: strike, spot: spot, oneSigmaMove: oneSigma);
          firstOneSigma ??= oneSigma;
          expect(oneSigma, firstOneSigma);
        }
        expect(firstOneSigma!.toDouble(), closeTo(1.95, 0.01));
      },
    );
  });

  group('deltaMagnitude', () {
    test('takes the absolute value', () {
      expect(deltaMagnitude(-0.35), 0.35);
      expect(deltaMagnitude(0.35), 0.35);
    });

    test('null -> null, no crash', () {
      expect(deltaMagnitude(null), isNull);
    });
  });
}
