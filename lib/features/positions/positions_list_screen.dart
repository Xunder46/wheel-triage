import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates/export_reminder.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../state/positions/positions_list_controller.dart';
import '../../widgets/bucket_badge.dart';
import '../export/export_reminder_banner.dart';

/// §5.2's positions list: ticker/strike/type/expiry/DTE, a bucket badge with
/// its reason underneath (never a bare badge), sortable by bucket severity
/// (the default), DTE, or ticker. Handles loading, error, and empty states —
/// not just the populated case (S-023).
class PositionsListScreen extends ConsumerStatefulWidget {
  const PositionsListScreen({super.key});

  @override
  ConsumerState<PositionsListScreen> createState() => _PositionsListScreenState();
}

/// The list stays alive underneath every route pushed from it (`/screener`,
/// `/positions/:legId`, the roll and assignment flows), so `autoDispose`
/// never tears the controller down and no rebuild marks its data stale.
/// Coming back to this location therefore has to reload explicitly — without
/// it, a position tracked elsewhere stays invisible until the app restarts
/// (S-205). Listening to the router delegate's location covers every way back
/// in (back button, `pop`, `go`), not just the ones this screen owns.
class _PositionsListScreenState extends ConsumerState<PositionsListScreen> {
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
      if (mounted) ref.read(positionsListControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_refreshOnArrival);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(positionsListControllerProvider);
    final controller = ref.read(positionsListControllerProvider.notifier);
    final prefs = ref.watch(preferencesControllerProvider).valueOrNull;

    // S-160/Feature Invariant 34: a pure derivation (lib/core/dates/) fed by
    // this screen's own already-loaded position list plus preferences --
    // no new provider needed, and the rule itself stays testable without a
    // widget harness.
    DateTime? earliestOpenedAt;
    for (final item in state.items) {
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
          hasOpenPositions: state.items.isNotEmpty,
          exportReminderDismissed: prefs.exportReminderDismissed,
          now: DateTime.now(),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Positions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Screener',
            onPressed: () => context.push('/screener'),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Journal',
            onPressed: () => context.push('/journal'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          PopupMenuButton<PositionSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onSelected: controller.setSort,
            itemBuilder: (context) => const [
              PopupMenuItem(value: PositionSort.bucketSeverity, child: Text('Bucket severity')),
              PopupMenuItem(value: PositionSort.dte, child: Text('DTE')),
              PopupMenuItem(value: PositionSort.ticker, child: Text('Ticker')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ExportReminderBanner(
            visible: reminderVisible,
            onDismiss: () => ref.read(preferencesControllerProvider.notifier).dismissExportReminder(),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: controller.load, child: _Body(state: state)),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final PositionsListState state;

  @override
  Widget build(BuildContext context) {
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
    if (state.items.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No open positions yet. Use the screener to evaluate a candidate, '
                'then "Track this position" to see it here.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.items[index];
        final leg = item.leg;
        return ListTile(
          onTap: () => context.push('/positions/${leg.id}'),
          title: Text(
            '${item.underlying.ticker} \$${leg.strike} '
            '${leg.optionType.name} · exp ${_dateText(leg.expiration)} · ${item.dte}d',
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(item.bucket.reason),
          ),
          trailing: BucketBadge(bucket: item.bucket),
        );
      },
    );
  }
}

String _dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
