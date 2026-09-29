// D-43's shared list helper (Pro Wave 3 Phase 1). Two callers render the same
// shape -- the delta's "Left out" line and Portfolio's past-expiration
// sentence -- so the phrasing lives here rather than at either call site.

import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/domain/rules/listing.dart';

void main() {
  group('listPhrase joins names the way the two lines read', () {
    test('one name is bare, with no "and"', () {
      expect(listPhrase(['AAL']), 'AAL');
    });

    test('two names take "and" and no comma', () {
      expect(listPhrase(['AAL', 'WBD']), 'AAL and WBD');
    });

    test('three or more take commas and a final "and"', () {
      expect(listPhrase(['AAL', 'PFE', 'WBD']), 'AAL, PFE and WBD');
      expect(listPhrase(['A', 'B', 'C', 'D']), 'A, B, C and D');
    });

    test('an empty list renders nothing at all, never a stray "and"', () {
      expect(listPhrase(const []), '');
    });
  });

  group('listPhraseWithReason names the reason in parentheses', () {
    test('one ticker', () {
      expect(listPhraseWithReason(['PFE'], 'no reading'), 'PFE (no reading)');
    });

    test('two tickers keep the list phrasing inside the clause', () {
      expect(
        listPhraseWithReason(['WBD', 'AAL'], 'past expiration'),
        'WBD, AAL (past expiration)',
      );
    });

    test('an empty list renders nothing, so a reason with no members is absent', () {
      expect(listPhraseWithReason(const [], 'no reading'), '');
    });
  });
}
