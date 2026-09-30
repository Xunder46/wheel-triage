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
    // Not a `ListTile`: its `trailing` slot is given a fixed height, and the
    // two figures below overflow it by 59px at the largest text size
    // (S-313). An `InkWell` over an intrinsic-height `Row` lets the row grow
    // instead of clipping (D-63's remedy). The metrics are `ListTile`'s M3
    // ones -- `contentPadding` start 16 / end 24 and a `bodyLarge` title -- so
    // removing the tile is not also a restyle. The goldens move by a hairline:
    // the title is identical, the subtitle by 1px and the two trailing figures
    // by 2px in opposite directions -- the 4px gap that replaced the tile's
    // centred trailing alignment; see the plan's Assumption Log.
    // `InkWell` sets the tap *action* but no `button` flag, so the row is
    // wrapped to keep the role `ListTile` used to set from `onTap` alone.
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 16,
            end: 24,
            top: 16,
            bottom: 16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$ticker · ${pnl.daysHeld}d · $legCount leg${legCount == 1 ? '' : 's'}',
                      style: textTheme.bodyLarge,
                    ),
                    Text(
                      'Total premium ${_money(pnl.totalPremium)} · ${_outcomeLabel(outcome)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // D-62: the trailing column is the smallest widget holding the
              // net result and the return on capital, so neither figure is read
              // out without its quantity. The two figures are one above the
              // other, so each gets its own node rather than sharing a line.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Semantics(
                    label:
                        'Net result ${beforeFees ? 'not available' : _money(pnl.netResult)}',
                    child: Text(
                      beforeFees ? 'Before fees' : _money(pnl.netResult),
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    label:
                        'Return on capital ${beforeFees ? 'not available' : '${pnl.returnOnCapitalPct.toStringAsFixed(1)}%'}',
                    child: Text(
                      beforeFees
                          ? '--'
                          : '${pnl.returnOnCapitalPct.toStringAsFixed(1)}%',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
