import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../domain/rules/expiry.dart';
import '../../state/today/today_controller.dart';
import '../../widgets/leg_title.dart';

/// D-13's "Past expiration, still open" card (S-251): the legs whose
/// expiration has passed, what the batch will record, and — separately, each
/// with its own actions — the legs the batch leaves out.
///
/// A leg past expiration is in no bucket count and no list row (S-254), so
/// this card is the only place it appears.
class PastExpirationCard extends ConsumerStatefulWidget {
  const PastExpirationCard({super.key, required this.legs});

  final List<TodayItem> legs;

  @override
  ConsumerState<PastExpirationCard> createState() => _PastExpirationCardState();
}

class _PastExpirationCardState extends ConsumerState<PastExpirationCard> {
  /// The batch's or a per-leg action's failure message. Held here rather than
  /// in `TodayState.error` on purpose: the card reports its own failure
  /// inline, and the book behind it must survive it (S-252).
  String? _error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = ref.watch(todayControllerProvider).isLoading;

    final eligible = widget.legs.where((item) => item.batchEligible).toList();
    // Which section a left-out leg belongs in is read off its own data, not
    // re-derived from the rule: no reading, or a reading in the money.
    final inTheMoney = widget.legs
        .where((item) => !item.batchEligible && item.latestSnapshot != null)
        .toList();
    final noReading = widget.legs
        .where((item) => !item.batchEligible && item.latestSnapshot == null)
        .toList();
    final latest = widget.legs
        .map((item) => item.leg.expiration)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        key: const ValueKey('past-expiration-card'),
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
                  child: Text(
                    'Past expiration, still open',
                    style: textTheme.titleSmall,
                  ),
                ),
                Text(
                  shortWeekdayDateText(latest),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            for (final item in eligible) _CardLeg(item: item),
            if (eligible.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton(
                  key: const ValueKey('mark-all-expired'),
                  onPressed: busy ? null : () => _confirmBatch(eligible),
                  child: Text('Mark all expired (${eligible.length})'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _batchExplanation(eligible),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            if (inTheMoney.isNotEmpty || noReading.isNotEmpty)
              Divider(height: 20, color: scheme.outlineVariant),
            if (inTheMoney.isNotEmpty)
              _LeftOutSection(
                caption: 'Not in Mark all: last reading in the money',
                legs: inTheMoney,
                busy: busy,
                onMarkAssigned: _markAssigned,
                onMarkExpired: _confirmSingle,
              ),
            if (noReading.isNotEmpty)
              _LeftOutSection(
                caption: 'Not in Mark all: no reading',
                legs: noReading,
                busy: busy,
                onMarkAssigned: _markAssigned,
                onMarkExpired: _confirmSingle,
              ),
          ],
        ),
      ),
    );
  }

  /// D-13's own wording for the batch, naming the leg when there is only one
  /// (the reference's drawn case) and the date each leg carries when there
  /// are several.
  String _batchExplanation(List<TodayItem> eligible) => expiryBatchExplanation(
    eligible: [for (final item in eligible) item.cardEntry],
    singleTicker: eligible.length == 1 ? eligible.single.underlying.ticker : null,
  );

  /// D-13: a leg past expiration is recorded on its own expiration date, so
  /// the batch needs no date picker — and no fee, since the close debit is
  /// zero and the close fee stays blank.
  Future<void> _confirmBatch(List<TodayItem> eligible) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark all expired?'),
        content: Text(_batchExplanation(eligible)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-mark-all-expired'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark all expired'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final message = await ref
        .read(todayControllerProvider.notifier)
        .markAllExpired();
    if (message != null && mounted) setState(() => _error = message);
  }

  Future<void> _confirmSingle(TodayItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark expired?'),
        content: Text(
          'Records this leg as expired worthless on '
          '${shortDateText(item.leg.expiration)}, no close debit. '
          'The close fee stays blank.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-mark-expired'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark expired'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final message = await ref
        .read(todayControllerProvider.notifier)
        .markExpiredLeg(legId: item.leg.id);
    if (message != null && mounted) setState(() => _error = message);
  }

  void _markAssigned(TodayItem item) =>
      context.push('/positions/${item.leg.id}/assign');
}

/// One leg on the card: its title, then the reading the decision turns on.
class _CardLeg extends StatelessWidget {
  const _CardLeg({required this.item});

  final TodayItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LegTitle(ticker: item.underlying.ticker, leg: item.leg),
          const SizedBox(height: 2),
          Text(
            expiryReadingLine(item.cardEntry),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The legs "Mark all expired" leaves out, under their own caption, each with
/// the two ways of recording it by hand.
class _LeftOutSection extends StatelessWidget {
  const _LeftOutSection({
    required this.caption,
    required this.legs,
    required this.busy,
    required this.onMarkAssigned,
    required this.onMarkExpired,
  });

  final String caption;
  final List<TodayItem> legs;
  final bool busy;
  final void Function(TodayItem item) onMarkAssigned;
  final void Function(TodayItem item) onMarkExpired;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        for (final item in legs) ...[
          _CardLeg(item: item),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: ValueKey('mark-assigned-${item.leg.id}'),
                  onPressed: busy ? null : () => onMarkAssigned(item),
                  child: const Text('Mark assigned'),
                ),
                OutlinedButton(
                  key: ValueKey('mark-expired-${item.leg.id}'),
                  onPressed: busy ? null : () => onMarkExpired(item),
                  child: const Text('Mark expired'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
