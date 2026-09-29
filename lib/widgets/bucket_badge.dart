import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/help/help_topics.dart';
import '../core/theme/app_theme.dart';
import '../domain/rules/bucket.dart';
import 'help_chip.dart';

/// A compact, color-coded chip for a [Bucket]'s neutral-verb label —
/// `Close`/`Roll`/`Assign`/`Leave` (`docs/conventions.md` §4). Pure
/// presentation: data in through [bucket], nothing computed here.
///
/// This widget deliberately shows the label only, never the reason —
/// callers place the reason string immediately beside/underneath this
/// badge in the same view (§5.2: "bucket badge with the reason
/// underneath"), so "never a bare verdict" is enforced at the row/screen
/// level, not baked into this atom.
///
/// Colors are derived from the active theme's [BucketColors] extension (D-4),
/// which is the only colour source in the app — never a hard-coded literal and
/// never a role that happens to look right in one theme. Assign is painted from
/// its own token and never from the error role: assignment is part of the
/// strategy, not a failure. "No data" carries no fill at all — muted text and a
/// dashed outline — so it stays distinct from `Leave` (Feature Invariant 19).
///
/// Tapping the badge opens that bucket's help content (brief-followup
/// §C2's "Buckets" table, S-083) via the same shared sheet [HelpChip] uses,
/// so the layout never duplicates between the two entry points.
class BucketBadge extends StatelessWidget {
  const BucketBadge({super.key, required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final colors = BucketColors.of(context);
    final label = bucketLabel(bucket);
    final (fill, ink, dashed, topicId) = switch (bucket) {
      BucketClose() => (colors.closeFill, colors.closeInk, false, 'bucket_close'),
      BucketRoll() => (colors.rollFill, colors.rollInk, false, 'bucket_roll'),
      BucketAssign() => (colors.assignFill, colors.assignInk, false, 'bucket_assign'),
      BucketLeave() => (colors.leaveFill, colors.leaveInk, false, 'bucket_leave'),
      // "No data" -- deliberately no verb (Feature Invariant 19). No fill,
      // muted ink, and a dashed outline: the three cues together are what
      // keep it visually distinct from `leave` at a glance (S-058), not just
      // semantically different. The reference gives this pill the dashed
      // outline *instead of* the hairline edge the filled pills carry.
      BucketUnknown() => (null, colors.noDataInk, true, 'bucket_unknown'),
    };
    final topic = helpTopics[topicId]!;
    // OC-10: in the light theme each filled pill gets a hairline edge for
    // shape; the dark theme's fills already read against its ground. A
    // `BoxDecoration` border paints inside the box, so this adds no layout.
    final edge = !dashed && colors.pillEdge.a > 0
        ? Border.all(color: colors.pillEdge)
        : null;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: edge,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: ink, fontWeight: FontWeight.w600),
      ),
    );

    return Semantics(
      button: true,
      label: 'Help: ${topic.title}',
      child: GestureDetector(
        onTap: () => showHelpSheet(context, topic),
        child: dashed
            ? CustomPaint(
                foregroundPainter: _DashedPillOutline(colors.noDataOutline),
                child: pill,
              )
            : pill,
      ),
    );
  }
}

/// Strokes a dashed rounded outline over the pill's own box.
///
/// A dashed border is not expressible as a `Border`, and drawing it as a
/// foreground painter keeps the badge's geometry identical to the filled
/// states — so "No data" differs from `Leave` in fill and edge, not in size.
class _DashedPillOutline extends CustomPainter {
  const _DashedPillOutline(this.color);

  final Color color;

  static const double _dash = 3;
  static const double _gap = 3;
  // The reference draws this outline at 1.5px, unlike the 1px hairline the
  // filled pills carry — it is the pill's only edge.
  static const double _strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..color = color;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + _dash, metric.length)),
          paint,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillOutline oldDelegate) => oldDelegate.color != color;
}
