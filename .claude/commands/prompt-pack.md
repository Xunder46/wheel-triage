---
description: Build a phased implementation prompt pack through Q&A and repo analysis, for another agent or tool to execute.
argument-hint: <what you want built or fixed>
---

Invoke the `prompt-engineer` subagent for this request:

$ARGUMENTS

This produces a **prompt pack**, not an implementation and not a pipeline plan.
Use it when the executing run is a different tool or a different session that
will not have this context.

- No source code is written in this run.
- The subagent asks **at least one** clarification batch before producing
  anything, even when the request looks clear. Surface it and **WAIT**. The
  requests that look clearest are the ones whose hidden assumptions cost most.
- It may ask a follow-up batch if analysis surfaces genuinely new ambiguity.
  More than two batches usually means the scope is unstable — say so rather than
  continuing to drill.

Before reporting back, confirm every phase in the pack is **stop-safe**: if
execution halts after that phase, the repository is still coherent, building,
and testable. This is the constraint most often violated and the most expensive
one to discover late.

Also confirm each phase carries observable acceptance criteria. The test: could
two people disagree about whether a criterion is met while looking at the same
code? If yes, it needs rewriting before the pack ships.

Report the file path, one line per phase, and any unresolved questions.

**If this project's work will be executed by its own pipeline agents, use
`/plan` instead** — it produces a plan file the pipeline can act on directly,
with Done Criteria and Predicted Files that `/review` can verify mechanically. A
prompt pack has neither.
