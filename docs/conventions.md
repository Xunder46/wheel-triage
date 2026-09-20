# Wheel Triage — Conventions

Standing, cross-cutting rules. Every agent (data-architect, developer,
code-reviewer) is bound by this file for every phase, every iteration. Phase-
and feature-specific decisions live in the plan file
(`docs/plans/wheel-triage-plan.md`), not here. If a plan's Feature Invariant
and this file ever disagree, the plan wins for that feature and the conflict
gets flagged for reconciliation — but that should not happen for the rules
below; they come directly from `docs/brief.md` and are not expected to change
per-feature.

## 1. Precision — no `double` for money or gate inputs

- Never use `double` for: strikes, credits, option marks, underlying prices,
  extrinsic/intrinsic values, cost basis, or any P&L figure. Use the `decimal`
  package (`Decimal`) end to end for these — construction, arithmetic, and
  comparison (`>=`, `<=` used directly in gate checks in
  `lib/domain/rules/classify.dart` must be exact `Decimal` comparisons, never
  float epsilon hacks).
- Storage units (SQLite, via Drift, as integers — never `REAL`):
  - **Integer ten-thousandths of a dollar** for anything denominated as an
    *option price*: `openCreditPerShare`, `closeDebitPerShare`, `optionMark`,
    `tailExtrinsicThreshold`. (Options quote in pennies but can fill at
    sub-penny prices.)
  - **Integer cents** for anything denominated as an *underlying/equity
    price*: `strike`, `underlyingPrice`/`spot`, `assignmentStrike`, and any
    basis figure (`wheelBasis`, `taxBasis`) derived from a strike.
  - Convert to/from `Decimal` only at the persistence boundary (inside
    `DriftWheelRepository` and `InMemoryWheelRepository`). Nothing above the
    repository layer ever sees a raw integer money value.
- Greeks (`delta`, `gamma`, `theta`, `vega`) and IV/IV-rank are dimensionless
  `double`s. Round to a fixed number of places for display. Never compare two
  doubles with `==`; compare with a small epsilon (suggested `1e-6`, unless a
  scenario in the plan pins a specific epsilon).
- A missing input (no snapshot yet, `dte == 0`, a null optional field) is a
  normal state. Every rules-engine function that can be missing an input
  returns `null` (or a `Result`-style type) for that call — it never throws,
  never returns `NaN`, never returns `Infinity`. Guard every division
  (`oneSigmaMove`, `cushionSigmas`) explicitly.
- **Multi-leg dollar figures take legs, never pre-summed per-share values.**
  Any function computing a dollar-denominated figure across more than one leg
  takes the legs themselves (so it can read each leg's own `contracts`), never
  caller-summed per-share `Decimal`s. Four formula errors of this exact shape
  — per-share components assembled into a dollar figure without carrying the
  contract multiplier — have been found across three briefs
  (`cycleTotalPremium`, `netResult`, `stockPnL`, `peakCapitalCommitted`,
  `taxBasis`, `wheelBasis`; see the Feature Invariant 25 audit in the plan's
  `## Feedback`). The fix already made the bug inexpressible in `basis.dart`
  by changing its signature from pre-summed `Decimal`s to leg-shaped inputs —
  applying the same shape everywhere closes the defect family structurally
  instead of patching each instance as it's found.

## 2. Delta sign convention

- A **call** has option delta in `[0, +1]`; a **put** has option delta in
  `[-1, 0]`. A **short** position inverts the sign (short call position delta
  `[-1, 0]`; short put position delta `[0, +1]`).
- `deltaAsEntered` is stored exactly as the user typed it, sign included.
  Every place `deltaAsEntered` is stored also stores which convention it was
  entered under (`deltaConvention: position | option`), immutably, next to it.
  See the plan's Feature Invariants for exactly where this lives in the schema.
- `deltaMagnitude = deltaAsEntered.abs()`. This is convention-independent —
  never branch on `deltaConvention` before taking the absolute value, and
  never let a "normalize to position delta first" step exist upstream of a
  magnitude calculation (that step is only needed for **signed** portfolio
  aggregation, not for magnitude).
- The rules engine (gates 1–4, `rollBandFor`) reads **`deltaMagnitude` only**.
  Never the signed value. Portfolio-level exposure aggregation (deferred
  feature) reads the **signed position delta** — getting this backwards makes
  a hedged book look directional, or a directional book look hedged.
- Every quadrant (short call / short put × entered positive / entered
  negative) must be covered by a unit test wherever delta-derived logic is
  added.

## 3. Rules engine purity (`lib/domain/rules/`)

- Zero Flutter imports, permanently. Verify with
  `grep -rl "package:flutter" lib/domain/rules/` returning no output — this is
  a Done Criterion in every phase that touches this directory, not a one-time
  check.
- `lib/domain/rules/` may import `lib/domain/models/` (also pure Dart, no
  Flutter, no Drift) but never `lib/data/`, `lib/state/`, `lib/features/`, or
  any Flutter/platform package. `lib/domain/models/` must never import
  `lib/domain/rules/` — the dependency edge is one-directional so models stay
  a leaf.
- Every function is a pure function of its inputs. No `DateTime.now()`, no I/O,
  no global state. `now` (and any other "current" value) is always a passed-in
  parameter so tests are deterministic.
- Gate order in `classify()` is fixed and load-bearing: profit target →
  assignment → roll band → tail → fallback leave. Do not reorder without a
  test that specifically pins the new order's precedence the way
  `docs/plans/wheel-triage-plan.md` already requires for delta `0.85`.
- If a rule in the brief looks wrong, say so before implementing a "fix" —
  don't silently correct a threshold or a boundary. Flag it in the plan's
  Notes or Assumption Log and implement what's written.

## 4. Vocabulary and tone (binding on every string shown to the user)

**Revised in Iteration 3.** The original ban list (`recommend|should\b|\bbuy\b|
sell signal|opportunity|we suggest|our analysis`) was tested against
`docs/brief-followup.md` §C2's help copy and failed — not because the copy is
advisory, but because the word list was too blunt. "Buy" is a transaction
verb an options app cannot avoid ("a put obligates you to buy shares at the
strike"); bare "should" appears in legitimate descriptions of app mechanics
("the band should scale with IV"). The fix is a narrower, more precise list,
**not** an exemption for the file where advisory drift is most likely — the
help-copy file is exactly the wrong place to remove the guard, since its
entire job is explaining what an action means. Narrowing the list keeps the
guard live everywhere, including there.

- Never use, anywhere in UI copy, code comments that become user-facing
  strings, or notification text: **"recommend", "we suggest", "our
  analysis", "buy signal", "sell signal", "opportunity", "guaranteed", "you
  should"**. Grep for these (case-insensitive) across `lib/` — with **no file
  exemptions** — as part of every phase's Done Criteria:
  ```
  grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/
  ```
- **Explicitly allowed**: bare "buy", bare "sell", "close", "roll", "assign"
  (all ordinary transaction/mechanics verbs an options app cannot describe
  itself without), and bare "should" when it describes the *app's own*
  behavior rather than instructing the user (e.g. "the band should scale
  with IV" is fine; "you should roll this" is not — that's why "you should"
  specifically is banned even though bare "should" is not).
- **Reviewer checklist item — not a grep Done Criterion, because no regex
  catches this reliably.** Check by hand on every phase that touches
  user-facing copy:

  > No sentence may pair an action verb with a named security or with the
  > user's own position. "Buy it back and start fresh" is generic mechanics.
  > "Buy back your SBET call" is advice.

  This is the actual App Store review risk (§10 of `docs/brief.md`) the
  original word list was reaching for. Narrowing the grep does not lower the
  bar here — it sharpens it: the word-list grep catches vocabulary; this
  checklist item catches the one pattern vocabulary alone cannot, a specific
  security or the user's own holding named alongside an instruction. Record
  findings against this item in the plan's `## Feedback`, not as a failed
  command.
- Bucket names are neutral verbs only: `Close`, `Roll`, `Assign`, `Leave`.
  Never a synonym, never a severity label ("Urgent", "Warning").
- **Never a bare verdict.** Every place a bucket result is displayed, the
  reason string that fired it is displayed with it, in the same view, not
  behind a tap. `Bucket` values always carry their `reason` field; no call
  site is allowed to discard it.
- The screener's 0–9 score is a **sorting aid**. Label it "Sorting score" in
  the UI — never "rating", "grade", or "verdict" — and it must never be the
  visually largest element on the screener screen. A one-line note stating the
  thresholds are user-owned and editable accompanies it.
- Tax basis note: wherever `taxBasis` appears in the UI, show the exact
  disclaimer text from `docs/brief.md` §3.6 verbatim (or the App-Store
  disclaimer from §10 wherever that specific one is called for) — do not
  paraphrase either.

## 5. No network, no data feed

- No HTTP client dependency, no quote/greeks-fetching code, no "adapter ready
  for a future data feed." All market data is typed in by the user. If a
  phase's design starts sketching an interface that assumes an external data
  source, that is a signal to stop and simplify, not to build the abstraction
  "for later."

## 6. Layering and naming

```
lib/domain/rules/    pure logic — formulas, classify(), RuleProfile,
                     validateRuleProfile, Bucket. Owned by @developer. Zero
                     Flutter imports.
lib/domain/models/   plain persisted data classes (Underlying, WheelCycle,
                     Leg, Snapshot, ShareLot, RuleProfileData +
                     RuleProfileVersionData). Owned by @data-architect. No
                     business logic, no derivation methods
                     beyond serialization — derivation lives in domain/rules
                     or lib/state, never on the data container.
lib/data/            WheelRepository interface + DriftWheelRepository +
                     InMemoryWheelRepository + Drift schema/tables/migrations.
                     Owned by @data-architect. Storage-agnostic interface:
                     no SQL fragments, no Drift types, no file paths in the
                     interface's signatures.
lib/state/           Riverpod providers/controllers: orchestration, mapping
                     between domain/models and domain/rules types, calling
                     the repository. Owned by @developer.
lib/features/        Screens. Owned by @developer.
lib/widgets/         Shared/reusable UI (e.g. the bucket badge). Owned by
                     @developer.
lib/core/            Cross-cutting app wiring (router, theme, app-level
                     constants). Owned by @developer.
```

- Dependency direction is one-way: `rules ← models ← data ← state ← features`.
  Nothing downstream leaks into an upstream layer.
- `{{DATA_INTERFACE}}` = `WheelRepository`. Methods express domain intent
  (`getOpenLegs()`, `recordRoll(...)`), never storage mechanics (`runQuery`).
  Every method returns a `Future` (or `Stream`), even where the current
  implementation could be synchronous.
- **Implementation parity is non-negotiable.** `DriftWheelRepository` and
  `InMemoryWheelRepository` must produce the same observable output for the
  same inputs. Every new repository method ships in both implementations in
  the same phase, with a shared contract test exercising both. Never add a
  method to one and leave the other throwing `UnimplementedError`.
- One canonical type per concept. Rule profiles split identity from
  thresholds: `RuleProfileData` (`lib/domain/models/rule_profile_data.dart`)
  is id + name, each immutable `RuleProfileVersionData` carries one version's
  14 thresholds, and `Leg.ruleProfileVersionId` pins the version a leg was
  opened under. `RuleProfile.fromVersion(...)` is the sole bridge from a
  version DTO to the rules-engine value type
  (`lib/domain/rules/rule_profile.dart`); nothing else re-derives it. The
  threshold bounds live in exactly one place too — `validateRuleProfile`
  (`lib/domain/rules/rule_profile_validation.dart`), never in a widget.

## 7. Testing conventions

- The rules engine gets table-driven, pure-function unit tests — no widget
  harness needed for `lib/domain/rules/`.
- Golden tests are required for the bucket badge widget (all four bucket
  states), committed alongside the widget in the same phase.
- Every Drift schema version ships with a migration test. A version with no
  migration test is an incomplete phase.
- **A scenario's fixture outranks its own narrative arithmetic.** When a
  plan's prose walkthrough for a scenario disagrees with the numbers in that
  same scenario's enumerated fixture, implement and test against the
  fixture, and flag the discrepancy (plan's Notes or Assumption Log) rather
  than silently resolving it either way. S-104 is the precedent: the plan's
  narrative stated `$250`/`$3.90`/`$646.10` while its own fixture yields
  `$280`/`$5.20`/`$674.80`; the fixture was implemented and the mismatch was
  flagged. The alternative — bending code to match a planner's mental math —
  is how a wrong number becomes a passing test.
- `flutter analyze` and the relevant `flutter test` suite(s) are run and
  green before a phase is reported complete — this is the actual Done
  Criterion, not a description of intent.

## 8. Commands

- Lint: `flutter analyze`
- Test: `flutter test`
- Build (this build's acceptance target): `flutter build ios --simulator --no-codesign`
- Run (manual, performed by the user, not by an agent): `flutter run -d <simulator>`
