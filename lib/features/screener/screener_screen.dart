import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/leg.dart';
import '../../domain/rules/credit_bound.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../state/screener/screener_controller.dart';
import '../../widgets/help_chip.dart';

/// §5.1's entry screener: type a candidate trade, see the outputs, either
/// "Just calculating" (nothing persisted) or "Track this position" (creates
/// a `WheelCycle` + first `Leg`, S-020).
class ScreenerScreen extends ConsumerWidget {
  const ScreenerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(screenerControllerProvider);
    final controller = ref.read(screenerControllerProvider.notifier);
    final outputs = ref.watch(screenerOutputsProvider);
    final totalPerContract = ref
        .watch(preferencesControllerProvider)
        .valueOrNull
        ?.totalPerContractToggle ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Screener')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Ticker',
              suffixIcon: Padding(padding: EdgeInsets.all(8), child: HelpChip(topicId: 'ticker')),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: controller.setTicker,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<OptionType>(
                  segments: const [
                    ButtonSegment(value: OptionType.put, label: Text('Put')),
                    ButtonSegment(value: OptionType.call, label: Text('Call')),
                  ],
                  selected: {form.side},
                  onSelectionChanged: (selection) => controller.setSide(selection.first),
                ),
              ),
              const HelpChip(topicId: 'side'),
            ],
          ),
          const SizedBox(height: 12),
          _NumberField(
            label: 'Strike (\$)',
            helpTopicId: 'strike',
            onChangedDecimal: controller.setStrike,
          ),
          _NumberField(
            label: 'Stock price (\$)',
            helpTopicId: 'stock_price',
            onChangedDecimal: controller.setSpot,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NumberField(
                  label: totalPerContract ? 'Credit (\$ total for contract)' : 'Credit (\$ per share)',
                  helpTopicId: 'credit',
                  onChangedDecimal: controller.setCredit,
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: totalPerContract,
                    onChanged: (v) => ref
                        .read(preferencesControllerProvider.notifier)
                        .update((p) => p.copyWith(totalPerContractToggle: v)),
                  ),
                  const Text('Total per\ncontract', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          if (outputs.creditBound != null && outputs.creditBound!.level != CreditBoundLevel.ok)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                outputs.creditBound!.message!,
                style: TextStyle(
                  color: outputs.creditBound!.blocks
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          _ExpirationPicker(
            expiration: form.expiration,
            nonFridayWarning: form.nonFridayWarning,
            onPick: controller.setExpiration,
          ),
          _NumberField(
            label: 'DTE (days) -- moves the expiration above',
            onChangedInt: controller.setDteConvenience,
          ),
          _NumberField(
            label: 'IV (%)',
            helpTopicId: 'iv',
            onChangedDouble: controller.setIv,
          ),
          _NumberField(
            label: 'IV rank',
            helpTopicId: 'iv_rank',
            onChangedDouble: controller.setIvRank,
          ),
          _NumberField(
            label: 'Contracts',
            helpTopicId: 'contracts',
            initialText: '1',
            onChangedInt: (v) => controller.setContracts(v ?? 1),
          ),
          _NumberField(
            label: 'Open fee (\$, optional)',
            onChangedDecimal: controller.setOpenFee,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Happy to be assigned on this one?'),
            value: form.acceptsAssignment,
            onChanged: controller.setAcceptsAssignment,
          ),
          const SizedBox(height: 20),
          _OutputsSection(outputs: outputs),
          const SizedBox(height: 20),
          if (form.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(form.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.justCalculate,
                  child: const Text('Just calculating'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: form.isSaving
                      ? null
                      : () async {
                          final ok = await controller.trackThisPosition();
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('Position tracked.')));
                            controller.reset();
                          }
                        },
                  child: form.isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Track this position'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Feature Invariant 22's date picker: defaults to the nearest Friday
/// 30-45 days out, warns (never blocks) on a non-Friday pick.
class _ExpirationPicker extends StatelessWidget {
  const _ExpirationPicker({
    required this.expiration,
    required this.nonFridayWarning,
    required this.onPick,
  });

  final DateTime? expiration;
  final bool nonFridayWarning;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Expiration: ${expiration == null ? '--' : _dateText(expiration!)}')),
              const HelpChip(topicId: 'expiration'),
              TextButton(
                onPressed: () async {
                  final now = expiration ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) onPick(picked);
                },
                child: const Text('Change'),
              ),
            ],
          ),
          if (nonFridayWarning)
            Text(
              'Not a Friday -- listed equity options expire on Fridays, though index and '
              'month-end products legitimately differ.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
        ],
      ),
    );
  }
}

String _dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    this.helpTopicId,
    this.initialText,
    this.onChangedDecimal,
    this.onChangedDouble,
    this.onChangedInt,
  });

  final String label;
  final String? helpTopicId;
  final String? initialText;
  final ValueChanged<Decimal?>? onChangedDecimal;
  final ValueChanged<double?>? onChangedDouble;
  final ValueChanged<int?>? onChangedInt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialText,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: helpTopicId == null
              ? null
              : Padding(padding: const EdgeInsets.all(8), child: HelpChip(topicId: helpTopicId!)),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        onChanged: (text) {
          onChangedDecimal?.call(Decimal.tryParse(text.trim()));
          onChangedDouble?.call(double.tryParse(text.trim()));
          onChangedInt?.call(int.tryParse(text.trim()));
        },
      ),
    );
  }
}

class _OutputsSection extends StatelessWidget {
  const _OutputsSection({required this.outputs});

  final ScreenerOutputs outputs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (outputs.isBlocked) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outputs', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Fix the credit above to see the outputs -- an impossible credit '
                'produces no yield, one-sigma move, or sorting score.',
                style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outputs', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _OutputRow('Annualised yield', _pctText(outputs.annualisedYield), helpTopicId: 'annualised_yield'),
            _OutputRow('One-sigma move', _moneyText(outputs.oneSigmaMove), helpTopicId: 'one_sigma'),
            _OutputRow(
              'Strike distance (\$)',
              _moneyText(outputs.strikeDistanceDollars),
              helpTopicId: 'strike_distance',
            ),
            _OutputRow(
              'Strike distance (sigmas)',
              _numText(outputs.cushionSigmas),
              helpTopicId: 'strike_distance',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Hard gates', style: textTheme.titleSmall),
                const HelpChip(topicId: 'hard_gates'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _GateChip(label: 'IV rank', pass: outputs.gates?.ivRankPasses),
                const SizedBox(width: 8),
                _GateChip(label: 'Annualised yield', pass: outputs.gates?.annualisedYieldPasses),
              ],
            ),
            const SizedBox(height: 16),
            // Deliberately small text and no special emphasis -- the score
            // is a sorting aid, never the largest element on this screen
            // (docs/conventions.md §4).
            Row(
              children: [
                Text('Sorting score', style: textTheme.labelLarge),
                const HelpChip(topicId: 'sorting_score'),
              ],
            ),
            Text(
              outputs.sortingScore == null ? '--' : '${outputs.sortingScore} / 9',
              style: textTheme.bodyMedium,
            ),
            Text(
              'These bands are yours to edit — they are not established doctrine.',
              style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow(this.label, this.value, {this.helpTopicId});

  final String label;
  final String value;
  final String? helpTopicId;

  @override
  Widget build(BuildContext context) {
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GateChip extends StatelessWidget {
  const _GateChip({required this.label, required this.pass});

  final String label;
  final bool? pass;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color = pass == null
        ? scheme.surfaceContainerHighest
        : (pass! ? scheme.primaryContainer : scheme.errorContainer);
    final String suffix = pass == null ? '' : (pass! ? ' ✓' : ' ✗');
    return Chip(label: Text('$label$suffix'), backgroundColor: color);
  }
}

String _pctText(double? v) => v == null ? '--' : '${v.toStringAsFixed(1)}%';

String _moneyText(Decimal? v) => v == null ? '--' : '\$${v.toStringAsFixed(2)}';

String _numText(double? v) => v == null ? '--' : v.toStringAsFixed(2);
