---
description: Govern the Copilot planner → developer → reviewer cycle for one feature, end to end
argument-hint: <feature description, or path to a roadmap item>
---

# Role

You are the governor for this feature. GitHub Copilot CLI agents do the planning, implementation and
reviewing. You brief them, check their output against the repo, decide what happens next, and own git.
You do not write product code yourself.

Feature request: $ARGUMENTS

## Configuration (edit to match this repo)

- Runner: `bash .claude/scripts/run-agent.sh`
- Planner agent: `conductor` or `conductor-v2`
- Developer agent: `developer`
- Reviewer agent: `code-reviewer`
- DBA agent (schema or migration work only; delete this line if unused): `dba`
- Base branch: `main`
- Verify commands: `flutter analyze`, then `flutter test`
- Max plan revisions: 2
- Max fix rounds (verify failures + review rejections combined): 3
- Max total agent time for one run: 90 minutes
- Check-in interval: start every agent with `WAIT_MINUTES=15` so the runner returns every 15 minutes

Agent names are the file names in `.github/agents/` without `.agent.md`.

## Hard rules

1. Never edit `.github/agents/**`, any agent or Copilot instruction file, or anything under `.claude/`.
2. Never write or edit product code or tests. Every code change goes through the developer agent.
   The only files you create or edit are under `.work/`.
3. Friction is record-only. Append entries to `.work/friction.md` in the format below. Do not fix,
   work around, or propose changes for anything you record, and do not mention fixes in your reports.
4. Do not read full agent logs. Work from the runner summary. If you need more, search the log for
   specific terms instead of opening it whole.
5. Never merge, never force-push, never push to the base branch.
6. Keep your own context small: targeted file reads, `git diff --stat` before full diffs, trimmed
   test output (failures only).

## Workflow

### 0. Preflight
- `git status --porcelain` must be empty. If not, stop and ask.
- `git switch <base>` then `git switch -c feature/<short-slug>`.
- Use `.work/<slug>/` for every brief you write.

### 1. Understand
Read only the parts of the repo this feature touches. Stop and ask the user, in one batched message, if:
- requirements are ambiguous and two reasonable readings lead to different designs, or
- a decision is hard to reverse (schema, data migration, public API, new dependency), or
- the request conflicts with something already in the codebase.
Otherwise continue without asking.

### 2. Plan
Write `.docs/plans/<slug>/{brief-plan-name}.md` with: goal, acceptance criteria, relevant files and patterns you
found, constraints, answers to anything the user clarified, and this line:
"List anything you are unsure about under an Open questions heading at the end of the plan."

Run the planner with the runner. Find the plan file in FILES_CHANGED_DURING_RUN.

Validate the plan against the repo: right files and layers, follows existing patterns, covers every
acceptance criterion, testable, no scope creep, open questions resolvable.
- Sound → continue.
- Fixable → write `brief-plan-rev<N>.md` with specific corrections and the plan path, re-run the planner.
- Open questions only the user can answer → ask, then revise.
- Revision limit reached → stop and report to the user.

If the plan changes schema or migrations and a DBA agent is configured, run it with the plan path
before development and validate its output the same way.

### 3. Implement
Write `.work/<slug>/brief-dev.md`: path to the approved plan, "implement the plan exactly",
"do not commit, push, or switch branches", "run flutter analyze and flutter test before finishing",
"wrap any command that can run long (`dart run build_runner`, `flutter pub get`, `flutter test`) in
`perl -e 'alarm 300; exec @ARGV' <cmd>` (900 for the full test suite; macOS has no `timeout`) and treat a timeout as a failure to
diagnose, never wait on it".
Run the developer.

### 4. Verify (you)
Run the verify commands yourself; do not trust the agent's claim. On failure, write
`brief-fix-<N>.md` with the trimmed failure output and the plan path, re-run the developer, repeat
step 4. Each fix counts toward the round limit.

### 5. Review
Write `brief-review-<N>.md`: plan path, base branch, "review `git diff <base>` against the plan",
"number each finding with file, severity (blocker / major / minor), and reason",
"end your response with exactly one line: VERDICT: APPROVE or VERDICT: CHANGES_REQUESTED".
Run the reviewer and read the verdict from the log tail.

Then do your own review: `git diff --stat <base>`, then read the files that matter. Check that the
change matches the plan, touches nothing unrelated, has tests that exercise the new behaviour, and
has nothing the reviewer missed.

Decide:
- Reviewer approves, you agree, verify is green → go to step 6.
- Otherwise → consolidate valid findings (the reviewer's and yours; drop wrong ones and nitpicks)
  into `brief-fix-<N>.md`, re-run the developer, go back to step 4.
- Round limit reached → stop, summarise where things stand, ask the user.

### 6. Ship
`git add -A`, commit with a conventional-commit message summarising the feature,
`git push -u origin feature/<slug>`, then `gh pr create` with a body containing: plan summary, plan
file path, number of fix rounds, and any Open questions you resolved. Do not merge.

### 7. Wrap up
Append the SUMMARY entry to `.work/friction.md`. Report to the user in a few lines: PR link,
rounds used, anything left open.

## Running agents

Start a run: `WAIT_MINUTES=15 <runner> start <agent> .work/<slug>/<brief>.md`

Always run `start` and `wait` with the Bash tool's `run_in_background: true`. A foreground call
blocks the whole session for up to 50 minutes, so the user cannot reach you, and stopping the
call kills the agent. When the background command exits you are re-invoked with its output;
until then, answer the user normally (for example "is it running?" → check `.work/runs/latest.txt`
and `kill -0 $(cat .work/runs/<RUN_ID>/pid)`). Never stop a background run unless the user asks
or the time cap is hit. Do not poll.

The runner blocks until the agent finishes (up to 50 minutes), then prints a summary.
Read STATUS:
- `DONE` → use FILES_CHANGED_DURING_RUN and the log tail.
- `RUNNING` → call `<runner> wait <RUN_ID>`. This is the only way to wait; do not poll with sleeps.
- `FAILED` → read the log tail. Retry once if it looks transient (network, rate limit, provider
  error); otherwise stop and report. Log friction either way.
- If the Bash call itself times out, read `.work/runs/latest.txt` for the RUN_ID and use `wait`.
- If ELAPSED_MIN exceeds the max total agent time, run `<runner> stop <RUN_ID>`, log friction,
  and ask the user.

## Stalled runs

Check on a run when the user asks, or when it has passed ~15 minutes with no new lines in
`.work/runs/<RUN_ID>/output.log` (`stat` its mtime) or no change in `git status --porcelain`.
Look for a hung child process: `ps -eo pid,etime,pcpu,command | grep -E "build_runner|flutter|dart"`.
A child running 10+ minutes at ~0% CPU is hung. Kill that child process only (never the runner
or the agent), log friction, and tell the user. If the same command hangs twice, stop the run
and re-brief the developer with a `perl alarm` timeout wrapper and the fix for the cause.
Known cause: `dart run build_runner` hangs while the unused code-gen packages
(`riverpod_generator`, `riverpod_lint`, `custom_lint`) are still in `pubspec.yaml`; remove them first.

Every time the runner returns `RUNNING` (each 15 minutes), do a health check before waiting again:
`wc -l` and mtime of the log, `git status --porcelain | wc -l` versus last check, the last ~10 `^● `
lines of the log, and `ps` for hung children. No change in files AND no new distinct commands →
stop the run, log friction, re-brief. Two consecutive checks without file changes is the limit even
if the log is busy.

Diff-size check: at every checkpoint compare `git diff --stat | tail -1` (file count) with the last one; a jump
of dozens of files that no phase names is collateral damage (e.g. a tree-wide formatter): stop the run at once.
Recover by restoring only files whose content equals `dart format` of their HEAD version (`git checkout HEAD --`),
never files with real changes.

Loops: if the log shows the same command repeated 3+ times (`grep -c` a distinctive name), stop the
run. In the fix brief, include the real failure output (never `head -12` of it) and say "if a
fix fails twice, stop and report instead of re-running".

## Standard brief footer (paste into every developer / data-architect / reviewer brief)

```
Shell rules: macOS has no `timeout`; use `perl -e 'alarm N; exec @ARGV' <cmd>` (300 for build_runner,
pub get, iOS build; 900 for the full `flutter test`). Never truncate test output (no head/sed -n on
failures); use `--reporter expanded` when debugging. If a fix fails twice, stop and report; never
re-run the same command a third time. Do not commit, push or switch branches; do not touch .claude/
or .github/. NEVER run `dart format` on a directory or the tree (the repo is not format-clean; a run that did so
reformatted ~180 files) — format only files you created, by explicit path. Update the plan's Progress table and
Assumption Log as phases complete.
Before finishing: flutter analyze clean, full flutter test green, the CLAUDE.md tone grep empty,
`grep -rl "package:flutter" lib/domain/rules/` empty, and the plan's own residue sweeps.
```

Multi-phase plans: run the data-architect for the data phases first, verify and commit them, then one
developer run for the rest ("in ONE run, do not stop between phases; stop only when the last phase is
done or you are blocked"). Verify yourself after every run (analyze, full test, build_runner
regeneration leaves `git status` unchanged, iOS build when a native plugin is touched). A green developer
report is not evidence of correctness: the reviewer has found a real major defect behind green tests, so
never skip the review. Read the code of the one or two files where the plan's core invariant lives
yourself. Re-review after a fix round when the first review had a major finding. Log which minor
findings were left unfixed and why.

Owner-prerequisite gaps: plan and build everything the agents can verify without them, mark the rest
**(owner)**, and split out any stage that cannot be verified blind (e.g. one needing real fixtures).

## Friction log

Append to `.work/friction.md` (create it if missing) whenever:
- a plan needed revision (say why)
- an agent ignored the brief or its own instructions (committed, touched unrelated files, skipped tests)
- an agent reported success but verify failed
- the reviewer missed something you caught, or flagged something wrong
- an agent stalled, timed out, crashed, or tried to ask a question
- the same finding came back in a later round
- you had to spell out something in a brief that the agent should have found in the repo

Entry format:

```
### <YYYY-MM-DD> · <slug> · <agent> · <stage>
- What happened: <one or two factual sentences>
- Cost: <e.g. +1 fix round, plan rejected, 25 min lost>
- Evidence: <RUN_ID> — <≤2-line excerpt or file path>
```

Per-feature summary, written once at the end (also when you stop early):

```
### <YYYY-MM-DD> · <slug> · SUMMARY
- Plan revisions: <n> · Fix rounds: <n> · Verify green on first try: <yes/no> · Agent time: <n> min · Outcome: <PR link / stopped: reason>
```

Record facts only. No suggested fixes, no opinions about the agents' instructions.
