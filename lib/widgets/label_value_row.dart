import 'package:flutter/material.dart';

import 'help_chip.dart';

/// One label and one value, which **stacks** when the label and the value
/// cannot share a line at the active text scale -- so neither is truncated at
/// any accessibility size (D-63). The row owns no formatting: [value] is the
/// string the caller already renders, and [label] is the quantity's name.
///
/// It is also the smallest widget containing both the quantity's visible name
/// and its value, so it is where D-62's `Semantics(label:)` goes: the label
/// reads `<quantity> <value>`, which is what makes a number audible without
/// its quantity. A [HelpChip] inside it stays its own node.
///
/// It replaces four near-identical private copies (D-64): the screener's
/// `_OutputRow`, the journal's `_stat`, the position detail sheet's `_Row` and
/// the cycle summary card's `_row`. A shared widget beside four live copies
/// would be drift, not consolidation.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.helpTopicId,
    this.emphasize = false,
    this.trailing,
    this.stacked = false,
    this.spokenValue,
  });

  final String label;

  /// The already-formatted string the caller renders -- never a `Decimal`,
  /// never a `Bucket`, never a percentage computed here.
  final String value;

  /// What the accessibility label says instead of [value] when the two must
  /// differ. The one case is D-61's: a screen that renders a placeholder for
  /// an absent number speaks `not available` instead, so the label never reads
  /// a bare `--` (S-316). Defaults to [value].
  final String? spokenValue;

  /// Renders a [HelpChip] beside the label, which stays its own node (D-62):
  /// merging a button into the number's label would cost the user the tap
  /// target.
  final String? helpTopicId;

  /// The cycle summary card's bold variant.
  final bool emphasize;

  /// An optional widget placed after the value -- the position detail sheet's
  /// own value-adjacent shape.
  final Widget? trailing;

  /// Forces the stacked shape below [stackAtScale] as well, for a row whose
  /// value is long enough to squeeze the label at any scale (S-144).
  final bool stacked;

  /// The scale at or above which the label sits above the value. Below it the
  /// shipped one-line shape is kept, so the default look is unchanged.
  static const double stackAtScale = 2.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, style: textTheme.bodyMedium)),
        if (helpTopicId != null) HelpChip(topicId: helpTopicId!),
      ],
    );
    final valueText = Text(
      value,
      style: textTheme.bodyMedium?.copyWith(
        fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
      ),
    );
    final valueSide = trailing == null
        ? valueText
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: valueText),
              trailing!,
            ],
          );

    final mustStack =
        stacked || MediaQuery.textScalerOf(context).scale(1.0) >= stackAtScale;

    return Semantics(
      label: '$label ${spokenValue ?? value}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: mustStack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelRow, const SizedBox(height: 2), valueSide],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: labelRow),
                  const SizedBox(width: 8),
                  Flexible(child: valueSide),
                ],
              ),
      ),
    );
  }
}
