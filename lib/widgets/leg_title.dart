import 'package:flutter/material.dart';

import '../core/format.dart';
import '../domain/models/leg.dart';

/// One leg named as a card row names it — the ticker in the row's own weight
/// followed by `$14 put ×3`. One [Text.rich] so the plain text is the whole
/// line, never a second, ticker-only widget beside it.
///
/// Pure presentation: the ticker and the leg in, nothing computed here.
class LegTitle extends StatelessWidget {
  const LegTitle({super.key, required this.ticker, required this.leg});

  final String ticker;
  final Leg leg;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$ticker ',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: legContractText(leg), style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
