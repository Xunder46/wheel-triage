import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/disclaimer.dart';

/// `docs/brief-pro.md` D-P15's wording, retyped here from the brief so the
/// constant is pinned character-for-character rather than against itself
/// (D-18). The brief's own italic quotes are not part of the string.
const String _dP15 =
    'Wheel Triage is a journal and calculator for your own options trades. '
    'It keeps a record of what you enter and checks those numbers against the '
    'thresholds you set. It is not investment advice. It has no market data '
    'connection and no view on any security.';

void main() {
  group('S-249: the disclaimer, in D-P15\'s exact words', () {
    test('kAppDisclaimer is the brief\'s string, character for character', () {
      expect(kAppDisclaimer, _dP15);
    });

    test('it says what the app is and is not, and tells the user nothing to do', () {
      expect(kAppDisclaimer, startsWith('Wheel Triage is a journal and calculator'));
      expect(kAppDisclaimer, contains('It is not investment advice.'));
      expect(kAppDisclaimer, contains('no market data connection'));
      expect(kAppDisclaimer, contains('no view on any security'));
    });
  });
}
