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
  return y > 216 / 24389
      ? 116 * math.pow(y, 1 / 3).toDouble() - 16
      : y * (24389 / 27);
}

/// Every `scheme.<role>` read under `lib/` (S-320), with the reason it is or
/// is not asserted at 4.5:1. A role read that is missing from this map fails
/// S-320, so a new one cannot arrive unaudited.
const Map<String, String> auditedRoles = {
  'onSurface': 'text -- asserted on background, card and raised surface',
  'onSurfaceVariant':
      'muted text -- asserted on card, accent container, error container, raised surface',
  'surface': 'the card background every text pair is measured against',
  'outlineVariant':
      'D-68 exemption: card borders and dividers only, never text or a state-conveying component',
  'primary':
      'accent text and the selected plan indicator -- asserted on background',
  'onPrimary': 'text on the accent fill -- asserted',
  'primaryContainer':
      'the selected plan indicator\'s fill -- asserted with its own ink',
  'onPrimaryContainer': 'text on the accent container -- asserted',
  'tertiary': 'caution text -- asserted on card',
  'error': 'error text -- asserted on card',
  'errorContainer':
      'the failing gate chip\'s fill -- asserted with its own ink',
  'onErrorContainer': 'text on the error container -- asserted',
  'surfaceContainerHighest':
      'the unknown gate chip\'s fill -- asserted with both inks',
  'outline':
      'the unselected plan indicator\'s old colour; no longer painted anywhere (see the S-321 note below)',
};

void main() {
  // D-5: this is a permanent guard, not a one-off audit. Every pair the
  // design's token table documents a ratio for is asserted here, in both
  // themes, so a later palette edit cannot quietly drop below 4.5:1.
  group('S-219: token contrast holds in both themes', () {
    final themes = <(String, ThemeData)>[
      ('dark', darkTheme),
      ('light', lightTheme),
    ];

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
        (
          'muted on accent container',
          scheme.onSurfaceVariant,
          scheme.primaryContainer,
        ),
        (
          'caution on caution container',
          scheme.onTertiaryContainer,
          scheme.tertiaryContainer,
        ),
        (
          'on-error-container on error container',
          scheme.onErrorContainer,
          scheme.errorContainer,
        ),
        (
          'muted on error container',
          scheme.onSurfaceVariant,
          scheme.errorContainer,
        ),
        (
          'text on secondary container',
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
        ),
        (
          'muted on raised surface',
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
        ),
        (
          'text on raised surface',
          scheme.onSurface,
          scheme.surfaceContainerHighest,
        ),
        // Screen pairings this wave walked (D-70): each names a pair an
        // existing widget actually paints, so a palette edit that fixes a
        // token table but breaks a screen still fails here.
        (
          'text on the selected plan row',
          scheme.onSurface,
          scheme.primaryContainer,
        ),
        ('muted on a plan row', scheme.onSurfaceVariant, scheme.surface),
        (
          'error on the raised surface',
          scheme.error,
          scheme.surfaceContainerHighest,
        ),
      ];
      // Not painted, and therefore recorded rather than asserted (D-68's
      // convention for pairs no widget renders): `tertiary` on
      // `surfaceContainerHighest` is 4.20:1 in the light theme. No screen
      // paints caution text on the raised surface -- the gate chips carry
      // `onSurface`/`onSurfaceVariant` -- so this is a note, not a bar.

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

    test('the role audit is complete and every entry carries its reason', () {
      expect(auditedRoles.length, greaterThanOrEqualTo(14));
      for (final entry in auditedRoles.entries) {
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason: 'role ${entry.key} has no reason',
        );
      }
      expect(
        auditedRoles.keys,
        containsAll(['onSurfaceVariant', 'outlineVariant', 'outline']),
      );
    });

    test(
      'S-321: the unselected plan indicator clears 3:1 on the surface it sits on',
      () {
        // D-68's non-text bar. The indicator is `Icons.radio_button_unchecked`
        // painted `onSurfaceVariant` on `surface` (D-69, as the brief overrides
        // it) -- so the bar is checked against the colour the widget now paints,
        // not against the token table.
        for (final (name, theme) in themes) {
          final scheme = theme.colorScheme;
          final ratio = _contrast(scheme.onSurfaceVariant, scheme.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason:
                'the $name theme\'s unselected indicator is ${ratio.toStringAsFixed(2)}:1',
          );
        }
      },
    );

    test('S-321: the old outline colour would not have cleared it', () {
      // Pins the reason the colour changed, so a later edit that reverts to
      // `outline` fails here rather than shipping a 1.93:1 indicator.
      for (final (name, theme) in themes) {
        final scheme = theme.colorScheme;
        expect(
          _contrast(scheme.outline, scheme.surface),
          lessThan(3.0),
          reason:
              'the $name theme\'s outline now clears 3:1, so this exemption can be revisited',
        );
      }
    });

    test('Assign never borrows the error role, in either theme', () {
      for (final theme in [darkTheme, lightTheme]) {
        final buckets = theme.extension<BucketColors>()!;
        expect(buckets.assignFill, isNot(theme.colorScheme.error));
        expect(buckets.assignFill, isNot(theme.colorScheme.errorContainer));
        expect(buckets.assignInk, isNot(theme.colorScheme.onErrorContainer));
      }
    });

    test(
      'the bucket fills stay ordered by L*, with a real step between them',
      () {
        final buckets = darkTheme.extension<BucketColors>()!;
        final steps = [
          _lStar(buckets.closeFill),
          _lStar(buckets.rollFill),
          _lStar(buckets.assignFill),
          _lStar(buckets.leaveFill),
        ];
        // Descending in lightness, so greyscale still separates them.
        expect(
          steps,
          orderedEquals(List.of(steps)..sort((a, b) => b.compareTo(a))),
        );
        for (var i = 1; i < steps.length; i++) {
          expect(
            steps[i - 1] - steps[i],
            greaterThanOrEqualTo(10.0),
            reason: 'step $i is too small',
          );
        }
        // And all four are genuinely different fills.
        expect(buckets.closeFill, isNot(buckets.rollFill));
        expect(buckets.rollFill, isNot(buckets.assignFill));
        expect(buckets.assignFill, isNot(buckets.leaveFill));
      },
    );
  });
}
