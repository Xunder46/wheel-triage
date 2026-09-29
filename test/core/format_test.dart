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

  group('monthYearText spells the month out (D-51, D-45)', () {
    test('a month reads as its full name and the year', () {
      expect(monthYearText(DateTime.utc(2026, 9, 1)), 'September 2026');
      expect(monthYearText(DateTime.utc(2026, 9, 28)), 'September 2026');
      expect(monthYearText(DateTime.utc(2027, 1, 31)), 'January 2027');
    });

    test('every month has its own full name, and none is abbreviated', () {
      const expected = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      for (var month = 1; month <= 12; month++) {
        expect(monthYearText(DateTime.utc(2026, month, 15)), '${expected[month - 1]} 2026');
      }
    });

    test('the year is never abbreviated or padded', () {
      expect(monthYearText(DateTime.utc(999, 5, 1)), 'May 999');
      expect(monthYearText(DateTime.utc(10000, 5, 1)), 'May 10000');
    });
  });

  group('signedSharesText renders a position delta (D-43)', () {
    test('a positive total carries an explicit plus', () {
      expect(signedSharesText(360.0), '+360 shares');
      expect(signedSharesText(76.0), '+76 shares');
      expect(signedSharesText(1.0), '+1 shares');
    });

    test('a negative total uses the app\'s own minus sign, not a hyphen', () {
      expect(signedSharesText(-30.0), '\u221230 shares');
      expect(signedSharesText(-25.0), '\u221225 shares');
      expect(signedSharesText(-30.0), isNot(contains('-')));
    });

    test('a total of zero carries no sign at all', () {
      expect(signedSharesText(0.0), '0 shares');
      expect(signedSharesText(-0.0), '0 shares');
    });

    test('no reading at all renders the app\'s own placeholder', () {
      expect(signedSharesText(null), '--');
    });

    test('shares are whole, rounded away from zero on a half', () {
      expect(signedSharesText(360.4), '+360 shares');
      expect(signedSharesText(360.5), '+361 shares');
      expect(signedSharesText(-360.5), '\u2212361 shares');
      // A binary artefact from the shares arithmetic must not reach the
      // screen as 75.99999999999999.
      expect(signedSharesText(0.19 * 100 * 4), '+76 shares');
    });

    test('a four-figure share count is grouped', () {
      expect(signedSharesText(1000.0), '+1,000 shares');
      expect(signedSharesText(-2500.0), '\u22122,500 shares');
      expect(signedSharesText(12345.0), '+12,345 shares');
    });
  });

  group('percentText renders a ratio to a fixed number of decimals (D-48)', () {
    test('one decimal by default, matching the Journal row', () {
      expect(percentText(1.5627), '1.6%');
      expect(percentText(1.4), '1.4%');
      expect(percentText(0.6), '0.6%');
      expect(percentText(83.0), '83.0%');
      expect(percentText(0.0), '0.0%');
    });

    test('a whole percent is available for the figures that want one', () {
      expect(percentText(82.0, decimals: 0), '82%');
      expect(percentText(1.5627, decimals: 0), '2%');
    });

    test('a negative ratio keeps its sign', () {
      expect(percentText(-1.5), '-1.5%');
      expect(percentText(-1.5, decimals: 0), '-2%');
    });

    test('no computable value renders the placeholder, never a zero', () {
      expect(percentText(null), '--');
      expect(percentText(null, decimals: 0), '--');
    });
  });
}
