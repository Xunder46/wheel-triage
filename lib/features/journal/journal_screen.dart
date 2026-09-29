import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/journal/journal_controller.dart';
import '../../widgets/cycle_summary_card.dart';
import '../../widgets/journal_row.dart';

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
      appBar: AppBar(title: const Text('Journal')),
      body: RefreshIndicator(onRefresh: controller.load, child: _Body(state: state)),
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
              child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
            _stat(context, 'Win rate', '${(aggregates.winRate * 100).toStringAsFixed(0)}%'),
            _stat(context, 'Average days in cycle', aggregates.averageDaysInCycle.toStringAsFixed(0)),
            _stat(
              context,
              'Average premium capture (median)',
              aggregates.medianPremiumCapturePct == null
                  ? '--'
                  : '${aggregates.medianPremiumCapturePct!.toStringAsFixed(0)}%',
            ),
            _stat(context, 'Total premium collected', '\$${aggregates.totalPremiumCollected.toStringAsFixed(2)}'),
            _stat(context, 'Total fees paid', '\$${aggregates.totalFeesPaid.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Net result by underlying', style: textTheme.labelLarge),
            for (final entry in aggregates.netResultByUnderlying.entries)
              _stat(context, entry.key, '\$${entry.value.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Roll-count distribution', style: textTheme.labelLarge),
            for (final entry in (aggregates.rollCountDistribution.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key))))
              _stat(context, '${entry.key} roll${entry.key == 1 ? '' : 's'}', '${entry.value} cycle${entry.value == 1 ? '' : 's'}'),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
