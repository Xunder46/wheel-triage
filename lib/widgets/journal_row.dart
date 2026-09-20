import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../domain/models/wheel_cycle.dart';
import '../domain/rules/cycle_pnl.dart';

/// One Journal screen row (§4.4): ticker, duration, leg count, total
/// premium, outcome, net result, return on capital. Pure presentation --
/// [pnl]/[outcome]/[legCount] all arrive already computed; this widget only
/// formats and lays them out.
class JournalRowTile extends StatelessWidget {
  const JournalRowTile({
    super.key,
    required this.ticker,
    required this.outcome,
    required this.legCount,
    required this.pnl,
    this.onTap,
  });

  final String ticker;
  final WheelCycleOutcome? outcome;
  final int legCount;
  final CyclePnl pnl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final beforeFees = pnl.hasFeeGap;
    return ListTile(
      onTap: onTap,
      title: Text('$ticker · ${pnl.daysHeld}d · $legCount leg${legCount == 1 ? '' : 's'}'),
      subtitle: Text(
        'Total premium ${_money(pnl.totalPremium)} · ${_outcomeLabel(outcome)}',
        style: textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            beforeFees ? 'Before fees' : _money(pnl.netResult),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            beforeFees ? '--' : '${pnl.returnOnCapitalPct.toStringAsFixed(1)}%',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _outcomeLabel(WheelCycleOutcome? outcome) => switch (outcome) {
  WheelCycleOutcome.expiredWorthless => 'Expired worthless',
  WheelCycleOutcome.closedEarly => 'Closed early',
  WheelCycleOutcome.calledAway => 'Called away',
  WheelCycleOutcome.abandoned => 'Abandoned',
  null => 'Open',
};

String _money(Decimal v) => '\$${v.toStringAsFixed(2)}';
