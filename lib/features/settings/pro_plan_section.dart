import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/paywall_copy.dart';
import '../../core/purchases/pro_plans.dart';
import '../../state/entitlements/entitlement_providers.dart';
import '../paywall/paywall_route.dart';

/// The Settings plan section (D-34): what the user is on, and the three ways
/// out of it — the paywall, the store's subscription screen, and a restore.
///
/// It reads the entitlement and renders it. It evaluates nothing: the free
/// tier's count is a display of `getOpenCycles().length`, and the only thing
/// that ever acts on that number is `NewCycleGate.evaluate()` (D-28), which
/// this widget does not call and must not.
class ProPlanSection extends ConsumerStatefulWidget {
  const ProPlanSection({super.key});

  @override
  ConsumerState<ProPlanSection> createState() => _ProPlanSectionState();
}

class _ProPlanSectionState extends ConsumerState<ProPlanSection> {
  String? _message;

  Future<void> _restore() async {
    final outcome = await ref.read(entitlementControllerProvider.notifier).restore();
    if (!mounted) return;
    setState(() => _message = restoreOutcomeLine(outcome));
  }

  Future<void> _manageSubscription() async {
    await ref.read(entitlementControllerProvider.notifier).manageSubscription();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entitlement = ref.watch(entitlementControllerProvider);
    final openCycles = ref.watch(openCycleCountProvider).valueOrNull;
    final rows = proPlanRowsFor(entitlement.status, entitlement.planKind);

    final header = proPlanHeaderLine(
      status: entitlement.status,
      kind: entitlement.planKind,
      openCycleCount: openCycles,
      limit: kFreeTierOpenCycles,
    );
    final detail = proPlanDetailLine(
      status: entitlement.status,
      kind: entitlement.planKind,
      expiresAt: entitlement.expiresAt,
      willRenew: entitlement.willRenew,
      purchasedAt: entitlement.purchasedAt,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(kPaywallTitle, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          header,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail, style: textTheme.bodySmall),
        ],
        // Display only, and never a downgrade: a subscription in billing retry
        // is still Pro (D-26).
        if (entitlement.isActive && entitlement.billingIssue) ...[
          const SizedBox(height: 4),
          Text(kBillingIssueLine, style: textTheme.bodySmall),
        ],
        const SizedBox(height: 4),
        if (rows.seePlans)
          TextButton(
            onPressed: () => showPaywall(
              context,
              trigger: const SettingsPaywallTrigger(),
            ),
            child: const Text(kSeeProPlansLabel),
          ),
        if (rows.manageSubscription)
          TextButton(
            onPressed: _manageSubscription,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(kManageSubscriptionLabel),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        if (rows.restore)
          TextButton(
            onPressed: _restore,
            child: const Text(kRestorePurchasesLabel),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_message!, key: const ValueKey('pro-plan-message')),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
