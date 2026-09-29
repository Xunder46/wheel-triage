import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates/export_reminder.dart';
import '../../core/format.dart';
import '../../core/money/whole_dollars.dart';
import '../../domain/rules/bucket.dart';
import '../../domain/rules/capital_committed.dart';
import '../../domain/rules/reading_age.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../state/today/today_controller.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/bucket_badge.dart';
import '../export/export_reminder_banner.dart';
import '../positions/snapshot_sheet.dart';
import 'expiring_this_week_card.dart';
import 'past_expiration_card.dart';

/// Stage 3's start screen (D-14): the date and "Today", the export reminder
/// banner, the five bucket counts, the aging line, and the open-position list
/// with each row's badge *and* the reason that fired it.
///
/// Replaces the Positions screen; the `/positions` route is unchanged, so the
/// detail, roll and assignment flows underneath it are untouched.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

/// The list stays alive underneath every route pushed from it (`/screener`,
/// `/record`, `/positions/:legId`, the roll and assignment flows), so
/// `autoDispose` never tears the controller down and no rebuild marks its data
/// stale. Coming back to this location therefore has to reload explicitly —
/// without it, a position tracked elsewhere stays invisible until the app
/// restarts (S-205). Listening to the router delegate's location covers every
/// way back in (back button, `pop`, `go`), not just the ones this screen owns.
class _TodayScreenState extends ConsumerState<TodayScreen> {
  static const _path = '/positions';

  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_refreshOnArrival);
    _router = router;
    router.routerDelegate.addListener(_refreshOnArrival);
  }

  void _refreshOnArrival() {
    if (_router?.routerDelegate.currentConfiguration.uri.path != _path) return;
    // The delegate notifies from inside go_router's own rebuild; one deferred
    // frame keeps the provider update out of the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(todayControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_refreshOnArrival);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);
    final prefs = ref.watch(preferencesControllerProvider).valueOrNull;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // S-160/Feature Invariant 34: a pure derivation (lib/core/dates/) fed by
    // this screen's own already-loaded position list plus preferences --
    // no new provider needed, and the rule itself stays testable without a
    // widget harness. A leg past expiration is still an open position, so it
    // counts here even though it is not in the list.
    DateTime? earliestOpenedAt;
    for (final item in [...state.items, ...state.pastExpiration]) {
      final openedAt = item.leg.openedAt;
      if (earliestOpenedAt == null || openedAt.isBefore(earliestOpenedAt)) {
        earliestOpenedAt = openedAt;
      }
    }
    final reminderVisible =
        prefs != null &&
        exportReminderDue(
          lastExportAt: prefs.lastExportAt,
          earliestOpenPositionOpenedAt: earliestOpenedAt,
          hasOpenPositions: state.items.isNotEmpty || state.pastExpiration.isNotEmpty,
          exportReminderDismissed: prefs.exportReminderDismissed,
          now: DateTime.now(),
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayDateText(DateTime.now()),
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text('Today', style: textTheme.titleLarge),
          ],
        ),
      ),
      body: Column(
        children: [
          ExportReminderBanner(
            visible: reminderVisible,
            onDismiss: () => ref
                .read(preferencesControllerProvider.notifier)
                .dismissExportReminder(),
          ),
          Expanded(child: _Body()),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentPath: _path),
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayControllerProvider);
    final controller = ref.read(todayControllerProvider.notifier);

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      );
    }
    if (state.items.isEmpty && state.pastExpiration.isEmpty) {
      return RefreshIndicator(onRefresh: controller.load, child: const _EmptyState());
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _CountsRow(state: state, onTap: controller.toggleBucketFilter),
          if (state.agingLine.isNotEmpty)
            _AgingLine(
              line: state.agingLine,
              active: state.agingOnly,
              onTap: controller.toggleAgingFilter,
            ),
          _LedgerStrip(state: state),
          if (state.pastExpiration.isNotEmpty)
            PastExpirationCard(legs: state.pastExpiration),
          if (state.expiringThisWeek.isNotEmpty)
            ExpiringThisWeekCard(groups: state.expiringThisWeek),
          const SizedBox(height: 8),
          _ListHeader(state: state, onSort: controller.setSort),
          for (final item in state.visible) _Row(item: item),
        ],
      ),
    );
  }
}

/// D-14's five counts, in the list's own sort order. Each is a filter, so it
/// is deliberately **not** a [BucketBadge]: a badge tap opens that bucket's
/// help, and a count tap must narrow the list instead.
class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.state, required this.onTap});

  final TodayState state;
  final void Function(Type bucket) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (final count in state.bucketCounts)
            Expanded(
              child: _CountChip(
                label: bucketLabel(count.bucket),
                count: count.count,
                selected: state.bucketFilter == count.bucket.runtimeType,
                onTap: () => onTap(count.bucket.runtimeType),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$count $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          key: ValueKey('today-count-$label'),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D-11's aging line: an overlapping count that names the legs and dates it
/// counts, and filters the list to those legs when tapped.
class _AgingLine extends StatelessWidget {
  const _AgingLine({required this.line, required this.active, required this.onTap});

  final String line;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          key: const ValueKey('today-aging-line'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: active ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D-8/D-9/D-15's ledger strip: three tiles, then the one paragraph that
/// defines what they mean, then D-10's concentration lines.
///
/// The strip is a statement of the book, not a filter, so nothing here is
/// tappable — D-10 keeps concentration a neutral fact with no link to a
/// portfolio view that does not exist yet.
class _LedgerStrip extends StatelessWidget {
  const _LedgerStrip({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final capital = state.wheelCapital;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LedgerTile(
                label: 'Net premium · ${state.ledgerMonthLabel}',
                value: wholeDollars(state.netPremiumMonth),
              ),
              _LedgerTile(
                label: 'Year to date',
                value: wholeDollars(state.netPremiumYearToDate),
              ),
              _LedgerTile(
                label: 'Committed now',
                value: wholeDollars(state.committedNow),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            state.ledgerDefinitionLine,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          for (final flag in state.concentrationFlags)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                concentrationFlagLine(flag),
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          if (capital == null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                kConcentrationInviteLine,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// One ledger figure (D-15): a small label over whole dollars, in equal
/// thirds so the three read as one row. Deliberately smaller than a bucket
/// count — the strip reports the book, it does not lead the screen.
class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.state, required this.onSort});

  final TodayState state;
  final void Function(TodaySort sort) onSort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Open positions · ${state.items.length}',
              style: textTheme.titleSmall,
            ),
          ),
          PopupMenuButton<TodaySort>(
            key: const ValueKey('today-sort'),
            tooltip: 'Sort',
            onSelected: onSort,
            itemBuilder: (context) => [
              for (final sort in TodaySort.values)
                PopupMenuItem(value: sort, child: Text(todaySortLabel(sort))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    todaySortLabel(state.sort),
                    style: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One open position: ticker and its contract on the first line, the badge
/// and the reason that fired it together on the second (§5.2 — never a bare
/// verdict), the reading's date when there is one, and the inline Update for
/// rows that need a reading (D-11).
class _Row extends ConsumerWidget {
  const _Row({required this.item});

  final TodayItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final leg = item.leg;
    final age = item.readingAgeDays;
    final reading = item.latestSnapshot == null
        ? null
        : 'From ${shortDateText(item.latestSnapshot!.takenAt)} reading'
              '${age != null && age > kAgingDays ? ' · $age days old' : ''}';

    return InkWell(
      onTap: () => context.push('/positions/${leg.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.underlying.ticker, style: textTheme.titleSmall),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _contractText(item),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BucketBadge(bucket: item.bucket),
              ],
            ),
            const SizedBox(height: 2),
            Text(item.bucket.reason, style: textTheme.bodySmall),
            if (reading != null || item.needsReading) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (reading != null)
                    Expanded(
                      child: Text(
                        reading,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (item.needsReading)
                    TextButton(
                      onPressed: () async {
                        final saved = await showSnapshotSheet(
                          context: context,
                          legId: leg.id,
                        );
                        if (saved != true || !context.mounted) return;
                        ref.read(todayControllerProvider.notifier).load();
                      },
                      child: const Text('Update'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `$12 put ×2 · Oct 9 · 11 DTE` — the reference's own row meta.
String _contractText(TodayItem item) {
  final leg = item.leg;
  return '${legContractText(leg)} · ${shortDateText(leg.expiration)} · ${item.dte} DTE';
}

/// D-14's empty variant: nothing recorded yet, and the two ways to start.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
          child: Column(
            children: [
              Text('Nothing recorded yet', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Trades you record appear here, grouped by which of your rules applies.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push('/record'),
                child: const Text('Record a trade'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.push('/screener'),
                child: const Text('Open screener'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
