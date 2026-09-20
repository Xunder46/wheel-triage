import 'package:flutter/material.dart';

/// The 30-day export reminder (`docs/brief-ledger.md` §5, S-160): pure
/// presentation only, matching this project's reusable-component rules
/// (data in via [visible], the event out via [onDismiss]) even though it
/// lives under `lib/features/export/` rather than `lib/widgets/` -- it is
/// specific enough to this one feature that it is grouped with the rest of
/// Phase 20's export/import surface instead of the generic shared-widgets
/// folder.
///
/// [visible]/[onDismiss] are entirely computed and owned by the caller
/// (`PositionsListScreen`, watching `preferencesControllerProvider` and its
/// own loaded position list) -- this widget itself never reads a provider
/// and never decides *when* it should show, only *how*.
class ExportReminderBanner extends StatelessWidget {
  const ExportReminderBanner({super.key, required this.visible, required this.onDismiss});

  final bool visible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return MaterialBanner(
      content: const Text(
        "It's been 30 days since your last export. Back up your ledger in "
        'case this phone is ever lost or replaced.',
      ),
      actions: [
        TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
      ],
    );
  }
}
