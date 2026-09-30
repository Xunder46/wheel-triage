import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/disclaimer.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/features/journal/share_card.dart';
import 'package:wheel_triage/features/journal/share_card_screen.dart';
import 'package:wheel_triage/state/export/export_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/share_card_fixtures.dart';

/// Records every call, so S-309 can assert the file list, the mime type, the
/// path and the subject, and S-311 can assert nothing was shared at all.
class _FakeShareSheet implements ShareSheet {
  final List<List<XFile>> calls = [];

  List<XFile>? get lastFiles => calls.isEmpty ? null : calls.last;
  String? lastSubject;

  @override
  Future<void> shareFiles(List<XFile> files, {String? subject}) async {
    calls.add(files);
    lastSubject = subject;
  }
}

Future<void> _pumpShare(
  WidgetTester tester, {
  required InMemoryWheelRepository repo,
  required _FakeShareSheet sheet,
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        shareSheetProvider.overrideWithValue(sheet),
      ],
      child: MaterialApp(home: ShareCardScreen(now: now ?? DateTime(2026, 9, 28))),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps a control that may be below the fold in the screen's `ListView`.
Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps `Share image` and waits for the capture to finish.
///
/// `RenderRepaintBoundary.toImage` resolves on a real async gap, which the
/// fake clock `pumpAndSettle` drives never provides. The tap therefore runs
/// inside `runAsync`, where the real event loop is live, and the resulting
/// `setState` is settled with a plain pump afterwards.
Future<void> _tapShare(WidgetTester tester) async {
  final finder = find.text('Share image');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

/// Every string the card's own subtree renders, in tree order.
List<String> _cardTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(ShareCard), matching: find.byType(Text)))
    .map((t) => t.data ?? '')
    .toList();

void main() {
  group('S-308: the toggles', () {
    testWidgets('both start off, each adds exactly its own line, and a re-push resets them', (
      tester,
    ) async {
      final now = DateTime(2026, 9, 28);
      final repo = await septemberBook(now: now);
      final sheet = _FakeShareSheet();
      await _pumpShare(tester, repo: repo, sheet: sheet, now: now);

      // On open: no dollar figure, no ticker.
      var texts = _cardTexts(tester);
      expect(texts.any((t) => t.contains('357')), isFalse);
      expect(texts.any((t) => t.contains('\$')), isFalse);
      expect(texts.any((t) => t.contains('BAC')), isFalse);

      final figuresBefore = _cardTexts(tester).where((t) => t.contains('%')).toList();

      await _tap(tester, 'Show dollar amounts');
      texts = _cardTexts(tester);
      // A-8: `netResultLine` always ends `before fees` and appends D-50's
      // clause when there is a gap, so the rendered line carries both. The
      // duplication is logged in the plan's Assumption Log and is Phase 2's
      // shipped behaviour, not this screen's.
      expect(
        texts,
        contains(
          'Net result \$357.00 before fees Before fees: 3 closed legs have no fee recorded.',
        ),
      );
      expect(
        _cardTexts(tester).where((t) => t.contains('%')).toList(),
        figuresBefore,
        reason: 'the dollars toggle must not change any of the five figures',
      );

      await _tap(tester, 'Show tickers');
      texts = _cardTexts(tester);
      expect(texts, contains('BAC · CCL · KO · SNAP · UBER'));
      expect(
        _cardTexts(tester).where((t) => t.contains('%')).toList(),
        figuresBefore,
        reason: 'the tickers toggle must not change any of the five figures',
      );

      // Pop and push again: both toggles are off, the card is back to default.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpShare(tester, repo: repo, sheet: sheet, now: now);
      texts = _cardTexts(tester);
      expect(texts.any((t) => t.contains('357')), isFalse);
      expect(texts.any((t) => t.contains('BAC')), isFalse);

      // No preference was written by any of it.
      expect(repo.preferenceWrites, 0);
    });
  });

  group('S-309: the image, and the one share path', () {
    testWidgets('captures 1080x1350, shares one PNG, and two runs are byte-identical', (
      tester,
    ) async {
      final now = DateTime(2026, 9, 28);
      final repo = await septemberBook(now: now);
      final sheet = _FakeShareSheet();
      await _pumpShare(tester, repo: repo, sheet: sheet, now: now);

      await _tapShare(tester);

      expect(sheet.calls, hasLength(1));
      final file = sheet.lastFiles!.single;
      expect(file.mimeType, 'image/png');
      expect(file.path, 'wheel-triage-2026-09-ledger.png');
      expect(sheet.lastSubject, 'Wheel Triage — September 2026 ledger');

      // `XFile.readAsBytes` and `instantiateImageCodec` both need the real
      // event loop, which only `runAsync` provides.
      final first = (await tester.runAsync(file.readAsBytes))!;
      final decoded = (await tester.runAsync(() => ui.instantiateImageCodec(first)))!;
      final frame = (await tester.runAsync(decoded.getNextFrame))!;
      expect(frame.image.width, 1080);
      expect(frame.image.height, 1350);
      frame.image.dispose();
      decoded.dispose();

      await _tapShare(tester);
      expect(sheet.calls, hasLength(2));
      final second = (await tester.runAsync(sheet.lastFiles!.single.readAsBytes))!;
      expect(second, equals(first), reason: 'the card carries no timestamp');
    });
  });

  group('S-311: the empty month', () {
    testWidgets('renders the empty state, no card and no share button', (tester) async {
      final now = DateTime(2026, 9, 28);
      final repo = await emptySeptemberBook();
      final sheet = _FakeShareSheet();
      await _pumpShare(tester, repo: repo, sheet: sheet, now: now);

      expect(find.text('No cycles closed in September 2026'), findsOneWidget);
      expect(find.byType(ShareCard), findsNothing);
      expect(find.text('Share image'), findsNothing);
      expect(find.text('Share September'), findsOneWidget);
      expect(sheet.calls, isEmpty);
    });

    testWidgets('a month with cycles does render the card', (tester) async {
      final now = DateTime(2026, 9, 28);
      final repo = await septemberBook(now: now);
      final sheet = _FakeShareSheet();
      await _pumpShare(tester, repo: repo, sheet: sheet, now: now);

      expect(find.byType(ShareCard), findsOneWidget);
      expect(find.text('Share image'), findsOneWidget);
      expect(find.text('No cycles closed in September 2026'), findsNothing);
    });
  });

  group('S-312: the card copy', () {
    testWidgets('carries no advice, no praise, and the disclaimer verbatim', (tester) async {
      final now = DateTime(2026, 9, 28);
      final repo = await septemberBook(now: now);
      final sheet = _FakeShareSheet();
      await _pumpShare(tester, repo: repo, sheet: sheet, now: now);

      await _tap(tester, 'Show dollar amounts');
      await _tap(tester, 'Show tickers');

      final copy = _cardTexts(tester).join('\n');

      expect(
        RegExp(
          'recommend|we suggest|our analysis|buy signal|sell signal|opportunity|'
          'guaranteed|you should',
          caseSensitive: false,
        ).allMatches(copy),
        isEmpty,
      );
      for (final banned in [
        'streak',
        'badge',
        'congrat',
        'great',
        'keep it up',
        "you're",
        'your best',
      ]) {
        expect(copy.toLowerCase(), isNot(contains(banned)));
      }

      expect(_cardTexts(tester), contains(kAppDisclaimer));
      expect(copy, contains('Return on capital: net result ÷ peak capital committed'));
    });
  });

  group('S-306: the five figures on the card', () {
    testWidgets('renders the reference arithmetic', (tester) async {
      final now = DateTime(2026, 9, 28);
      final repo = await septemberBook(now: now);
      final sheet = _FakeShareSheet();
      await _pumpShare(tester, repo: repo, sheet: sheet, now: now);

      final copy = _cardTexts(tester).join('\n');
      expect(copy, contains('1.6%'));
      expect(copy, contains('4 of 5'));
      expect(copy, contains('27'));
      expect(copy, contains('82%'));
      expect(
        copy,
        contains(
          'Return on capital: net result ÷ peak capital committed, over cycles closed in '
          'September 2026. Before fees: 3 closed legs have no fee recorded.',
        ),
      );
    });
  });

  group('S-309 structural: one share seam', () {
    test('no file under lib/features/ imports share_plus', () {
      final result = Process.runSync('grep', [
        '-rl',
        'share_plus',
        'lib/features/',
      ], workingDirectory: Directory.current.path);
      expect(result.stdout.toString().trim(), isEmpty);
    });

    test('ShareSheet.shareFiles has exactly two call sites in lib/', () {
      final result = Process.runSync('grep', [
        '-rn',
        r'\.shareFiles(',
        'lib/',
      ], workingDirectory: Directory.current.path);
      final hits = result.stdout.toString().trim().split('\n').where((line) => line.isNotEmpty);
      expect(
        hits,
        hasLength(2),
        reason: 'the export and the share card are the only two callers; '
            'a third would be a second share path. Got:\n${hits.join('\n')}',
      );
      expect(hits.join('\n'), contains('lib/features/journal/share_card_screen.dart'));
      expect(hits.join('\n'), contains('lib/features/settings/settings_screen.dart'));
    });
  });
}
