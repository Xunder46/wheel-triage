import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/purchases/paywall_copy.dart';

/// What opened the paywall (D-30). Sealed, and every variant carries the line
/// it puts above the plans, so the paywall never re-derives why it is open and
/// the three entry points cannot disagree about the wording.
///
/// The paywall is opened from exactly three places and never on launch
/// (S-277): a refused fourth cycle, a Pro feature, and the Settings row.
sealed class PaywallTrigger {
  const PaywallTrigger();

  /// The sentence the paywall shows above the plans, verbatim.
  String get line;
}

/// D-24's refusal: a fourth new cycle was blocked. [line] is the finished
/// sentence the save result already carried, so the number in it is the number
/// the gate saw.
final class NewCyclePaywallTrigger extends PaywallTrigger {
  const NewCyclePaywallTrigger(this.line);

  @override
  final String line;

  @override
  bool operator ==(Object other) => other is NewCyclePaywallTrigger && other.line == line;

  @override
  int get hashCode => line.hashCode;
}

/// D-30's second entry point: a Pro feature was reached on the free tier.
/// Defined and tested this wave with no caller until Wave 3, which is why
/// [feature] is a parameter rather than a constant.
final class ProFeaturePaywallTrigger extends PaywallTrigger {
  const ProFeaturePaywallTrigger(this.feature);

  final String feature;

  @override
  String get line => proFeatureLine(feature);

  @override
  bool operator ==(Object other) => other is ProFeaturePaywallTrigger && other.feature == feature;

  @override
  int get hashCode => feature.hashCode;
}

/// D-30's third entry point: the Settings row. Also the fallback for a
/// `/paywall` route reached with no trigger at all (a deep link), so an
/// unexpected entry shows the generic explanation instead of throwing.
final class SettingsPaywallTrigger extends PaywallTrigger {
  const SettingsPaywallTrigger();

  @override
  String get line => kPaywallSettingsLine;

  @override
  bool operator ==(Object other) => other is SettingsPaywallTrigger;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The **only** place in `lib/` that pushes `/paywall` (D-30), which a
/// structural test asserts. One function rather than a route string at each
/// call site, so a screen cannot open the paywall with the wrong trigger type
/// or forget to pass one.
void showPaywall(BuildContext context, {required PaywallTrigger trigger}) =>
    context.push('/paywall', extra: trigger);

/// The trigger a `/paywall` route should use, given whatever `extra` it was
/// handed. Anything that is not a [PaywallTrigger] — `null` from a deep link,
/// or a value a future caller passed by mistake — falls back to the Settings
/// trigger rather than throwing inside a route builder.
PaywallTrigger paywallTriggerFrom(Object? extra) =>
    extra is PaywallTrigger ? extra : const SettingsPaywallTrigger();
