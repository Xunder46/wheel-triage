import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/rules/credit_bound.dart';

void main() {
  group('checkCreditBound -- call side (bound is spot)', () {
    final spot = Decimal.parse('45');
    final strike = Decimal.parse('50'); // irrelevant on the call side

    test(
      'value == spot -> never hard-rejected (the no-arbitrage bound is C <= S, inclusive) -- '
      'still a softWarn since spot is always > spot*0.5, but never blocks',
      () {
        final result = checkCreditBound(
          value: Decimal.parse('45'),
          side: OptionType.call,
          spot: spot,
          strike: strike,
        );
        expect(result.level, CreditBoundLevel.softWarn);
        expect(result.blocks, isFalse);
      },
    );

    test('S-050 row 1: value > spot -> hardReject, call message verbatim', () {
      final result = checkCreditBound(
        value: Decimal.parse('46'),
        side: OptionType.call,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.hardReject);
      expect(result.blocks, isTrue);
      expect(
        result.message,
        "A premium can't exceed the share price. Did you enter the total for "
        'the contract? Divide by 100 — one contract covers 100 shares.',
      );
    });

    test('value == spot * 0.5 -> ok (soft-warn boundary is exclusive)', () {
      final result = checkCreditBound(
        value: Decimal.parse('22.5'),
        side: OptionType.call,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.ok);
    });

    test('S-051 row 1: value strictly between spot*0.5 and spot -> softWarn, never blocks', () {
      final result = checkCreditBound(
        value: Decimal.parse('25'),
        side: OptionType.call,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.softWarn);
      expect(result.blocks, isFalse);
      expect(result.message, contains('share price'));
    });

    test('value well below the bound -> ok', () {
      final result = checkCreditBound(
        value: Decimal.parse('0.35'),
        side: OptionType.call,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.ok);
    });
  });

  group('checkCreditBound -- put side (bound is strike)', () {
    final spot = Decimal.parse('39'); // irrelevant on the put side
    final strike = Decimal.parse('40');

    test('value == strike -> never hard-rejected, but still a softWarn (strike > strike*0.5)', () {
      final result = checkCreditBound(
        value: Decimal.parse('40'),
        side: OptionType.put,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.softWarn);
      expect(result.blocks, isFalse);
    });

    test('S-050 row 2: value > strike -> hardReject, put message verbatim', () {
      final result = checkCreditBound(
        value: Decimal.parse('41'),
        side: OptionType.put,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.hardReject);
      expect(result.blocks, isTrue);
      expect(
        result.message,
        "A premium can't exceed the strike price. Did you enter the total for "
        'the contract? Divide by 100 — one contract covers 100 shares.',
      );
    });

    test('value == strike * 0.5 -> ok', () {
      final result = checkCreditBound(
        value: Decimal.parse('20'),
        side: OptionType.put,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.ok);
    });

    test('S-051 row 2: value strictly between strike*0.5 and strike -> softWarn, never blocks', () {
      final result = checkCreditBound(
        value: Decimal.parse('22'),
        side: OptionType.put,
        spot: spot,
        strike: strike,
      );
      expect(result.level, CreditBoundLevel.softWarn);
      expect(result.blocks, isFalse);
      expect(result.message, contains('strike price'));
    });
  });
}
