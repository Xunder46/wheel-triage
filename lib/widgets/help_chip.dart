import 'package:flutter/material.dart';

import '../core/help/help_topics.dart';

/// A small circled "?" placed at the trailing edge of a field label or
/// output row (brief-followup §C1). Tap opens a bottom sheet, never a
/// `Tooltip` overlay -- tooltips are unreadable on phones and unreachable
/// for screen readers (S-080).
///
/// Pure presentation: [topicId] in, [showHelpSheet] out. Content always
/// comes from `lib/core/help/help_topics.dart`, never inlined here.
class HelpChip extends StatelessWidget {
  const HelpChip({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final topic = helpTopics[topicId];
    assert(topic != null, 'No help topic registered for "$topicId"');
    if (topic == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: 'Help: ${topic.title}',
      child: GestureDetector(
        onTap: () => showHelpSheet(context, topic),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.help_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The shared sheet-building function (Phase 12 step 2) -- reused by
/// [HelpChip] and by `BucketBadge`'s tap handler (S-083) so the layout
/// never duplicates between the two entry points.
Future<void> showHelpSheet(BuildContext context, HelpTopic topic) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _HelpSheet(topic: topic),
  );
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.title, style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(topic.body, style: textTheme.bodyMedium),
            if (topic.whereToFind != null) ...[
              const SizedBox(height: 16),
              Text('Where to find it', style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(topic.whereToFind!, style: textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
