// S-197 (D-2): the editor controller's no-op rule — a save whose 14 values
// equal the current version writes nothing — plus the draft seeding, the
// D-9 validation wiring (S-201's fixture), and the post-save baseline move.
// The widget-level halves of S-199/S-200/S-201 live in
// `test/features/settings/rule_profile_editor_test.dart`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/rule_profile_version_data.dart';
import 'package:wheel_triage/domain/rules/rule_profile_validation.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/rule_profiles/rule_profile_editor_controller.dart';

import '../../support/rule_profile_fixtures.dart';

/// Counts appends so "no version was written" can be asserted as "no append
/// was called" — the D-2 guarantee, not just its observable side effect.
class _CountingRepository extends InMemoryWheelRepository {
  int appendCalls = 0;

  @override
  Future<RuleProfileVersionData> appendRuleProfileVersion({
    required String profileId,
    required DateTime effectiveAt,
    required NewRuleProfileVersionInput values,
  }) {
    appendCalls++;
    return super.appendRuleProfileVersion(
      profileId: profileId,
      effectiveAt: effectiveAt,
      values: values,
    );
  }
}

final _now = DateTime(2026, 9, 19, 12);

void main() {
  late _CountingRepository repo;
  late ProviderContainer container;
  late RuleProfileEditorController controller;

  Future<List<String>> versionIds() async =>
      (await repo.getRuleProfileVersions(RuleProfileIds.standard)).map((v) => v.id).toList();

  Future<void> openEditor() async {
    container = ProviderContainer(
      overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    // `.autoDispose` providers are disposed once nothing is listening.
    container.listen(ruleProfileEditorProvider, (previous, next) {});
    controller = container.read(ruleProfileEditorProvider.notifier);
    await controller.ready;
  }

  setUp(() {
    repo = _CountingRepository();
  });

  RuleProfileEditorState state() => container.read(ruleProfileEditorProvider);

  test('load: seeds the draft from the current version, formatted for entry', () async {
    await openEditor();

    expect(state().current!.versionId, RuleProfileVersionIds.standardV1);
    expect(state().current!.version, 1);
    expect(state().history, hasLength(1));
    expect(state().error, isNull);

    // The §4.4 defaults, in the shape the register's S-199 names them.
    expect(state().draft[RuleProfileField.profitTargetPct], '50');
    expect(state().draft[RuleProfileField.assignThreshold], '0.70');
    expect(state().draft[RuleProfileField.baseRollBand], '0.30');
    expect(state().draft[RuleProfileField.midIvRollBand], '0.35');
    expect(state().draft[RuleProfileField.highIvRollBand], '0.40');
    expect(state().draft[RuleProfileField.midIvCutoff], '40');
    expect(state().draft[RuleProfileField.highIvCutoff], '70');
    expect(state().draft[RuleProfileField.tailDteDays], '3');
    expect(state().draft[RuleProfileField.tailExtrinsicThreshold], '0.05');
    expect(state().draft[RuleProfileField.minIvRank], '30');
    expect(state().draft[RuleProfileField.minAnnualisedYield], '20');
    expect(state().draft[RuleProfileField.targetDteMin], '30');
    expect(state().draft[RuleProfileField.targetDteMax], '45');
    expect(state().draft[RuleProfileField.targetDelta], '0.30');

    expect(state().violations, isEmpty);
    expect(state().canSave, isFalse, reason: 'D-2/S-199: inert until a value changes');
  });

  test('load: the history is newest-first, ordering by version not time', () async {
    await repo.appendRuleProfileVersion(
      profileId: RuleProfileIds.standard,
      effectiveAt: _now,
      values: standardVersionInput(profitTargetPct: 60.0),
    );
    await openEditor();

    expect(state().history.map((v) => v.version).toList(), [2, 1]);
    expect(state().current!.version, 2);
    expect(state().current!.profitTargetPct, 60.0);
    expect(state().draft[RuleProfileField.profitTargetPct], '60');
  });

  group('S-197 (D-2): a no-op save writes nothing', () {
    test('an untouched draft reports no change and calls no append', () async {
      await openEditor();
      final before = await versionIds();

      final outcome = await controller.save();

      expect(outcome, RuleProfileSaveOutcome.noChange);
      expect(repo.appendCalls, 0);
      expect(await versionIds(), before);
      expect(state().error, isNull);
      expect(state().current!.version, 1);
    });

    test('re-typing the same numbers in another representation is still no change', () async {
      await openEditor();

      // "50" vs the stored 50.0, "0.7" vs 0.70, "0.0500" vs 0.05 — value
      // equality is numeric equality (D-2), never text equality, so the
      // form is still not an edit.
      controller
        ..setField(RuleProfileField.profitTargetPct, '50')
        ..setField(RuleProfileField.assignThreshold, '0.7')
        ..setField(RuleProfileField.tailExtrinsicThreshold, '0.0500');
      expect(state().isDirty, isFalse);
      expect(state().canSave, isFalse, reason: 'S-199: inert until a *value* changes');

      final outcome = await controller.save();

      expect(outcome, RuleProfileSaveOutcome.noChange);
      expect(repo.appendCalls, 0);
    });

    test('changing exactly one value appends exactly v2 and nothing else', () async {
      await openEditor();
      controller.setField(RuleProfileField.profitTargetPct, '60');

      final outcome = await controller.save();

      expect(outcome, RuleProfileSaveOutcome.saved);
      expect(repo.appendCalls, 1);
      expect(await versionIds(), [
        RuleProfileVersionIds.standardV1,
        RuleProfileVersionIds.forVersion(RuleProfileIds.standard, 2),
      ]);

      final v2 = (await repo.getRuleProfileVersions(RuleProfileIds.standard)).last;
      expect(v2.version, 2);
      expect(v2.profitTargetPct, 60.0);
      expect(v2.assignThreshold, 0.70, reason: 'untouched fields carry forward');
      expect(v2.baseRollBand, 0.30);
      expect(v2.targetDelta, 0.30);
      expect(state().current!.versionId, v2.id);
      expect(state().canSave, isFalse, reason: 'the new version is the baseline now');
    });

    test('the baseline moves: a second save with no further edits is a no-op', () async {
      await openEditor();
      controller.setField(RuleProfileField.profitTargetPct, '60');
      await controller.save();

      final outcome = await controller.save();

      expect(outcome, RuleProfileSaveOutcome.noChange);
      expect(repo.appendCalls, 1);
    });
  });

  group('S-201: invalid input blocks the save, every violation at once', () {
    test('two violations (one cross-field) block the write; correcting saves once', () async {
      await openEditor();

      controller
        ..setField(RuleProfileField.profitTargetPct, '0')
        ..setField(RuleProfileField.baseRollBand, '0.9')
        ..setField(RuleProfileField.midIvRollBand, '0.3');

      final blocked = await controller.save();

      expect(blocked, RuleProfileSaveOutcome.invalid);
      expect(repo.appendCalls, 0);
      expect(state().hasAttemptedSave, isTrue);
      expect(
        state().violations.map((v) => v.field).toList(),
        [RuleProfileField.profitTargetPct, RuleProfileField.baseRollBand],
      );
      expect(state().violations.every((v) => v.message.isNotEmpty), isTrue);

      controller
        ..setField(RuleProfileField.profitTargetPct, '60')
        ..setField(RuleProfileField.baseRollBand, '0.30');
      expect(state().violations, isEmpty, reason: 'errors clear as the values are fixed');

      final saved = await controller.save();

      expect(saved, RuleProfileSaveOutcome.saved);
      expect(repo.appendCalls, 1);
      expect(await versionIds(), hasLength(2));
    });

    test('text that is not a number is its own violation, per field', () async {
      await openEditor();
      controller.setField(RuleProfileField.tailDteDays, 'soon');

      final outcome = await controller.save();

      expect(outcome, RuleProfileSaveOutcome.invalid);
      expect(repo.appendCalls, 0);
      expect(state().violations.single.field, RuleProfileField.tailDteDays);
      expect(state().violationFor(RuleProfileField.tailDteDays)!.message, isNotEmpty);
      expect(state().violationFor(RuleProfileField.profitTargetPct), isNull);
    });

    test('a value outside its bound never doubles as a cross-field violation', () async {
      await openEditor();
      controller
        ..setField(RuleProfileField.baseRollBand, '1.5')
        ..setField(RuleProfileField.midIvRollBand, '0.3');

      await controller.save();

      expect(state().violations.single.field, RuleProfileField.baseRollBand);
    });
  });

  test('D-9 bounds reject an out-of-range value the UI cannot pre-empt', () async {
    await openEditor();
    // `double.tryParse('1e3')` succeeds, so only the validator can catch it.
    controller.setField(RuleProfileField.minIvRank, '1e3');

    await controller.save();

    expect(state().violations.single.field, RuleProfileField.minIvRank);
    expect(repo.appendCalls, 0);
  });
}
