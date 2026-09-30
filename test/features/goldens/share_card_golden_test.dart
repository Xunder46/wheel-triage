import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/theme/app_theme.dart';
import 'package:wheel_triage/domain/rules/share_card.dart';
import 'package:wheel_triage/features/journal/share_card.dart';
import 'package:wheel_triage/state/journal/journal_controller.dart';

import '../../support/share_card_fixtures.dart';

/// S-310: the card in both themes, generated and compared on the Mac only
/// (`docs/conventions.md` §3 — goldens render differently on other systems).
///
/// The card is pumped at its own fixed logical size, so the golden is the
/// export's own 4:5 surface rather than whatever the screen's `ListView`
/// happened to give it.
Widget _wrap(ShareCard card, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    backgroundColor: theme.scaffoldBackgroundColor,
    body: Center(child: card),
  ),
);

/// S-306's month, read through the Journal's own controller so the golden
/// renders the same `CyclePnl` the screen does.
Future<List<ShareCardCycle>> _septemberCycles() async {
  final now = DateTime(2026, 9, 28);
  final repo = await septemberBook(now: now);
  final controller = JournalController(repo);
  await controller.load(now: now);
  return cyclesInCardMonth(
    cycles: [
      for (final row in controller.state.rows)
        (cycle: row.cycle, ticker: row.ticker, legs: row.legs, pnl: row.pnl),
    ],
    now: now,
  );
}

void main() {
  group('S-310: the card in both themes', () {
    for (final (themeName, theme) in <(String, ThemeData)>[
      ('dark', darkTheme),
      ('light', lightTheme),
    ]) {
      testWidgets('the September card in the $themeName theme', (tester) async {
        final cycles = await _septemberCycles();
        await tester.pumpWidget(
          _wrap(
            ShareCard(
              monthYear: 'September 2026',
              cycles: cycles,
              showDollars: true,
              showTickers: true,
            ),
            theme,
          ),
        );
        await expectLater(
          find.byType(ShareCard),
          matchesGoldenFile('share_card_$themeName.png'),
        );
      });
    }

    // The goldens catch a palette drift; these pin the two things a golden
    // alone would let through as "looks fine" (D-53, Feature Invariant 11)
    // without needing an image diff to say why.
    testWidgets('the two themes are genuinely different, and the figures are not', (
      tester,
    ) async {
      final cycles = await _septemberCycles();
      final rendered = <String, (Color, List<String>)>{};

      for (final (themeName, theme) in <(String, ThemeData)>[
        ('dark', darkTheme),
        ('light', lightTheme),
      ]) {
        await tester.pumpWidget(
          _wrap(
            ShareCard(
              monthYear: 'September 2026',
              cycles: cycles,
              showDollars: true,
              showTickers: true,
            ),
            theme,
          ),
        );
        // `MaterialApp` cross-fades a theme change over 200ms, and the second
        // iteration of this loop is a change; settle so the assertions read
        // the theme they name rather than a half-lerped one.
        await tester.pumpAndSettle();
        rendered[themeName] = (
          tester.widget<DecoratedBox>(
            find.descendant(of: find.byType(ShareCard), matching: find.byType(DecoratedBox)).first,
          ).decoration.let((d) => (d as BoxDecoration).color!),
          tester
              .widgetList<Text>(
                find.descendant(of: find.byType(ShareCard), matching: find.byType(Text)),
              )
              .map((t) => t.data ?? '')
              .toList(),
        );
      }

      // The dark card is genuinely dark, so the test cannot pass by ignoring
      // the theme.
      expect(rendered['dark']!.$1, isNot(rendered['light']!.$1));
      expect(rendered['dark']!.$1.computeLuminance(), lessThan(0.5));
      expect(rendered['light']!.$1.computeLuminance(), greaterThan(0.5));

      // The five figures are the same strings in both.
      expect(rendered['dark']!.$2, equals(rendered['light']!.$2));
      for (final figure in ['1.6%', '5', '4 of 5', '27', '82%']) {
        expect(rendered['dark']!.$2, contains(figure));
      }
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
