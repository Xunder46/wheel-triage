import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money/whole_dollars.dart';
import '../../domain/rules/bucket.dart';
import '../../domain/rules/capital_committed.dart';
import '../../domain/rules/obligation.dart';
import '../../state/portfolio/portfolio_controller.dart';

/// Stage 7's Portfolio surface (Pro Wave 3 D-42…D-46): capital committed and
/// concentration, net position delta, the assignment calendar and the five
/// bucket counts.
///
/// It is a **second view of the same calculations**, not a second
/// implementation: every figure comes from `PortfolioState`, which is
/// assembled from the shipped rules functions. The screen derives nothing.
///
/// Reached only through D-40's gate — Today evaluates it and either pushes
/// this route or opens the paywall. This screen never asks the store anything
/// and never reads the entitlement, so "the entitlement is read in exactly
/// one place" stays true by construction.
class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key, this.now});

  /// The clock the screen reads, injectable so a test can pin the month the
  /// calendar opens on. Production passes nothing and gets `DateTime.now()`.
  final DateTime? now;

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    // The controller is `autoDispose`, so it is rebuilt on every entry and
    // this is the one load. A deferred frame keeps the provider update out of
    // the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(portfolioControllerProvider.notifier).load(now: widget.now);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pro · as of ${_asOf(widget.now ?? DateTime.now())}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text('Portfolio', style: textTheme.titleLarge),
          ],
        ),
      ),
      body: _Body(state: state, now: widget.now),
    );
  }
}

/// `Mon, Sep 28` — the sub-line's own casing (D-42). Built from the shipped
/// formatters rather than a new one.
String _asOf(DateTime now) =>
    '${shortWeekdayDateText(now)}, ${monthAbbreviation(now)} ${now.day}';

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.now});

  final PortfolioState state;

  /// The screen's clock, passed on so a reload and the grid read the same one
  /// the first load did. Null in production, which means `DateTime.now()`.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.committedNow == null) {
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

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(portfolioControllerProvider.notifier).load(now: now),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          _ConcentrationCard(state: state),
          const SizedBox(height: 12),
          _DeltaCard(state: state),
          const SizedBox(height: 12),
          _CalendarCard(state: state, now: now),
          const SizedBox(height: 12),
          _CountsRow(counts: state.bucketCounts),
        ],
      ),
    );
  }
}

/// D-42's concentration card: the big committed figure, the per-underlying
/// bars (or dollar rows when there is no wheel capital), the limit key and
/// the definition paragraph.
class _ConcentrationCard extends StatelessWidget {
  const _ConcentrationCard({required this.state});

  final PortfolioState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final committed = state.committedNow;
    final capital = state.wheelCapital;

    return _Card(
      children: [
        Semantics(
          label: committed == null
              ? 'Capital committed now'
              : 'Capital committed now ${wholeDollars(committed)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                committed == null ? '--' : wholeDollars(committed),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              if (committed != null && capital != null)
                Text(
                  'committed now · ${state.percentOfWheelCapital}% of '
                  '${wholeDollars(capital)} wheel capital',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (capital == null)
          // D-42: no wheel capital means no bars, no percentages, no limit
          // key and no flag line -- only the dollars, which are knowable.
          for (final bar in state.bars)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(bar.ticker, style: textTheme.bodyMedium),
                  ),
                  Text(
                    wholeDollars(bar.committed),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
        else ...[
          for (final bar in state.bars) _BarRow(bar: bar, state: state),
          const SizedBox(height: 8),
          if (state.keyLine != null)
            Row(
              children: [
                Container(width: 2, height: 12, color: scheme.onSurface),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    state.keyLine!,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
        ],
        const SizedBox(height: 8),
        Text(
          state.definitionLine,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        for (final line in state.flagLines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (state.inviteLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              state.inviteLine!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// One underlying's bar: the ticker, a track with the fill and the limit
/// mark, and the rounded whole percent.
///
/// The fill is the **unrounded** ratio over the track max (D-42), so a book
/// sitting just under the limit fills just under the mark and the two cannot
/// disagree about which is larger.
class _BarRow extends StatelessWidget {
  const _BarRow({required this.bar, required this.state});

  final PortfolioBar bar;
  final PortfolioState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final trackMax = concentrationTrackMaxPct(state.concentrationLimitPct);
    final ratio = concentrationRatio(
      capital: bar.committed,
      wheelCapital: state.wheelCapital,
    );
    final fill = ratio == null
        ? 0.0
        : (ratio.toDouble() / trackMax).clamp(0.0, 1.0);
    final mark = state.concentrationLimitPct / trackMax;
    final over =
        ratio != null && ratio.toDouble() > state.concentrationLimitPct;

    return KeyedSubtree(
      key: ValueKey('portfolio-bar-${bar.ticker}'),
      child: Semantics(
        label:
            '${bar.ticker} ${wholeDollars(bar.committed)} committed, '
            '${bar.percent}% of wheel capital',
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  bar.ticker,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: over ? FontWeight.w700 : FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Container(
                        height: 9,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      Container(
                        height: 9,
                        width: constraints.maxWidth * fill,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      Positioned(
                        left: (constraints.maxWidth * mark).clamp(
                          0.0,
                          constraints.maxWidth - 2,
                        ),
                        top: -4,
                        bottom: -4,
                        child: Container(width: 2, color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${bar.percent}%',
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: over ? FontWeight.w700 : FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D-43's delta card: the signed total, the definition, the aging note and
/// the "Left out" line.
class _DeltaCard extends StatelessWidget {
  const _DeltaCard({required this.state});

  final PortfolioState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return _Card(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Net position delta',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Semantics(
              label:
                  'Net position delta ${signedSharesText(state.deltaShares)}',
              child: Text(
                signedSharesText(state.deltaShares),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Signed position delta × 100 × contracts, plus shares held.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (state.agingLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              state.agingLine!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (state.leftOutLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              state.leftOutLine!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// D-45's calendar: the month header, the seven-column grid and one row per
/// date with an obligation.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.state, required this.now});

  final PortfolioState state;

  /// The screen's clock (D-45): the outlined "today" cell and the reload both
  /// read it, so a pinned clock in a test is honoured rather than bypassed.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final month = state.calendarMonth;
    if (month == null) return const SizedBox.shrink();

    final today = now ?? DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday-first, so the leading pad is the first day's weekday index.
    final leading = first.weekday % 7;
    final cells = <DateTime>[
      for (var i = leading; i > 0; i--) first.subtract(Duration(days: i)),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(cells.last.add(const Duration(days: 1)));
    }

    final marked = {
      for (final obligation in state.obligations)
        DateTime(
          obligation.date.year,
          obligation.date.month,
          obligation.date.day,
        ),
    };

    // One row per date, ascending -- the obligations arrive already grouped
    // and sorted, so the rows are a fold rather than a second sort.
    final byDate = <DateTime, List<PortfolioObligation>>{};
    for (final obligation in state.obligations) {
      byDate.putIfAbsent(obligation.date, () => []).add(obligation);
    }
    final dates = byDate.keys.toList()..sort();

    return _Card(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthYearText(month),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'Expirations',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(
            key: ValueKey('portfolio-calendar-row-$row'),
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _DayCell(
                    date: cells[row * 7 + column],
                    month: month,
                    today: today,
                    marked: marked,
                  ),
                ),
            ],
          ),
        for (final date in dates) ...[
          const SizedBox(height: 8),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 6),
          Text(
            // D-13's expiry-card form (`Fri Oct 2`), which is what the plan's
            // S-300 pins -- not Today's own comma-bearing header form.
            shortWeekdayDateText(date),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          for (final obligation in byDate[date]!)
            Semantics(
              label:
                  '${obligation.ticker} ${legContractText(obligation.leg)} '
                  '${obligationFor(obligation.leg)?.text ?? ''}',
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${obligation.ticker} ${legContractText(obligation.leg)} · '
                  '${obligationFor(obligation.leg)?.text ?? ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// One day in the grid. A day outside the shown month is muted; today is
/// outlined **even when it is a leading cell** (D-45); a day in the shown
/// month with an expiration is marked.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.month,
    required this.today,
    required this.marked,
  });

  final DateTime date;
  final DateTime month;
  final DateTime today;
  final Set<DateTime> marked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final inMonth = date.month == month.month && date.year == month.year;
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isMarked = inMonth && marked.contains(date);

    return Container(
      margin: const EdgeInsets.all(1.5),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isMarked ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Text(
        '${date.day}',
        textAlign: TextAlign.center,
        style: textTheme.bodySmall?.copyWith(
          color: inMonth ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: isMarked ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// D-46's five counts, in `kBucketOrder`, read-only tiles rather than Today's
/// filters. The order and the counts come from `bucket.dart`; only the
/// rendering differs, which is why there is no shared widget.
class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.counts});

  final List<({Bucket bucket, int count})> counts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (final entry in counts)
          Expanded(
            child: Semantics(
              label: '${bucketLabel(entry.bucket)} ${entry.count}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    Text(
                      '${entry.count}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      bucketLabel(entry.bucket),
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The card shell every section shares: the theme's surface, the theme's
/// outline, the theme's radius. No literal colour anywhere.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
