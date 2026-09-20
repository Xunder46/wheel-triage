import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates/nearest_friday.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../state/roll/roll_planner_controller.dart';

/// §5.3's roll planner: enter two or three candidate replacements for the
/// open leg and compare them side by side. `netCredit <= 0` is always
/// labeled a debit roll, never shown as income (S-025) — the roll itself is
/// never blocked, only clearly labeled.
class RollPlannerScreen extends ConsumerWidget {
  const RollPlannerScreen({super.key, required this.legId});

  final String legId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rollPlannerControllerProvider(legId));
    final controller = ref.read(rollPlannerControllerProvider(legId).notifier);

    ref.listen(rollPlannerControllerProvider(legId), (previous, next) {
      if (next.rolled && context.mounted) {
        // Pop the planner and the detail sheet -- the roll is done, and the
        // detail screen's `positionDetailControllerProvider` is autoDispose,
        // so returning to the list and back in shows the new leg fresh.
        context.pop();
        context.pop();
      }
    });

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final leg = state.leg;
    if (leg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Roll')),
        body: Center(child: Text(state.error ?? 'This position no longer exists.')),
      );
    }

    final results = controller.results();

    return Scaffold(
      appBar: AppBar(title: const Text('Roll planner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Current leg: \$${leg.strike} ${leg.optionType.name}, exp ${_dateText(leg.expiration)}'),
          const SizedBox(height: 16),
          for (final result in results) _CandidateCard(result: result, controller: controller),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.candidates.length >= 3
                ? null
                : () => _showAddCandidateDialog(context, ref, legId, controller, leg.expiration, leg.strike),
            icon: const Icon(Icons.add),
            label: const Text('Add candidate'),
          ),
          if (state.candidateWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                state.candidateWarning!,
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.result, required this.controller});

  final RollCandidateResult result;
  final RollPlannerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strikeDirection = result.strikeDelta > Decimal.zero
        ? 'up'
        : (result.strikeDelta < Decimal.zero ? 'down' : 'unchanged');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New strike \$${result.candidate.newStrike} · exp ${_dateText(result.candidate.newExpiry)}'),
            const SizedBox(height: 4),
            Text('Strike moves $strikeDirection by \$${result.strikeDelta.abs()}'),
            Text('Annualised yield on extended duration: ${result.annualisedYield.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  result.isDebit ? 'Debit roll: \$${result.netCredit.abs()}' : 'Net credit: \$${result.netCredit}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: result.isDebit ? scheme.error : scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _confirmRollWithFees(context, controller, result.candidate),
              child: const Text('Confirm this roll'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAddCandidateDialog(
  BuildContext context,
  WidgetRef ref,
  String legId,
  RollPlannerController controller,
  DateTime currentExpiry,
  Decimal currentStrike,
) async {
  final strikeController = TextEditingController(text: currentStrike.toString());
  final debitController = TextEditingController();
  final creditController = TextEditingController();
  var newExpiry = currentExpiry.add(const Duration(days: 14));
  String? dialogError;
  // `ref.watch` is only valid inside a ConsumerWidget's own `build` method --
  // this dialog builder runs later, outside that scope -- so the toggle's
  // starting value is read once here and kept in sync locally via
  // `setDialogState`, with every change also persisted through the shared
  // preferences provider (Feature Invariant 21), same pattern as the
  // snapshot sheet's toggle.
  var totalPerContract =
      ref.read(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final nonFriday = !isFriday(newExpiry);
          return AlertDialog(
            title: const Text('New candidate'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: strikeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'New strike (\$)'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: debitController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: totalPerContract
                              ? 'Buyback debit (\$ total for contract)'
                              : 'Buyback debit (\$ per share)',
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: totalPerContract,
                          onChanged: (v) {
                            setDialogState(() => totalPerContract = v);
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
                  controller: creditController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: totalPerContract
                        ? 'New credit (\$ total for contract)'
                        : 'New credit (\$ per share)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('New expiry: ${_dateText(newExpiry)}'),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: newExpiry,
                          firstDate: currentExpiry,
                          lastDate: currentExpiry.add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => newExpiry = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                // Feature Invariant 22: the planner's existing picker already
                // worked -- only this warning is new, and it never blocks.
                if (nonFriday)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Not a Friday -- index and month-end products legitimately differ.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                if (dialogError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dialogError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final strike = Decimal.tryParse(strikeController.text.trim());
                  final debit = Decimal.tryParse(debitController.text.trim());
                  final credit = Decimal.tryParse(creditController.text.trim());
                  if (strike == null || debit == null || credit == null) return;
                  final added = controller.addCandidate(
                    RollCandidate(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      newExpiry: newExpiry,
                      newStrike: strike,
                      buybackDebit: debit,
                      newCredit: credit,
                    ),
                  );
                  if (added) {
                    Navigator.of(context).pop();
                  } else {
                    // Hard reject (Feature Invariant 20) -- keep the dialog
                    // open and surface the exact message from the controller
                    // (read via the provider, not the protected `.state`
                    // getter -- state is already updated synchronously by
                    // `addCandidate` before it returns).
                    setDialogState(
                      () => dialogError = ref.read(rollPlannerControllerProvider(legId)).error,
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// S-120 item 2: the roll confirmation's two fee fields (`closeFee` on the
/// closing leg, `openFee` on the new leg), one action -- both optional,
/// blank persists `null` never `0`.
Future<void> _confirmRollWithFees(
  BuildContext context,
  RollPlannerController controller,
  RollCandidate candidate,
) async {
  final closeFeeController = TextEditingController();
  final openFeeController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm this roll'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: closeFeeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Close fee, closing leg (\$, optional)'),
          ),
          TextField(
            controller: openFeeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Open fee, new leg (\$, optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.confirmRoll(
      candidate,
      closeFee: Decimal.tryParse(closeFeeController.text.trim()),
      openFee: Decimal.tryParse(openFeeController.text.trim()),
    );
  }
}

String _dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
