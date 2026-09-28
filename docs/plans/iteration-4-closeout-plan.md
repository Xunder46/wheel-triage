# Feature: Iteration 4 Closeout — Phase 23 Verification

> Status: **Q&A answered (2026-09-28).** Phase 23.0 (ratify-or-revert) and
> Phase 23.2 (CR-6 record) are both Complete. **Q1 = FIX** (Phase 23.1
> Branch A is live — the binding branch, D-11). **Q2 = the user confirms
> they gave the Phase 17 checkpoint go-ahead** — recorded as a retroactive
> record on `wheel-triage-plan.md`'s Phase 17 Progress entry, D-12. **Q3 =
> KEEP** the notification copy — Phase 23.3 does not trigger, D-13. Three
> further user decisions are recorded as D-14 (git constraint retired), D-15
> (no test counts in `CLAUDE.md`), D-16 (`flutter pub upgrade` outcome — does
> not resolve the Phase 24 Assumption #3 crash; a follow-up dependency
> question is logged in `## Notes`, not planned).
> Phase 23.1 Branch A is **Complete** (2026-09-28). Phase 23.4's final
> verification found two WARNING findings (2a, 2b — see `wheel-triage-plan.md`'s
> `### Phase 23.4 final verification` `## Feedback`); the user routed both to
> `@developer` as a bounded follow-up, now also **Complete** as **Phase
> 23.4.1** (2026-09-28) — see `## Progress`.
> **Phase 23.4.1 re-verified (2026-09-28, `@code-reviewer`) and RATIFIED —
> both findings hold fixed, zero new findings. Phase 23 is CLOSED.** Fresh
> `flutter analyze` 0 issues, whole-repo `flutter test` 464 passed/0
> failed, `flutter build ios --simulator --no-codesign` exit 0,
> `--plain-name "S-210"` green, tone/purity greps empty. Diff matches
> Phase 23.4.1's own Predicted Files exactly. See `wheel-triage-plan.md`'s
> `### Phase 23.4.1 re-verification` `## Feedback` entry for the full
> record, including the duplication ruling and the open-cycle/put-only
> parity confirmation.
> Next handoff: **none — Iteration 4 closed.**
> Binding conventions: `docs/conventions.md` + `CLAUDE.md` (repo root) +
> `docs/plans/wheel-triage-plan.md` — that file is Iteration 4's binding
> spec and this plan's parent; it is not restated here beyond what each
> phase needs verbatim. **Read its `### Phase 23` (~line 3247+), its
> `## Progress` Phase 23 entry (~line 4085+), and its `## Feedback` section
> from `### Standing audit obligation ... Phase 23's independent pass`
> onward (~line 5511+) before touching any phase below** — this plan
> continues that work, it does not summarize it away.

## Overview

Iteration 4 (the ledger release) shipped its code across Phases 15–22; Phase
23 (`@code-reviewer`) then ran, found and fixed real defects (CR-1 through
CR-8), corrected two false claims in the plan's own record (CR-4, CR-5) and
one self-contradictory scenario (CR-2), and left the phase open pending "the
coordinator's ratify-or-revert pass" — a step only the coordinator can
perform, and the one step Phase 23's own Done Criteria required before its
nine checkboxes and the Iteration 4 Acceptance Criteria could be ticked as
verified rather than self-reported. Iteration 5 (rule versioning) was then
planned and shipped **on top of** the still-technically-open Phase 23,
which is why this closeout is happening after, not before, Iteration 5.

This plan performs that ratification pass (done, see `## Progress`), corrects
one stale wording drift the ratification surfaced (S-029, done — see the
diff to `wheel-triage-plan.md`), and disposes of three items that genuinely
require the user's input: a rules-engine formula inconsistency the CR-1
remediation entry flagged but never resolved (`stockPnL` vs
`peakCapitalCommitted`/`wheelBasis` reading different strikes for the same
assignment), CR-6's missing checkpoint-consent record, and CR-8's notification
copy suggestion. It closes with a final `@code-reviewer` pass that ticks
Phase 23's own nine checklist items and the Iteration 4 Acceptance Criteria
against the **current** tree (Iteration 4 + Iteration 5 both present), and
separately reviews the one other piece of unreviewed working-tree code — the
roll-planner "add candidate" hotfix — without folding it into Iteration 4's
own scope or Acceptance Criteria.

**Update (2026-09-28): the user answered the Question Round the same day it
was written** (verbatim: "yes, yes I approved, yes keep it" — Q1 = FIX, Q2 =
go-ahead confirmed, Q3 = KEEP; see D-11–D-13) and supplied three further
decisions (D-14–D-16, unrelated to Q1–Q3). Phase 23.2 closed the same
session. Only Phase 23.1 (Branch A) and Phase 23.4 remain.

**Tier: CONSOLIDATION, not TRIVIAL**, despite being small. Nothing here adds
a screen or a table, which is what would normally route this to STANDARD or
below — but it converges an already-shipped feature's still-disagreeing
formulas and still-open review record, it carries a real product question
(Q1) whose answer changes a persisted-report figure (`netResult`,
`returnOnCapitalPct`) for at least one already-recorded shape of cycle, and
its primary deliverable is ratification, not new capability — exactly the
CONSOLIDATION definition ("the plan exists to converge implementations, not
to add behavior"). It does not warrant a full Drift Checklist breadth pass:
the surface is one already-audited iteration closing out, not a
multi-iteration feature with unknown drift, so the checklist below is scoped
to what the CR-1 remediation entry itself already flagged, plus what this
plan's own Impact Check turned up while scoping Q1.

## Resolved Decisions (Ledger)

Numbered D-1…D-16. **Immutable once written.** Changes are new superseding
entries, never edits. D-1–D-7 required no user input and were
ratified/decided in the prior session. D-8–D-10 were written in both-branch
form, conditional on the Question Round below; the user has now answered
(2026-09-28, verbatim: "yes, yes I approved, yes keep it" — see `## Question
Round` for which sentence answers which question), and D-11–D-13 record
which branch of each is binding **as new entries, not as edits to D-8/D-10's
own text**, matching this Ledger's own immutability rule and the same
supersede-don't-edit precedent D-7 already used on Feature Invariant 14.
D-14–D-16 record three further decisions from the same answer, unrelated to
Q1–Q3.

**D-1 — CR-1 remediation (`recordCallAway` retains the `ShareLot` row) is
RATIFIED as shipped, no follow-up.** `WheelRepository.recordCallAway` no
longer deletes the row; it stays retained as the cycle's assignment record,
readable via `getAssignmentForCycle(cycleId)`, while `getShareLotForCycle`
keeps its unchanged "active lot only" meaning by deriving activeness from
`WheelCycle.status`. Both `DriftWheelRepository`/`InMemoryWheelRepository`
implement it identically; contract parity tests exist; an export/restore
round-trip test (`ledger_export_test.dart`'s CR-1 case) proves a restored
backup reports identical figures. Full rationale:
`wheel-triage-plan.md`'s `### CR-1 remediation` Feedback entry — not
restated here.

**D-2 — CR-1's consumer fix (`JournalController.load` prefers
`getAssignmentForCycle`, falls back to `_reconstructShareLot` only for a
legacy cycle with no retained record) is RATIFIED as shipped, no
follow-up.** The guard test asserts `peakCapitalCommitted` equality (not
`returnOnCapitalPct`/`netResult` equality, which is correctly *not*
invariant between a cycle's open and closed states) — this was itself a
correction the developer made after a first draft asserted a false
invariant; the corrected assertion is the right one and is not revisited
here.

**D-3 — CR-3 fix (`PositionDetailController.closeDirect` reads bare
`load()`, matching the S-140 shape) is RATIFIED as shipped, no follow-up.**
The developer chose to fix rather than merely pin the dormancy, for the
stated reason (relying on "no caller passes `closedAt` today" is the same
reasoning class that produced the original S-140 defect) — sound, ratified.

**D-4 — CR-7 (a pointer comment in
`test/data/wheel_repository_contract_test.dart`'s header naming the
export/import trio and pointing at `test/data/export/`, tests left in
place) is RATIFIED as shipped, no follow-up.**

**D-5 — CR-2/CR-4/CR-5 register corrections are RATIFIED as verified
in-place.** Confirmed this session by direct read: S-104's "Expected
outcome" (`wheel-triage-plan.md` `### S-104`) now points at the test instead
of restating arithmetic (CR-2); the Phase 16/17 `## Assumption Log` entry
now carries both corrections labeled "(a)"/"(b)" (CR-4: the gap was not
actually flagged in `## Feedback` before CR-1; CR-5: the assigned put leg's
`strike` does **not** equal `ShareLot.assignmentStrike` by construction,
since the assignment-flow strike field is prefilled but freely editable —
`lib/features/assignment/assignment_flow_screen.dart`'s `_strikeController`,
confirmed this session, plain `TextField`, no read-only flag). No further
action.

**D-6 — Feature Invariant 29's presentation shape (median, not a
distribution, not dropped) is RATIFIED and reaffirmed, restated here for
this plan's own self-containment.** `docs/domain/rules/journal_aggregates.dart`'s
`medianPremiumCapturePct` stands as the binding shape; this was already
promoted to binding in `wheel-triage-plan.md`'s own Phase 23 Assumption Log
adjudication summary — this entry does not change that, only records that
this closeout plan agrees and needs no separate action.

**D-7 — Feature Invariant 14 / S-029's "consumes"/"consumed-removed" wording
is superseded, in wording only, never in behavior.** Since CR-1, marking a
call leg assigned **deactivates** the cycle's `ShareLot` for
`getShareLotForCycle`'s purposes (still returns `null` from that point on —
unchanged, still asserted by S-029) and **retains** the row as the cycle's
permanent assignment record, readable only via `getAssignmentForCycle`. Every
behavioral claim Feature Invariant 14 and S-029 make (`Leg.closedAt`,
`closeReason=assigned`, `WheelCycle.status → closed`, `outcome →
calledAway`, `endedAt=now`, "shares sold at `$52`") remains exactly correct
and is untouched. Only the noun for what happens to the row itself was wrong
("consumes"/"consumed/removed" implied deletion). Disposition, matching this
project's own precedent (Iteration 5's D-10/D-13 superseded Feature
Invariants 11/8 the same way, by pointer, rather than by editing them,
since a numbered Feature Invariant is this plan's closest analogue to an
immutable Ledger entry): **S-029's "Expected outcome" bullet is corrected in
place this session** (scenario oracle text is correctable in place per the
CR-2 precedent, which already did exactly this to S-104); **Feature
Invariant 14's own text is left untouched** and is superseded in wording
only by this D-7 entry. See the diff to `wheel-triage-plan.md`'s `### S-029`
for the exact corrected text.

**D-8 — CONDITIONAL on Q1 — `stockPnL`'s put-side strike source.** See
`## Question Round`, Q1, for the full problem statement.

- *If Q1 = fix (recommended default):* `stockPnL` (`lib/domain/rules/
  cycle_pnl.dart`) and its mirror `_stockPnL` (`lib/data/export/
  ledger_csv.dart`) both gain a `ShareLot? shareLot` (or, in `ledger_csv.dart`'s
  naming, `ShareLot? assignment`) parameter. The put-side strike used in the
  `(callStrike − putStrike) × 100 × calledAwayCallLeg.contracts` formula
  becomes `shareLot?.assignmentStrike ?? assignedPutLeg.strike` — the same
  "retained record preferred, leg-value legacy fallback" rule CR-1 already
  established for `peakCapitalCommitted`/`wheelBasis`. The call-side term
  (`calledAwayCallLeg.contracts`) is **unchanged** — Feature Invariant 25
  already rules that the call leg's own `contracts`, never `ShareLot.contracts`,
  governs the call side, and nothing here revisits that. `computeCyclePnl`
  already receives a `shareLot` parameter for `peakCapitalCommitted`'s sake;
  it is threaded to `stockPnL`/`netResult` too — no new plumbing above
  `computeCyclePnl`, so `journal_controller.dart`/`position_detail_controller.dart`
  need no changes of their own. `ledger_csv.dart`'s `buildClosedCyclesCsv`
  already fetches `getAssignmentForCycle` (currently *after* computing
  `_stockPnL` — the fetch must move earlier; see Phase 23.1). Full
  scenario/test spec: Phase 23.1, `## Scenarios` S-207–S-209.
- *If Q1 = leave:* no code change. A one-line doc-comment cross-reference is
  added at both `stockPnL` and `_stockPnL`'s definitions recording this as a
  deliberate, named deviation (D-8/leave), not an unnoticed bug, and pointing
  at `peakCapitalCommitted`'s differing strike source so a future reader
  doesn't "fix" it as a surprise defect. No new Feature Invariant, no new
  scenario — the deviation is documented in code and in this Ledger entry
  only.

**D-9 — CONDITIONAL on Q2 — CR-6's missing checkpoint-consent record.** See
`## Question Round`, Q2. Whichever disposition the user selects is appended,
verbatim, to `wheel-triage-plan.md`'s Phase 17 Progress entry by Phase 23.2.
No behavior or test is affected either way — this is a process record only.

**D-10 — CONDITIONAL on Q3 — CR-8's notification copy.** See `## Question
Round`, Q3.

- *If Q3 = keep (recommended default):* no action beyond what already
  exists — the developer's adjudication (`wheel-triage-plan.md`'s `###
  CR-1 remainder, CR-3, CR-7, CR-8 (@developer)` entry) stands as final,
  ratified here.
- *If Q3 = change:* Phase 23.3 fires — see that phase for the exact string
  and file list.

**D-11 — Q1 answered: FIX. D-8's "fix" branch is binding.** User answer
(2026-09-28): "yes." Phase 23.1 **Branch A** is live and is the next
`@developer` handoff — the only implementation work this plan still has
outstanding. D-8's own text is left as written (both branches, for the
historical record of what was offered); this entry is what makes Branch A
binding rather than an edit to D-8 itself.

**D-12 — Q2 answered: the user confirms the Phase 17 checkpoint go-ahead was
given.** User answer (2026-09-28): "yes I approved." This **supersedes
D-9's recommended default** ("log it as a permanent, non-blocking
documentation gap") — the user did not pick that default or offer a
different disposition; they supplied the missing fact itself. Disposition:
`wheel-triage-plan.md`'s Phase 17 Progress entry now carries the go-ahead
record, **explicitly labelled retroactive** — attributed to "the user's
confirmation on 2026-09-28," not backdated or written to read as if it had
been recorded contemporaneously at Phase 17's own checkpoint. Phase 23.2 is
now **Complete** (see `## Progress` and the diff to `wheel-triage-plan.md`);
no `@developer`/`@code-reviewer` follow-up.

**D-13 — Q3 answered: KEEP. D-10's "keep" branch is binding.** User answer
(2026-09-28): "yes keep it." The notification copy `"At $milestoneDte DTE —
worth a look."` ships unchanged. **Phase 23.3 does not trigger** — marked
not-triggered in `## Iteration 4 Closeout` below, not merely left at "not
started."

**D-14 — The "no source control" constraint is retired; git is in use.**
The user states they use git and that the constraint dated from the
project's earliest builds. This **supersedes, by this entry and not by
editing history**, three specific lines in `wheel-triage-plan.md`: the
Acceptance Criteria line "No `.git` commits exist at the end of this run,"
the Iteration 4 criterion "no `.git` writes," and the commits-exist half of
Phase 23 step 8 ("no `git` commits exist"). Those lines are **left
untouched verbatim** in `wheel-triage-plan.md` — they stand as the historical
record of a constraint that applied when they were written — and are
overridden going forward by this entry alone. **Phase 23.4's reviewer must
NOT fail, flag, or open a remediation item on the basis of `.git` commits
existing.** The other half of Phase 23 step 8 — no file under `ios/` or
`android/` modified beyond scaffold generation — is **not** touched by this
entry and stays fully binding. `CLAUDE.md` has already been updated by the
user (with the user's own authorization) to state the repo is under git;
per this plan's standing scope, `CLAUDE.md` is not a conductor-writable
artifact and is not touched here.

**D-15 — `CLAUDE.md` no longer records test counts; this is not a
docs↔code disagreement to flag.** The user removed the "456 tests pass"
line from `CLAUDE.md`, calling a hardcoded count a maintenance burden. This
**supersedes** this plan's own prior `## Notes` item, which flagged
"CLAUDE.md's `456` vs. the observed `458`" as a stale-docs finding — that
finding no longer applies and is corrected below, not left standing.
**Plan files may still record observed test counts as dated evidence** (as
`## Progress`/Feedback entries throughout `wheel-triage-plan.md` already do)
— this entry is about `CLAUDE.md` specifically, not about this plan's own
verification records.

**D-16 — `flutter pub upgrade` was run (user-authorised); it does not
resolve the Phase 24 Assumption #3 build_runner crash.** Result: only
`built_collection` `5.1.1` → `5.1.2` changed in `pubspec.lock`. 50 packages
have newer versions sitting outside `pubspec.yaml`'s constraints, because
the codegen stack is pinned to exact versions (`build_runner 2.5.4`,
`riverpod_generator 2.6.5`, `drift_dev 2.28.0`, `freezed 3.1.0`,
`json_serializable 6.9.5`, `custom_lint 0.7.5`, `riverpod_lint 2.6.5`), and
`pubspec.yaml`'s own comment records that `riverpod_generator 2.x` caps
`analyzer` below `8.0.0`. Post-upgrade verification, observed this session:
`flutter analyze` → No issues found; `flutter test` → 458 passed, 0 failed.
**Phase 23.4's reviewer must re-verify on this upgraded lockfile** (not the
pre-upgrade one this plan's earlier `## Notes` entry was written against).
**Observation, not a decision, logged for the record**: `grep -rln
"@riverpod\|riverpod_annotation" lib/` returns nothing — `riverpod_generator`
(and by extension `riverpod_lint`) appears to be dead weight in this
codebase (hand-written `StateNotifier`s throughout, per CLAUDE.md's own
documented deviation), and is what holds the whole codegen stack's version
ceiling down. Removing it and loosening the other pins would likely unblock
a full `build_runner` run, at the cost of bumping `freezed`/`drift_dev`/
`json_serializable` majors and churning every generated file. **This is a
dependency change the user has not approved** (CLAUDE.md: ask before adding
or changing a dependency) — logged as a follow-up question in `## Notes`,
**not planned as a phase**.

## Feature Invariants

Only the ones this closeout plan's own work depends on; all are already
binding in `wheel-triage-plan.md` and are referenced, not restated in full:

- **Feature Invariant 11** (`lib/data/` never imports `lib/domain/rules/`) —
  stays as-is, not re-litigated. This is exactly why Q1's fix (if adopted)
  must be written twice — once in `cycle_pnl.dart`, once as `ledger_csv.dart`'s
  own self-contained mirror — rather than importing the fixed function.
- **Feature Invariant 25** (every multi-leg dollar figure contract-weights
  each leg before summing) — `stockPnL`'s call-side `contracts` term is
  unaffected by D-8; only the put-side *strike* source changes, never a
  contract-weighting rule.
- **Feature Invariant 14** — behavioral claims unchanged, ratified; wording
  superseded per D-7.
- **Feature Invariant 29** — median shape, ratified per D-6.

## Requirements

1. Perform the coordinator's ratify-or-revert pass Phase 23 has been
   waiting on (D-1–D-7) — **done this session**.
2. Resolve, via one batched question round, the three items only the user
   can settle: the `stockPnL` strike-source inconsistency (Q1), CR-6's
   missing checkpoint record (Q2), and CR-8's notification copy (Q3).
3. Implement whichever conditional phases the answers trigger, each with its
   own fixture-enumerated scenarios and a red-before-green structural guard
   where code changes.
4. Run a final `@code-reviewer` pass that ticks Phase 23's own nine
   checklist items and the Iteration 4 Acceptance Criteria in
   `wheel-triage-plan.md` against the **current** tree, and separately
   reviews the roll-planner hotfix without folding it into Iteration 4's own
   scope.

## Acceptance Criteria

- [x] AC-1: Phase 23's ratify-or-revert pass is recorded with an explicit
      RATIFY/REVERT/CONDITIONAL disposition for every open item (D-1–D-10).
- [x] AC-2: Q1–Q3 are answered by the user (done, 2026-09-28 — D-11/D-12/
      D-13) and each answer's disposition is implemented (or explicitly
      no-op'd per its "keep/leave" branch). Q2's disposition is implemented
      (Phase 23.2 Complete); Q3's is a no-op (Phase 23.3 not triggered,
      already true); **Q1's disposition (Phase 23.1 Branch A) is now also
      implemented and Complete (2026-09-28)** — see `## Progress`.
- [x] AC-3 (conditional on Q1 = fix): S-207, S-208, S-209 all pass (observed
      2026-09-28 — see `## Progress`); the two pre-existing pinned
      expectations that became stale under the fix
      (`ledger_csv_test.dart`'s CR-1 case, `journal_controller_test.dart`'s
      CR-1 remainder case) were updated in the same change, shown red
      against the unfixed formula first; `cycle_pnl.dart` and
      `ledger_csv.dart` agree bit-for-bit on the fixed formula (Feature
      Invariant 11 parity, both compute `stockPnL = 250.00`/`netResult =
      425.00` for the S-207/CR-1 fixture, differing only in the
      `returnOnCapitalPct` **display** rounding S-207 itself calls out —
      `"4.3"` one-decimal CSV string vs. `closeTo(4.35, 0.01)` raw double).
- [x] AC-4: `wheel-triage-plan.md`'s Phase 23 nine-item checklist (~line
      3247+) and the Iteration 4 Acceptance Criteria (~line 287+) are ticked
      against observed, reproduced-fresh output — not carried forward from
      an earlier session's report. **Met (2026-09-28) — see the diff to
      `wheel-triage-plan.md`.**
- [x] AC-5: the roll-planner hotfix (`lib/features/roll/roll_planner_screen.dart`,
      `test/features/roll/roll_planner_screen_test.dart`) is diff-reviewed
      against `docs/plans/roll-planner-add-candidate-bug-plan.md`'s own
      Predicted Files and Done Criteria, and that plan's `## Feedback`
      carries a recorded verdict. **Met — RATIFIED, no remediation; see
      that plan's own `## Feedback`.**
- [x] AC-6: `flutter analyze` clean, whole-repo `flutter test` green,
      `flutter build ios --simulator --no-codesign` exit 0, all three
      reproduced fresh by the closing reviewer (not merely cited from this
      plan's own earlier numbers). **Met (2026-09-28) — 0 issues, 463
      passed/0 failed, exit 0 at the first Phase 23.4 pass; re-confirmed
      fresh at 464 passed/0 failed after Phase 23.4.1 added S-210
      (re-verification pass, same day).**
- **Not an AC in this list, but material to closure — now resolved.** The
  two WARNING findings (2a, 2b) that withheld Phase 23's "Complete" mark are
  both fixed and re-verified as of Phase 23.4.1's re-verification pass
  (2026-09-28): zero new findings from the re-verification itself. **Phase
  23 is marked Complete in `wheel-triage-plan.md`.** See `## Feedback`
  below and `wheel-triage-plan.md`'s `### Phase 23.4.1 re-verification`
  entry.

## Existing-Functionality Impact

- **`stockPnL`/`netResult` (`lib/domain/rules/cycle_pnl.dart`)** → read by
  `computeCyclePnl`, called from `lib/state/journal/journal_controller.dart:114`
  and `lib/state/positions/position_detail_controller.dart:276` (grep:
  `grep -rn "computeCyclePnl(" lib/`, both hits are it) → effect (if Q1=fix):
  both call sites inherit the corrected strike source automatically, since
  neither calls `stockPnL` directly — they only pass `shareLot` into
  `computeCyclePnl`, which already happens today. Guarded by S-207/S-209.
- **`_stockPnL` (`lib/data/export/ledger_csv.dart`)** → read only by
  `buildClosedCyclesCsv`, called from `lib/state/export/export_controller.dart:42`
  (grep: `grep -rn "buildClosedCyclesCsv(" lib/`, one hit) → effect (if
  Q1=fix): the CSV's `net_result`/`return_on_capital_pct` columns shift for
  any cycle whose assignment strike differs from its put leg's own strike,
  matching the Journal screen's own (also-shifted) figure — parity
  preserved by construction (Feature Invariant 11's cross-check), guarded by
  S-207 plus the existing S-154-style CSV/Journal equality tests.
- **Two already-pinned tests become stale under Q1=fix** (grep-confirmed
  this session, exact lines): `test/data/export/ledger_csv_test.dart:178`
  (`'CR1,75,2,175.00,Called away,375.00,3.8'` → recomputes to
  `'CR1,75,2,175.00,Called away,425.00,4.3'`) and
  `test/state/journal/journal_controller_test.dart:212-213`
  (`closedPnl.netResult` `375.00` → `425.00`; `returnOnCapitalPct` `closeTo(3.83, 0.01)`
  → recomputes to `~4.35`) — both are the same CR-1 fixture (put leg
  strike $50, retained `assignmentStrike` $49.50, call leg strike $52,
  1→2 contracts) and both already have a mismatched strike, which is exactly
  what makes them the correct adversarial home for S-207 rather than a new
  fixture. Effect: guarded by AC-3 — updated in the same change that lands
  the fix, not discovered later as a break.
- **`test/domain/rules/cycle_pnl_test.dart:134,141`** (S-104's `stockPnL`/
  `netResult` unit assertions) → currently call the two-argument shape
  without a `shareLot`; S-104's fixture has `assignmentStrike == putLeg.strike`
  ($50 both), so passing `shareLot` explicitly changes nothing numerically —
  this is S-209's proof-of-no-change fixture, reused rather than invented.
- **`docs/architecture/wheel-triage.md`** (~line 161-166, the CR-1 write-up)
  → names `stockPnL` only in a list, states no formula → effect (if
  Q1=fix): one clarifying sentence added, not a correction of a false claim.
- **Feature Invariant 14 / S-029 wording** → no code reader (register text
  only) → effect: purely editorial, done this session, zero test impact
  (`getShareLotForCycle`'s actual behavior — the only thing S-029's own
  assertion checks — is unchanged).
- **CR-8 notification copy, if Q3=change** (grep this session: `grep -rn
  "worth a look" lib/ test/ docs/`) → hits: `lib/core/notifications/
  notification_scheduler.dart:75` (a doc comment explaining the phrase,
  needs updating for consistency, not required by any test),
  `:86` (the shipped string), `test/core/notifications/
  notification_scheduler_test.dart:57-58` (two verbatim assertions),
  `wheel-triage-plan.md`'s `### S-173` fixture text (~line 2037, its own
  worked example). **Not touched**: `docs/brief.md:463` and
  `docs/brief-ledger.md:274` — both are the original product-spec documents'
  own worked examples, historical and frozen, outside this plan's writable
  scope and outside CR-8's own framing ("a copy/register decision," scoped
  to shipped code and this plan's register, never the brief).

## Scenarios

Reserved ids: **S-207, S-208, S-209** (next free after S-205/S-206, per
`docs/plans/roll-planner-add-candidate-bug-plan.md`). All three are
**conditional on Q1 = fix** — if Q1 = leave, they are not implemented; they
stay reserved (never reused) rather than orphaned, documenting the fix that
was deliberately not made.

### S-207: Mismatched assignment strike — `stockPnL`/`peakCapitalCommitted` parity
- Fixture: put leg (1 contract, `strike=$50.00`, `openCreditPerShare=$1.20`)
  assigned via `recordAssignment` at a **user-edited** `assignmentStrike=
  $49.50`, `contracts=2` (differing from the put leg's own strike/contracts
  — the exact CR-1 fixture already present in `ledger_csv_test.dart`'s
  `'CR1'` case and `journal_controller_test.dart`'s CR-1 remainder case);
  covered call (1 contract, `strike=$52.00`, `openCreditPerShare=$0.55`)
  called away.
- Trigger: compute `stockPnL`/`netResult` for the closed cycle via
  `computeCyclePnl` and independently via `buildClosedCyclesCsv`.
- Expected outcome: `stockPnL = (52.00 − 49.50) × 100 × 1 = $250.00` (the
  put-side strike sourced from the **retained assignment record**, not the
  put leg's own `$50.00`); `totalPremium = $175.00` (unchanged — not a D-8
  figure); `netResult = 175.00 − 0 + 250.00 = $425.00`; raw
  `returnOnCapitalPct = 425.00 / 9780.00 × 100 = 4.345603…%`
  (`peakCapitalCommitted` stays `$9,780.00`, untouched by D-8).
  `cycle_pnl.dart` and `ledger_csv.dart` agree on every underlying dollar
  figure bit-for-bit (Feature Invariant 11 parity), but **the two files pin
  this percentage at different rounding and must be asserted separately, not
  as one shared literal**: `ledger_csv.dart`'s CSV column formats it via
  `returnOnCapitalPct.toStringAsFixed(1)` — **`"4.3"`**, one decimal, matching
  the existing CR-1 row's own `toStringAsFixed(1)` style (`3.8`, not
  `3.83`) — while `journal_controller_test.dart` asserts the raw `double`
  with a `closeTo` tolerance, matching its own existing two-decimal style
  (`closeTo(3.83, 0.01)`) — the new value is **`closeTo(4.35, 0.01)`**, not
  `4.3`. **Supersedes** the CR-1 guard's now-stale expectations in
  `ledger_csv_test.dart:178` (full row `'CR1,75,2,175.00,Called
  away,425.00,4.3'`, replacing `'...,375.00,3.8'`) and
  `journal_controller_test.dart:212-213` (`netResult` `375.00` → `425.00`;
  `returnOnCapitalPct` `closeTo(3.83, 0.01)` → `closeTo(4.35, 0.01)`) — update
  those two assertions in place as part of landing this scenario, do not
  leave a second, duplicate fixture beside them, and do not let one file's
  rounding leak into the other's assertion.
- Edge case of: none.

### S-208: Legacy closed cycle, no retained assignment record — leg-strike fallback
- Fixture: a cycle whose assigned put leg has `strike=$50.00`, whose
  called-away call leg has `strike=$52.00`, `contracts=1`, with
  `shareLot: null` passed directly into `stockPnL`/`computeCyclePnl` (the
  pure-function way of simulating a pre-CR-1 legacy row, or a hand-built
  import, for which `getAssignmentForCycle` genuinely returns `null` — no
  repository fixture is needed to exercise this at the `cycle_pnl.dart`
  unit-test layer).
- Trigger: compute `stockPnL` with `shareLot: null`.
- Expected outcome: `stockPnL = (52.00 − 50.00) × 100 × 1 = $200.00` — the
  fallback to `assignedPutLeg.strike`, bit-for-bit identical to the pre-D-8
  formula's output for this fixture, proving the legacy fallback preserves
  every already-shipped legacy figure exactly (no silent regression for data
  with no retained record).
- Edge case of: S-207.

### S-209: Equal-strike cycle — proof of no change for the ordinary case
- Fixture: S-104's own existing fixture (`test/domain/rules/cycle_pnl_test.dart`
  — put legs at `strike=$50` throughout, `ShareLot.assignmentStrike=$50`
  matching every put leg's own strike, call leg `strike=$52`, 2 contracts) —
  reused verbatim, not duplicated. The only change at this call site is that
  `stockPnL(...)`/`netResult(...)` now receive `shareLot: shareLot`
  explicitly (previously omitted since the parameter didn't exist).
- Trigger: compute `stockPnL`/`netResult` with the now-required `shareLot`
  argument supplied.
- Expected outcome: `stockPnL` stays exactly `$400.00`, `netResult` stays
  exactly `$674.80` — bit-for-bit identical to the pre-D-8 figures, since
  `assignmentStrike == leg.strike` here. Proves the fix is a no-op for the
  ordinary case (the user never edited the prefilled assignment strike),
  which is every wheel cycle except the deliberately-adversarial S-207.
- Edge case of: S-207.

### S-210: Closed cycle in `PositionDetailController` sources `cyclePnl.shareLot` from the retained assignment record, not the active lot (Phase 23.4 ruling 2b)
- Fixture: the same CR-1/S-207 fixture shape, loaded directly through
  `PositionDetailController` rather than the Journal — put leg (1 contract,
  `strike=$50.00`, `openCreditPerShare=$1.20`) assigned via
  `recordAssignment` at a user-edited `assignmentStrike=$49.50`,
  `contracts=2`; covered call (1 contract, `strike=$52.00`,
  `openCreditPerShare=$0.55`) called away via `recordCallAway`, ending the
  cycle. Loaded by `legId` = the call leg's own id (bypassing navigation,
  the same direct-load pattern the existing S-120 test at line ~304 uses).
- Trigger: `PositionDetailController.load()` on the closed cycle's call leg.
- Expected outcome: `state.cyclePnl!.stockPnL == $250.00`,
  `state.cyclePnl!.netResult == $425.00`,
  `state.cyclePnl!.peakCapitalCommitted == $9,780.00` — identical to the
  Journal's own figures for this exact fixture (S-207), proving the
  controller now prefers `getAssignmentForCycle` the same way
  `journal_controller.dart` does. `state.shareLot` (the field fed by
  `getShareLotForCycle`, "active lot only") is untouched by this scenario —
  not asserted here, since its documented meaning does not change.
- Edge case of: S-207.

## Iteration 4 Closeout (phases continue `wheel-triage-plan.md`'s Phase 23 numbering)

Dependency graph, **as resolved (2026-09-28)**: Phase 23.0 (done) →
Question Round (answered — D-11/D-12/D-13) → Phase 23.1 Branch A is live
(D-11) and is the sole remaining dependency of Phase 23.4; Phase 23.2 is
already Complete (D-12); Phase 23.3 is not triggered (D-13) → Phase 23.4
depends only on Phase 23.1 landing.

*(Original graph, for context: Phase 23.0 (done) → Question Round (blocked
everything below) → Phase 23.1 and Phase 23.2 would run independently of
each other (23.1 depends only on Q1, 23.2 only on Q2) → Phase 23.3 depends
only on Q3 and is independent of 23.1/23.2 → Phase 23.4 depends on all of
23.1/23.2/23.3 having reached their conclusion, whatever the answers were.
Left here unedited since the answers only resolved which branches are live,
not the shape of the graph itself.)*

### Phase 23.0: Coordinator ratification pass (conductor) — **Complete, this session**

1. [x] Ratify CR-1 remediation, CR-1's remainder, CR-3, and CR-7 as shipped,
       no follow-up (D-1–D-4).
2. [x] Verify CR-2/CR-4/CR-5's corrections landed in `wheel-triage-plan.md`'s
       text, by direct read rather than trusting the prior session's own
       report (D-5) — confirmed at `### S-104`'s "Expected outcome" and the
       Phase 16/17 `## Assumption Log` entry's "(a)"/"(b)" corrections.
3. [x] Reaffirm Feature Invariant 29's median ruling for this plan's own
       record (D-6) — no new action, already binding upstream.
4. [x] Correct S-029's wording in place; leave Feature Invariant 14's text
       untouched and supersede it in wording only via D-7 — see the diff to
       `wheel-triage-plan.md`.
5. [x] Add a one-line-plus pointer to `wheel-triage-plan.md`'s status header
       naming this plan, per the task's minimum requirement.

**Done Criteria**: N/A — read/analysis and doc edits only; the edits
themselves (visible in `wheel-triage-plan.md`'s diff) are the artifact.

**Predicted Files**: `docs/plans/wheel-triage-plan.md` (status header, `###
S-029`).

---

## Question Round (batched — answer to unblock Phases 23.1–23.3)

**ANSWERED (2026-09-28).** The user's reply, verbatim: "yes, yes I
approved, yes keep it" — answering Q1, Q2, Q3 in order. Dispositions are
recorded as D-11 (Q1), D-12 (Q2), D-13 (Q3) in `## Resolved Decisions
(Ledger)`; the questions and their original recommended defaults are left
below unedited, as the historical record of what was asked, per this
Ledger's own supersede-don't-edit rule.

**Q1 (item 2 — `stockPnL`/`peakCapitalCommitted` strike-source
inconsistency).** Since CR-1, `peakCapitalCommitted`/`wheelBasis`
(`lib/domain/rules/cycle_pnl.dart`) prefer the cycle's **retained assignment
record** (`getAssignmentForCycle`) for the put-side strike/contracts used in
the post-assignment capital-committed term, falling back to the assigned put
leg's own `strike`/`contracts` only for a legacy cycle with no retained
record. `stockPnL`, in the same file (and its mirror, `lib/data/export/
ledger_csv.dart`'s `_stockPnL`), was **not** updated the same way — it still
always reads the assigned put leg's own `strike`, never the retained
record's `assignmentStrike`. Since the assignment flow's strike field is
prefilled but freely editable (`lib/features/assignment/
assignment_flow_screen.dart`, confirmed editable this session), any cycle
where the user records an assignment strike different from the put leg's own
strike now has two dollar figures — `stockPnL`/`netResult` and
`peakCapitalCommitted`/`wheelBasis` — silently disagreeing about which
strike the same assignment happened at. Should `stockPnL` be changed to
match, using the identical "retained record preferred, leg-value legacy
fallback" rule CR-1 already established?

*Should `stockPnL` prefer the retained assignment record's strike, the same
way `peakCapitalCommitted`/`wheelBasis` already do?*

- **Recommended default: yes, fix it** (D-8/fix; Phase 23.1 branch A;
  S-207–S-209). CR-1 already established "the retained record is the source
  of truth for the assignment's actual terms" as the ledger release's own
  central correction (Feature Invariant 25's whole reason for existing).
  Leaving `stockPnL` on the stale leg-strike reading keeps exactly the class
  of defect CR-1 was written to eliminate, just relocated to a sibling
  figure that happens to share the same two already-existing test fixtures.
- Alternative: **no, leave it** (D-8/leave; Phase 23.1 branch B — doc-only,
  no test/behavior change). A reasonable choice if the deviation is judged
  low-impact enough (only a user-edited assignment strike triggers it) not
  to be worth touching a formula this late in the build; it is then recorded
  as a permanent, named, deliberate deviation rather than an unnoticed
  defect.

**Answered: yes — fix it** (the recommended default). See D-11. Phase 23.1
Branch A is live.

**Q2 (item 4 — CR-6's missing checkpoint-consent record).** Phase 17 was a
hard checkpoint requiring the user's explicit go-ahead before Phase 18+
began (`wheel-triage-plan.md`'s `## Notes` and Phase 18's own dependency
line). The checkpoint's **technical** Done Criteria are documented and green
(304 tests, `flutter analyze` 0 issues, iOS build exit 0, reproduced twice)
— but the plan carries no record of the **consent** itself, and Phase 18+
work happened regardless. This cannot be reconstructed after the fact
without fabricating it, which CLAUDE.md-style conductor practice forbids.

*How should this gap be closed?*

- **Recommended default: log it as a permanent, non-blocking documentation
  gap** (D-9/(a)) — appended verbatim to the Phase 17 Progress entry by
  Phase 23.2, stating plainly that the technical gate passed twice but the
  consent record itself is missing and unrecoverable. The work built on top
  of it has since been independently verified end-to-end by Phase 22, Phase
  23's own review, and Iteration 5 — re-litigating a milestone from earlier
  in a now-verified build is not proportionate.
- Alternative: **something else you specify** (D-9/(b)) — e.g., treating
  this as a standing process reminder for future checkpoints rather than a
  closed item, or any other disposition; state it and Phase 23.2 records it
  verbatim instead.

**Answered: yes, I approved — the user confirms the go-ahead was given at
the Phase 17 checkpoint.** This is neither the recommended default nor "(b)
something else" in the abstract — it supplies the missing fact itself. See
D-12, which supersedes the recommended default accordingly. Phase 23.2 is
Complete.

**Q3 (item 5 — CR-8's notification copy).** The shipped milestone
notification body reads `"At $milestoneDte DTE — worth a look."`
(`lib/core/notifications/notification_scheduler.dart:86`). The reviewer
flagged it as advice-adjacent framing on the app's most interruption-prone
surface, though it trips no banned-vocabulary grep and pairs no action verb
with a named security or position, so it violates no existing rule. The
developer's own counter-proposal, offered but not implemented, was the
strictly date-only `"At $milestoneDte DTE."`.

*Keep the current copy, or switch to the date-only alternative?*

- **Recommended default: keep the current copy** (D-10/keep). The
  developer's adjudication (`wheel-triage-plan.md`'s `### CR-1 remainder,
  CR-3, CR-7, CR-8 (@developer)` entry) already holds under every existing
  rule: S-173's own register text uses this exact sentence as its worked
  example and defines the pass condition as "every string describes a date
  arriving, never what the position is doing," which this copy satisfies;
  it names no security or position. No code phase runs.
- Alternative: **switch to `"At $milestoneDte DTE."`** (D-10/change) — Phase
  23.3 fires: a one-line copy change, the S-173 register text updated to
  match, and the two verbatim test assertions updated.

**Answered: yes, keep it** (the recommended default). See D-13. Phase 23.3
does not trigger.

---

### Phase 23.1: `stockPnL` strike-source parity — Q1 = FIX, Branch A is LIVE (D-11) (@developer)

**Status: Complete (2026-09-28).** Depends on: Q1 answered (done — D-11).
Independent of Phase 23.2 (Complete)/Phase 23.3 (not triggered).

**Branch A — Q1 = fix (recommended default; now the binding branch per
D-11).**

1. [x] `lib/domain/rules/cycle_pnl.dart`: add a `ShareLot? shareLot`
       parameter to `stockPnL(...)`; the put-side strike becomes
       `shareLot?.assignmentStrike ?? assignedPutLeg.strike` (call-side
       `contracts` stays `calledAwayCallLeg.contracts`, Feature Invariant 25
       untouched). Thread the same parameter through `netResult(...)`'s
       internal call to `stockPnL`, and through both of
       `computeCyclePnl`'s call sites (`netResult(...)` and the direct
       `stockPnL(...)` assigned to `CyclePnl.stockPnL`) — `computeCyclePnl`
       already receives `shareLot` as its own parameter, so no plumbing
       above it changes.
2. [x] `lib/data/export/ledger_csv.dart`: mirror the same change in
       `_stockPnL(...)`. Move the existing `final assignment = await
       repository.getAssignmentForCycle(cycle.id);` fetch (currently after
       the `_stockPnL(...)` call) to **before** it, so `assignment` is
       available when `_stockPnL` is invoked, and pass it through.
3. [x] `test/domain/rules/cycle_pnl_test.dart`: update S-104's `stockPnL`/
       `netResult` unit tests to pass `shareLot: shareLot` explicitly,
       asserting the figures are unchanged (S-209, lines currently ~132-144).
       Add S-207 (mismatched strike) and S-208 (legacy/`null` `shareLot`)
       as new test groups per their `## Scenarios` fixtures.
4. [x] `test/data/export/ledger_csv_test.dart:178`: update the CSV row
       string from `'CR1,75,2,175.00,Called away,375.00,3.8'` to
       `'CR1,75,2,175.00,Called away,425.00,4.3'` — the CSV's
       `returnOnCapitalPct.toStringAsFixed(1)` rounds the raw `4.3456…%` to
       one decimal, **`4.3`**, not `4.35` (S-207's own precision note —
       do not copy the controller test's rounding into this file).
       `test/state/journal/journal_controller_test.dart:212-213`: update
       `closedPnl.netResult` from `375.00` to `425.00` and
       `returnOnCapitalPct` from `closeTo(3.83, 0.01)` to
       `closeTo(4.35, 0.01)` — this file asserts the raw `double`, not the
       CSV's rounded string, so its own two-decimal `closeTo` style is
       unaffected by the CSV's one-decimal formatting. Show each updated
       assertion **red** against the pre-fix formula first (the CSV row
       still reading `375.00,3.8`; the controller assertion still reading
       `375.00`/`closeTo(3.83, 0.01)`), then green after steps 1-2 land —
       the same red-before-green convention every CR-1/CR-3 guard this
       iteration already followed.
5. [x] `docs/architecture/wheel-triage.md` (~line 161-166, the CR-1
       write-up): add one sentence noting `stockPnL` now also prefers the
       retained assignment record, mirroring `peakCapitalCommitted`/
       `wheelBasis`.
6. [x] Add **Feature Invariant 36** to `wheel-triage-plan.md` (append-only —
       a new invariant, not an edit to an existing one) stating the final
       rule: "`stockPnL`'s put-side strike is `shareLot?.assignmentStrike ??
       assignedPutLeg.strike`, the same retained-record-preferred,
       leg-value-legacy-fallback rule the CR-1 remediation established for
       `peakCapitalCommitted`/`wheelBasis` (`## Feedback`, `### CR-1
       remediation`); the call-side `contracts` term is unaffected (Feature
       Invariant 25)." Cross-reference D-8/fix (`docs/plans/
       iteration-4-closeout-plan.md`).
7. [x] Residue grep: `grep -rn "stockPnL(" lib/ test/` — confirm every call
       site now passes `shareLot`/`assignment`, none left on the old
       two-argument shape.

**Done Criteria**: `flutter analyze`; `flutter test
test/domain/rules/cycle_pnl_test.dart test/data/export/ledger_csv_test.dart
test/data/export/ledger_export_test.dart
test/state/journal/journal_controller_test.dart`; `flutter test
--plain-name "S-207"`; `flutter test --plain-name "S-208"`; `flutter test
--plain-name "S-209"`; whole-repo `flutter test` green; step 7's grep shows
zero unconverted call sites.

**Predicted Files**: `lib/domain/rules/cycle_pnl.dart`,
`lib/data/export/ledger_csv.dart`, `test/domain/rules/cycle_pnl_test.dart`,
`test/data/export/ledger_csv_test.dart`,
`test/state/journal/journal_controller_test.dart`,
`docs/architecture/wheel-triage.md`, `docs/plans/wheel-triage-plan.md` (new
Feature Invariant 36 appended, not editing 25/27/14).

**Branch B — Q1 = leave. NOT TAKEN (superseded by D-11's "fix" answer) —
left below only as the historical record of the road not taken; do not
implement it.**

1. ~~`lib/domain/rules/cycle_pnl.dart`'s `stockPnL` doc comment: add a
       line recording this as a deliberate, named deviation (D-8/leave),
       cross-referencing `peakCapitalCommitted`'s differing strike source so
       a future reader does not mistake it for an unnoticed bug.~~
2. ~~`lib/data/export/ledger_csv.dart`'s `_stockPnL` doc comment: mirror
       the same note.~~

**Done Criteria**: `flutter analyze`; whole-repo `flutter test` count
unchanged from the pre-phase baseline (comment-only change, zero test
impact expected). *(Moot — Branch B is not taken.)*

**Predicted Files**: `lib/domain/rules/cycle_pnl.dart`,
`lib/data/export/ledger_csv.dart` (doc comments only). *(Moot — Branch B is
not taken.)*

---

### Phase 23.2: CR-6 checkpoint-record disposition — **Complete** (Q2 answered, D-12) (conductor)

Depended on: Q2 answered (done — D-12, which superseded D-9's recommended
default rather than selecting it). Independent of Phase 23.1/23.3.

1. [x] Appended the user's Q2 answer to `wheel-triage-plan.md`'s Phase 17
       Progress entry as a dated note closing out CR-6 — **not** D-9/(a)'s
       "permanent documentation gap" default (the user did not pick that;
       they supplied the missing fact), and **not** a generic "(b) something
       else" — the actual go-ahead record itself, explicitly labelled
       **retroactive** (attributed to the user's 2026-09-28 confirmation,
       not written to read as a contemporaneous Phase 17 record). See the
       diff to `wheel-triage-plan.md`.

**Done Criteria**: N/A — doc edit only, no code/tests touched. **Met.**

**Predicted Files**: `docs/plans/wheel-triage-plan.md` (Phase 17 `##
Progress` entry). **Touched, as predicted.**

---

### Phase 23.3: CR-8 notification copy — **NOT TRIGGERED** (Q3 = KEEP, D-13) (@developer)

**Q3 was answered "keep" (D-13). This phase does not run.** D-10/keep's
ratification is the final disposition; Phase 23.4 treats CR-8 as closed with
no diff to review, and no notification-copy file is touched anywhere in this
plan. The steps below are left as the historical record of what "change"
would have required, not as outstanding work.

**[NOT EXECUTED — Q3 = keep] 1.** `lib/core/notifications/notification_scheduler.dart:86`:
       change the body string from `'At $milestoneDte DTE — worth a look.'`
       to `'At $milestoneDte DTE.'`. Update the doc comment at line 75 that
       explains the phrase's wording for consistency.
**[NOT EXECUTED] 2.** `wheel-triage-plan.md`'s `### S-173` (~line 2037+):
       update the fixture's worked example from `"SBET $11 call is at 21
       DTE — worth a look."` to `"SBET $11 call is at 21 DTE."`.
**[NOT EXECUTED] 3.** `test/core/notifications/notification_scheduler_test.dart:57-58`:
       update the two verbatim assertions to the new string.
**[NOT EXECUTED] 4.** Do **not** touch `docs/brief.md:463` or
       `docs/brief-ledger.md:274` — both are the original product-spec
       documents' own frozen worked examples, outside this plan's writable
       scope.

**Done Criteria** *(moot — phase not triggered)*: `flutter analyze`;
`flutter test test/core/notifications/notification_scheduler_test.dart`;
`flutter test --plain-name "S-173"`; whole-repo `flutter test` green; tone
grep (`grep -rniE "recommend|we suggest|our analysis|buy signal|sell
signal|opportunity|guaranteed|you should" lib/`) stays clean.

**Predicted Files** *(moot — phase not triggered)*:
`lib/core/notifications/notification_scheduler.dart`,
`test/core/notifications/notification_scheduler_test.dart`,
`docs/plans/wheel-triage-plan.md` (`### S-173` text only). **None of these
are touched by this plan.**

---

### Phase 23.4: Final verification (@code-reviewer)

Depends on: Phase 23.1 Branch A (the only phase still outstanding — Phase
23.2 is Complete, Phase 23.3 is not triggered). This phase is the one that
actually closes Iteration 4 and runs last.

1. [x] Re-run `flutter analyze`, full `flutter test`, and `flutter build ios
       --simulator --no-codesign` fresh **on the post-`flutter pub upgrade`
       lockfile** (D-16 — only `built_collection` changed, `pubspec.lock` as
       it stands after that upgrade, not an earlier lockfile); confirm
       clean/green/exit-0 independently (do not cite this plan's or the
       prior session's numbers as a substitute). Per **D-14, do not fail or
       flag on the presence of `.git` commits** — the "no `.git` writes"
       criterion is retired; the `ios/`/`android/`-untouched half of the old
       step 8 still applies and is still checked in step 2 below.
       **Done: flutter analyze → No issues found; flutter test (whole
       repo) → 463 passed, 0 failed; flutter build ios --simulator
       --no-codesign → exit 0. `.git` commits present, not flagged, per
       D-14. No file under `ios/`/`android/` touched (`git diff --stat`).**
2. [x] Tick `wheel-triage-plan.md`'s Phase 23 nine-item checklist (~line
       3247+, currently all `[ ]`) against observed reality — one evidence
       line per item, not a bare checkmark. For step 8's git half, mark it
       **"retired per D-14"** rather than pass/fail; keep checking its
       `ios/`/`android/` half as written.
       **Done — see the diff to `wheel-triage-plan.md`'s `### Phase 23:
       Verification` block, all nine items now `[x]` with an evidence
       line each.**
3. [x] Tick every Iteration 4 Acceptance Criteria checkbox
       (`wheel-triage-plan.md`, ~line 287+, currently all `[ ]`) against
       current observed output. The "`android/` is untouched; no file under
       `ios/` beyond `flutter create`'s own defaults; no `.git` writes"
       criterion has its last clause retired per D-14 — tick the
       `android/`/`ios/` half against observed output as normal, and mark
       the "no `.git` writes" clause **"retired per D-14,"** not fail.
       **Done — all 22 boxes ticked with a consolidated verification note
       naming the fresh evidence for each.**
4. [x] Phase 23.1 Branch A is the live branch (D-11) — confirm S-207/S-208/S-209 are present,
       passing, and cross-referenced from the `### CR-1 remediation`/`###
       CR-1 remainder` `## Feedback` entries — add a one-line forward
       pointer there so a future reader lands on the superseding fix
       (Feature Invariant 36) rather than stopping at the original,
       now-partially-superseded CR-1 write-up.
       **Done — S-207/S-208/S-209 independently re-run and green; forward
       pointers added to both `### CR-1 remediation` and `### CR-1
       remainder, CR-3, CR-7, CR-8` entries.**
5. [x] Update `wheel-triage-plan.md`'s status header: mark Phase 23
       **Complete**; state Iteration 4 is fully closed (already joined by
       Iteration 5, independently verified); remove the "Phase 23 stays
       open" language this plan's own header edit (Phase 23.0) left in
       place. **Done (2026-09-28, Phase 23.4.1 re-verification) — the two
       WARNING findings that withheld this step at the first Phase 23.4
       pass (2a, 2b) are now both fixed and re-verified (Phase 23.4.1);
       zero new findings from the re-verification itself, so the condition
       that blocked this step no longer holds. See `wheel-triage-plan.md`'s
       status header and its `### Phase 23.4.1 re-verification` `##
       Feedback` entry.**
6. [x] Update this plan's own `## Progress`/`## Acceptance Criteria` to the
       same verified state, self-contained.
7. [x] **Separate, secondary item — the roll-planner hotfix (out of
       Iteration 4's own scope, folded in here only because no other review
       pass is scheduled to catch it):** diff-review
       `lib/features/roll/roll_planner_screen.dart` and
       `test/features/roll/roll_planner_screen_test.dart` against
       `docs/plans/roll-planner-add-candidate-bug-plan.md`'s own Predicted
       Files and claimed Done Criteria; re-run `flutter test
       test/features/roll/roll_planner_screen_test.dart
       test/state/roll/roll_planner_controller_test.dart`; confirm S-205/
       S-206 pass and the fix stayed screen-local as that plan's own
       Progress claims (no controller change). Record the verdict in
       `roll-planner-add-candidate-bug-plan.md`'s own `## Feedback`
       (currently empty) — ratify, or open a remediation item there, not in
       this plan. **Does not gate Iteration 4's own closure** (item 1 above
       can close independently of item 7's outcome) — it is reviewed here
       solely because it is the one other piece of unreviewed working-tree
       code and no dedicated review pass exists for it.
       **Done — RATIFIED, no remediation. 14 passed/0 failed
       (10 controller + 4 screen); S-205/S-206 pass; controller/its test
       confirmed untouched by `git diff --stat`. Verdict recorded in
       `roll-planner-add-candidate-bug-plan.md`'s `## Feedback`.**

**Done Criteria**: all of the above pass; `wheel-triage-plan.md`'s Phase 23
checklist and Iteration 4 Acceptance Criteria checkboxes reflect verified
reality; this plan's own checkboxes reflect the same;
`roll-planner-add-candidate-bug-plan.md` carries a recorded reviewer verdict
in its `## Feedback`.

**Predicted Files**: `docs/plans/wheel-triage-plan.md` (checkbox ticks,
status header, Phase 23 `## Progress` entry), `docs/plans/
iteration-4-closeout-plan.md` (this plan's own `## Progress`), `docs/plans/
roll-planner-add-candidate-bug-plan.md` (`## Feedback` section only).

---

### Phase 23.4.1: Remediate the two WARNING findings (2a, 2b) from Phase 23.4 (@developer)

**Status: Complete (2026-09-28).** Depends on: Phase 23.4's findings 2a/2b
(`wheel-triage-plan.md`'s `### Phase 23.4 final verification` `## Feedback`
entry) and the user's follow-up instruction to fix both in a bounded pass.
No new product decision — the policy is already decided (D-11 / Feature
Invariant 36); this phase only tightens the signature and fixes the one
dormant caller that never adopted it.

1. [x] **2a — `required ShareLot? shareLot`.** In
       `lib/domain/rules/cycle_pnl.dart`, change `stockPnL`'s and
       `netResult`'s `ShareLot? shareLot` parameter to `required ShareLot?
       shareLot`. In `lib/data/export/ledger_csv.dart`, same change to
       `_stockPnL`. Fix every call site the compiler then flags (production
       and test) — Phase 23.1 already threads `shareLot` through every live
       call site including S-208's deliberate `shareLot: null`, so this is
       expected to be a signature-only change with zero call-site edits, but
       confirm by compiling, not by assumption. Self-guarding; no new test
       required for this item (a compile error is the guard).
2. [x] **2b — `position_detail_controller.dart`'s `computeCyclePnl` call
       sources `shareLot` from `getAssignmentForCycle`, not
       `getShareLotForCycle`.** In `load()` (~line 273), keep the existing
       `shareLot = await _repo.getShareLotForCycle(cycle.id)` line and
       `PositionDetailState.shareLot` field completely unchanged (it keeps
       its documented "active lot only" meaning — do not repurpose it).
       Add a second, separate value sourced the way
       `journal_controller.dart:113-116` does —
       `await _repo.getAssignmentForCycle(cycle.id) ??
       _reconstructShareLot(cycleLegs)` — and pass *that* into
       `computeCyclePnl`'s `shareLot:` argument instead of the active-lot
       value. `_reconstructShareLot` does not need to move: duplicate the
       small private helper locally in `position_detail_controller.dart`
       (same shape as `journal_controller.dart`'s own, doc-commented as a
       deliberate duplication — logged in `## Assumption Log` with the
       reason, matching this codebase's existing `ledger_csv.dart`
       duplication precedent for small formula helpers) rather than
       exporting/importing it across state files, to keep this remediation
       pass's diff bounded to the one named file plus its test.
   - **Guard test first, red before green**: add a test to
     `test/state/positions/position_detail_controller_test.dart` (new S-id
     **S-210**, fixture per `## Scenarios`) that loads a closed cycle
     directly (bypassing navigation, as S-120 already does) with a retained
     assignment record whose strike differs from the put leg's own, and
     asserts `state.cyclePnl!.stockPnL`/`netResult`/`peakCapitalCommitted`
     match the Journal's own figures for the identical fixture (`250.00` /
     `425.00` / `9780.00`). Run it against the unfixed controller first,
     record the observed failure message, then apply the source fix and
     confirm green.
3. [x] Residue check: `grep -rn "stockPnL(\|netResult(" lib/ test/` — same
       shape as Phase 23.1's own step 7, re-run to confirm no fallout.

**Done Criteria**: `flutter analyze` clean; `flutter test --plain-name
"S-210"` green; `flutter test test/state/positions/
test/domain/rules/cycle_pnl_test.dart test/data/export/
test/state/journal/` green; whole-repo `flutter test` green (baseline 463);
tone grep (`grep -rniE
"recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should"
lib/`) and rules-purity grep (`grep -rl "package:flutter"
lib/domain/rules/`) both empty.

**Predicted Files**: `lib/domain/rules/cycle_pnl.dart`,
`lib/data/export/ledger_csv.dart`, `lib/state/positions/
position_detail_controller.dart`, `test/state/positions/
position_detail_controller_test.dart`, `docs/plans/
iteration-4-closeout-plan.md` (`## Scenarios` S-210, this phase's own
`## Progress`, status header), `docs/plans/wheel-triage-plan.md` only if a
new Feature Invariant is needed (not expected — 2a/2b are both refinements
of the already-recorded Feature Invariant 36, not a new rule).

## Files Affected

See each phase's **Predicted Files**. No file under `ios/` or `android/`.
No `.git` writes by any phase in this plan (see `## Notes` — the repo's
`.git` state is the user's call, not acted on here).

## Notes

- **`stockPnL`/`peakCapitalCommitted` strike-source split was found, not
  invented, by the CR-1 remediation entry itself** (`wheel-triage-plan.md`:
  "One adjacent inconsistency observed, deliberately not fixed here"). This
  plan's Q1 is that flagged item, finally put to the user rather than left
  open a second time.
- **Ledger-entry immutability vs. scenario-text correction.** This plan
  treats `wheel-triage-plan.md`'s numbered "Feature Invariants" as that
  file's Ledger-equivalent (immutable, supersede-only — matching how
  Iteration 5's D-10/D-13 already superseded Feature Invariants 11/8 by
  pointer rather than by editing them) and treats Scenario "Expected
  outcome" text as correctable in place (matching CR-2's precedent at
  S-104). Feature Invariant 14 was therefore left untouched and superseded
  by D-7; S-029 was corrected in place. Both dispositions are visible in the
  diff to `wheel-triage-plan.md` from this session.
- **RESOLVED (D-14): the "no source control"/"`.git` exists despite CLAUDE.md's
  claim" item this Notes section previously flagged is no longer a
  discrepancy.** The user confirmed (2026-09-28) they use git and that the
  "deliberately not a git repository" constraint dated from the project's
  earliest builds. The constraint is retired; `wheel-triage-plan.md`'s three
  now-superseded lines are left untouched per D-14 (supersede, don't edit);
  `CLAUDE.md` was updated by the user themselves, outside this plan's
  writable scope either way. **No phase in this plan runs any git write
  command** — that remains true, but is no longer a constraint this plan is
  merely respecting under protest; it simply isn't this plan's job to commit
  anything. The roll-planner change
  (`lib/features/roll/roll_planner_screen.dart`,
  `test/features/roll/roll_planner_screen_test.dart`) is still uncommitted
  as of this session — whether/when to commit it is the user's own call,
  still not acted on here.
- **RESOLVED (D-15): the "CLAUDE.md's `456` vs. the observed `458`" item
  this Notes section previously flagged is no longer a discrepancy to
  track.** The user removed the hardcoded test-count line from `CLAUDE.md`
  entirely, calling it a maintenance burden. This plan's own dated evidence
  (458 passed as of 2026-09-28, pre-Phase-23.1) stays recorded in `##
  Progress`/`## Acceptance Criteria` as usual — D-15 is about `CLAUDE.md`
  specifically, not about this plan no longer citing counts.
- **Still owed from Iteration 5, unrelated to this plan**: the user's manual
  simulator launch, and the optional `docs/brief.md:336/453` pointer
  (`rule-versioning-plan.md`'s Feedback #8c). Not scheduled here.
- **UPDATED (D-16): `flutter pub upgrade` was run (user-authorised) and did
  not resolve Phase 24 Assumption #3's `build_runner` crash** — only
  `built_collection` moved (`5.1.1` → `5.1.2`); the codegen stack's exact
  version pins (`build_runner`, `riverpod_generator`, `drift_dev`,
  `freezed`, `json_serializable`, `custom_lint`, `riverpod_lint`) are what
  hold 50 other packages below their latest versions, and
  `riverpod_generator 2.x`'s own `analyzer <8.0.0` cap is the actual
  ceiling. **Open follow-up question for the user, not planned as a
  phase**: `grep -rln "@riverpod\|riverpod_annotation" lib/` returns
  nothing — the codebase is hand-written `StateNotifier`s throughout
  (CLAUDE.md's own documented deviation) — so is `riverpod_generator`
  (and, with it, `riverpod_lint`) dead weight that could be dropped,
  loosening the whole codegen stack's pins at the cost of bumping
  `freezed`/`drift_dev`/`json_serializable` majors and regenerating every
  generated file? This is a dependency change and needs the user's
  explicit go-ahead (CLAUDE.md: ask before adding/changing a dependency)
  before any plan schedules it.
- **Why Phase 23.1/23.3 are `@developer`, not `@data-architect`**: neither
  touches the schema, a model, or a repository method signature —
  `getAssignmentForCycle` already exists (added under CR-1) and is only
  consumed, not extended. This mirrors how CR-1's own consumer fix
  (`JournalController`) and CR-3/CR-7/CR-8 were all `@developer` work, with
  only CR-1's data-layer half going to `@data-architect`.

## Progress

- [x] Phase 23.0: Coordinator ratification pass — Complete (2026-09-28).
      D-1–D-7 recorded above; `wheel-triage-plan.md` diff carries the status
      header pointer and the S-029 correction. Ratifications independently
      re-verified this session by direct read (not carried forward from a
      prior session's report): S-104's "Expected outcome" text, the Phase
      16/17 Assumption Log's "(a)"/"(b)" corrections, and
      `assignment_flow_screen.dart`'s freely-editable strike field
      (confirming CR-5's finding still holds in the current tree).
- [x] Question Round: answered by the user (2026-09-28, verbatim "yes, yes
      I approved, yes keep it") — Q1 = FIX (D-11), Q2 = go-ahead confirmed
      (D-12), Q3 = KEEP (D-13). Three further decisions recorded the same
      session: D-14 (git constraint retired), D-15 (no test counts in
      `CLAUDE.md`), D-16 (`flutter pub upgrade` outcome).
- [x] Phase 23.1: **Complete (2026-09-28).** Branch A (Q1 = fix, D-11)
      implemented in full — steps 1-7 all done. Baseline before starting:
      `flutter analyze` clean, whole-repo `flutter test` 458 passed, 0
      failed.
      - Steps 1-2 (source): `stockPnL`/`netResult`
        (`lib/domain/rules/cycle_pnl.dart`) and `_stockPnL`
        (`lib/data/export/ledger_csv.dart`) both gained `ShareLot? shareLot`;
        put-side strike is `shareLot?.assignmentStrike ??
        assignedPutLeg.strike`; the `getAssignmentForCycle` fetch in
        `ledger_csv.dart` was moved before the `_stockPnL` call. Both of
        `computeCyclePnl`'s call sites (`netResult(...)`, the direct
        `stockPnL(...)` assigned to `CyclePnl.stockPnL`) now pass `shareLot`
        through; no plumbing above `computeCyclePnl` changed.
      - **Red-first, observed before any test-file edit** (source fix
        landed, test files still on their pre-fix assertions), run:
        `flutter test test/domain/rules/cycle_pnl_test.dart
        test/data/export/ledger_csv_test.dart
        test/data/export/ledger_export_test.dart
        test/state/journal/journal_controller_test.dart` → 2 failures, both
        exactly the two AC-3-predicted stale assertions:
        - `ledger_csv_test.dart` CR-1 (both `DriftWheelRepository` and
          `InMemoryWheelRepository`): `Expected: 'CR1,75,2,175.00,Called
          away,375.00,3.8' Actual: 'CR1,75,2,175.00,Called
          away,425.00,4.3'`.
        - `journal_controller_test.dart` CR-1: `Expected: Decimal:<375>
          Actual: Decimal:<425>` (at the `netResult` assertion, line 212).
        No other test in any of the four files failed — confirms the fix is
        a no-op everywhere assignmentStrike matched the put leg's own
        strike (every fixture except CR-1/S-207).
      - Step 3: `test/domain/rules/cycle_pnl_test.dart` — S-104's two direct
        `stockPnL`/`netResult` calls now pass `shareLot: shareLot`
        explicitly (S-209, figures unchanged: `stockPnL` `400.00`,
        `netResult` `674.80`). Added `S-207` group (4 tests: `stockPnL`
        `250.00`, `netResult` `425.00`, `peakCapitalCommitted` unchanged at
        `9780.00`, raw `returnOnCapitalPct` `closeTo(4.3456, 0.0001)`) and
        `S-208` group (1 test: `stockPnL` falls back to `assignedPutLeg
        .strike` when `shareLot: null`, `200.00`, bit-for-bit identical to
        the pre-fix formula).
      - Step 4 (green after steps 1-2): `ledger_csv_test.dart:178` CSV row
        updated to `'CR1,75,2,175.00,Called away,425.00,4.3'`;
        `journal_controller_test.dart:212-213` updated to `netResult
        Decimal.parse('425.00')`, `returnOnCapitalPct closeTo(4.35, 0.01)`.
      - Step 5: one sentence added to `docs/architecture/wheel-triage.md`'s
        CR-1 write-up (~line 166-170) noting `stockPnL`/`_stockPnL` now also
        prefer the retained assignment record for the put-side strike,
        cross-referencing Feature Invariant 36.
      - Step 6: Feature Invariant 36 appended to `wheel-triage-plan.md`'s
        `## Feature Invariants` list (after item 35, append-only; 14/25/27
        untouched).
      - Step 7 residue grep (`grep -rn "stockPnL(" lib/ test/`): every hit
        (2 in `lib/domain/rules/cycle_pnl.dart`, 2 in
        `lib/data/export/ledger_csv.dart`, 3 in
        `test/domain/rules/cycle_pnl_test.dart`) passes `shareLot`
        explicitly (S-208's own call passes `shareLot: null` on purpose,
        per its own fixture spec) — zero left on the old two-argument
        shape. Same check for direct `netResult(` callers — all pass
        `shareLot` too.
      - **Final focused run**: `flutter test
        test/domain/rules/cycle_pnl_test.dart
        test/data/export/ledger_csv_test.dart
        test/data/export/ledger_export_test.dart
        test/state/journal/journal_controller_test.dart` → **33 passed, 0
        failed**. `flutter test --plain-name "S-207"` → **5 passed, 0
        failed** (the 4 S-207 tests plus the S-208 test, which also matches
        the substring filter since its own group name reads "...leg-strike
        fallback (edge case of S-207)"). `flutter test --plain-name
        "S-208"` → **1 passed, 0 failed** (standalone, S-208's own test
        only). `flutter test --plain-name "S-209"` → **2 passed, 0
        failed**.
      - **Whole-repo `flutter test`**: **463 passed, 0 failed** (458
        baseline + 5 new: 4 in the new S-207 group, 1 in the new S-208
        group; S-104's two existing tests were edited in place, not added,
        so they don't change the count).
      - `flutter analyze`: **No issues found!** (after fixing two `$`
        string-interpolation typos the new test literals introduced —
        `'putLeg.strike ($50 both)'` and `'peakCapitalCommitted stays
        $9,780.00'` both needed escaping to `\$50`/`\$9,780.00`; caught by
        `flutter analyze` itself, not silently left broken).
      - Tone grep (`grep -rniE
        "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should"
        lib/`) — empty, as required.
- [x] Phase 23.2: Complete (2026-09-28). CR-6's go-ahead record appended to
      `wheel-triage-plan.md`'s Phase 17 Progress entry, explicitly labelled
      retroactive per D-12. See the diff to `wheel-triage-plan.md`.
- [x] Phase 23.3: **Not triggered** (2026-09-28) — Q3 = KEEP (D-13). No file
      touched; ratification of the existing shipped copy stands.
- [x] Phase 23.4: **Complete, this session (2026-09-28)**, except step 5
      (deliberately not done — see that step's own note and `## Feedback`
      below). All Done Criteria that don't depend on step 5 are met: fresh
      `flutter analyze` (0 issues), whole-repo `flutter test` (463
      passed/0 failed), `flutter build ios --simulator --no-codesign`
      (exit 0), S-207/S-208/S-209 re-confirmed green, tone and purity
      greps clean, no `ios/`/`android/` file touched. `wheel-triage-plan.md`'s
      Phase 23 nine-item checklist and Iteration 4 Acceptance Criteria are
      ticked against this observed output; forward pointers added at
      `### CR-1 remediation`/`### CR-1 remainder`. The roll-planner hotfix
      is independently reviewed and RATIFIED
      (`roll-planner-add-candidate-bug-plan.md`'s own `## Feedback`). Two
      new WARNING findings from this pass's own additional rulings (2a,
      2b) are why Phase 23 is not marked Complete in `wheel-triage-plan.md` —
      full detail in `## Feedback` below.
- [x] Phase 23.4.1: **Complete (2026-09-28).** Both WARNING findings fixed
      in one bounded pass. Baseline before starting: `flutter analyze`
      clean, whole-repo `flutter test` 463 passed/0 failed.
      - **2a**: `stockPnL`/`netResult` (`lib/domain/rules/cycle_pnl.dart`)
        and `_stockPnL` (`lib/data/export/ledger_csv.dart`) all changed
        `ShareLot? shareLot` → `required ShareLot? shareLot`. Verified
        zero call-site fallout by compiling (`flutter analyze` → No issues
        found, immediately after the signature change, before touching any
        other file) — confirms Phase 23.1 had already threaded `shareLot`
        through every call site, including S-208's deliberate
        `shareLot: null`.
      - **2b, red-first**: added `S-210` to
        `test/state/positions/position_detail_controller_test.dart` (fixture
        per `## Scenarios`, loading a closed cycle with a mismatched
        retained assignment strike directly through
        `PositionDetailController`, bypassing navigation as S-120 does).
        Run against the unfixed controller: `flutter test --plain-name
        "S-210"` → **1 failed**: `Expected: Decimal:<250> Actual:
        Decimal:<200>` (line 397, the `stockPnL` assertion) — the unfixed
        controller used the put leg's own strike (`50.00`) via
        `getShareLotForCycle` instead of the retained assignment's
        (`49.50`), exactly the dormant defect ruling 2b named.
      - **2b, fix**: `lib/state/positions/position_detail_controller.dart`'s
        `load()` — the existing `shareLot` local (fed by
        `getShareLotForCycle`) and the `PositionDetailState.shareLot` field
        are byte-for-byte unchanged, still "active lot only." A new
        `pnlShareLot` local — `(await _repo.getAssignmentForCycle(cycle.id))
        ?? _reconstructShareLot(cycleLegs)`, mirroring
        `journal_controller.dart:113-116` — is what's now passed into
        `computeCyclePnl`'s `shareLot:` argument. `_reconstructShareLot` is
        duplicated locally (private, doc-commented) rather than exported
        from `journal_controller.dart` — see `## Assumption Log`.
      - **2b, green**: `flutter test --plain-name "S-210"` → **1 passed, 0
        failed**.
      - Step 3 residue grep (`grep -rn "stockPnL(\|netResult(" lib/
        test/`): 13 hits, all inside `cycle_pnl.dart`/`ledger_csv.dart`
        (definitions/internal calls) or `cycle_pnl_test.dart` (already
        passing `shareLot` since Phase 23.1) — zero fallout, zero new call
        sites needing a fix.
      - **Focused run**: `flutter test test/state/positions/
        test/domain/rules/cycle_pnl_test.dart test/data/export/
        test/state/journal/` → **74 passed, 0 failed**.
      - **Whole-repo `flutter test`**: **464 passed, 0 failed** (463
        baseline + 1 new: S-210).
      - `flutter analyze`: **No issues found!**
      - Tone grep and rules-purity grep (`grep -rl "package:flutter"
        lib/domain/rules/`): both empty, as required.
- [x] Phase 23.4.1 re-verification: **Complete (2026-09-28), RATIFIED —
      Phase 23 is now CLOSED.** Fresh, independent run: `flutter analyze` →
      No issues found. Whole-repo `flutter test` → **464 passed, 0
      failed** (matches the developer's claimed count exactly). `flutter
      test --plain-name "S-210"` → 1 passed, 0 failed (standalone).
      `flutter build ios --simulator --no-codesign` → exit 0. Tone grep and
      rules-purity grep both empty. Diff-checked against Phase 23.4.1's own
      Predicted Files: exact match (`cycle_pnl.dart`, `ledger_csv.dart`,
      `position_detail_controller.dart`, its test, this plan) — no
      out-of-scope file touched, no new Feature Invariant added to
      `wheel-triage-plan.md` (37 does not exist, as predicted).
      **2a verified**: both `stockPnL`/`netResult`
      (`cycle_pnl.dart:74,89`) and `_stockPnL` (`ledger_csv.dart:106`) now
      read `required ShareLot? shareLot` — confirmed by direct diff read,
      not just the developer's claim.
      **2b verified**: `position_detail_controller.dart`'s `shareLot` local
      and `PositionDetailState.shareLot` field are untouched (confirmed by
      diff — only the `computeCyclePnl` call site's argument changed from
      `shareLot` to the new `pnlShareLot`); `pnlShareLot` sources
      `getAssignmentForCycle(cycle.id) ?? _reconstructShareLot(cycleLegs)`,
      byte-for-byte the same shape as `journal_controller.dart:113-116`'s
      own expression (confirmed by direct comparison of both files). The
      claimed red-first figure (`Actual: Decimal:<200>`) is independently
      corroborated by arithmetic, not merely re-trusted: pre-fix, a closed
      cycle's `getShareLotForCycle` is `null` (Feature Invariant 14), so
      `stockPnL` falls back to the put leg's own strike `$50.00`, giving
      `(52.00-50.00) x 100 x 1 = $200.00` — exactly the claimed pre-fix
      figure. (Did not revert source to literally re-run red, since that
      would require a source edit outside this review's writable scope;
      the arithmetic match plus the passing post-fix S-210 is sufficient
      corroboration.)
      **Duplication ruling (`_reconstructShareLot`): RATIFIED, no
      remediation.** Same shape, same reasoning as the already-accepted
      `_dateText` duplication (`wheel-triage-plan.md` `## Feedback`, "The
      five other `_dateText`-shaped y-m-d formatters... were not
      consolidated," ratified there for the same "don't widen the diff
      beyond this phase's Predicted Files" reason) and as
      `ledger_csv.dart`'s own Feature-Invariant-11-forced duplication of the
      rules-engine formulas (`wheel-triage-plan.md` `## Feedback`,
      "`ledger_csv.dart`'s duplicated money formulas... RATIFIED as-is").
      Four lines, private, doc-commented, cross-checked by S-210 against
      the Journal's own figure for the identical fixture — this is
      DRY-adjacent, not architectural, and DRY violations are "rarely
      blocking" per this reviewer's own standing rule. The Assumption Log's
      own flag (promote to a shared location if a third caller ever needs
      the same fallback) is the right disposition; no action needed now.
      **Open-cycle / put-only parity, confirmed by existing tests** (per
      the coordinator's specific request): while a cycle is
      `holdingShares`, `getShareLotForCycle` and `getAssignmentForCycle`
      read the same underlying row —
      `test/data/wheel_repository_contract_test.dart:885-886` proves
      `getShareLotForCycle` returns the exact `ShareLot` object
      `recordAssignment` just created (object equality, not just
      non-null), and `:980-988` (inside the `getAssignmentForCycle` group)
      exercises both accessors on the same still-open cycle and gets the
      same recorded values from each. For a put-only cycle (no assignment
      ever reached), `:1012-1034` asserts both `getAssignmentForCycle` and
      `getShareLotForCycle` return `null`. No `PositionDetailController`-
      level test asserts a specific open-cycle `cyclePnl` dollar figure
      before/after this change (the two pre-existing open-cycle assertions
      at lines 299/517/527 check only `hasFeeGap`, not `stockPnL`/
      `netResult`) — flagged as a 💡 SUGGEST, not blocking: the
      repository-level object-identity proof plus the unchanged 464-test
      whole-suite pass (no open-cycle test regressed) is sufficient
      evidence of no behavior change for this closure, and the same gap
      already existed for `journal_controller.dart`'s identical pattern
      since Phase 23.1 without being treated as blocking then either.

## Assumption Log

Every disposition made in this plan's sessions (Phase 23.0's ratification
pass, recording Q1–Q3's answers plus D-14–D-16, Phase 23.1's implementation,
and Phase 23.4.1's remediation) was either a direct ratification of
already-shipped/user-confirmed fact, a documentation correction with a
precedented mechanism, or a literal, unambiguous execution of an
already-decided spec (D-8/fix for Phase 23.1; the reviewer's own 2a/2b
rulings for Phase 23.4.1) — never a Decide-and-Log guess on a genuinely open
question. Two formatting-only calls, neither substantive:

- Phase 23.1's two new test groups (S-207/S-208) were placed at the end of
  `cycle_pnl_test.dart`, after the existing S-109 group, rather than inline
  after S-104 — minimal diff noise against the existing file.
- Phase 23.4.1's `_reconstructShareLot` helper was **duplicated locally**
  in `lib/state/positions/position_detail_controller.dart` (private,
  doc-commented as a deliberate duplication) rather than promoted to a
  shared, exported location and imported from `journal_controller.dart`.
  Both files live in `lib/state/`, so no Feature Invariant 11-style
  layer-boundary rule forced the duplication the way it does for
  `ledger_csv.dart`'s own formula helpers — this was a scope-boundedness
  call, not an architectural one: ruling 2b's remediation was scoped to
  "the one named file," and promoting/exporting the helper would have
  touched `journal_controller.dart` (outside this sub-phase's Predicted
  Files) to save four lines of duplication. If a third `computeCyclePnl`
  caller ever needs the same fallback, that is the point at which
  promoting it to a shared location (e.g. alongside `cycle_pnl.dart`'s own
  functions) stops being over-engineering for two call sites and becomes
  the right call — flagged here for whoever adds that caller, not acted on
  now.

Phase 23.4's reviewer appends here per the usual protocol if it hits
genuine ambiguity not resolved by D-1–D-16 or by 2a/2b's own rulings.

## Feedback

### Phase 23.4 (@code-reviewer) — final verification, 2026-09-28

**All six technical gates green, fresh, on the post-`flutter pub upgrade`
lockfile**: `flutter analyze` 0 issues; whole-repo `flutter test` 463
passed/0 failed; `flutter build ios --simulator --no-codesign` exit 0;
tone grep and rules-purity grep both empty; S-207/S-208/S-209 independently
re-run and green; `git diff --stat` confirms no `ios/`/`android/` file
touched. Diff vs Phase 23.1's own Predicted Files: conforms (the only
extras — `CLAUDE.md`, `pubspec.lock` — are already-ledgered user edits,
D-14/D-15/D-16, not new findings).

**Two new WARNING findings, from the two rulings requested outside Phase
23.1's own diff** (full detail in `wheel-triage-plan.md`'s `## Feedback`,
`### Phase 23.4 final verification` — not restated here):

- 🟡 **2a — `stockPnL`/`netResult`/`_stockPnL`'s `shareLot` parameter is
  optional, not `required`.** No live caller is affected (`computeCyclePnl`,
  the sole production entry point, already requires it); the risk is a
  future direct caller silently landing on the legacy-fallback strike with
  no compiler signal. → `@developer`: `required ShareLot? shareLot` on all
  three signatures; self-guarding (a compile error), no new test needed.
- 🟡 **2b — `position_detail_controller.dart` never adopted CR-1's
  `getAssignmentForCycle`-preferred pattern; only `getShareLotForCycle`.**
  Traced the live navigation graph: no reachable UI path renders `cyclePnl`
  for a closed cycle that actually has a retained assignment record today
  (confirmed, not merely assumed) — so this is dormant, not a live wrong
  figure. It is the same "relies on no caller doing X today" reasoning
  class CR-3/D-3 already named as having produced a real defect once. →
  `@developer`: source `shareLot` the same way
  `journal_controller.dart:113-116` does; guard with a controller test that
  loads a closed cycle with a mismatched retained assignment strike
  directly (bypassing navigation, as the existing S-120 test at line ~304
  already does) and asserts parity with the Journal's own figure — red
  before, green after.

**Disposition**: neither finding is CRITICAL (no unmet acceptance
criterion, no live wrong figure, no failing test) — both are WARNING per
this reviewer's own severity rules, which route to the user rather than
auto-close. Phase 23.4's own Done Criteria (steps 1–4, 6, 7) are met; step
5 (mark Phase 23 Complete) is deliberately not done — see that step's own
note in `### Phase 23.4: Final verification` above. This plan's Phase 23.4
is otherwise Complete.

**Roll-planner hotfix**: RATIFIED, no remediation — verdict and full detail
recorded in `docs/plans/roll-planner-add-candidate-bug-plan.md`'s own
`## Feedback`, per this plan's own instruction not to record it here.

**Awaiting**: the user's decision — approve as-is (mark Phase 23 Complete
despite 2a/2b, logging them as accepted, deferred risk), or route 2a/2b to
`@developer` as a short follow-up turn before closing.
