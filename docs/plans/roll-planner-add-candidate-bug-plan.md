# Feature: Roll Planner Add Candidate Re-entry

> Status: Iteration 1 complete
> Next handoff: none
> Binding conventions: docs/conventions.md (+ docs/brief.md §5.3)

## Overview

The Roll Planner currently accepts the first candidate through the screen UI
but does not reliably allow the user to add the second and third candidates
that `docs/brief.md` §5.3 requires. Current repository evidence points to a
local screen/dialog defect rather than a controller or repository defect:
`RollPlannerController.addCandidate` already accepts repeated adds until the
list reaches three, and the existing controller test for S-025 adds two
candidates directly. The missing guard is a widget-level regression test that
reopens the dialog after the first successful add.

## Requirements

- Keep the Roll Planner compliant with `docs/brief.md` §5.3: the user can
  enter two or three candidates and compare them side by side.
- After a successful add, the planner must return to a state where tapping
  `Add candidate` opens a fresh dialog for the next candidate, until the count
  reaches three.
- Preserve the existing three-candidate cap, bound-validation behavior, debit
  labeling, and total-per-contract toggle behavior.

## Acceptance Criteria

- [x] S-205 passes: from the screen UI, candidate A can be added, the dialog
      can be reopened, and candidate B can be added without losing A.
- [x] S-206 passes: after the third successful add, `Add candidate` becomes
      disabled; before that point it remains enabled.
- [x] `flutter test test/features/roll/roll_planner_screen_test.dart` is green.
- [x] `flutter test test/state/roll/roll_planner_controller_test.dart` is green.
- [x] `flutter analyze` is clean.

## Feature Invariants

- `docs/brief.md` §5.3's wording is literal: the user can enter two or three
  candidates, not just one.
- A debit roll remains clearly labeled and never blocked solely for being a
  debit.
- Hard-reject and soft-warn bound validation remains owned by
  `RollPlannerController.addCandidate`; a UI fix must not bypass or duplicate
  that logic.

## Existing-Functionality Impact

- Roll Planner add entry point -> grep `Add candidate|New candidate` under
  `lib/` hits only `lib/features/roll/roll_planner_screen.dart`; effect: the
  defect is localized to the Roll Planner screen path and guarded by S-205 and
  S-206.
- Candidate accumulation semantics -> grep `state.candidates.length >= 3` and
  existing S-025 coverage in `test/state/roll/roll_planner_controller_test.dart`
  show the controller already supports multiple candidates up to the cap;
  effect: treat controller changes as conditional, only if the widget repro
  disproves the UI-only hypothesis.
- Removal surface -> grep `removeCandidate\(` in `lib/` and `test/` finds only
  the declaration in `lib/state/roll/roll_planner_controller.dart`; effect:
  this fix should not expand scope into candidate removal behavior.
- Current UI coverage gap -> grep `Add candidate` in `test/` finds only the
  helper that opens the first dialog in
  `test/features/roll/roll_planner_screen_test.dart`; effect: the regression
  guard must be added at the widget-test layer.

## Scenarios

### S-205: Add second candidate after the first succeeds
- Fixture: one open leg exists for the planner; zero existing candidates;
  candidate A and candidate B are both valid and distinct, with values that do
  not trigger a hard reject.
- Trigger: the user adds candidate A, returns to the planner, then taps
  `Add candidate` again and adds candidate B.
- Precondition: the planner is loaded and `state.candidates.length == 0`.
- Flow: open the dialog; enter candidate A; submit; verify candidate A renders;
  tap `Add candidate` again; enter candidate B; submit.
- Expected outcome: both candidates render side by side; the first candidate
  remains visible; the second add succeeds through the same UI path; the
  `Add candidate` button remains enabled because the count is still below three.
- Edge case of: none

### S-206: The third add is the last allowed add
- Fixture: one open leg exists for the planner; two valid candidates are
  already present.
- Trigger: the user adds candidate C from the same dialog flow.
- Precondition: the planner is loaded and `state.candidates.length == 2`.
- Flow: tap `Add candidate`; enter candidate C; submit; return to the planner.
- Expected outcome: the third candidate renders; `Add candidate` becomes
  disabled only after the third add succeeds.
- Edge case of: S-205

## Iteration 1

### Phase 1: Roll Planner re-entry fix (@developer)
1. [x] Add a widget-level reproduction in
       `test/features/roll/roll_planner_screen_test.dart` that performs two
       successful adds through the actual Roll Planner dialog flow.
2. [x] Fix the local add-candidate UI path in
       `lib/features/roll/roll_planner_screen.dart` so each successful add
       leaves the planner ready for the next add until the cap is reached.
3. [x] Extend the widget test to cover the third-candidate cap; touch
       `lib/state/roll/roll_planner_controller.dart` only if the repro shows
       the controller, not the screen, is the controlling defect.
**Done Criteria** (run until green): `flutter test test/features/roll/roll_planner_screen_test.dart`, `flutter test test/state/roll/roll_planner_controller_test.dart`, `flutter analyze`
**Predicted Files**: `lib/features/roll/roll_planner_screen.dart`, `test/features/roll/roll_planner_screen_test.dart`

## Files Affected

- `lib/features/roll/roll_planner_screen.dart`
- `test/features/roll/roll_planner_screen_test.dart`
- `lib/state/roll/roll_planner_controller.dart` (only if the widget repro
  disproves the UI-only hypothesis)
- `test/state/roll/roll_planner_controller_test.dart` (only if controller
  behavior changes)

## Notes

- Lean TRIVIAL bug-fix plan. For a change this size, the user could skip
  conductor and open `@developer` directly.
- Local hypothesis: the controller semantics are already correct for repeated
  adds; the defect is in the screen/dialog lifecycle after the first
  successful add.
- Cheapest discriminating check: a widget test that adds candidate A, reopens
  the dialog, and adds candidate B through the screen. If the controller tests
  remain green and that widget test fails, keep the fix local to the screen.
- Do not widen scope into roll confirmation, repository code, or unrelated
  copy/layout changes.

## Progress

- [x] Phase 1 complete

## Assumption Log

- No product-choice ambiguity found. The intended behavior is the brief's
  literal "enter two or three candidates," with the button remaining usable
  until the candidate count reaches three.

## Feedback

- Observed red before the fix: on a phone-sized viewport, the add-candidate
  dialog overflowed horizontally and, after the first add, the `Add candidate`
  control dropped below the built portion of the `ListView`, which blocked the
  repeat-add path through the normal UI.
- Observed green after the fix: `flutter test test/features/roll/roll_planner_screen_test.dart`
  -> 4 passed, 0 failed; `flutter test test/state/roll/roll_planner_controller_test.dart`
  -> 10 passed, 0 failed; `flutter analyze` -> no issues found.

### Reviewer verdict (@code-reviewer, 2026-09-28, Iteration 4 closeout Phase 23.4)

**RATIFY — ships as-is, no remediation.** Diff-reviewed
`lib/features/roll/roll_planner_screen.dart` and
`test/features/roll/roll_planner_screen_test.dart` against this plan's own
Predicted Files and Acceptance Criteria: both files match, and
`lib/state/roll/roll_planner_controller.dart`/its test are confirmed
untouched (`git diff --stat` empty for both), matching this plan's own
"screen-local, controller unchanged" claim.

Re-ran fresh: `flutter test test/features/roll/roll_planner_screen_test.dart
test/state/roll/roll_planner_controller_test.dart` → **14 passed, 0
failed** (10 controller + 4 screen, independently reproducing the Feedback
entry above exactly). `flutter test --plain-name "S-205"` and `--plain-name
"S-206"` both pass as part of the same run
(`roll_planner_screen_test.dart`'s "S-205/S-206: roll planner can add
multiple candidates through the UI" group). `flutter analyze` → no issues
found (whole-repo run, shared with the Iteration 4 closeout verification).

Acceptance Criteria: both S-205 and S-206 pass exactly as specified — the
dialog reopens after a successful add without losing the prior candidate,
and `Add candidate` disables only after the third add. Feature Invariants
(brief §5.3 literal two-or-three, debit labeling untouched, bound
validation still owned by the controller) hold — no change to
`RollPlannerController.addCandidate` in this diff. No documentation under
`docs/` declares this screen in its scope and none was touched or made
false by this fix. This item does not gate Iteration 4's own closure
(`docs/plans/iteration-4-closeout-plan.md` Phase 23.4, item 7) and carries
no dependency on it either way.