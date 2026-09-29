import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/purchases/paywall_copy.dart';
import '../../core/purchases/pro_plans.dart';
import '../../state/entitlements/entitlement_controller.dart';
import '../../state/entitlements/entitlement_providers.dart';
import '../../state/paywall/paywall_controller.dart';

import 'paywall_route.dart';

/// The Pro paywall (Pro Wave 2, D-30/D-31/D-32/D-33/D-37).
///
/// It is a *renderer*: it reads `paywallControllerProvider` for the store's
/// plans and `entitlementControllerProvider` for what the user owns, and it
/// decides nothing itself. It never imports the purchase gateway or the store
/// SDK (Feature Invariant 10), so "is this user Pro?" cannot be answered here
/// — only shown.
///
/// Every string comes from `paywall_copy.dart`, and every colour from the
/// active theme, so the tone grep and the theme both stay honest.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, required this.trigger});

  /// Why the paywall is open. Its [PaywallTrigger.line] is shown verbatim
  /// above the plans (S-276).
  final PaywallTrigger trigger;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    // Post-frame: a provider write during `initState` would rebuild the tree
    // mid-build. This runs once per screen rather than per rebuild, so the
    // store is asked for its plans once, and the retry action is what asks
    // again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(paywallControllerProvider.notifier).load();
    });
  }

  /// Both dismissals — the close icon and "Not now" — are the same gesture: pop
  /// the route and change nothing (S-284c). No purchase is attempted and no
  /// state is written, which is what makes the paywall dismissable rather than
  /// a wall.
  void _dismiss() {
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final state = ref.watch(paywallControllerProvider);
    final entitlement = ref.watch(entitlementControllerProvider);
    final visible = state.visibleRows(entitlement);
    final selected = state.selectedRowIn(visible);
    final controller = ref.read(paywallControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('paywall-close'),
          tooltip: kPaywallCloseLabel,
          icon: const Icon(Icons.close),
          onPressed: _dismiss,
        ),
        actions: [
          TextButton(
            key: const ValueKey('paywall-not-now'),
            onPressed: _dismiss,
            child: const Text(kNotNowLabel),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            kPaywallTitle,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            widget.trigger.line,
            key: const ValueKey('paywall-trigger-line'),
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          for (final feature in kPaywallFeatures) _featureRow(context, feature),
          const SizedBox(height: 12),
          _privacyLine(context),
          const SizedBox(height: 20),
          if (entitlement.isActive) ...[
            _ownedLine(context, entitlement),
            const SizedBox(height: 16),
          ],
          if (!state.offersLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.offersUnavailable)
            _unavailable(context, controller)
          else if (visible.isNotEmpty) ...[
            for (final row in visible)
              _planRow(
                context,
                row,
                selected: row.productId == state.selectedProductId,
                onTap: () => controller.select(row.productId),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('paywall-purchase-button'),
              onPressed: state.isBusy || selected == null ? null : controller.purchase,
              child: Text(selected == null ? kContinueLabel : selected.buttonLabel),
            ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              // The fine print repeats the price and states the store's own
              // renewal terms; one label so a screen reader reads it as the
              // single paragraph App Review expects it to be.
              Semantics(
                label: selected.finePrint,
                child: Text(
                  selected.finePrint,
                  key: const ValueKey('paywall-fine-print'),
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ],
          if (state.message != null) ...[
            const SizedBox(height: 16),
            Text(
              state.message!,
              key: const ValueKey('paywall-message'),
              style: textTheme.bodyMedium,
            ),
          ],
          if (state.showManageSubscription) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('paywall-manage-subscription'),
              onPressed: state.isBusy ? null : controller.manageSubscription,
              child: const Text(kManageSubscriptionLabel),
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('paywall-restore'),
              onPressed: state.isBusy ? null : controller.restore,
              child: const Text(kRestorePurchasesLabel),
            ),
          ),
          const SizedBox(height: 8),
          _policyText(context, label: kTermsOfUseLabel, url: kTermsOfUseUrl),
          // D-37: while the owner has not supplied a hosted policy, the entry
          // is hidden rather than shown as a link that goes nowhere.
          if (kPrivacyPolicyUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            _policyText(context, label: kPrivacyPolicyLabel, url: kPrivacyPolicyUrl),
          ],
        ],
      ),
    );
  }

  /// One launch feature (OC-9): the bolded phrase, then the plain clause.
  Widget _featureRow(BuildContext context, ({String lead, String? detail}) feature) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: feature.lead,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (feature.detail != null) TextSpan(text: ' · ${feature.detail}'),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// D-P3's privacy promise, in the plain words the store label is written
  /// from (`docs/privacy.md`).
  Widget _privacyLine(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            kPaywallPrivacyLine,
            key: const ValueKey('paywall-privacy-line'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// D-33's owned state. Rendered whenever Pro is on; whether a purchase
  /// button accompanies it depends on which plans are still visible — none for
  /// lifetime, the lifetime upgrade alone for a subscriber.
  Widget _ownedLine(BuildContext context, EntitlementState entitlement) {
    final theme = Theme.of(context);
    final kind = entitlement.planKind;
    final purchasedAt = entitlement.purchasedAt;
    final line = paywallOwnedLine(kind, purchasedAt);
    return Semantics(
      label: purchasedAt == null
          ? 'Pro plan, ${planKindLabel(kind)}'
          : 'Pro plan, ${planKindLabel(kind)}, purchased ${renewalDateText(purchasedAt)}',
      child: Container(
        key: const ValueKey('paywall-owned'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(line, style: theme.textTheme.bodyMedium),
      ),
    );
  }

  /// S-280: the store answered, and the answer was no plans. An honest
  /// unavailable state — no row, no price and no purchase button — with the
  /// one action that can change it.
  Widget _unavailable(BuildContext context, PaywallController controller) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kPaywallOffersUnavailableLine,
          key: const ValueKey('paywall-unavailable'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('paywall-retry'),
          onPressed: controller.load,
          child: const Text(kPaywallRetryLabel),
        ),
      ],
    );
  }

  /// One plan row (D-31). The price, the period and the trial all come from
  /// the store's own offer; only the kind label is the app's. The semantics
  /// label names the quantity — the plan and its price — rather than letting
  /// the row read as three loose numbers.
  Widget _planRow(
    BuildContext context,
    PaywallPlanRow row, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${row.title}, ${row.subtitle}',
      child: InkWell(
        key: ValueKey('paywall-plan-${row.productId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surface,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      row.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// D-37: the policy entries render as selectable text, not as tappable
  /// links, because opening a URL would need a launcher dependency this wave
  /// deliberately does not add.
  Widget _policyText(BuildContext context, {required String label, required String url}) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $url',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SelectableText(
            url,
            key: ValueKey('paywall-policy-$label'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
