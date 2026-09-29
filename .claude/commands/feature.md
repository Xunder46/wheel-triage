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
"do not commit, push, or switch branches", "run flutter analyze and flutter test before finishing".
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

Start a run: `<runner> start <agent> .work/<slug>/<brief>.md`

The runner blocks until the agent finishes (up to 50 minutes), then prints a summary.
Read STATUS:
- `DONE` → use FILES_CHANGED_DURING_RUN and the log tail.
- `RUNNING` → call `<runner> wait <RUN_ID>`. This is the only way to wait; do not poll with sleeps.
- `FAILED` → read the log tail. Retry once if it looks transient (network, rate limit, provider
  error); otherwise stop and report. Log friction either way.
- If the Bash call itself times out, read `.work/runs/latest.txt` for the RUN_ID and use `wait`.
- If ELAPSED_MIN exceeds the max total agent time, run `<runner> stop <RUN_ID>`, log friction,
  and ask the user.

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
