import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/disclaimer.dart';
import '../../core/notifications/notification_scheduler.dart';
import '../../data/export/ledger_export.dart';
import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/snapshot.dart';
import '../../domain/rules/capital_committed.dart';
import '../../state/export/export_controller.dart';
import '../../state/journal/journal_controller.dart';
import '../../state/notifications/notification_providers.dart';
import '../../state/portfolio/portfolio_controller.dart';
import '../../state/today/today_controller.dart';
import '../../state/preferences/preferences_provider.dart';
import '../../state/rule_profiles/rule_profile_editor_controller.dart';
import '../../state/rule_profiles/rule_profile_providers.dart';

import 'pro_plan_section.dart';
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
      ref.invalidate(todayControllerProvider);
      ref.invalidate(journalControllerProvider);
      ref.invalidate(portfolioControllerProvider);
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
      bottomNavigationBar: const AppBottomNav(currentPath: '/settings'),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ProPlanSection(),
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
                const _YourBookSection(),
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
                const Divider(height: 32),
                // D-18: the persistent disclaimer, verbatim, in the two
                // places a user can always find it (S-249).
                Text(
                  kAppDisclaimer,
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

/// D-6's "Your book": the two figures the concentration readout on Today is
/// computed from. Both are **refused rather than clamped** -- a silently
/// rewritten number would be a different fact about the user's own book than
/// the one they entered.
///
/// The fields hold their own text and their own refusal message, and write
/// straight through `PreferencesController` on every keystroke that parses:
/// an incomplete entry is refused and nothing is written, so storage never
/// holds a value the user did not mean.
class _YourBookSection extends ConsumerStatefulWidget {
  const _YourBookSection();

  @override
  ConsumerState<_YourBookSection> createState() => _YourBookSectionState();
}

class _YourBookSectionState extends ConsumerState<_YourBookSection> {
  late final TextEditingController _capital;
  late final TextEditingController _limit;
  String? _capitalError;
  String? _limitError;

  @override
  void initState() {
    super.initState();
    // The section only exists once preferences have loaded (its parent
    // renders a spinner until then), so this read is never the `null` one.
    final prefs = ref.read(preferencesControllerProvider).valueOrNull;
    _capital = TextEditingController(text: _decimalText(prefs?.wheelCapital));
    _limit = TextEditingController(text: _percentText(prefs?.concentrationLimitPct ?? 25.0));
  }

  @override
  void dispose() {
    _capital.dispose();
    _limit.dispose();
    super.dispose();
  }

  /// The stored figure as the user would have typed it; `null` capital is the
  /// empty field, which is how "not set" reads.
  static String _decimalText(Decimal? value) => value?.toString() ?? '';

  /// `25`, not `25.0`: the limit is a percentage of the user's own capital,
  /// and trailing zeros read as precision the figure does not have.
  static String _percentText(double value) {
    var text = value.toStringAsFixed(4);
    if (text.contains('.')) text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }

  /// Strips the characters a user may type around a figure -- `$`, thousands
  /// separators, spaces -- so `$30,000` is the same entry as `30000`. What is
  /// left that does not parse is refused like any other out-of-range entry.
  static String _bare(String text) => text.replaceAll(RegExp(r'[\$,\s]'), '');

  void _onCapitalChanged(String text) {
    final bare = _bare(text);
    if (bare.isEmpty) {
      setState(() => _capitalError = null);
      ref.read(preferencesControllerProvider.notifier).setWheelCapital(null);
      // Portfolio divides by wheel capital, so a change here makes its
      // already-loaded figures stale (D-45).
      ref.invalidate(portfolioControllerProvider);
      return;
    }

    Decimal? value;
    try {
      value = Decimal.parse(bare);
    } on FormatException {
      value = null;
    }
    if (value == null || !wheelCapitalInRange(value)) {
      setState(() => _capitalError = kWheelCapitalRefusal);
      return;
    }
    setState(() => _capitalError = null);
    ref.read(preferencesControllerProvider.notifier).setWheelCapital(value);
    ref.invalidate(portfolioControllerProvider);
  }

  void _onLimitChanged(String text) {
    final value = double.tryParse(_bare(text));
    if (value == null || !concentrationLimitInRange(value)) {
      setState(() => _limitError = kConcentrationLimitRefusal);
      return;
    }
    setState(() => _limitError = null);
    ref.read(preferencesControllerProvider.notifier).setConcentrationLimit(value);
    ref.invalidate(portfolioControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your book', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Wheel capital is the money you have set aside for the wheel. Today '
          'divides each underlying by it to show how concentrated the book is, '
          'and flags anything over the limit below.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('wheel-capital'),
          controller: _capital,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Wheel capital',
            prefixText: '\$',
            helperText: 'The money you set aside for the wheel',
            errorText: _capitalError,
          ),
          onChanged: _onCapitalChanged,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('concentration-limit'),
          controller: _limit,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Concentration limit',
            suffixText: '%',
            helperText: 'Flags an underlying above this share of wheel capital',
            errorText: _limitError,
          ),
          onChanged: _onLimitChanged,
        ),
      ],
    );
  }
}
