import 'package:flutter/material.dart';

import '../../core/disclaimer.dart';
import '../../core/format.dart';
import '../../domain/rules/share_card.dart';

/// The share card itself (Pro Wave 3 D-53): a fixed logical **360 × 450**
/// surface (4:5) that the screen previews and captures at `pixelRatio: 3` to
/// produce the 1080 × 1350 image.
///
/// One widget tree serves both the preview and the export, so the image
/// cannot drift from what the user saw. The size is fixed rather than
/// intrinsic because the export's dimensions are a contract (S-309), and a
/// card that grew with its content would silently change the image's shape.
///
/// Every colour comes from `Theme.of(context)` — there is no colour literal
/// here (D-53, Feature Invariant 11), so the card is correct in both themes
/// and the standing grep outside `lib/core/theme/` stays empty.
///
/// The copy is descriptive only (D-54): five figures, one definition
/// paragraph, and the app's own disclaimer verbatim. No streak, no badge, no
/// praise, no comparison, and no sentence pairing an action verb with a
/// security.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.monthYear,
    required this.cycles,
    required this.showDollars,
    required this.showTickers,
  });

  /// The card's fixed logical size — the export's 1080 × 1350 at
  /// `pixelRatio: 3`.
  static const double width = 360;
  static const double height = 450;

  /// `September 2026`, from `format.monthYearText` — the same string the
  /// definition paragraph names, so the card cannot spell the month twice.
  final String monthYear;

  /// The month's cycles, already filtered by `cyclesInCardMonth`.
  final List<ShareCardCycle> cycles;

  /// D-52's two toggles. Both default off on the screen; the card only
  /// renders what it is told.
  final bool showDollars;
  final bool showTickers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final figures = shareCardFigures(cycles);

    // The card is a fixed 360 x 450 export surface (S-309), not a screen: it
    // cannot reflow, so it is laid out at its design text scale rather than
    // the app's accessibility scale. Without this the card's copy overflows
    // its own fixed box at the largest text size and the exported PNG is
    // wrong (S-313). The footer already scales down for the same reason.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Eyebrow(
                      'Wheel Triage',
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                    _Eyebrow(
                      'Monthly ledger',
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  monthYear,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _Figure(
                  label: 'Return on capital',
                  value: percentText(figures.returnOnCapitalPct),
                  scheme: scheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'Cycles closed',
                        value: '${figures.cyclesClosed}',
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Figure(
                        label: 'Closed positive',
                        value: figures.closedPositiveText,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'Average days in cycle',
                        value: figures.averageDaysInCycle?.toString() ?? '--',
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Figure(
                        label: 'Median premium capture',
                        value: figures.medianPremiumCapturePct == null
                            ? '--'
                            : percentText(
                                figures.medianPremiumCapturePct,
                                decimals: 0,
                              ),
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // The two footer paragraphs are the card's longest copy and the
                // only part whose height depends on the font the platform
                // resolves. `Flexible` bounds the box and `FittedBox` scales the
                // copy down rather than letting it overflow the fixed 360 x 450
                // surface, so the card is always exactly the size the export
                // contract names (S-309) and the disclaimer is still rendered
                // verbatim (D-54).
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shareCardDefinitionLine(
                              monthYear: monthYear,
                              cycles: cycles,
                            ),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                          // D-52 puts both toggle lines directly under the
                          // definition paragraph, above the disclaimer.
                          if (showDollars) ...[
                            const SizedBox(height: 6),
                            Text(
                              netResultLine(cycles: cycles),
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (showTickers) ...[
                            const SizedBox(height: 6),
                            Text(
                              cardTickerLine(cycles),
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            kAppDisclaimer,
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's small uppercase header pair.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {required this.scheme, required this.textTheme});

  final String text;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );
}

/// One labelled figure. Every figure is the same size (D-49), so none reads
/// as the headline.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.scheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) => Semantics(
    // D-62: the smallest widget holding both the quantity's visible label and
    // its value. The card is a preview a user reads with VoiceOver as well as
    // an image, so its five figures are labelled like any other number.
    label: '$label $value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 8),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    ),
  );
}
