import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/rules/rule_profile.dart';
import 'package:wheel_triage/domain/rules/screener.dart';

void main() {
  group('S-016: screener yield-score boundaries', () {
    const rows = <(double, int)>[
      (19.9, 0),
      (20.0, 1),
      (34.9, 1),
      (35.0, 2),
      (49.9, 2),
      (50.0, 3),
      (80.0, 3),
    ];
    for (final (yield_, expected) in rows) {
      test('annualisedYield $yield_ -> score $expected', () {
        expect(screenerYieldScore(yield_), expected);
      });
    }
  });

  group('S-017: screener IV-rank-score boundaries', () {
    const rows = <(double, int)>[
      (29.9, 0),
      (30.0, 1),
      (49.9, 1),
      (50.0, 2),
      (69.9, 2),
      (70.0, 3),
      (90.0, 3),
    ];
    for (final (ivRank, expected) in rows) {
      test('ivRank $ivRank -> score $expected', () {
        expect(screenerIvRankScore(ivRank), expected);
      });
    }
  });

  group('S-018: screener cushion-score boundaries', () {
    const rows = <(double, int)>[
      (0.49, 0),
      (0.50, 1),
      (0.99, 1),
      (1.00, 2),
      (1.49, 2),
      (1.50, 3),
      (1.60, 3),
    ];
    for (final (cushion, expected) in rows) {
      test('cushionSigmas $cushion -> score $expected', () {
        expect(screenerCushionScore(cushion), expected);
      });
    }
  });

  group('S-019: screener hard gates pass/fail matrix', () {
    final profile = RuleProfile.standard; // minIvRank=30, minAnnualisedYield=20

    const rows = <(double, double, bool, bool)>[
      (35, 25, true, true), // both pass
      (25, 25, false, true), // ivRank fails
      (35, 15, true, false), // yield fails
      (25, 15, false, false), // both fail
    ];

    for (final (ivRank, annualisedYield, expectIvRank, expectYield) in rows) {
      test('(ivRank=$ivRank, annualisedYield=$annualisedYield)', () {
        final gates = screenerHardGates(
          ivRank: ivRank,
          annualisedYield: annualisedYield,
          profile: profile,
        );
        expect(gates.ivRankPasses, expectIvRank);
        expect(gates.annualisedYieldPasses, expectYield);
        expect(gates.passesAll, expectIvRank && expectYield);
      });
    }

    test(
      'gate pass/fail is independent of the 0-9 soft score, which is still '
      'computed regardless (§4.5)',
      () {
        // (25, 15) fails both hard gates, but the soft score is still a
        // well-defined, non-crashing number -- the gates decide, the score
        // only sorts.
        final score = screenerSortingScore(annualisedYield: 15, ivRank: 25, cushionSigmas: 0.2);
        expect(score, 0);
      },
    );
  });
}
