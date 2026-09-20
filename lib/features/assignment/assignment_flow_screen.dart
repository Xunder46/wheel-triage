import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dates/nearest_friday.dart';
import '../../state/assignment/assignment_flow_controller.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../widgets/help_chip.dart';

/// The exact §3.6 disclaimer, shown verbatim wherever tax basis appears —
/// never paraphrased (`docs/conventions.md` §4).
const String kTaxBasisDisclaimer =
    'Tax treatment of options is genuinely complicated and varies by '
    "jurisdiction and account type. These figures are for your own tracking. "
    "Check them against your broker's 1099 and talk to a tax professional "
    'before filing.';

/// §5.4's assignment flow. A **put** leg walks the four steps (confirm
/// shares/strike, see both basis figures, cycle transitions, offered a
/// covered call). A **call** leg is "called away" (S-029) — the cycle
/// closes instead. Both are reached through the same "Mark assigned" action,
/// dispatched on the leg's `optionType` (Feature Invariant 14).
class AssignmentFlowScreen extends ConsumerWidget {
  const AssignmentFlowScreen({super.key, required this.legId});

  final String legId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assignmentFlowControllerProvider(legId));
    final controller = ref.read(assignmentFlowControllerProvider(legId).notifier);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final leg = state.leg;
    if (leg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mark assigned')),
        body: Center(child: Text(state.error ?? 'This position no longer exists.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mark assigned')),
      body: state.isPutSide
          ? _PutAssignmentFlow(state: state, controller: controller)
          : _CallAwayFlow(state: state, controller: controller),
    );
  }
}

class _CallAwayFlow extends StatefulWidget {
  const _CallAwayFlow({required this.state, required this.controller});

  final AssignmentFlowState state;
  final AssignmentFlowController controller;

  @override
  State<_CallAwayFlow> createState() => _CallAwayFlowState();
}

class _CallAwayFlowState extends State<_CallAwayFlow> {
  final _feeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.completed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('This covered call was assigned. Shares were called away and the cycle is closed.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go('/positions'), child: const Text('Back to positions')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Mark \$${state.leg!.strike} ${state.leg!.optionType.name} assigned?'),
          const SizedBox(height: 8),
          const Text('Shares will be sold at the strike and this cycle will close.'),
          const SizedBox(height: 12),
          TextField(
            controller: _feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Close fee (\$, optional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isSubmitting
                ? null
                : () => widget.controller.confirmCallAway(
                    closeFee: Decimal.tryParse(_feeController.text.trim()),
                  ),
            child: const Text('Confirm call-away'),
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

class _PutAssignmentFlow extends StatefulWidget {
  const _PutAssignmentFlow({required this.state, required this.controller});

  final AssignmentFlowState state;
  final AssignmentFlowController controller;

  @override
  State<_PutAssignmentFlow> createState() => _PutAssignmentFlowState();
}

class _PutAssignmentFlowState extends State<_PutAssignmentFlow> {
  late final TextEditingController _strikeController = TextEditingController(
    text: widget.state.leg!.strike.toString(),
  );
  late final TextEditingController _contractsController = TextEditingController(
    text: widget.state.leg!.contracts.toString(),
  );
  final TextEditingController _feeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (!state.completed) {
      // Step 1: confirm shares acquired (100 x contracts) and strike.
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Assignment strike (\$)'),
          TextField(
            controller: _strikeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          const Text('Contracts assigned'),
          TextField(controller: _contractsController, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(
            controller: _feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Close fee, on the put (\$, optional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isSubmitting
                ? null
                : () {
                    final strike = Decimal.tryParse(_strikeController.text.trim());
                    final contracts = int.tryParse(_contractsController.text.trim());
                    if (strike == null || contracts == null) return;
                    widget.controller.confirmPutAssignment(
                      assignmentStrike: strike,
                      contracts: contracts,
                      closeFee: Decimal.tryParse(_feeController.text.trim()),
                    );
                  },
            child: const Text('Confirm assignment'),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      );
    }

    // Step 2/3: ShareLot created, cycle transitioned, both basis numbers
    // shown and labeled distinctly.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('${state.createdShareLot?.contracts != null ? state.createdShareLot!.contracts * 100 : 0} '
            'shares acquired at \$${state.createdShareLot?.assignmentStrike}.'),
        const SizedBox(height: 8),
        const Text('This cycle is now holding shares.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Wheel-adjusted basis: \$${state.wheelBasisValue}'),
                    const HelpChip(topicId: 'wheel_basis'),
                  ],
                ),
                const Text('The management number -- use this for the covered-call strike floor.'),
                const SizedBox(height: 8),
                Text('Tax basis: \$${state.taxBasisValue}'),
                const Text('The reporting number.'),
                const SizedBox(height: 12),
                Text(
                  kTaxBasisDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!state.coveredCallOpened) ...[
          Text(
            'Open a covered call? Selling below \$${state.wheelBasisValue} locks in a loss on '
            'assignment -- this is advisory, you can still type a lower strike.',
          ),
          const SizedBox(height: 12),
          _CoveredCallForm(state: state, controller: widget.controller),
        ] else
          const Text('Covered call opened.'),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go('/positions'),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _CoveredCallForm extends ConsumerStatefulWidget {
  const _CoveredCallForm({required this.state, required this.controller});

  final AssignmentFlowState state;
  final AssignmentFlowController controller;

  @override
  ConsumerState<_CoveredCallForm> createState() => _CoveredCallFormState();
}

class _CoveredCallFormState extends ConsumerState<_CoveredCallForm> {
  late final TextEditingController _strikeController = TextEditingController(
    text: widget.state.wheelBasisValue?.toString() ?? '',
  );
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _dteController = TextEditingController();
  final TextEditingController _contractsController = TextEditingController(text: '1');
  final TextEditingController _feeController = TextEditingController();

  // S-125: asked fresh for this new leg -- NEVER inherited from the put
  // leg's own `acceptsAssignment` value (contrast with a roll's leg, which
  // does inherit, S-102).
  bool _acceptsAssignment = true;

  // Feature Invariant 22 (brief-followup A5, found independently while
  // grounding the plan at `assignment_flow_screen.dart:254`): expiration is
  // a date picker, never `DateTime.now().add(Duration(days: dte))` -- the
  // identical defect the screener had.
  late DateTime _expiration = defaultExpiration(DateTime.now());
  String? _localError;

  @override
  Widget build(BuildContext context) {
    final totalPerContract =
        ref.watch(preferencesControllerProvider).valueOrNull?.totalPerContractToggle ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _strikeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Call strike (\$)'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _creditController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: totalPerContract ? 'Credit (\$ total for contract)' : 'Credit (\$ per share)',
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: totalPerContract,
                  onChanged: (v) => ref
                      .read(preferencesControllerProvider.notifier)
                      .update((p) => p.copyWith(totalPerContractToggle: v)),
                ),
                const Text('Total/contract', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('Expiration: ${_dateText(_expiration)}')),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expiration,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _expiration = picked);
              },
              child: const Text('Change'),
            ),
          ],
        ),
        if (!isFriday(_expiration))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Not a Friday -- index and month-end products legitimately differ.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
        TextField(
          controller: _dteController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'DTE (days) -- moves the expiration above'),
          onChanged: (text) {
            final days = int.tryParse(text.trim());
            if (days == null) return;
            setState(() => _expiration = DateTime.now().add(Duration(days: days)));
          },
        ),
        TextField(
          controller: _contractsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Contracts'),
        ),
        TextField(
          controller: _feeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Open fee (\$, optional)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Happy to sell these at that strike?'),
          value: _acceptsAssignment,
          onChanged: (v) => setState(() => _acceptsAssignment = v),
        ),
        if (widget.state.coveredCallWarning != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.state.coveredCallWarning!,
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
        if (_localError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_localError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final strike = Decimal.tryParse(_strikeController.text.trim());
            final credit = Decimal.tryParse(_creditController.text.trim());
            final contracts = int.tryParse(_contractsController.text.trim());
            if (strike == null || credit == null || contracts == null) return;
            final ok = await widget.controller.openCoveredCall(
              strike: strike,
              expiration: _expiration,
              openCreditPerShare: credit,
              contracts: contracts,
              openFee: Decimal.tryParse(_feeController.text.trim()),
              acceptsAssignment: _acceptsAssignment,
            );
            if (!ok) {
              // Read via the provider, not the protected `.state` getter --
              // state is already updated synchronously by `openCoveredCall`
              // before it returns.
              setState(
                () => _localError =
                    ref.read(assignmentFlowControllerProvider(widget.state.leg!.id)).error,
              );
            }
          },
          child: const Text('Open covered call'),
        ),
      ],
    );
  }
}

String _dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
