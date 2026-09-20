import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/rules/bucket.dart';
import 'package:wheel_triage/domain/rules/classify.dart';
import 'package:wheel_triage/domain/rules/formulas.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';
import 'package:wheel_triage/domain/rules/triage_input.dart';

void main() {
  test(
    'S-012: decimal rounding -- credit 0.35, mark 0.175 -> exactly 50.0% captured, '
    'not 49.999999... (required test #8)',
    () {
      final captured = capturedPct(
        openCredit: Decimal.parse('0.35'),
        currentMark: Decimal.parse('0.175'),
      );

      // Decimal equality, not a float epsilon -- this is the exact bug class
      // brief §2 warns about.
      expect(captured, Decimal.parse('50.0'));
      expect(captured == Decimal.parse('50'), isTrue);

      final input = TriageInput(
        capturedPct: captured,
        deltaMagnitude: 0.10,
        iv: null,
        dte: 30,
        extrinsic: Decimal.parse('0.20'),
      );
      final result = classify(input, RuleProfile.standard);

      expect(result, isA<BucketClose>());
      expect((result as BucketClose).reason, '50% of credit captured');
    },
  );
}
