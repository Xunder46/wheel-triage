import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'help_chip.dart';

/// A labelled numeric entry field with an optional [HelpChip] at its
/// trailing edge — the shape both the screener's form and Record's form
/// need, extracted so the two do not drift (the label for the credit field,
/// in particular, has to change with the total-per-contract preference in
/// both). Pure presentation: parsed value out through one of the three
/// callbacks, nothing else.
///
/// All three callbacks fire on every change; a caller passes only the one
/// matching its field's type and the other two parse to `null` unread.
class LabeledNumberField extends StatelessWidget {
  const LabeledNumberField({
    super.key,
    required this.label,
    this.helpTopicId,
    this.initialText,
    this.onChangedDecimal,
    this.onChangedDouble,
    this.onChangedInt,
    this.signed = true,
  });

  final String label;
  final String? helpTopicId;
  final String? initialText;
  final ValueChanged<Decimal?>? onChangedDecimal;
  final ValueChanged<double?>? onChangedDouble;
  final ValueChanged<int?>? onChangedInt;

  /// Contract counts and DTE are never negative, but every other field here
  /// may be (a signed delta, a debit), so signed is the default.
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialText,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: helpTopicId == null
              ? null
              : Padding(padding: const EdgeInsets.all(8), child: HelpChip(topicId: helpTopicId!)),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true, signed: signed),
        onChanged: (text) {
          onChangedDecimal?.call(Decimal.tryParse(text.trim()));
          onChangedDouble?.call(double.tryParse(text.trim()));
          onChangedInt?.call(int.tryParse(text.trim()));
        },
      ),
    );
  }
}
