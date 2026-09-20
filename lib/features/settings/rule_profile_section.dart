import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates/date_text.dart';
import '../../domain/models/rule_profile_ids.dart';
import '../../domain/models/rule_profile_version_data.dart';
import '../../domain/rules/rule_profile_validation.dart';
import '../../state/rule_profiles/rule_profile_editor_controller.dart';
import '../../state/rule_profiles/rule_profile_providers.dart';

/// D-11/S-199: the Active-profile section — which version new cycles open
/// under, the 14-field editor over it, and the append-only history. Lives
/// in the Settings screen's own list, so there is no new navigation
/// concept: open Settings and it is there.
class RuleProfileSection extends ConsumerWidget {
  const RuleProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ruleProfileEditorProvider);
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final profile = state.current;
    final history =
        ref.watch(ruleProfileVersionsProvider(RuleProfileIds.standard)).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Active profile', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        if (profile == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Text(profile.name, style: textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(_versionLine(state), style: muted),
          const SizedBox(height: 12),
          // D-5, stated where the save action is: this is the whole reason
          // an edit is safe to make.
          Text(
            'Saving applies the new numbers to the next new position you open; '
            'positions you already hold -- and legs rolled from them -- keep the rules '
            'they were opened under.',
            style: muted,
          ),
          const SizedBox(height: 12),
          for (final field in RuleProfileField.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                // Keyed by version so a save re-seeds every field from the
                // version it just wrote, instead of leaving stale text.
                key: ValueKey('${field.name}-${profile.versionId}'),
                initialValue: state.draft[field] ?? '',
                enabled: !state.isSaving,
                keyboardType: _integerFields.contains(field)
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _labels[field],
                  // The same plain decoration every other entry field in
                  // the app uses -- no border override, no density change.
                  errorText: state.hasAttemptedSave ? state.violationFor(field)?.message : null,
                ),
                // Presentation only: parsing and validation are the
                // controller's job.
                onChanged: (text) => ref
                    .read(ruleProfileEditorProvider.notifier)
                    .setField(field, text),
              ),
            ),
          if (state.error != null) ...[
            Text(
              state.error!,
              style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: state.canSave ? () => _save(context, ref) : null,
            child: Text(state.isSaving ? 'Saving…' : 'Save as new version'),
          ),
          if (state.isDirty && state.violations.isNotEmpty && state.hasAttemptedSave) ...[
            const SizedBox(height: 8),
            Text(
              '${state.violations.length} '
              '${state.violations.length == 1 ? 'field needs' : 'fields need'} '
              'fixing before this can be saved.',
              style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Text('Version history', style: textTheme.titleSmall),
          // Newest first (D-11) -- the provider hands them over ascending.
          for (final version in history.reversed) _VersionEntry(version: version),
        ],
      ],
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(ruleProfileEditorProvider.notifier).save();
    final version = ref.read(ruleProfileEditorProvider).current?.version;
    final message = switch (outcome) {
      RuleProfileSaveOutcome.saved => 'Saved as v$version.',
      RuleProfileSaveOutcome.noChange => 'No changes to save.',
      RuleProfileSaveOutcome.failed => 'Could not save the new version.',
      RuleProfileSaveOutcome.invalid => null,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _versionLine(RuleProfileEditorState state) {
    final date = state.currentEffectiveAt;
    final label = 'Version ${state.current!.version}';
    return date == null ? label : '$label -- effective ${dateText(date)}';
  }
}

/// One history row: the version, when it took effect, and the 14 values it
/// holds (D-11's "each version's values and effective date"). The active
/// one is named in the section header above, so it is not tagged here.
class _VersionEntry extends StatelessWidget {
  const _VersionEntry({required this.version});

  final RuleProfileVersionData version;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'v${version.version} -- ${dateText(version.effectiveAt)}',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            _valuesSummary(version),
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat, fixity-free rendering of the 14 stored values — the history is for
/// recognising what changed, not for re-editing.
String _valuesSummary(RuleProfileVersionData v) => [
  'profit target ${_number(v.profitTargetPct)}%',
  'assign ${_number(v.assignThreshold)}',
  'bands ${_number(v.baseRollBand)}/${_number(v.midIvRollBand)}/${_number(v.highIvRollBand)}',
  'IV cutoffs ${_number(v.midIvCutoff)}/${_number(v.highIvCutoff)}',
  'tail ${v.tailDteDays}d',
  'tail extrinsic \$${v.tailExtrinsicThreshold}',
  'IV rank ${_number(v.minIvRank)}',
  'yield ${_number(v.minAnnualisedYield)}%',
  'DTE ${v.targetDteMin}-${v.targetDteMax}',
  'delta ${_number(v.targetDelta)}',
].join(' · ');

String _number(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toString();

/// The field labels, in the D-9 order [RuleProfileField] declares — the same
/// order the form renders them in, which is also the order the validator
/// reports violations in.
const Map<RuleProfileField, String> _labels = {
  RuleProfileField.profitTargetPct: 'Profit target (%)',
  RuleProfileField.assignThreshold: 'Assign threshold (delta)',
  RuleProfileField.baseRollBand: 'Roll band -- base',
  RuleProfileField.midIvRollBand: 'Roll band -- mid IV',
  RuleProfileField.highIvRollBand: 'Roll band -- high IV',
  RuleProfileField.midIvCutoff: 'Mid IV cutoff',
  RuleProfileField.highIvCutoff: 'High IV cutoff',
  RuleProfileField.tailDteDays: 'Tail window (days)',
  RuleProfileField.tailExtrinsicThreshold: 'Tail extrinsic threshold (\$)',
  RuleProfileField.minIvRank: 'Minimum IV rank',
  RuleProfileField.minAnnualisedYield: 'Minimum annualised yield (%)',
  RuleProfileField.targetDteMin: 'Target DTE minimum (days)',
  RuleProfileField.targetDteMax: 'Target DTE maximum (days)',
  RuleProfileField.targetDelta: 'Target delta',
};

/// The three count-valued fields — a decimal keypad would invite "45.5
/// days" for a field that can only hold a whole number.
const Set<RuleProfileField> _integerFields = {
  RuleProfileField.tailDteDays,
  RuleProfileField.targetDteMin,
  RuleProfileField.targetDteMax,
};
