import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/rules/obligation.dart';
import '../../state/today/today_controller.dart';
import '../../widgets/leg_title.dart';

/// D-13's "Expiring this week" card (S-250): what the book obliges inside the
/// next seven days, grouped by expiration date, each leg's obligation beside
/// it.
///
/// Pure presentation — every figure and every date comes from the state the
/// controller already built, and the grouping from
/// `obligation.expiringThisWeek`. The caller renders no card at all when
/// [groups] is empty.
class ExpiringThisWeekCard extends StatelessWidget {
  const ExpiringThisWeekCard({super.key, required this.groups});

  final List<ExpiringDateGroup> groups;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // The groups are ascending, so the last one is the latest date the card
    // covers — the caption's own figure, and the only date shown when there
    // is a single group.
    final latest = groups.last.date;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        key: const ValueKey('expiring-this-week-card'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Expiring this week', style: textTheme.titleSmall),
                ),
                Text(
                  shortWeekdayDateText(latest),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            for (final group in groups) ...[
              // The caption already carries the only date a single-group card
              // covers, so a per-group label would print it twice (A-26).
              if (groups.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    shortWeekdayDateText(group.date),
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final item in group.legs) _ObligationRow(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

/// One expiring leg: its ticker and contract on the left, what assignment
/// would move on the right.
class _ObligationRow extends StatelessWidget {
  const _ObligationRow({required this.item});

  final TodayItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final obligation = obligationFor(item.leg);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LegTitle(
              ticker: item.underlying.ticker,
              leg: item.leg,
            ),
          ),
          if (obligation != null) ...[
            const SizedBox(width: 8),
            Text(
              obligation.text,
              textAlign: TextAlign.right,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
