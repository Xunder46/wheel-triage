import 'package:decimal/decimal.dart';

/// `Decimal.parse('3800')` → `'$3,800'` — whole dollars, half-up, with
/// thousands separators (D-15). The summary tiles on Today's ledger strip
/// and Record's preview use this; position rows and the detail sheet keep
/// two decimals instead (`brief-ledger.md` §8).
///
/// `lib/domain/rules/obligation.dart` renders its own obligation figure the
/// same way and keeps a private copy: the rules layer may import only
/// `lib/domain/models/`, so it cannot reach `lib/core/` and sharing this one
/// would break the one-way dependency the architecture depends on.
String wholeDollars(Decimal value) {
  final whole = value.round().toBigInt().toString();
  final negative = whole.startsWith('-');
  final digits = negative ? whole.substring(1) : whole;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$$buffer';
}
