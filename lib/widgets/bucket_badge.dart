import 'package:flutter/material.dart';

import '../core/help/help_topics.dart';
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
/// Colors are derived from the active theme's [ColorScheme], not hard-coded
/// literals, so the badge stays correct under both light and dark themes.
///
/// Tapping the badge opens that bucket's help content (brief-followup
/// §C2's "Buckets" table, S-083) via the same shared sheet [HelpChip] uses,
/// so the layout never duplicates between the two entry points.
class BucketBadge extends StatelessWidget {
  const BucketBadge({super.key, required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground, outlined, topicId) = switch (bucket) {
      BucketClose() => ('Close', scheme.primaryContainer, scheme.onPrimaryContainer, false, 'bucket_close'),
      BucketRoll() => ('Roll', scheme.tertiaryContainer, scheme.onTertiaryContainer, false, 'bucket_roll'),
      BucketAssign() => (
        'Assign',
        scheme.errorContainer,
        scheme.onErrorContainer,
        false,
        'bucket_assign',
      ),
      BucketLeave() => (
        'Leave',
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        false,
        'bucket_leave',
      ),
      // "No data" -- deliberately no verb (Feature Invariant 19). Grey like
      // `leave`, but drawn with an outline and on the lowest surface
      // container role so the two are visually distinguishable at a glance
      // (S-058), not just semantically different.
      BucketUnknown() => (
        'No data',
        scheme.surfaceContainerLowest,
        scheme.outline,
        true,
        'bucket_unknown',
      ),
    };
    final topic = helpTopics[topicId]!;

    return Semantics(
      button: true,
      label: 'Help: ${topic.title}',
      child: GestureDetector(
        onTap: () => showHelpSheet(context, topic),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: outlined ? Border.all(color: scheme.outline) : null,
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
