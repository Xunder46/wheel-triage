import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/theme/app_theme.dart';

/// WCAG 2.1 relative luminance, straight off `Color.computeLuminance`
/// (which is the same sRGB linearization the spec defines).
double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE L*, used only for the greyscale-separation check: the bucket fills
/// must stay ordered when hue is discarded (D-4, S-218/S-219).
double _lStar(Color c) {
  final y = _luminance(c);
  return y > 216 / 24389 ? 116 * math.pow(y, 1 / 3).toDouble() - 16 : y * (24389 / 27);
}

void main() {
  // D-5: this is a permanent guard, not a one-off audit. Every pair the
  // design's token table documents a ratio for is asserted here, in both
  // themes, so a later palette edit cannot quietly drop below 4.5:1.
  group('S-219: token contrast holds in both themes', () {
    final themes = <(String, ThemeData)>[('dark', darkTheme), ('light', lightTheme)];

    for (final (name, theme) in themes) {
      final scheme = theme.colorScheme;

      final pairs = <(String, Color, Color)>[
        // The D-4 table's own documented ratios.
        ('text on background', scheme.onSurface, theme.scaffoldBackgroundColor),
        ('text on card', scheme.onSurface, scheme.surface),
        ('muted on card', scheme.onSurfaceVariant, scheme.surface),
        ('accent on background', scheme.primary, theme.scaffoldBackgroundColor),
        ('on-accent on accent', scheme.onPrimary, scheme.primary),
        ('caution on card', scheme.tertiary, scheme.surface),
        ('error on card', scheme.error, scheme.surface),
        // Roles an existing screen paints text onto. D-4 gives no container
        // value for these, so the containers are derived from the table
        // (A-4) — which is exactly why they need a guard.
        (
          'on-accent-container on accent container',
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        ),
        ('muted on accent container', scheme.onSurfaceVariant, scheme.primaryContainer),
        ('caution on caution container', scheme.onTertiaryContainer, scheme.tertiaryContainer),
        ('on-error-container on error container', scheme.onErrorContainer, scheme.errorContainer),
        ('muted on error container', scheme.onSurfaceVariant, scheme.errorContainer),
        ('text on secondary container', scheme.onSecondaryContainer, scheme.secondaryContainer),
        ('muted on raised surface', scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
        ('text on raised surface', scheme.onSurface, scheme.surfaceContainerHighest),
      ];

      for (final (label, foreground, background) in pairs) {
        test('$name: $label is at least 4.5:1', () {
          final ratio = _contrast(foreground, background);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$label in the $name theme is ${ratio.toStringAsFixed(2)}:1 '
                '($foreground on $background)',
          );
        });
      }

      test('$name: every bucket fill clears 4.5:1 against its own ink', () {
        final buckets = theme.extension<BucketColors>()!;
        final bucketPairs = <(String, Color, Color)>[
          ('Close', buckets.closeInk, buckets.closeFill),
          ('Roll', buckets.rollInk, buckets.rollFill),
          ('Assign', buckets.assignInk, buckets.assignFill),
          ('Leave', buckets.leaveInk, buckets.leaveFill),
        ];
        for (final (label, ink, fill) in bucketPairs) {
          final ratio = _contrast(ink, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$label ink on fill is ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('$name: "No data" is muted text, never a bucket fill', () {
        final buckets = theme.extension<BucketColors>()!;
        // Feature Invariant 19: no fill at all, and visually distinct from
        // `Leave` in particular.
        expect(buckets.noDataInk, isNot(buckets.leaveInk));
        expect(buckets.noDataInk, isNot(buckets.leaveFill));
        expect(
          _contrast(buckets.noDataInk, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    test('Assign never borrows the error role, in either theme', () {
      for (final theme in [darkTheme, lightTheme]) {
        final buckets = theme.extension<BucketColors>()!;
        expect(buckets.assignFill, isNot(theme.colorScheme.error));
        expect(buckets.assignFill, isNot(theme.colorScheme.errorContainer));
        expect(buckets.assignInk, isNot(theme.colorScheme.onErrorContainer));
      }
    });

    test('the bucket fills stay ordered by L*, with a real step between them', () {
      final buckets = darkTheme.extension<BucketColors>()!;
      final steps = [
        _lStar(buckets.closeFill),
        _lStar(buckets.rollFill),
        _lStar(buckets.assignFill),
        _lStar(buckets.leaveFill),
      ];
      // Descending in lightness, so greyscale still separates them.
      expect(steps, orderedEquals(List.of(steps)..sort((a, b) => b.compareTo(a))));
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i - 1] - steps[i], greaterThanOrEqualTo(10.0), reason: 'step $i is too small');
      }
      // And all four are genuinely different fills.
      expect(buckets.closeFill, isNot(buckets.rollFill));
      expect(buckets.rollFill, isNot(buckets.assignFill));
      expect(buckets.assignFill, isNot(buckets.leaveFill));
    });
  });
}
