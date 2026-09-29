# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Wheel Triage — a Flutter app for a self-directed options trader running the wheel
strategy. It does three things: **screen** a candidate trade, **triage** open
positions into four buckets by arithmetic, and **record** what happened.

It is a free download with an optional **Wheel Triage Pro** upgrade (monthly,
annual or lifetime, through RevenueCat). There are still no accounts, no
backend and no sync; see [docs/brief-pro.md](docs/brief-pro.md) §2.

Two constraints shape every design decision, and neither is negotiable:

- **All market data is typed in by hand**, or read on-device from a screenshot
  the user picks (Pro, `docs/brief-pro.md` D-P4). No quote APIs, no broker
  integration, no scraping, and no abstraction "ready for" a future data feed.
  If a design starts sketching an interface that assumes an external source,
  simplify rather than build for later.
- **It is a calculator, not an advisor.** It has no view on any security and
  makes no predictions. See *Tone* below — this is enforced by grep, not taste.

The specification is a chain of briefs:
[docs/brief.md](docs/brief.md) → [docs/brief-followup.md](docs/brief-followup.md)
(corrections to the first) → [docs/brief-ledger.md](docs/brief-ledger.md) (wins
over both where they disagree) → [docs/brief-pro.md](docs/brief-pro.md), whose
§2 decisions win over everything earlier; nothing else in it overrides an
earlier rule. Section numbers cited throughout the code (`§4.3`, `§3.6`) refer to
`brief.md` unless the comment names another brief (`brief-followup A2`). The Pro
release's UI reference is
[docs/design/pro-ui-reference.html](docs/design/pro-ui-reference.html).

## Commands

```bash
flutter analyze                                  # lint — must be clean
flutter test                                     # full suite
flutter test test/domain/rules/classify_test.dart  # one file
flutter test --plain-name "S-006"                # one scenario by S-id
flutter build ios --simulator --no-codesign      # the acceptance build
dart run build_runner build --delete-conflicting-outputs   # after touching models/Drift/freezed
```

Run on a simulator:

```bash
xcrun simctl list devices available | grep Booted
flutter run -d <device-id>
```

These run on the Mac, and so do goldens (they render differently on other
operating systems). A checkout without the Flutter SDK can plan and edit docs,
but it cannot run any Done Criterion.

**The Mac's repo path contains a space** (`/Users/irinakutsenko/Developer/wheel triage`).
Quote it in every shell command.

**The repo is under git.** Older plans carry a "no source control"
constraint from the project's first builds; it is retired, so ignore any
plan step that checks for the absence of commits.

## Architecture

Dependency direction is one-way and enforced by review:

```
lib/domain/rules/   pure logic — formulas, classify(), RuleProfile, Bucket
lib/domain/models/  persisted data classes (freezed + json_serializable)
lib/data/           WheelRepository + Drift and in-memory implementations
lib/state/          Riverpod controllers — orchestration and type mapping
lib/features/       screens
lib/widgets/        shared UI (bucket badge, delta sparkline)
lib/core/           router, app wiring
```

`docs/conventions.md` is the binding rule source and covers each layer's
ownership in detail. The points below are the ones that require reading several
files to discover.

### The rules engine is the product

`lib/domain/rules/` (~1,400 lines) is pure Dart with **zero Flutter imports,
permanently**. Verify with `grep -rl "package:flutter" lib/domain/rules/`
returning nothing — this is a Done Criterion on every phase touching the
directory, not a one-time check. Every function is pure; `now` is always a
passed-in parameter so tests are deterministic. If something wants to reach into
the engine, the boundary is in the wrong place.

It may import `lib/domain/models/` but nothing else. Models must never import
rules — that edge stays one-directional so models remain a leaf.

### Gate ordering in `classify()` is load-bearing

`profit target → assignment → roll band → tail → fallback leave`, first match
wins. An earlier draft put the roll band before the assignment check; because the
band (0.30–0.40) is *lower* than the assign threshold (0.70), a delta of 0.85
matched roll first and the assign branch was unreachable dead code. `S-006`
pins this with both `isA<BucketAssign>()` and `isNot(isA<BucketRoll>())`. Do not
reorder without a replacement precedence test.

Gate 1 is checked **continuously** from the moment a position opens — there is no
DTE at which it "becomes active".

`rollBandFor` has a deliberate asymmetry: `iv > 70 → 0.40` (strict) but
`iv >= 40 → 0.35` (inclusive), so **IV of exactly 70.0 yields 0.35**. This looks
like a typo and is not; `S-008` pins all six boundary rows. Do not "fix" it.

### Money precision

**Never `double` for money or any value feeding a gate.** A captured-credit
calculation landing on 49.999999% instead of 50% silently fails to fire Gate 1 —
that is the bug class this rule exists to prevent, and `S-012` guards it by
asserting exact `Decimal` equality to `50.0`, not an epsilon.

Use `Decimal` end to end for strikes, credits, marks, underlying prices,
extrinsic/intrinsic, basis, and P&L. On disk, money is stored as integers:
**ten-thousandths** for option prices (options quote in pennies but fill
sub-penny), **cents** for equity prices. Conversion happens only at the
persistence boundary via `lib/data/db/type_converters.dart`; nothing above the
repository layer sees a raw integer money value.

Greeks and IV are dimensionless `double`. Compare them with an epsilon, never
`==`. The one `double` inside the engine — `oneSigmaMove`'s `sqrt` term — is
irrational by nature, isolated, and reaches only the screener's soft score and
display. **No `double` reaches any of Gates 1–4.** Keep it that way.

### Delta sign is a bug magnet

Brokers differ, and the same number means different things in different places.
`deltaAsEntered` is stored exactly as typed, sign included, with its
`deltaConvention` stored **per snapshot** beside it — not as a global setting, so
flipping the Settings default never silently reinterprets history.

- Gates read `deltaMagnitude = abs(delta)` **only**, never the signed value.
  Thresholds are always magnitudes.
- Signed position delta is reserved for portfolio exposure aggregation (the Pro
  release's Stage 7). Getting this backwards makes a hedged book look
  directional.
- Never normalize to position delta upstream of a magnitude calculation.

### A leg is not a cycle

A roll does not modify a leg — it **closes one leg and opens another** in a single
atomic transaction (`recordRoll`), with `rolledFromLegId` forming the chain. The
credit on the current leg is *not* the cumulative credit on the trade.

`capturedPct`, and therefore Gate 1, is **leg-level by decision**. Cycle
cumulative credit is displayed alongside it so the leg-level gate is not
misleading. `TriageInput` documents that this contract is enforced by the caller
in `lib/state/positions/`, not by `classify()` itself.

`wheelBasis` and `taxBasis` are **computed live, never persisted** — wheelBasis
changes as more calls are sold after assignment, so storing it once goes stale.
Both are shown and labelled; they are not the same number. Do not implement
wash-sale detection or tax-lot matching — flag it, don't compute it.

### Repository parity is structural

`WheelRepository` has two implementations — `DriftWheelRepository`
and `InMemoryWheelRepository` — and one shared contract suite
(`test/data/wheel_repository_contract_test.dart`) runs against both. **Every new
method ships in both implementations in the same change**, with contract
coverage. Never leave one throwing `UnimplementedError`.

The interface is storage-agnostic: no SQL fragments, no Drift types, no file
paths in any signature. Methods express domain intent (`recordRoll`,
`getOpenLegs`), not mechanics.

`wheelRepositoryProvider` deliberately has **no default implementation** and
throws if unoverridden. `main.dart` overrides it with Drift; every test's
`ProviderScope` overrides it with in-memory. This prevents a screen from being
wired to a repository nobody chose on purpose.

### One canonical type per concept

Rule profiles split identity from thresholds: `RuleProfileData` (persistence
DTO, `lib/domain/models/`) is `{id, name}`; each immutable
`RuleProfileVersionData` carries one version's 14 thresholds; a leg pins a
version id (`Leg.ruleProfileVersionId`). They are bridged to the rules-engine
value type in exactly one place: `RuleProfile.fromVersion()`. Nothing else
re-derives that mapping. Threshold bounds live in exactly one place too —
`validateRuleProfile` in `lib/domain/rules/rule_profile_validation.dart`,
never in a widget.

A position records **which version it was opened under**, so editing a profile
later does not silently re-classify historical trades. `Conservative` and
`Aggressive` are seeded, hidden, non-editable rows (the same
`StandardProfileDefaults` numbers) that exist only so a legacy reference still
resolves — they are not a feature and are never listed or selected.

## Tone — enforced by grep

**Revised in Iteration 3** (see `docs/conventions.md` §4 for the full rationale):
the original word list broke on the brief-followup's own help copy — "buy" is a
transaction verb an options app cannot avoid, and bare "should" appears in
legitimate mechanics descriptions. The fix narrows the list; it does **not**
exempt any file, including the help-copy file, which is the highest-risk
place to lose the guard, not the right place to remove it.

Banned from all user-facing copy, including notification text, the paywall,
the share card, the store listing and any comment that becomes a string:
**recommend, we suggest, our analysis, buy signal, sell signal, opportunity,
guaranteed, you should**. Check with:

```bash
grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/
```

Explicitly allowed: bare "buy", bare "sell", "close"/"roll"/"assign", and bare
"should" describing the app's own behavior (not the user's). A second check a
grep cannot do, reviewed by hand: no sentence may pair an action verb with a
named security or the user's own position — "Buy it back and start fresh" is
generic mechanics, "Buy back your SBET call" is advice. That distinction is the
actual §10 review risk; this sharpens it rather than lowering the bar.

- Bucket names are neutral verbs only: `Close`, `Roll`, `Assign`, `Leave`. Never
  a severity label.
- **Never a bare verdict.** Every bucket result displays the reason that fired it,
  in the same view, not behind a tap. `Bucket` is a sealed class where every
  variant requires a `reason`, so a bare verdict cannot compile.
- The 0–9 screener score is labelled **"Sorting score"** — never "rating" or
  "grade" — must never be the largest element on screen, and carries a note that
  the thresholds are the user's own.
- A net debit is never presented as a credit. The roll planner marks
  `netCredit <= 0` clearly as a debit roll but does not block it.
- The tax disclaimer from §3.6 appears verbatim wherever tax basis appears. Do
  not paraphrase.
- The app presents itself as a journal and calculator for the user's own
  trades, never as anything more. The persistent disclaimer (Settings, first-run
  explainer) is `docs/brief-pro.md` D-P15's exact text. Do not paraphrase it
  either.

## Scenario register

`docs/plans/wheel-triage-plan.md` is the source of truth for requirements and
carries the registers `S-001`…`S-180` — Iterations 1–4, each entry with an
enumerated fixture, authored there while planning each iteration (the briefs
themselves specify the work but carry no S-ids). Iteration 5's register,
`S-190`–`S-204`, is in `docs/plans/rule-versioning-plan.md`; `S-205`–`S-206`
are in `docs/plans/roll-planner-add-candidate-bug-plan.md` and `S-207`–`S-210`
in `docs/plans/iteration-4-closeout-plan.md`. The Pro release's wave plans
continue from `S-211`. Tests reference S-ids in their names. When adding
behavior, add or extend a scenario in the current plan first — S-ids are stable
and never reused.

`S-015` is a regression fixture from a real position (SBET $11 call) and exercises
the whole pipeline end to end; treat a failure there as a genuine break.

## State of the build

**Iterations 1–5 are complete.** M1–M4 (the wheel loop) plus Iteration 3
(brief-followup corrections + help system), Iteration 4 (`docs/brief-ledger.md`:
schema v3, cycle P&L, the Journal, fees, `acceptsAssignment`, snapshot
staleness, display fixes, export/import, notifications) and Iteration 5
(rule versioning + the single-profile threshold editor) have all shipped, and
the Iteration 4 closeout (Phase 23) is closed.

**Next: the Pro release** ([docs/brief-pro.md](docs/brief-pro.md)), planned
one wave per plan file. Wave 1 is Stages 0 → 4A → 1 → 2 → 3: dependency
cleanup, the theme, Record a trade, the snapshot preview, and the Today screen.

The Drift schema is at **v4**: v2 added `user_preferences`, v3 added the fee
columns and `acceptsAssignment`, v4 split the profile into `rule_profile`
(identity only) + `rule_profile_version` (the 14 thresholds, immutable,
append-only) and renamed `leg.rule_profile_id` to
`rule_profile_version_id`. The full suite and `flutter analyze` are clean,
and the iOS simulator build succeeds (`flutter build ios --simulator
--no-codesign`, exit 0).

**Still not built**, now scheduled by `docs/brief-pro.md`: the portfolio view
and assignment calendar (Stage 7), accessibility polish beyond the help system
(Stage 4B), screenshot scan (Stage 6), broker CSV import (Stage 10, after
launch), and the disclaimer (exact wording in `docs/brief-pro.md` D-P15),
which is missing from Settings and the first-run explainer (Stage 3).

Known deviations from the brief's §2 stack, all reviewed and logged in the
plans' `## Assumption Log`:

- Controllers are hand-written `StateNotifier`, **not `@riverpod` code-gen**.
  Still Riverpod 2.x. Follow the existing pattern rather than mixing styles.
  The unused code-gen stack (`riverpod_annotation`, `riverpod_generator`,
  `riverpod_lint`, `custom_lint`) crashes a full `build_runner` run and is
  removed in the Pro release's Stage 0.
- `fl_chart` is declared in `pubspec.yaml` but **unused** — the delta sparkline
  is a hand-painted `CustomPainter`, and the journal renders its aggregates as
  numbers and rows rather than charts. Stage 0 removes it.
- `Bucket`, `TriageInput`, and `RuleProfile` are plain Dart rather than
  `@freezed`, since none are persisted or serialized. The persisted DTOs
  (`RuleProfileData`, `RuleProfileVersionData`) use `@freezed` normally.

**Rule profiles: one editable profile, versioned.** `Standard`
(`rule-profile-standard`) is the only editable profile; `Conservative` and
`Aggressive` remain seeded rows that are never listed, selected, or edited,
and that is permanent — **multiple named profiles were dropped, not
deferred** (Iteration 5's D-1: a profile picker would be a decision at
exactly the moment the user wants fewest decisions, and the IV-adjusted roll
band already covers the per-underlying need). All three are seeded from
`StandardProfileDefaults`, and they will keep those values: there is no plan
to give the two hidden ones "real numbers." Editing `Standard` appends an
immutable version (`rule-profile-standard-v2`, …); every leg pins the
version it was opened under, which is what stops an edit from reclassifying
history.

## Working agreement

- **Ask before adding a dependency** not already in `pubspec.yaml`. The Pro
  release pre-approves exactly two: `purchases_flutter` (RevenueCat, D-P3) and
  `image_picker` (D-P4). ML Kit text recognition is approved for the Android
  stage only.
- **Ask before changing any threshold default** — they are documented in the brief
  deliberately.
- **If a rule looks wrong, say so before implementing a "fix".** Several numbers
  are heuristics rather than doctrine, and at least one bug (gate ordering) was
  found during design. Flag it in the plan's Assumption Log and implement what is
  written.
- Out of scope, permanently: network calls for market data, broker integration,
  price prediction or backtesting, social features (the share card is an
  exported image, not a social feature — D-P7), accounts, backend and sync,
  analytics, crash-reporting and ad SDKs, wash-sale detection, and multi-leg
  spreads. The domain model is deliberately shaped around one short leg at a
  time — spreads would be a redesign, not an extension.

## Agent pipeline

`.claude/agents/` holds a five-agent pipeline (`conductor` → `data-architect` →
`developer` → `code-reviewer`) driven by `.claude/commands/run-pipeline.md`. The
plan file is the contract between them; they coordinate through it rather than
through chat history.

**These templates ship with unresolved `{{PLACEHOLDER}}` variables.** Resolve them
in the invoking prompt — `{{PLANS_ROOT}}/<feature>-plan.md` is
`docs/plans/wheel-triage-plan.md`, `{{LINT_CMD}}` is `flutter analyze`,
`{{TEST_CMD}}` is `flutter test`, `{{DATA_INTERFACE}}` is `WheelRepository`. An
agent given an unresolved placeholder will invent a path and silently fork the
pipeline.

`/plan` invokes the original `conductor`. The Pro release is planned with
`conductor-v2`, invoked directly, one wave per plan file
(`docs/plans/pro-wave-<n>-plan.md`). Its full placeholder set:

| Placeholder | Value |
|---|---|
| `{{PROJECT_NAME}}` | Wheel Triage |
| `{{STACK}}` | Flutter / Dart — Riverpod 2.x (hand-written `StateNotifier`), Drift, go_router, freezed |
| `{{SOURCE_ROOT}}` / `{{TEST_ROOT}}` | `lib/` / `test/` |
| `{{DOCS_ROOT}}` | `docs/architecture/` — the index is `wheel-triage.md`; there is no `README.md` |
| `{{CONVENTIONS_DOC}}` | `docs/conventions.md` |
| `{{PLANS_ROOT}}` | `docs/plans/` |
| `{{LINT_CMD}}` / `{{TEST_CMD}}` | `flutter analyze` / `flutter test` |
| `{{DATA_INTERFACE}}` | `WheelRepository` |
| `{{PRIMARY_IMPL}}` / `{{TEST_IMPL}}` | `DriftWheelRepository` / `InMemoryWheelRepository` |
| `{{MODEL_DIR}}` | `lib/domain/models/` |
| `{{STATE_DIR}}` / `{{UI_DIR}}` | `lib/state/` / `lib/features/` |
| `{{SCHEMA_ARTIFACT}}` | `lib/data/db/schema/drift_schema_v<N>.json` |
