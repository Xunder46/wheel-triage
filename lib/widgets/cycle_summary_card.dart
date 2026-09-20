import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../domain/rules/cycle_pnl.dart';

/// The §4.1/§4.2 cycle-P&L card, in its two variants: a **closed** cycle
/// shows a real net result (or "Before fees" when [CyclePnl.hasFeeGap],
/// Feature Invariant 28/brief §4.3); an **open** cycle shows the identical
/// figures marked "Unrealised, excludes closing costs" instead (Feature
/// Invariant 28, S-126) — an open leg's own not-yet-recorded closing fee is
/// the ordinary case, not an error state, so an open cycle never shows
/// "Before fees" regardless of [CyclePnl.hasFeeGap].
///
/// Pure presentation: every figure arrives already computed via
/// `lib/domain/rules/cycle_pnl.dart`'s `computeCyclePnl` — this widget only
/// formats and lays it out, never derives anything itself.
class CycleSummaryCard extends StatelessWidget {
  const CycleSummaryCard({
    super.key,
    required this.pnl,
    required this.isClosed,
    this.outcomeLabel,
    this.onEditFees,
  });

  final CyclePnl pnl;

  /// `true` for a cycle whose `WheelCycle.status == closed`.
  final bool isClosed;

  /// e.g. "Called away", "Expired worthless" — `null` while still open.
  final String? outcomeLabel;

  /// S-122: reachable from the "Before fees" banner when non-null. Pure
  /// presentation — this widget never touches the repository itself; the
  /// caller (`position_detail_sheet.dart`) owns what tapping it does.
  final VoidCallback? onEditFees;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // "Before fees" only ever applies to a CLOSED cycle -- an open cycle's
    // own still-open leg is expected to be missing a closing fee, so it is
    // never treated as a completeness gap (Feature Invariant 28).
    final beforeFees = isClosed && pnl.hasFeeGap;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Cycle P&L', style: textTheme.titleSmall),
                if (outcomeLabel != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(outcomeLabel!, style: textTheme.labelSmall),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            if (!isClosed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Unrealised, excludes closing costs',
                  style: textTheme.bodySmall?.copyWith(color: scheme.tertiary, fontStyle: FontStyle.italic),
                ),
              ),
            if (beforeFees)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Before fees -- ${pnl.feeGapCount} leg${pnl.feeGapCount == 1 ? '' : 's'} missing fee data',
                        style: textTheme.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ),
                    if (onEditFees != null)
                      TextButton(onPressed: onEditFees, child: const Text('Add fees')),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _row(context, 'Total premium', _money(pnl.totalPremium)),
            _row(context, 'Total fees', _money(pnl.totalFees)),
            _row(context, 'Stock P&L', _money(pnl.stockPnL)),
            _row(context, 'Net result', beforeFees ? 'Before fees' : _money(pnl.netResult), emphasize: true),
            const Divider(),
            // S-129: the on-screen label is always "Peak capital committed",
            // never a bare "Capital committed" (Feature Invariant 27).
            _row(context, 'Peak capital committed', _money(pnl.peakCapitalCommitted)),
            _row(
              context,
              'Return on capital',
              beforeFees ? 'Before fees' : _pct(pnl.returnOnCapitalPct),
            ),
            _row(
              context,
              'Annualised return',
              beforeFees
                  ? 'Before fees'
                  : (pnl.annualisedReturnPct != null ? _pct(pnl.annualisedReturnPct!) : (pnl.annualisedReturnNote ?? '--')),
            ),
            _row(context, 'Days held', '${pnl.daysHeld}'),
            _row(context, 'Roll count', '${pnl.rollCount}'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          Text(value, style: TextStyle(fontWeight: emphasize ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}

String _money(Decimal v) => '\$${v.toStringAsFixed(2)}';

String _pct(double v) => '${v.toStringAsFixed(1)}%';
