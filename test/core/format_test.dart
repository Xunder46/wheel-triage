// `lib/core/format.dart`'s Pro-release additions (Phase 6): the two formatters
// the paywall and the Settings plan row need, neither of which existed before
// Wave 2. The rest of the file is covered by the screens that use it.

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/format.dart';

void main() {
  group('currencyText formats a store price in the store\'s own currency', () {
    test('USD and EUR both carry their own symbol, not the locale\'s', () {
      expect(currencyText(Decimal.parse('2.50'), 'USD'), '\$2.50');
      expect(currencyText(Decimal.parse('2.49'), 'EUR'), '€2.49');
      expect(currencyText(Decimal.parse('79.99'), 'USD'), '\$79.99');
    });

    test('the value is formatted to the currency\'s own precision', () {
      // A derived per-month figure is a Decimal with more precision than a
      // price has; the formatter, not the caller, decides what is shown.
      expect(currencyText(Decimal.parse('2.5'), 'USD'), '\$2.50');
      expect(currencyText(Decimal.parse('2'), 'USD'), '\$2.00');
    });

    test('a price that crosses a thousands boundary is grouped', () {
      expect(currencyText(Decimal.parse('1234.5'), 'USD'), '\$1,234.50');
    });

    test('an empty currency code falls back to the locale rather than throwing', () {
      // A gateway that reported a price without a code must not be able to
      // crash the paywall (D-31).
      final text = currencyText(Decimal.parse('2.50'), '');
      expect(text, contains('2.50'));
    });

    test('an unrecognised currency code is still formatted, not rejected', () {
      final text = currencyText(Decimal.parse('2.50'), 'ZZZ');
      expect(text, contains('2.50'));
    });
  });

  group('renewalDateText spells the year out', () {
    test('a renewal date reads as month, day, year', () {
      expect(renewalDateText(DateTime(2027, 10, 5)), 'Oct 5, 2027');
      expect(renewalDateText(DateTime(2026, 3, 3)), 'Mar 3, 2026');
      expect(renewalDateText(DateTime(2026, 12, 31)), 'Dec 31, 2026');
    });

    test('the month abbreviation is fixed and locale-independent', () {
      for (var month = 1; month <= 12; month++) {
        expect(renewalDateText(DateTime(2026, month, 1)), matches(r'^[A-Z][a-z]{2} 1, 2026$'));
      }
    });

    test('a single-digit day has no padding, unlike dateText', () {
      expect(renewalDateText(DateTime(2026, 1, 9)), 'Jan 9, 2026');
      expect(dateText(DateTime(2026, 1, 9)), '2026-01-09');
    });
  });
}
