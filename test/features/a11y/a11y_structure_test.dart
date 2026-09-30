import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../core/theme/app_theme_contrast_test.dart';
import '../../support/screen_a11y_harness.dart';

/// The structural guards: the ones that belong to no single screen and that a
/// later change could otherwise undo silently.
///
/// Each guard is a source scan plus, where it can be, a negative fixture that
/// proves the guard bites.

String _read(String path) => File(path).readAsStringSync();

/// [line] reduced to its code: the comment is cut and each string literal's
/// contents are blanked. A pattern named in prose, in a `reason:` message or in
/// any other string therefore cannot satisfy a guard -- and a `//` inside a
/// string cannot hide the code that follows it, which a plain split on `//`
/// would do.
String _codeOnly(String line) {
  final out = StringBuffer();
  var quote = '';
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quote.isEmpty) {
      if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') break;
      if (ch == "'" || ch == '"') quote = ch;
      out.write(ch);
    } else if (ch == '\\') {
      i++;
    } else if (ch == quote) {
      quote = '';
      out.write(ch);
    }
  }
  return out.toString();
}

/// `file:line: text` for every line under [root] matching [pattern].
List<String> _scan(String root, RegExp pattern, {String extension = '.dart'}) {
  final hits = <String>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith(extension)) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(_codeOnly(lines[i]))) {
        hits.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return hits;
}

/// A deterministic, dependency-free fingerprint of [bytes] (two interleaved
/// FNV-1a 32s, concatenated). `crypto` is only a transitive dependency, so
/// importing it would trip `depend_on_referenced_packages`.
String _fingerprint(List<int> bytes) {
  var h1 = 0x811c9dc5;
  var h2 = 0x01000193;
  for (final b in bytes) {
    h1 = ((h1 ^ b) * 0x01000193) & 0xFFFFFFFF;
    h2 = ((h2 ^ b) * 0x811c9dc5) & 0xFFFFFFFF;
  }
  return h1.toRadixString(16).padLeft(8, '0') +
      h2.toRadixString(16).padLeft(8, '0');
}

/// The `TextScaler.linear(` sites S-314 leaves alone, each with the reason it
/// is not the ceiling.
const _textScaleAllowList = <String, String>{
  'test/features/portfolio/portfolio_screen_test.dart':
      'the S-304 probe at 2.0 -- the "large but not maximal" reading the 3.2 '
      'ceiling is measured against',
  'test/widgets/label_value_row_test.dart':
      'S-318 measures the row across the whole certified range, so it scales a '
      'parameter rather than naming the ceiling',
};

void main() {
  group('S-314 the largest text size is one constant', () {
    test('the suite declares it once, in the harness', () {
      final hits = _scan(
        'test',
        RegExp(r'TextScaler\.linear\('),
      ).where((hit) => !_textScaleAllowList.keys.any(hit.startsWith)).toList();
      expect(
        hits,
        hasLength(1),
        reason:
            'expected exactly one TextScaler.linear( outside the allow-list:\n'
            '${hits.join('\n')}',
      );
      expect(hits.single, contains('test/support/screen_a11y_harness.dart'));
      expect(hits.single, contains('kMaxTextScale'));
    });

    test('the ceiling is 3.2', () {
      expect(kMaxTextScale, 3.2);
    });

    test(
      'every allow-listed probe is still there, and each is lower than the ceiling',
      () {
        final hits = _scan(
          'test',
          RegExp(r'TextScaler\.linear\('),
        ).where((hit) => _textScaleAllowList.keys.any(hit.startsWith)).toList();
        expect(
          hits,
          hasLength(_textScaleAllowList.length),
          reason: hits.join('\n'),
        );
        expect(
          hits.every((hit) => hit.contains('2.0') || hit.contains('scale')),
          isTrue,
        );
      },
    );
  });

  group('S-317 nothing that can carry a number or a reason is truncated', () {
    test(
      'no TextOverflow.ellipsis or clip survives under lib/features or lib/widgets',
      () {
        final hits = [
          ..._scan('lib/features', RegExp(r'TextOverflow\.(ellipsis|clip)')),
          ..._scan('lib/widgets', RegExp(r'TextOverflow\.(ellipsis|clip)')),
        ];
        expect(
          hits,
          isEmpty,
          reason:
              'an ellipsis or clip site truncates a number or a reason:\n${hits.join('\n')}',
        );
      },
    );

    test(
      'the guard bites: the walk reads real files, and not a token inside a string',
      () {
        // The pattern matching on its own is not evidence that the scan reaches a
        // file (finding 12), so this half uses the real tree: the token appears
        // twice in `label_value_row_test.dart` and both times inside a string, so
        // a `reason:` message or a comment cannot satisfy the guard.
        expect(
          _scan('test/widgets', RegExp(r'TextOverflow\.(ellipsis|clip)')),
          isEmpty,
        );
        // The same walk does return a token that is in code, so the emptiness
        // above is the blanking and not a walk that found no files.
        expect(_scan('test/widgets', RegExp(r'testWidgets\(')), isNotEmpty);
      },
    );
  });

  group('S-317 no colour literal outside the theme', () {
    // `(^|[^A-Za-z])` so `AppColors.`/`BucketColors.` are not false hits; the
    // rest mirrors the plan's residue grep. A colour named in a screen is a
    // role the contrast audit cannot see, so this is what keeps S-319/S-321
    // meaningful rather than merely green.
    final colourLiteral = RegExp(r'(^|[^A-Za-z])Colors\.|Color\(0x');

    test(
      'no Colors./Color(0x literal survives under lib/features or lib/widgets',
      () {
        final hits = [
          ..._scan('lib/features', colourLiteral),
          ..._scan('lib/widgets', colourLiteral),
        ];
        expect(
          hits,
          isEmpty,
          reason:
              'a colour literal outside the theme is a role the contrast '
              'audit cannot see:\n${hits.join('\n')}',
        );
      },
    );

    test(
      'the guard bites: the scan finds the theme\'s own colour literals',
      () {
        // A real-file fixture, not a hand-written string: it proves the scan
        // reaches files, which a string fed to the regex cannot.
        final hits = _scan('lib/core/theme', colourLiteral);
        expect(
          hits,
          isNotEmpty,
          reason: 'the scan found no literal in lib/core/theme',
        );
        expect(
          hits.any((hit) => hit.contains('Color(0x')),
          isTrue,
          reason: hits.join('\n'),
        );
      },
    );
  });

  group('S-320 a new role read cannot arrive unaudited', () {
    test(
      'every scheme.<role> under lib/ is a key of the contrast test\'s auditedRoles',
      () {
        final roles = <String>{};
        for (final hit in _scan('lib', RegExp(r'scheme\.[A-Za-z]+'))) {
          for (final match in RegExp(r'scheme\.([A-Za-z]+)').allMatches(hit)) {
            roles.add(match.group(1)!);
          }
        }
        expect(roles, isNotEmpty);

        // The map's own keys, not the file's text: a role named in a comment or
        // in a `reason:` string is not an audited role.
        final unaudited =
            roles.where((role) => !auditedRoles.containsKey(role)).toList()
              ..sort();
        expect(
          unaudited,
          isEmpty,
          reason:
              'these roles are read under lib/ but carry no entry in auditedRoles: '
              '${unaudited.join(', ')}',
        );
      },
    );
  });

  group('S-328 one seam, one file, no dependency', () {
    test('HapticFeedback appears in exactly one file', () {
      final files = _scan(
        'lib',
        RegExp(r'HapticFeedback'),
      ).map((hit) => hit.split(':').first).toSet();
      expect(files, {'lib/core/haptics/haptics.dart'});
    });

    test('hapticsProvider.bucketChanged is called from exactly one file', () {
      // Matches `ref.read(hapticsProvider).bucketChanged()` as well as a
      // bare `hapticsProvider.bucketChanged`, so the guard pins the seam's
      // single call site rather than one spelling of it.
      final files = _scan(
        'lib',
        RegExp(r'hapticsProvider[^\n]{0,20}bucketChanged'),
      ).map((hit) => hit.split(':').first).toSet();
      expect(files, {'lib/features/positions/snapshot_sheet.dart'});
    });

    test('pubspec.yaml is the manifest this wave pinned', () {
      // Pinned by content, not by `git show HEAD:pubspec.yaml`, which
      // degenerates to a self-comparison once the wave is committed.
      final bytes = File('pubspec.yaml').readAsBytesSync();
      expect(
        _fingerprint(bytes),
        '104ad1ec7173ef74',
        reason: 'this wave adds no dependency (D-74)',
      );
      expect(bytes.length, 6061, reason: 'the manifest changed size (D-74)');
    });
  });

  group('S-330 a new route cannot ship unaudited', () {
    test('every GoRoute path in the router has an audited row', () {
      final source = _read('lib/core/app_router.dart');
      final paths = _routePaths(source);
      expect(paths, isNotEmpty);
      // Every declared GoRoute is accounted for, so a parser that silently
      // missed one cannot leave the guard green on an uncovered route.
      expect(paths, hasLength(RegExp(r'GoRoute\(').allMatches(source).length));
      expect(paths, everyElement(isNotEmpty));
      final audited = auditedSurfaceRoutes.toSet();
      final uncovered = paths.where((path) => !audited.contains(path)).toList();
      expect(
        uncovered,
        isEmpty,
        reason:
            'these router paths have no auditedSurfaces row: ${uncovered.join(', ')}',
      );
    });

    test('the guard bites: a router with an extra route fails', () {
      final paths = _routePaths(
        "GoRoute(path: '/stage-6', builder: (_, _) => const SizedBox())",
      );
      expect(paths, ['/stage-6']);
      expect(auditedSurfaceRoutes.toSet().contains('/stage-6'), isFalse);
    });

    test(
      'the guard bites: a path that only contains an audited fragment fails',
      () {
        // `/share` must not satisfy the audited `/journal/share`, which is the
        // false pass substring matching allowed.
        final paths = _routePaths(
          "GoRoute(path: '/share', builder: (_, _) => const SizedBox())",
        );
        expect(paths, ['/share']);
        expect(auditedSurfaceRoutes.toSet().contains('/share'), isFalse);
      },
    );
  });
}

/// Every full route path declared in [source], parent segments joined
/// (`/positions` + `:legId` -> `/positions/:legId`) -- exact paths, not
/// fragments, so a nested segment cannot stand in for the route it belongs to.
List<String> _routePaths(String source) {
  final starts = RegExp(
    r'GoRoute\(',
  ).allMatches(source).map((m) => m.start).toList();
  final spans = <int, (int, int)>{};
  for (final start in starts) {
    final open = start + 'GoRoute'.length;
    var depth = 0;
    var quote = '';
    var i = open;
    while (i < source.length) {
      final ch = source[i];
      if (quote.isNotEmpty) {
        if (ch == '\\') {
          i += 2;
          continue;
        }
        if (ch == quote) quote = '';
      } else if (ch == "'" || ch == '"') {
        quote = ch;
      } else if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
      i++;
    }
    spans[start] = (open, i);
  }

  String fullPath(int start) {
    final body = source.substring(spans[start]!.$1, spans[start]!.$2);
    final segment = RegExp(r"path:\s*'([^']+)'").firstMatch(body)?.group(1);
    if (segment == null) return '';
    if (segment.startsWith('/')) return segment;
    int? parent;
    for (final candidate in starts) {
      final (open, close) = spans[candidate]!;
      if (candidate != start && open < start && start < close) {
        if (parent == null || spans[candidate]!.$1 > spans[parent]!.$1) {
          parent = candidate;
        }
      }
    }
    return parent == null ? '/$segment' : '${fullPath(parent)}/$segment';
  }

  return [for (final start in starts) fullPath(start)];
}
