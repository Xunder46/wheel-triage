import 'package:flutter_test/flutter_test.dart';

import '../../support/screen_a11y_harness.dart';

/// S-313 / S-315 / S-316: every audited surface, at the largest accessibility
/// text size, builds without an exception and names every number it shows.
///
/// One `testWidgets` per row of `auditedSurfaces`, so a failure names the
/// surface rather than an index.
final _now = DateTime(2026, 9, 28);

void main() {
  late SurfaceBook populated;
  late SurfaceBook empty;

  setUp(() async {
    populated = await buildSurfaceBook(SurfaceFixture.populated);
    empty = await buildSurfaceBook(SurfaceFixture.empty);
  });

  for (final surface in auditedSurfaces) {
    testWidgets(
      'S-313 ${surface.name} wraps and names its numbers at $kMaxTextScale',
      (tester) async {
        await auditSurface(tester, surface, book: populated, now: _now);
      },
    );
  }

  for (final surface in auditedEmptySurfaces) {
    testWidgets('S-313 ${surface.name} wraps at $kMaxTextScale', (
      tester,
    ) async {
      // The leg with no reading is the one empty variant that needs a book.
      final book = surface.route.contains(':noReadingLegId')
          ? populated
          : empty;
      await auditSurface(tester, surface, book: book, now: _now);
    });
  }

  // S-316's literal form -- "no node's label contains `--`" -- cannot hold
  // while the value cell still *renders* `--` (the shipped precedent, and the
  // design's own glyph for an absent number): the dash is a separate node
  // from the row that speaks it. The three assertions below are what the
  // scenario is protecting -- the row speaks the quantity plus
  // `not available`, the two spellings of absence never share a node, and no
  // quantity is ever followed by a dash.
  testWidgets(
    'S-316 an absent value is spoken as "not available", never as "--"',
    (tester) async {
      final rows = auditedEmptySurfaces
          .where(
            (row) =>
                row.expectedLabels.any((pair) => pair.$2 == 'not available'),
          )
          .toList();
      expect(rows, isNotEmpty);

      for (final row in rows) {
        final book = row.route.contains(':noReadingLegId') ? populated : empty;
        await auditSurface(tester, row, book: book, now: _now);
        final labels = semanticsLabels(tester);

        for (final pair in row.expectedLabels.where(
          (p) => p.$2 == 'not available',
        )) {
          expect(
            pairMatches(labels, pair),
            isTrue,
            reason: '${row.name}: $pair\n${labels.join('\n---\n')}',
          );
        }

        expect(
          anyLineMatches(labels, RegExp('not available.*--|--.*not available')),
          isFalse,
          reason: '${row.name}: one node mixes the two spellings of absence',
        );

        for (final pair in row.expectedLabels.where(
          (p) => p.$2 == 'not available',
        )) {
          expect(
            anyLineMatches(labels, RegExp('${RegExp.escape(pair.$1)}.*--')),
            isFalse,
            reason:
                '${row.name}: ${pair.$1} is followed by a dash\n${labels.join('\n---\n')}',
          );
        }
      }
    },
  );
}
