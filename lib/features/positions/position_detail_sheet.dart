import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/leg.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/models/wheel_cycle.dart';
import '../../domain/rules/formulas.dart' as formulas;
import '../../domain/rules/snapshot_freshness.dart';
import '../../state/positions/position_detail_controller.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../widgets/bucket_badge.dart';
import '../../widgets/cycle_summary_card.dart';
import '../../widgets/delta_sparkline.dart';
import '../../widgets/help_chip.dart';

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
    final controller = ref.read(positionDetailControllerProvider(legId).notifier);

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
              onPressed: () => _openUpdateSnapshotSheet(context, ref, legId, controller),
              icon: const Icon(Icons.edit_note),
              label: const Text('Update snapshot'),
            ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.legId, required this.state, required this.controller});

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
                        .update((p) => p.copyWith(ivResolutionNoticeDismissed: true)),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          '\$${leg.strike} ${leg.optionType.name} · exp ${_dateText(leg.expiration)} · '
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
                'Computed from the snapshot taken on ${_dateText(latestSnapshot.takenAt)}.',
                style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
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
                      Text(_freshnessLabel(freshness), style: textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                _Row('Captured', _pctText(state.capturedPct), helpTopicId: 'captured'),
                _Row(
                  'Delta magnitude',
                  state.deltaMagnitude == null ? '--' : state.deltaMagnitude!.toStringAsFixed(4),
                ),
                // S-144: this label + value pairing is long enough at a
                // realistic phone width to squeeze the label to nothing when
                // shared on one line -- stacked instead of truncating.
                _Row(
                  'Roll band in use',
                  state.rollBandLabelText ?? '--',
                  helpTopicId: 'roll_band',
                  stacked: true,
                ),
                _Row('One-sigma move', _moneyText(state.oneSigmaMove), helpTopicId: 'one_sigma'),
                _Row('Extrinsic remaining', _moneyText(state.extrinsic), helpTopicId: 'extrinsic'),
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
                      style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 8),
                for (final chainLeg in state.cycleLegs)
                  _Row(
                    'Leg ${chainLeg.sequence} (\$${chainLeg.strike} ${chainLeg.optionType.name})',
                    _moneyText(chainLeg.openCreditPerShare - (chainLeg.closeDebitPerShare ?? Decimal.zero)),
                  ),
                const Divider(),
                _Row(
                  'Cycle cumulative credit',
                  _moneyText(state.cycleCumulativeCredit),
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
                DeltaSparkline(values: state.snapshots.map((s) => s.deltaAsEntered).toList()),
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasize = false, this.helpTopicId, this.stacked = false});

  final String label;
  final String value;
  final bool emphasize;
  final String? helpTopicId;

  /// S-144: when the value string is long enough to otherwise squeeze the
  /// label to nothing (e.g. the roll-band row's source-aware label), the
  /// label and value stack on separate lines instead of sharing one.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: TextStyle(fontWeight: emphasize ? FontWeight.bold : FontWeight.w600),
    );

    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (helpTopicId != null) HelpChip(topicId: helpTopicId!),
              ],
            ),
            const SizedBox(height: 2),
            valueText,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                if (helpTopicId != null) HelpChip(topicId: helpTopicId!),
              ],
            ),
          ),
          valueText,
        ],
      ),
    );
  }
}

String _dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// S-143: fixed zero-decimal percentage formatting -- the same
/// "'--' when null, else fixed decimals" shape as the screener's
/// `_pctText`/`_moneyText` (`lib/features/screener/screener_screen.dart`),
/// with this sheet's own explicitly-specified decimal count (zero, not the
/// screener's one) so no raw `Decimal` (e.g. `-45.16129...%`) ever reaches
/// the widget tree.
String _pctText(Decimal? v) => v == null ? '--' : '${v.toStringAsFixed(0)}%';

/// S-143: fixed two-decimal money formatting, matching the screener's
/// `_moneyText` exactly.
String _moneyText(Decimal? v) => v == null ? '--' : '\$${v.toStringAsFixed(2)}';

String _freshnessLabel(Freshness f) => switch (f) {
  Freshness.fresh => 'Fresh',
  Freshness.recent => 'Recent',
  Freshness.old => 'Old',
  Freshness.stale => 'Stale',
};

/// Formats a carried-forward prefill value without a trailing `.0` (a whole
/// IV like `40.0` should prefill as "40", not "40.0") -- `null` becomes the
/// empty string, matching every other unset `TextEditingController` in this
/// sheet.
String _trimTrailingZeros(double? value) {
  if (value == null) return '';
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

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
      .where((l) => l.closedAt != null && (l.openFee == null || l.closeFee == null))
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
                  Text('Add fees', style: Theme.of(context).textTheme.titleMedium),
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
                          setSheetState(() => remaining = remaining.where((l) => l.id != leg.id).toList());
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Open fee (\$)'),
            ),
          if (needsCloseFee)
            TextField(
              controller: _closeFeeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Close fee (\$)'),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final openFee = needsOpenFee ? Decimal.tryParse(_openFeeController.text.trim()) : null;
                final closeFee = needsCloseFee ? Decimal.tryParse(_closeFeeController.text.trim()) : null;
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

Future<void> _confirmMarkExpired(BuildContext context, PositionDetailController controller) async {
  final feeController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mark expired?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This records the leg as expired worthless with no close debit.'),
          const SizedBox(height: 12),
          TextField(
            controller: feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Close fee (\$, optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Mark expired'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.closeDirect(
      reason: CloseReason.expiredWorthless,
      closeDebitPerShare: Decimal.zero,
      closeFee: Decimal.tryParse(feeController.text.trim()),
    );
  }
}

Future<void> _confirmClose(BuildContext context, PositionDetailController controller) async {
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
            decoration: const InputDecoration(labelText: 'Close debit (\$ per share)'),
          ),
          TextField(
            controller: feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Close fee (\$, optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Close')),
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

/// [pageContext] is the position detail screen's own context (outlives the
/// bottom sheet) -- used to show a post-dismiss soft-warn SnackBar, since the
/// sheet's own context is gone the moment it pops.
Future<void> _openUpdateSnapshotSheet(
  BuildContext pageContext,
  WidgetRef ref,
  String legId,
  PositionDetailController controller,
) {
  final markController = TextEditingController();
  final leg = ref.read(positionDetailControllerProvider(legId)).leg!;
  // S-142: defaults to now; backdating is optional and range-validated
  // against `[leg.openedAt, leg.expiration]` on submit (the controller is
  // the source of truth for that check -- this field just lets the user
  // pick a different date than "now").
  var takenAt = DateTime.now();
  // C4: Stock price and IV are prefilled from the previous snapshot (a
  // starting point, not a fresh reading) -- Option mark and Delta are
  // deliberately left blank, since those change too much to default
  // usefully (brief-followup C4).
  final previousSnapshot = ref.read(positionDetailControllerProvider(legId)).latestSnapshot;
  final spotController = TextEditingController(
    text: previousSnapshot?.underlyingPrice.toString() ?? '',
  );
  final deltaController = TextEditingController();
  final ivController = TextEditingController(text: _trimTrailingZeros(previousSnapshot?.iv));
  // `ref.watch` is only valid inside a ConsumerWidget's own `build` method --
  // this modal builder runs later, outside that scope -- so both
  // preference-derived starting values are read once here and kept in sync
  // locally via `setSheetState` (the toggle also persists every change
  // through the shared provider, Feature Invariant 21; the delta-convention
  // default only ever pre-fills the *next* entry, Feature Invariant 5/S-071
  // -- it never rewrites a stored `Snapshot.deltaConvention`).
  var convention =
      ref.read(preferencesControllerProvider).valueOrNull?.deltaConventionDefault ??
      DeltaConvention.position;
  String? localError;
  var totalPerContract =
      ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;

  return showModalBottomSheet(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update snapshot', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                // S-142: backdating -- defaults to now; the calendar itself
                // is bounded to `[leg.openedAt, leg.expiration]`, and the
                // controller re-validates the same range on submit.
                Row(
                  children: [
                    Expanded(child: Text('Snapshot date: ${_dateText(takenAt)}')),
                    TextButton(
                      onPressed: () async {
                        final clampedInitial = takenAt.isBefore(leg.openedAt)
                            ? leg.openedAt
                            : (takenAt.isAfter(leg.expiration) ? leg.expiration : takenAt);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: clampedInitial,
                          firstDate: leg.openedAt,
                          lastDate: leg.expiration,
                        );
                        if (picked != null) setSheetState(() => takenAt = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: markController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: totalPerContract
                              ? 'Option mark (\$ total for contract)'
                              : 'Option mark (\$)',
                          suffixIcon: const Padding(
                            padding: EdgeInsets.all(8),
                            child: HelpChip(topicId: 'option_mark'),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: totalPerContract,
                          onChanged: (v) {
                            setSheetState(() => totalPerContract = v);
                            ref
                                .read(preferencesControllerProvider.notifier)
                                .update((p) => p.copyWith(totalPerContractToggle: v));
                          },
                        ),
                        const Text('Total/contract', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                TextField(
                  controller: spotController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Stock price (\$)',
                    suffixIcon: const Padding(
                      padding: EdgeInsets.all(8),
                      child: HelpChip(topicId: 'stock_price'),
                    ),
                    // C4: prefilled values are clearly marked as carried
                    // forward, so a stale value can't be mistaken for a
                    // freshly typed one.
                    helperText: previousSnapshot == null ? null : 'Carried forward from last snapshot',
                  ),
                ),
                TextField(
                  controller: deltaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Delta, as shown on your broker screen',
                    helperText:
                        'Enter it exactly as your broker shows it, minus sign included.',
                    helperMaxLines: 2,
                    suffixIcon: const Padding(
                      padding: EdgeInsets.all(8),
                      child: HelpChip(topicId: 'delta'),
                    ),
                  ),
                  // C4: a live deltaMagnitude readout as the user types, so
                  // the sign handling is visible rather than implied.
                  onChanged: (_) => setSheetState(() {}),
                ),
                if (double.tryParse(deltaController.text.trim()) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Magnitude: '
                      '${formulas.deltaMagnitude(double.parse(deltaController.text.trim()))!.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Row(
                  children: [
                    const Text('Convention:'),
                    const SizedBox(width: 8),
                    DropdownButton<DeltaConvention>(
                      value: convention,
                      items: const [
                        DropdownMenuItem(value: DeltaConvention.position, child: Text('Position')),
                        DropdownMenuItem(value: DeltaConvention.option, child: Text('Option')),
                      ],
                      onChanged: (v) => setSheetState(() => convention = v ?? convention),
                    ),
                    const HelpChip(topicId: 'delta_convention'),
                  ],
                ),
                TextField(
                  decoration: InputDecoration(
                    suffixIcon: const Padding(
                      padding: EdgeInsets.all(8),
                      child: HelpChip(topicId: 'iv'),
                    ),
                    helperText: previousSnapshot?.iv == null
                        ? null
                        : 'Carried forward from last snapshot',
                    labelText: 'IV (%, optional)',
                  ),
                  controller: ivController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                if (localError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      localError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: () async {
                    final mark = Decimal.tryParse(markController.text.trim());
                    // Local variable named `stockPrice` here in
                    // `lib/features/`, since the S-060 terminology grep is
                    // scoped to this directory and matches on any bare
                    // occurrence of the shorter jargon word, not just UI
                    // label text. The shorter name stays the canonical
                    // internal identifier everywhere outside this directory
                    // (`lib/state/`, `lib/domain/`), per the brief's own
                    // allowance.
                    final stockPrice = Decimal.tryParse(spotController.text.trim());
                    final delta = double.tryParse(deltaController.text.trim());
                    if (mark == null || stockPrice == null || delta == null) return;
                    final iv = double.tryParse(ivController.text.trim());
                    final ok = await controller.updateSnapshot(
                      optionMark: mark,
                      underlyingPrice: stockPrice,
                      deltaAsEntered: delta,
                      deltaConvention: convention,
                      iv: iv,
                      takenAt: takenAt,
                    );
                    if (ok) {
                      // Read via the provider, not the protected `.state`
                      // getter -- state is already updated synchronously by
                      // `updateSnapshot` before it returns.
                      final warning = ref.read(positionDetailControllerProvider(legId)).snapshotWarning;
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      if (warning != null && pageContext.mounted) {
                        ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text(warning)));
                      }
                    } else {
                      setSheetState(
                        () => localError = ref.read(positionDetailControllerProvider(legId)).snapshotError,
                      );
                    }
                  },
                  child: const Text('Save snapshot'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
