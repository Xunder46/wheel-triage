import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/core/money/total_per_contract.dart';

void main() {
  group('S-052: perShareValue -- "total per contract" conversion', () {
    test('toggle off -> value passes through unchanged', () {
      final result = perShareValue(Decimal.parse('0.31'), totalPerContract: false);
      expect(result, Decimal.parse('0.31'));
    });

    test('toggle on -> typing 31 stores Decimal.parse("0.31")', () {
      final result = perShareValue(Decimal.parse('31'), totalPerContract: true);
      expect(result, Decimal.parse('0.31'));
    });
  });
}
