import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates/date_text.dart';
import '../../core/money/whole_dollars.dart';
import '../../domain/models/leg.dart';
import '../../domain/rules/credit_bound.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../state/record/record_controller.dart';
import '../../state/record/record_save_service.dart';
import '../../widgets/help_chip.dart';
import '../../widgets/labeled_number_field.dart';
import '../paywall/paywall_route.dart';

/// D-16's "Record a trade": the day-after-the-fill entry point, reachable in
/// one tap from Today. It writes exactly what the screener's "Track this
/// position" writes — both call `RecordSaveService` (D-19), so the two paths
/// cannot diverge.
///
/// The screen computes nothing: the credit bound, the yield, the capital
/// figure, the reminder line and the D-12 host line all come from the state
/// layer (Feature Invariant 5), and every number it renders carries a
/// semantics label naming its quantity (Feature Invariant 6).
class RecordTradeScreen extends ConsumerStatefulWidget {
  const RecordTradeScreen({super.key});

  @override
  ConsumerState<RecordTradeScreen> createState() => _RecordTradeScreenState();
}

class _RecordTradeScreenState extends ConsumerState<RecordTradeScreen> {
  final _tickerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // `load` reads the repository for the recent-ticker chips, so it is not
    // safe to call during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recordControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final controller = ref.read(recordControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await controller.save();
    if (!mounted) return;
    if (!ok) {
      // D-30's first entry point: the free tier's refusal is answered by the
      // paywall. The screen decides nothing about Pro -- it renders the line
      // the state layer produced (D-28).
      final refusal = controller.paywallTrigger;
      if (refusal != null) {
        // Consume it: the paywall owns the trigger from here, so a later
        // failure that is not the gate's must not reopen it (D-30, R12).
        controller.clearPaywallTrigger();
        showPaywall(context, trigger: NewCyclePaywallTrigger(refusal));
      }
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(ref.read(recordControllerProvider).confirmation ?? 'Recorded.')),
    );
    context.go('/positions');
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);
    final totalPerContract =
        ref.watch(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;
    final scheme = Theme.of(context).colorScheme;

    // The chips write through the provider, so the field has to follow them
    // rather than own its own text.
    if (_tickerController.text != form.ticker) {
      _tickerController.value = TextEditingValue(
        text: form.ticker,
        selection: TextSelection.collapsed(offset: form.ticker.length),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Record a trade')),
      bottomNavigationBar: const AppBottomNav(currentPath: '/record'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _tickerController,
            decoration: const InputDecoration(
              labelText: 'Ticker',
              suffixIcon: Padding(padding: EdgeInsets.all(8), child: HelpChip(topicId: 'ticker')),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: controller.setTicker,
          ),
          if (form.recentTickers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final ticker in form.recentTickers)
                    ActionChip(
                      label: Text(ticker),
                      onPressed: () => controller.selectRecentTicker(ticker),
                    ),
                ],
              ),
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
          if (form.side == OptionType.call) _CallHostLine(host: ref.watch(callHostProvider)),
          const SizedBox(height: 12),
          LabeledNumberField(
            label: 'Strike (\$)',
            helpTopicId: 'strike',
            onChangedDecimal: controller.setStrike,
          ),
          _ExpirationSection(
            expiration: form.expiration,
            dte: form.dte,
            fridayOptions: form.fridayOptions,
            nonFridayWarning: form.nonFridayWarning,
            onPick: controller.setExpiration,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledNumberField(
                  label: totalPerContract
                      ? 'Credit (\$ total for contract)'
                      : 'Credit (\$ per share)',
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
                  const Text(
                    'Total per\ncontract',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          if (controller.creditBound != null &&
              controller.creditBound!.level != CreditBoundLevel.ok)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                controller.creditBound!.message!,
                style: TextStyle(
                  color: controller.creditBound!.blocks ? scheme.error : scheme.tertiary,
                ),
              ),
            ),
          LabeledNumberField(
            label: 'Contracts',
            helpTopicId: 'contracts',
            initialText: '1',
            signed: false,
            onChangedInt: (v) => controller.setContracts(v ?? 1),
          ),
          TextButton(
            onPressed: () => controller.setShowOptional(!form.showOptional),
            child: Text(
              form.showOptional ? 'Hide optional fields' : 'Add optional fields',
            ),
          ),
          if (form.showOptional) ...[
            LabeledNumberField(
              label: 'Stock price (\$)',
              helpTopicId: 'stock_price',
              onChangedDecimal: controller.setSpot,
            ),
            LabeledNumberField(
              label: 'IV (%)',
              helpTopicId: 'iv',
              onChangedDouble: controller.setIv,
            ),
            LabeledNumberField(
              label: 'IV rank',
              helpTopicId: 'iv_rank',
              onChangedDouble: controller.setIvRank,
            ),
            LabeledNumberField(
              label: 'Open fee (\$, optional)',
              onChangedDecimal: controller.setOpenFee,
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Happy to be assigned on this one?'),
            value: form.acceptsAssignment,
            onChanged: controller.setAcceptsAssignment,
          ),
          const SizedBox(height: 8),
          _PreviewCard(
            annualisedYield: controller.annualisedYield,
            capitalCommitted: controller.capitalCommitted,
            dte: form.dte,
          ),
          const SizedBox(height: 8),
          Text(controller.reminderLine, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/screener'),
              child: const Text('Run the numbers first in the screener'),
            ),
          ),
          if (form.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(form.error!, style: TextStyle(color: scheme.error)),
            ),
          FilledButton(
            onPressed: form.isSaving ? null : _record,
            child: form.isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Record trade'),
          ),
        ],
      ),
    );
  }
}

/// D-12's one line, shown *before* the save: the explanation naming the host
/// cycle, its shares and its wheel-adjusted basis (S-233), or the refusal
/// reason (S-234/S-235). Never a bare verdict — the line always says why.
class _CallHostLine extends StatelessWidget {
  const _CallHostLine({required this.host});

  final AsyncValue<CallHostResolution?> host;

  @override
  Widget build(BuildContext context) {
    final resolution = host.valueOrNull;
    if (resolution == null) return const SizedBox.shrink();
    final refused = resolution.isRefused;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        refused ? resolution.refusalReason! : resolution.explanation!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: refused ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    );
  }
}

/// D-16's expiration control: the next four Fridays as chips plus "Other
/// date…", the derived DTE, and Feature Invariant 22's non-Friday warning
/// (which never blocks).
class _ExpirationSection extends StatelessWidget {
  const _ExpirationSection({
    required this.expiration,
    required this.dte,
    required this.fridayOptions,
    required this.nonFridayWarning,
    required this.onPick,
  });

  final DateTime? expiration;
  final int? dte;
  final List<DateTime> fridayOptions;
  final bool nonFridayWarning;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final selected = expiration;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Expiration: ${selected == null ? '--' : dateText(selected)}'),
              ),
              const HelpChip(topicId: 'expiration'),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final date in fridayOptions)
                ChoiceChip(
                  label: Text(_chipLabel(date)),
                  selected: selected != null && _sameDay(selected, date),
                  onSelected: (_) => onPick(date),
                ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected ?? now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (picked != null) onPick(picked);
                },
                child: const Text('Other date…'),
              ),
              const SizedBox(width: 8),
              Text(dte == null ? 'DTE: --' : 'DTE: $dte days'),
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

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _chipLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

/// The two figures D-16 shows before saving, each with the definition it
/// came from so the number is never a bare verdict (D-15's whole-dollar
/// rounding, Feature Invariant 6's semantics labels).
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.annualisedYield,
    required this.capitalCommitted,
    required this.dte,
  });

  final double? annualisedYield;
  final Decimal? capitalCommitted;
  final int? dte;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Before you save', style: textTheme.titleMedium),
                const HelpChip(topicId: 'annualised_yield'),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Annualised yield ${annualisedYield == null ? 'not available' : '${annualisedYield!.round()} percent'}',
              child: _PreviewRow(
                label: 'Annualised yield',
                value: annualisedYield == null ? '--' : '${annualisedYield!.round()}%',
                definition: 'credit ÷ strike × 365 ÷ DTE',
              ),
            ),
            Semantics(
              label:
                  'Capital committed ${capitalCommitted == null ? 'not available' : '${wholeDollars(capitalCommitted!)} dollars'}',
              child: _PreviewRow(
                label: 'Capital committed',
                value: capitalCommitted == null ? '--' : wholeDollars(capitalCommitted!),
                definition: 'strike × 100 × contracts',
              ),
            ),
            if (dte == null)
              Text(
                'Expiration and strike are needed before either figure can be worked out.',
                style: textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value, required this.definition});

  final String label;
  final String value;
  final String definition;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(
                  definition,
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
