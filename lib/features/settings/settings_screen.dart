import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification_scheduler.dart';
import '../../data/export/ledger_export.dart';
import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/snapshot.dart';
import '../../state/export/export_controller.dart';
import '../../state/journal/journal_controller.dart';
import '../../state/notifications/notification_providers.dart';
import '../../state/positions/positions_list_controller.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../state/rule_profiles/rule_profile_editor_controller.dart';
import '../../state/rule_profiles/rule_profile_providers.dart';

import 'rule_profile_section.dart';

/// The Settings screen: the delta-convention default, the "total per
/// contract" toggle, the Active-profile section (the `Standard` profile's
/// 14 thresholds as an editable, versioned form -- Iteration 5, S-199), a
/// way to re-open the first-run explainer (Phase 11), the export/import
/// actions and 30-day-reminder plumbing (Phase 20, `docs/brief-ledger.md`
/// §5), and the expiration-notification milestone editor (Phase 21, §6).
/// There is exactly one editable profile and no picker: Iteration 5's D-1
/// drops multiple named profiles, so this screen never offers a choice of
/// profile.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _importError;

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final files = await ref.read(exportControllerProvider).buildExportFiles();
      await ref.read(shareSheetProvider).shareFiles(files, subject: 'Wheel Triage export');
      await ref.read(exportControllerProvider).recordExportSucceeded();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    final file = await ref.read(importFilePickerProvider).pickJsonFile();
    if (file == null) return; // user cancelled the file picker itself

    setState(() {
      _isImporting = true;
      _importError = null;
    });
    try {
      final contents = await file.readAsString();
      final destroyedCount = await ref.read(exportControllerProvider).countCyclesForReplace();
      if (!mounted) return;
      final confirmed = await _confirmReplace(destroyedCount);
      if (confirmed != true) return; // S-162 outcome A: cancel is a no-op

      await ref.read(exportControllerProvider).restoreFromJson(contents);
      // A successful restore replaced every row -- every other screen's
      // already-loaded data must reflect it next time it's shown. The
      // profile rows are replaced too, so the editor's draft and baseline
      // are stale by definition, and so are the two non-autoDispose version
      // caches: without them the section would keep rendering the pre-import
      // history and a new leg would pin a version the imported database may
      // not contain.
      ref.invalidate(preferencesControllerProvider);
      ref.invalidate(positionsListControllerProvider);
      ref.invalidate(journalControllerProvider);
      ref.invalidate(ruleProfileEditorProvider);
      ref.invalidate(ruleProfileVersionsProvider(RuleProfileIds.standard));
      ref.invalidate(currentRuleProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Import complete.')));
      }
    } on LedgerImportFormatException catch (e) {
      // S-163: surface the error without touching any other on-screen
      // state -- nothing above this catch block mutated any provider.
      setState(() => _importError = e.message);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool?> _confirmReplace(int destroyedCount) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Replace everything?'),
      content: Text(
        '$destroyedCount ${destroyedCount == 1 ? 'cycle' : 'cycles'} will be '
        'replaced with the imported file. This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Replace')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesControllerProvider).valueOrNull;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Defaults for new entries', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Delta convention',
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SegmentedButton<DeltaConvention>(
                  segments: const [
                    ButtonSegment(value: DeltaConvention.position, label: Text('Position')),
                    ButtonSegment(value: DeltaConvention.option, label: Text('Option')),
                  ],
                  selected: {prefs.deltaConventionDefault},
                  onSelectionChanged: (selection) => ref
                      .read(preferencesControllerProvider.notifier)
                      .update((p) => p.copyWith(deltaConventionDefault: selection.first)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    // Feature Invariant 5: only pre-fills the next entry's
                    // form -- never rewrites a stored Snapshot.
                    'Pre-fills the convention on your next snapshot entry. Snapshots you '
                    'already saved keep whatever convention they were entered under.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Total per contract'),
                  subtitle: const Text(
                    'When on, credit/mark/debit fields expect the total for one '
                    'contract (100 shares) instead of a per-share price.',
                  ),
                  value: prefs.totalPerContractToggle,
                  onChanged: (v) => ref
                      .read(preferencesControllerProvider.notifier)
                      .update((p) => p.copyWith(totalPerContractToggle: v)),
                ),
                const Divider(height: 32),
                const RuleProfileSection(),
                const Divider(height: 32),
                Text('Export and backup', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Full JSON of every cycle, leg, snapshot, and fee, plus a CSV of '
                  'closed cycles for a spreadsheet. This is the only backup this app '
                  'has -- a lost phone is a lost ledger.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isExporting ? null : _handleExport,
                      icon: const Icon(Icons.ios_share),
                      label: Text(_isExporting ? 'Exporting…' : 'Export'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isImporting ? null : _handleImport,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(_isImporting ? 'Importing…' : 'Import'),
                    ),
                  ],
                ),
                if (_importError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _importError!,
                    style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const Divider(height: 32),
                Text('Expiration reminders', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Choose which days-to-expiration mark a reminder for a position -- '
                  'a change here only applies to positions you track after making it; '
                  'already-tracked positions keep whatever schedule they were opened '
                  'under.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final status = ref.watch(notificationPermissionStatusProvider).valueOrNull;
                    if (status != NotificationPermissionStatus.denied) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Notifications are turned off for this app in iOS Settings -- '
                        "reminders below won't fire until you turn them back on.",
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  },
                ),
                _MilestonesEditor(milestones: prefs.notificationMilestones),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.push('/first-run'),
                  icon: const Icon(Icons.replay),
                  label: const Text('How this app works'),
                ),
              ],
            ),
    );
  }
}

/// The checkbox list for `user_preferences.notificationMilestones`
/// (Feature Invariant 31, S-175): every option comes from the same fixed
/// [kSupportedNotificationMilestones] universe `NotificationScheduler` uses
/// to cancel without a lookup table, so nothing the user can select here
/// ever falls outside what cancellation already covers.
class _MilestonesEditor extends ConsumerWidget {
  const _MilestonesEditor({required this.milestones});

  final List<int> milestones;

  String _labelFor(int dte) =>
      dte == kExpirationMorningMilestone ? 'The morning it expires' : '$dte days before expiration';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final dte in kSupportedNotificationMilestones)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(_labelFor(dte)),
            value: milestones.contains(dte),
            onChanged: (checked) {
              final next = {...milestones};
              if (checked ?? false) {
                next.add(dte);
              } else {
                next.remove(dte);
              }
              final sorted = next.toList()..sort((a, b) => b.compareTo(a));
              ref
                  .read(preferencesControllerProvider.notifier)
                  .update((p) => p.copyWith(notificationMilestones: sorted));
            },
          ),
      ],
    );
  }
}
