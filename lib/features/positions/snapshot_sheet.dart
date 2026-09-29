import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/money/total_per_contract.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/rules/snapshot_preview.dart';
import '../../state/positions/position_detail_controller.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../widgets/bucket_badge.dart';
import '../../widgets/help_chip.dart';

/// Opens D-17's "Update snapshot" sheet: the existing C4 fields, plus the
/// preview of the bucket the entered numbers *would* produce.
///
/// Completes with `true` once a snapshot has actually been saved, `null` when
/// the sheet was dismissed — so a caller that renders the position's own
/// classification (Today's inline Update, S-244) reloads only on a real save.
Future<bool?> showSnapshotSheet({
  required BuildContext context,
  required String legId,
  DateTime? now,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => SnapshotSheet(legId: legId, now: now),
);

/// The snapshot sheet, extracted from `position_detail_sheet.dart` so a
/// second entry point can host it.
///
/// It takes a [legId] rather than a loaded leg and renders a loader until
/// the controller's leg arrives — it never dereferences an unloaded leg.
///
/// [now] is a test seam only: production always uses real `now` (D-17), and
/// a null [now] means exactly that.
class SnapshotSheet extends ConsumerStatefulWidget {
  const SnapshotSheet({super.key, required this.legId, this.now});

  final String legId;
  final DateTime? now;

  @override
  ConsumerState<SnapshotSheet> createState() => _SnapshotSheetState();
}

class _SnapshotSheetState extends ConsumerState<SnapshotSheet> {
  bool _adopted = false;

  late final TextEditingController _markController;
  late final TextEditingController _spotController;
  late final TextEditingController _deltaController;
  late final TextEditingController _ivController;
  late DateTime _takenAt;
  late DeltaConvention _convention;
  late bool _totalPerContract;

  /// C4/D-17: a prefilled value stays visibly marked as carried forward
  /// until the user edits *that* field, so a stale value cannot be mistaken
  /// for a fresh reading.
  bool _spotCarried = false;
  bool _ivCarried = false;

  String? _error;

  /// One-shot adoption of the loaded leg's own values. Runs on the first
  /// build that has a leg, so the sheet can be opened before the controller
  /// has finished loading.
  void _adopt(PositionDetailState state) {
    _adopted = true;
    final previous = state.latestSnapshot;
    _markController = TextEditingController();
    // Option mark and delta are deliberately never carried (C4/D-17) --
    // they change too much to default usefully.
    _deltaController = TextEditingController();
    _spotController = TextEditingController(
      text: previous?.underlyingPrice.toString() ?? '',
    );
    _ivController = TextEditingController(text: trimTrailingZeros(previous?.iv));
    _spotCarried = previous != null;
    _ivCarried = previous?.iv != null;
    _takenAt = widget.now ?? DateTime.now();
    _convention =
        ref.read(preferencesControllerProvider).valueOrNull?.deltaConventionDefault ??
        DeltaConvention.position;
    _totalPerContract =
        ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;
  }

  @override
  void dispose() {
    if (_adopted) {
      _markController.dispose();
      _spotController.dispose();
      _deltaController.dispose();
      _ivController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(positionDetailControllerProvider(widget.legId));
    final leg = state.leg;
    if (leg == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: state.error != null
            ? Text(state.error!)
            : const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    }
    if (!_adopted) _adopt(state);

    final controller = ref.read(positionDetailControllerProvider(widget.legId).notifier);
    final now = widget.now ?? DateTime.now();
    final mark = Decimal.tryParse(_markController.text.trim());
    final spot = Decimal.tryParse(_spotController.text.trim());
    final delta = double.tryParse(_deltaController.text.trim());
    final perShareMark = mark == null
        ? null
        : perShareValue(mark, totalPerContract: _totalPerContract);
    final preview = (perShareMark == null || spot == null || delta == null)
        ? null
        : buildSnapshotPreview(
            leg: leg,
            profile: state.profile,
            now: now,
            optionMark: perShareMark,
            underlyingPrice: spot,
            deltaAsEntered: delta,
            deltaConvention: _convention,
            iv: double.tryParse(_ivController.text.trim()),
            latestSnapshot: state.latestSnapshot,
          );

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
            Text('Update snapshot', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // S-142: backdating -- defaults to now; the calendar itself is
            // bounded to `[leg.openedAt, leg.expiration]`, and the
            // controller re-validates the same range on submit.
            Row(
              children: [
                Expanded(child: Text('Snapshot date: ${dateText(_takenAt)}')),
                TextButton(
                  onPressed: () async {
                    final clampedInitial = _takenAt.isBefore(leg.openedAt)
                        ? leg.openedAt
                        : (_takenAt.isAfter(leg.expiration) ? leg.expiration : _takenAt);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: clampedInitial,
                      firstDate: leg.openedAt,
                      lastDate: leg.expiration,
                    );
                    if (picked != null) setState(() => _takenAt = picked);
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
                    controller: _markController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _totalPerContract
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
                      value: _totalPerContract,
                      onChanged: (v) {
                        setState(() => _totalPerContract = v);
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
              controller: _spotController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _spotCarried = false),
              decoration: InputDecoration(
                labelText: 'Stock price (\$)',
                suffixIcon: const Padding(
                  padding: EdgeInsets.all(8),
                  child: HelpChip(topicId: 'stock_price'),
                ),
                helperText: _spotCarried ? 'Carried forward from last snapshot' : null,
              ),
            ),
            TextField(
              controller: _deltaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Delta, as shown on your broker screen',
                helperText: 'Enter it exactly as your broker shows it, minus sign included.',
                helperMaxLines: 2,
                suffixIcon: const Padding(
                  padding: EdgeInsets.all(8),
                  child: HelpChip(topicId: 'delta'),
                ),
              ),
              // C4: a live deltaMagnitude readout as the user types, so
              // the sign handling is visible rather than implied.
              onChanged: (_) => setState(() {}),
            ),
            if (delta != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  'Magnitude: ${delta.abs().toStringAsFixed(4)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Row(
              children: [
                const Text('Convention:'),
                const SizedBox(width: 8),
                DropdownButton<DeltaConvention>(
                  value: _convention,
                  items: const [
                    DropdownMenuItem(value: DeltaConvention.position, child: Text('Position')),
                    DropdownMenuItem(value: DeltaConvention.option, child: Text('Option')),
                  ],
                  onChanged: (v) => setState(() => _convention = v ?? _convention),
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
                helperText: _ivCarried ? 'Carried forward from last snapshot' : null,
                labelText: 'IV (%, optional)',
              ),
              controller: _ivController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _ivCarried = false),
            ),
            const SizedBox(height: 16),
            if (preview != null) ...[
              _PreviewCard(preview: preview),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Fill in the mark, stock price and delta to see the verdict this '
                  'reading would produce.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: () async {
                // Read the fields at press time rather than reusing the
                // build-time values: a `setState` from the last keystroke may
                // not have been pumped yet when the button is pressed.
                final enteredMark = Decimal.tryParse(_markController.text.trim());
                final enteredSpot = Decimal.tryParse(_spotController.text.trim());
                final enteredDelta = double.tryParse(_deltaController.text.trim());
                if (enteredMark == null || enteredSpot == null || enteredDelta == null) return;
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final ok = await controller.updateSnapshot(
                  optionMark: enteredMark,
                  underlyingPrice: enteredSpot,
                  deltaAsEntered: enteredDelta,
                  deltaConvention: _convention,
                  iv: double.tryParse(_ivController.text.trim()),
                  takenAt: _takenAt,
                );
                if (!mounted) return;
                if (ok) {
                  // Read via the provider, not the protected `.state`
                  // getter -- state is already updated synchronously by
                  // `updateSnapshot` before it returns.
                  final warning = ref
                      .read(positionDetailControllerProvider(widget.legId))
                      .snapshotWarning;
                  navigator.pop(true);
                  if (warning != null) {
                    messenger.showSnackBar(SnackBar(content: Text(warning)));
                  }
                } else {
                  setState(
                    () => _error = ref
                        .read(positionDetailControllerProvider(widget.legId))
                        .snapshotError,
                  );
                }
              },
              child: const Text('Save snapshot'),
            ),
          ],
        ),
      ),
    );
  }
}

/// D-17's preview: what the entered numbers would produce, shown before
/// anything is saved. Pure presentation of an already-computed
/// [SnapshotPreview] — no threshold, band or percentage is derived here.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final SnapshotPreview preview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Before you save', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                BucketBadge(bucket: preview.bucket),
                const SizedBox(width: 8),
                Expanded(child: Text(preview.bucket.reason, style: textTheme.bodyMedium)),
              ],
            ),
            if (preview.changeLine != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  preview.changeLine!,
                  style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 8),
            _PreviewRow('Captured', pctText(preview.capturedPct)),
            _PreviewRow(
              'Roll band in use',
              preview.rollBandLabelText,
              helpTopicId: 'roll_band',
              stacked: true,
            ),
            _PreviewRow('Extrinsic remaining', moneyText(preview.extrinsic), helpTopicId: 'extrinsic'),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value, {this.helpTopicId, this.stacked = false});

  final String label;
  final String value;
  final String? helpTopicId;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, style: textTheme.bodyMedium)),
        if (helpTopicId != null) HelpChip(topicId: helpTopicId!),
      ],
    );
    final valueText = Text(value, style: textTheme.bodyMedium);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelRow, valueText],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: labelRow),
                const SizedBox(width: 8),
                Flexible(child: valueText),
              ],
            ),
    );
  }
}
