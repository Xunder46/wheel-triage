import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/snapshot_freshness.dart';
import '../../state/positions/position_detail_controller.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../widgets/bucket_badge.dart';
import '../../widgets/cycle_summary_card.dart';
import '../../widgets/delta_sparkline.dart';
import '../../widgets/label_value_row.dart';
import 'snapshot_sheet.dart';

/// §5.2's position detail: current verdict + the arithmetic shown openly,
/// the roll chain with its cumulative credit, a delta-history sparkline,
/// and the Roll/Close/Mark assigned/Mark expired actions. "Update snapshot"
/// is the primary action, reachable in one tap from this screen.
class PositionDetailSheet extends ConsumerWidget {
  const PositionDetailSheet({super.key, required this.legId});

  final String legId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(positionDetailControllerProvider(legId));
    final controller = ref.read(
      positionDetailControllerProvider(legId).notifier,
    );

    return Scaffold(
      appBar: AppBar(title: Text(state.underlying?.ticker ?? 'Position')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? Center(child: Text(state.error!))
          : _DetailBody(legId: legId, state: state, controller: controller),
      floatingActionButton: state.leg == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  showSnapshotSheet(context: context, legId: legId),
              icon: const Icon(Icons.edit_note),
              label: const Text('Update snapshot'),
            ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.legId,
    required this.state,
    required this.controller,
  });

  final String legId;
  final PositionDetailState state;
  final PositionDetailController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leg = state.leg!;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(preferencesControllerProvider).valueOrNull;
    final showIvNote = prefs != null && !prefs.ivResolutionNoticeDismissed;
    // §7/Feature Invariant 33: display-only -- never fed back into
    // `classify()` or any gate. `DateTime.now()` here is exactly the same
    // "current wall-clock time for a UI-only reading" every date picker's
    // default already uses elsewhere in `lib/features/`.
    final latestSnapshot = state.latestSnapshot;
    final freshness = latestSnapshot == null
        ? null
        : freshnessOf(takenAt: latestSnapshot.takenAt, now: DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Q9 addition #2 (Feature Invariant 24): one-time, global, dismissable
        // note shown the first time any position detail sheet opens after
        // this update ships -- never per-leg.
        if (showIvNote) ...[
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'The roll band now falls back to the IV a leg was opened at when no '
                      'snapshot IV is recorded yet, instead of dropping straight to the '
                      'profile default.',
                      style: textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => ref
                        .read(preferencesControllerProvider.notifier)
                        .update(
                          (p) => p.copyWith(ivResolutionNoticeDismissed: true),
                        ),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          '\$${leg.strike} ${leg.optionType.name} · exp ${dateText(leg.expiration)} · '
          '${leg.contracts}x',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (state.bucket != null) ...[
          Row(
            children: [
              BucketBadge(bucket: state.bucket!),
              const SizedBox(width: 8),
              Expanded(child: Text(state.bucket!.reason)),
            ],
          ),
          // S-202/D-11: which threshold version classified this leg, right
          // beside the verdict it produced -- the leg's pinned version, not
          // the profile's current one, so an edit is visible here as a
          // changed number rather than a rewritten history.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Rules: ${state.profile.name} v${state.profile.version}',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // S-141/Feature Invariant 33: a stale reading names its own source
          // right beside the verdict it produced, not behind a tap.
          if (freshness == Freshness.stale && latestSnapshot != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Computed from the snapshot taken on ${dateText(latestSnapshot.takenAt)}.',
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        // S-124: editable while this leg is still open -- re-triages via a
        // fresh `load()`, no new snapshot required.
        if (leg.closedAt == null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Happy to be assigned on this one?'),
            value: leg.acceptsAssignment,
            onChanged: (value) => controller.setAcceptsAssignment(value),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Arithmetic', style: textTheme.titleSmall),
                    if (freshness != null)
                      Text(
                        _freshnessLabel(freshness),
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LabelValueRow(
                  label: 'Captured',
                  value: pctText(state.capturedPct),
                  spokenValue: state.capturedPct == null
                      ? 'not available'
                      : null,
                  helpTopicId: 'captured',
                ),
                LabelValueRow(
                  label: 'Delta magnitude',
                  value: state.deltaMagnitude == null
                      ? '--'
                      : state.deltaMagnitude!.toStringAsFixed(4),
                  spokenValue: state.deltaMagnitude == null
                      ? 'not available'
                      : null,
                ),
                // S-144: this label + value pairing is long enough at a
                // realistic phone width to squeeze the label to nothing when
                // shared on one line -- stacked instead of truncating.
                LabelValueRow(
                  label: 'Roll band in use',
                  value: state.rollBandLabelText ?? '--',
                  spokenValue: state.rollBandLabelText == null
                      ? 'not available'
                      : null,
                  helpTopicId: 'roll_band',
                  stacked: true,
                ),
                LabelValueRow(
                  label: 'One-sigma move',
                  value: moneyText(state.oneSigmaMove),
                  spokenValue: state.oneSigmaMove == null
                      ? 'not available'
                      : null,
                  helpTopicId: 'one_sigma',
                ),
                LabelValueRow(
                  label: 'Extrinsic remaining',
                  value: moneyText(state.extrinsic),
                  spokenValue: state.extrinsic == null ? 'not available' : null,
                  helpTopicId: 'extrinsic',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Roll chain', style: textTheme.titleSmall),
                if (state.cameFromRoll)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'This leg came from a roll. The credit above is this leg only.',
                      style: textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                for (final chainLeg in state.cycleLegs)
                  LabelValueRow(
                    label:
                        'Leg ${chainLeg.sequence} (\$${chainLeg.strike} ${chainLeg.optionType.name})',
                    value: moneyText(
                      chainLeg.openCreditPerShare -
                          (chainLeg.closeDebitPerShare ?? Decimal.zero),
                    ),
                  ),
                const Divider(),
                LabelValueRow(
                  label: 'Cycle cumulative credit',
                  value: moneyText(state.cycleCumulativeCredit),
                  emphasize: true,
                  helpTopicId: 'cumulative_credit',
                ),
              ],
            ),
          ),
        ),
        if (state.cyclePnl != null) ...[
          const SizedBox(height: 16),
          CycleSummaryCard(
            pnl: state.cyclePnl!,
            isClosed: state.cycle?.status == WheelCycleStatus.closed,
            onEditFees: state.cyclePnl!.hasFeeGap
                ? () => _openEditFeesSheet(context, controller, state.cycleLegs)
                : null,
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delta history', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                DeltaSparkline(
                  values: state.snapshots.map((s) => s.deltaAsEntered).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => context.push('/positions/$legId/roll'),
              child: const Text('Roll'),
            ),
            OutlinedButton(
              onPressed: () => _confirmClose(context, controller),
              child: const Text('Close'),
            ),
            OutlinedButton(
              onPressed: () => context.push('/positions/$legId/assign'),
              child: const Text('Mark assigned'),
            ),
            OutlinedButton(
              onPressed: () => _confirmMarkExpired(context, controller),
              child: const Text('Mark expired'),
            ),
          ],
        ),
        if (state.actionError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              state.actionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

String _freshnessLabel(Freshness f) => switch (f) {
  Freshness.fresh => 'Fresh',
  Freshness.recent => 'Recent',
  Freshness.old => 'Old',
  Freshness.stale => 'Stale',
};

/// S-122: the "Add fees" affordance reachable from `CycleSummaryCard`'s
/// "Before fees" banner — one row per leg still missing a fee, only asking
/// for whichever field(s) are actually missing on that leg (Feature
/// Invariant 28's both-fields-on-closed-legs reading). A saved row drops
/// out of the sheet; the sheet closes itself once none remain.
Future<void> _openEditFeesSheet(
  BuildContext pageContext,
  PositionDetailController controller,
  List<Leg> cycleLegs,
) async {
  var remaining = cycleLegs
      .where(
        (l) => l.closedAt != null && (l.openFee == null || l.closeFee == null),
      )
      .toList();
  if (remaining.isEmpty) return;

  await showModalBottomSheet<void>(
    context: pageContext,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add fees',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${remaining.length} leg${remaining.length == 1 ? '' : 's'} missing fee data',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final leg in remaining)
                    _EditFeesRow(
                      key: ValueKey(leg.id),
                      leg: leg,
                      onSave: (openFee, closeFee) async {
                        final ok = await controller.updateLegFees(
                          legId: leg.id,
                          openFee: openFee,
                          closeFee: closeFee,
                        );
                        if (ok) {
                          setSheetState(
                            () => remaining = remaining
                                .where((l) => l.id != leg.id)
                                .toList(),
                          );
                          if (remaining.isEmpty && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _EditFeesRow extends StatefulWidget {
  const _EditFeesRow({super.key, required this.leg, required this.onSave});

  final Leg leg;
  final Future<void> Function(Decimal? openFee, Decimal? closeFee) onSave;

  @override
  State<_EditFeesRow> createState() => _EditFeesRowState();
}

class _EditFeesRowState extends State<_EditFeesRow> {
  final TextEditingController _openFeeController = TextEditingController();
  final TextEditingController _closeFeeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final leg = widget.leg;
    final needsOpenFee = leg.openFee == null;
    final needsCloseFee = leg.closeFee == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leg ${leg.sequence} (\$${leg.strike} ${leg.optionType.name})',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (needsOpenFee)
            TextField(
              controller: _openFeeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Open fee (\$)'),
            ),
          if (needsCloseFee)
            TextField(
              controller: _closeFeeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Close fee (\$)'),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final openFee = needsOpenFee
                    ? Decimal.tryParse(_openFeeController.text.trim())
                    : null;
                final closeFee = needsCloseFee
                    ? Decimal.tryParse(_closeFeeController.text.trim())
                    : null;
                if (openFee == null && closeFee == null) return;
                widget.onSave(openFee, closeFee);
              },
              child: const Text('Save'),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

Future<void> _confirmMarkExpired(
  BuildContext context,
  PositionDetailController controller,
) async {
  final feeController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mark expired?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This records the leg as expired worthless with no close debit.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Close fee (\$, optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Mark expired'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.markExpired(
      closeFee: Decimal.tryParse(feeController.text.trim()),
    );
  }
}

Future<void> _confirmClose(
  BuildContext context,
  PositionDetailController controller,
) async {
  final debitController = TextEditingController(text: '0.00');
  final feeController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Close this leg'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: debitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Close debit (\$ per share)',
            ),
          ),
          TextField(
            controller: feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Close fee (\$, optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    final debit = Decimal.tryParse(debitController.text.trim()) ?? Decimal.zero;
    await controller.closeDirect(
      reason: CloseReason.closedEarly,
      closeDebitPerShare: debit,
      closeFee: Decimal.tryParse(feeController.text.trim()),
    );
  }
}
