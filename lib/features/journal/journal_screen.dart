import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/journal/journal_controller.dart';
import '../../widgets/cycle_summary_card.dart';
import '../../widgets/journal_row.dart';
import '../../widgets/label_value_row.dart';

/// §4.4's Journal screen: closed cycles newest-first, plus a factual
/// aggregates section. Descriptive statistics about the user's own history
/// and nothing else -- no insights, no coaching, no streaks, no badges, no
/// "you're doing great" (`docs/conventions.md` §4, brief §4.4).
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalControllerProvider);
    final controller = ref.read(journalControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          // D-53/D-56: the card is the Journal's own month, so the entry
          // point lives on the Journal rather than in the nav bar.
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share this month',
            onPressed: () => context.push('/journal/share'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: _Body(state: state),
      ),
      bottomNavigationBar: const AppBottomNav(currentPath: '/journal'),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final JournalState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.rows.isEmpty) {
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
    if (state.rows.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No closed cycles yet. Closed positions appear here once a cycle ends.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _AggregatesSection(aggregates: state.aggregates),
        const Divider(height: 24),
        for (final row in state.rows) ...[
          JournalRowTile(
            ticker: row.ticker,
            outcome: row.cycle.outcome,
            legCount: row.legs.length,
            pnl: row.pnl,
            onTap: () => _showCycleDetail(context, row),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  void _showCycleDetail(BuildContext context, JournalRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: CycleSummaryCard(
            pnl: row.pnl,
            isClosed: true,
            outcomeLabel: _outcomeText(row),
          ),
        ),
      ),
    );
  }

  String? _outcomeText(JournalRow row) => switch (row.cycle.outcome) {
    null => null,
    final o => o.name,
  };
}

class _AggregatesSection extends StatelessWidget {
  const _AggregatesSection({required this.aggregates});

  final JournalAggregatesSummary aggregates;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aggregates', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            LabelValueRow(
              label: 'Win rate',
              value: '${(aggregates.winRate * 100).toStringAsFixed(0)}%',
            ),
            LabelValueRow(
              label: 'Average days in cycle',
              value: aggregates.averageDaysInCycle.toStringAsFixed(0),
            ),
            LabelValueRow(
              label: 'Average premium capture (median)',
              value: aggregates.medianPremiumCapturePct == null
                  ? '--'
                  : '${aggregates.medianPremiumCapturePct!.toStringAsFixed(0)}%',
              spokenValue: aggregates.medianPremiumCapturePct == null
                  ? 'not available'
                  : null,
            ),
            LabelValueRow(
              label: 'Total premium collected',
              value: '\$${aggregates.totalPremiumCollected.toStringAsFixed(2)}',
            ),
            LabelValueRow(
              label: 'Total fees paid',
              value: '\$${aggregates.totalFeesPaid.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Text('Net result by underlying', style: textTheme.labelLarge),
            for (final entry in aggregates.netResultByUnderlying.entries)
              LabelValueRow(
                label: entry.key,
                value: '\$${entry.value.toStringAsFixed(2)}',
              ),
            const SizedBox(height: 8),
            Text('Roll-count distribution', style: textTheme.labelLarge),
            for (final entry
                in (aggregates.rollCountDistribution.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key))))
              LabelValueRow(
                label: '${entry.key} roll${entry.key == 1 ? '' : 's'}',
                value: '${entry.value} cycle${entry.value == 1 ? '' : 's'}',
              ),
          ],
        ),
      ),
    );
  }
}
