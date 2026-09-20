import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/domain/rules/classify.dart';
import 'package:wheel_triage/domain/rules/formulas.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';
import 'package:wheel_triage/domain/rules/triage_input.dart';

void main() {
  // Supersedes the original S-015 test (which asserted oneSigma ~= $2.31,
  // computed from strike): brief-followup A1 corrects oneSigmaMove to use
  // spot, not strike. This test's --plain-name tag is S-041, not S-015 -- it
  // no longer asserts S-015's superseded oneSigma/cushionSigmas figures. All
  // other assertions in the fixture are unchanged from S-015, per the
  // brief-followup's own "all other assertions in that fixture stand".
  test(
    'S-041: SBET regression fixture, corrected figures -- SBET \$11 call, short 1, opened '
    'at \$0.35 credit, 36 DTE; snapshot mark \$0.27, spot \$9.29, delta -0.2534, IV 87.61%, '
    'DTE 21',
    () {
      const strike = 11;
      final strikeDecimal = Decimal.fromInt(strike);
      final openCredit = Decimal.parse('0.35');
      final mark = Decimal.parse('0.27');
      final spot = Decimal.parse('9.29');
      const enteredDelta = -0.2534;
      const iv = 87.61;
      const dte = 21;

      final captured = capturedPct(openCredit: openCredit, currentMark: mark)!;
      expect(captured.toDouble(), closeTo(22.9, 0.1));

      final magnitude = deltaMagnitude(enteredDelta)!;
      expect(magnitude, 0.2534);

      final band = RuleProfile.standard.rollBandFor(iv);
      expect(band, 0.40); // iv > 70

      final oneSigma = oneSigmaMove(spot: spot, iv: iv, dte: dte)!;
      expect(oneSigma.toDouble(), closeTo(1.95, 0.02)); // corrected from ~$2.31 (A1)

      final cushion = cushionSigmas(strike: strikeDecimal, spot: spot, oneSigmaMove: oneSigma);
      expect(cushion, closeTo(0.88, 0.02)); // new assertion, not in the original S-015

      final intrinsicValue = intrinsic(
        optionType: OptionType.call,
        strike: strikeDecimal,
        spot: spot,
      )!;
      expect(intrinsicValue, Decimal.zero); // OTM call, spot < strike

      final extrinsicValue = extrinsic(currentMark: mark, intrinsic: intrinsicValue)!;
      expect(extrinsicValue, Decimal.parse('0.27'));

      final input = TriageInput(
        capturedPct: captured,
        deltaMagnitude: magnitude,
        iv: iv,
        dte: dte,
        extrinsic: extrinsicValue,
      );
      final result = classify(input, RuleProfile.standard);

      expect(result, isA<BucketLeave>());
      expect((result as BucketLeave).reason, contains('0.2534'));
      expect(result.reason, contains('0.40'));
    },
  );
}
