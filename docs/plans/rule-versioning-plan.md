# Feature: Rule versioning + the single-profile threshold editor (Iteration 5)

> Status: **Phase 28 complete — review findings resolved.** The critical
> import-cache defect and all three warnings are fixed with their guards,
> every suggestion is closed or explicitly accepted, and `CLAUDE.md` has been
> corrected with the user's authorisation. Independently verified: analyze
> clean, **456/456** tests, iOS build `✓ Built`.
> **Open:** the manual simulator launch (the only unexercised path) and the
> optional `docs/brief.md` pointer in `## Feedback` #8c.
> Every decision resolved by the coordinator's Q1–Q5 round and ratified by the
> user ("all defaults", 2026-09-19). No open questions.
> Binding conventions: `docs/conventions.md` (layer ownership, parity,
> precision, tone) + the standing plan `docs/plans/wheel-triage-plan.md`
> (Feature Invariants; **D-10 and D-13 below supersede parts of Invariants 8
> and 11**) + `docs/brief-ledger.md` §10 ("one Standard profile with
> editable thresholds covers the need"). This plan is self-contained for any
> executor: it is the only place the product intent below is recorded.

## Overview

The app's thresholds are the user's own numbers, and until now they were
read-only (`StandardProfileDefaults`, shown by `settings_screen.dart`). This
iteration makes them editable — **and does the versioning that editing
forces first**.

The product intent, verbatim from the user (2026-09-19):

- **Editable thresholds, one profile.** Change the profit target from 50% to
  60%, or move the roll bands. A settings form over the existing
  `RuleProfile` fields — no new concepts, no picker, no cloning.
- **Multiple named profiles are dropped, not deferred.** The IV-adjusted
  roll band already handles most of the "tighter here, looser there" need;
  a profile picker at every position open is a decision at exactly the
  moment you want fewest decisions.
- **Rule versioning is the prerequisite.** `Leg` pins `ruleProfileId` at
  creation, but the profile row is mutable — edit Standard's profit target
  and every historical leg pointing at it resolves to the new number. The
  pin protects against switching profiles, not against editing one.
- **The journal is the product.** A position must be able to say it was
  classified as Close under Standard v3, which had a 75% target, even
  though the target is 60% today. "An audit trail that silently rewrites
  itself isn't one."

**Sequence is binding: versioning (Phases 24–25) lands fully green before
the editor UI (Phase 26) starts.**

Ground truth this plan was built against (verified by reading source, not
docs): schema v3; 380 tests; `rule_profile` holds identity **and** the 14
threshold columns; `RuleProfileData` mirrors it 1:1; the single bridge is
`RuleProfile.fromData`; three profiles seeded (Conservative/Standard/
Aggressive, all copies of `StandardProfileDefaults`); legs pin
`ruleProfileId` today and rolls/covered calls inherit it
(`roll_planner_controller.dart:247`, `assignment_flow_controller.dart:249`);
the screener pins the default profile at creation
(`screener_controller.dart:269,280`); **four** read sites resolve
classification from a pinned profile: `positions_list_controller.dart:99–100`,
`position_detail_controller.dart:199–200`, plus the two fallback sites in
`screener_controller.dart:376` and the positions-list/detail otherwise-null
branches; export format is v1 (`LedgerExport.currentFormatVersion = 1`)
with referential validation of `ruleProfileId`.

## Resolved Decisions (Ledger)

Numbered D-1…D-13. **Immutable once written.** Changes are new superseding
entries, never edits.

**D-1 — One profile, editable.** The app has exactly one *editable* profile:
`Standard` (`rule-profile-standard`). **Multiple named profiles are
dropped**, not deferred — no clone, no set-default, no picker, no profile
selection UI of any kind. `Conservative` and `Aggressive` remain as seeded,
hidden, non-editable rows (each gaining a v1) so any existing reference to
them still resolves; nothing lists or selects them. (Supersedes the
standing plan's Iteration-2 M7 bullet "clone/edit/set-default UI".)

**D-2 — Editable = the 14 threshold numbers; identity and no-ops are not
edits.** The editor exposes exactly the 14 numeric fields of
`StandardProfileDefaults` (profit target, assign threshold, base/mid/high
roll bands, mid/high IV cutoffs, tail DTE window, tail extrinsic threshold,
min IV rank, min annualised yield, target DTE min/max, target delta).
`id` and `name` are not editable. There is no revert action this iteration
(a revert, if ever wanted, is just another new version). **A save whose
values equal the profile's current version creates no version and writes
nothing** — value equality is numeric equality (50 and "50.0" are equal).

**D-3 — Profiles become immutable version rows.** `rule_profile` shrinks to
identity only (`id`, `name`). A new `rule_profile_version` table carries
`id`, `profileId`, `version` (1-based integer), `effectiveAt` (integer `_ms`
on disk, per the naming table in `docs/conventions.md` §6), and the 14
threshold columns (identical storage encodings to today, including
`tail_extrinsic_threshold` as integer ten-thousandths). **Version rows are
append-only**: `WheelRepository` exposes no method that updates or deletes
one. Version id format is deterministic: **`<profileId>-v<version>`**
(e.g. `rule-profile-standard-v3`) — never a random id. `(profileId,
version)` is unique at the schema level. There is no threshold column left
on `rule_profile` — no parallel representation of a threshold exists
anywhere except a version row.

**D-4 — Legs pin the version.** `Leg.ruleProfileId` is renamed
`Leg.ruleProfileVersionId`; the SQLite column `rule_profile_id` is renamed
`rule_profile_version_id`; the JSON key is renamed in the same change.
`NewLegInput.ruleProfileId` → `ruleProfileVersionId`. **Nothing may write a
bare profile id into this column**; the stored value is always a version
id.

**D-5 — Pinning = predecessor's version on inheritance; current version on
a new cycle.** A leg created by a roll, or by the assignment flow's
covered-call step, inherits the predecessor leg's
`ruleProfileVersionId` (this is the existing S-102/S-125 behaviour, now
pinning a version rather than a profile). Only a **new cycle** (screener
"Track this position") pins the profile's then-current version. Consequence,
stated in the settings copy: **editing never changes the rules of an
existing open position or of legs rolled from it**; it changes what the
*next new cycle* opens under — the same "future positions only" precedent
as S-175.

**D-6 — Migration v3→v4 (and every older→v4 jump) preserves history
exactly.** The v4 upgrade step:

1. Copies every `rule_profile` row's 14 values verbatim into a new
   `rule_profile_version` row: `id = '<profileId>-v1'`, `version = 1`,
   `effectiveAt` = one timestamp shared by every v1 row created by that
   migration run (not one clock read per row). No value is re-parsed
   through `double`; `tail_extrinsic_threshold` stays integer
   ten-thousandths end to end.
2. Rewrites every existing leg's value in place: `rule_profile_id` →
   `<oldValue>-v1` (string append, no validation — D-7).
3. Removes the 14 threshold columns from `rule_profile`.

The step **must be gated on `to >= 4` as well as `from < 4`**, exactly like
the existing v2/v3 steps, so migration tests that target v2 or v3 in
isolation (`SchemaVerifier.migrateAndValidate(db, 2|3)`) still run only
their own steps. A v1→v4 or v2→v4 jump runs the earlier steps first, then
this one, with the same assertions. A **fresh install** (`onCreate`) seeds
3 identity rows + 3 v1 rows from `StandardProfileDefaults`, `effectiveAt` =
install time (one timestamp).

**D-7 — Missing rows degrade, never crash.** A `ruleProfileVersionId` that
resolves to no row falls back to the built-in `RuleProfile.standard`
constant (the §4.4 defaults, `versionId = 'rule-profile-standard-v1'`),
preserving today's `profileData == null ? RuleProfile.standard : …`
behaviour at every read site. The migration does not validate the appended
`-v1` suffix; a dangling legacy value is tolerated exactly as a dangling
`ruleProfileId` is today. A version whose profile row is missing still
resolves for classification (name display falls back to `'Standard'`).

**D-8 — Export format v2; format-1 files still import.** `LedgerExport`:
`currentFormatVersion = 2`; `ruleProfiles` (identity only) plus a new
`ruleProfileVersions` list; legs carry `ruleProfileVersionId`. **Import
accepts `formatVersion` 1 and 2.** A v1 file is converted in memory before
the existing hard validation runs: each `ruleProfiles` entry synthesizes a
version map `id = '<profileId>-v1'`, `version = 1`, the file's own values,
`effectiveAt` = the import moment; each leg map's `ruleProfileId` value is
rewritten to `<value>-v1` (the synthesized version ids). The conversion
entry points take an optional `now` so tests can pin `effectiveAt`
(`restoreFromJson` gains the same optional parameter and forwards it; the
UI passes nothing). Validation is **structural + referential only**, as
today, plus these v2 rules: unique ids in every list; every version's
`profileId` exists; **every profile has ≥ 1 version**; `(profileId,
version)` unique; every leg's `ruleProfileVersionId` exists in
`ruleProfileVersions`. **Import does NOT apply the editor's threshold
bounds (D-9)** — a hand-edited file with parseable but odd numbers still
loads; the bounds are a UI-entry gate, not a file-format contract. A
malformed file of either version still leaves the database untouched
(S-152's guarantee, unchanged).

**D-9 — Threshold validation is a pure function with pinned bounds.**
`lib/domain/rules/rule_profile_validation.dart` (pure Dart, zero Flutter
imports, like everything in that directory): given the 14 proposed values
it returns **all** violations in field order (never just the first), each
identifying its field; an empty result means valid. Bounds — inclusive on
both ends unless stated:

| field | rule |
|---|---|
| `profitTargetPct` | `0 < v ≤ 100` |
| `assignThreshold` | `0 < v ≤ 1` |
| `baseRollBand`, `midIvRollBand`, `highIvRollBand` | each `[0, 1]`, and `base ≤ mid ≤ high` |
| `midIvCutoff`, `highIvCutoff` | each `[0, 500]`, and `midCutoff ≤ highCutoff` (equal is legal — see D-12) |
| `tailDteDays` | `[0, 365]` |
| `tailExtrinsicThreshold` | `Decimal ≥ 0` |
| `minIvRank` | `[0, 100]` |
| `minAnnualisedYield` | `v ≥ 0` |
| `targetDteMin`, `targetDteMax` | `0 ≤ min ≤ max ≤ 3650` |
| `targetDelta` | `0 < v ≤ 1` |

Every value must also be finite (NaN/∞ rejected). All 14 §4.4 defaults pass.
Violations **block the save entirely — no partial version is written**.
Validation messages must pass the `docs/conventions.md` §4 tone grep, and no
message may pair an action verb with a named security or the user's own
position.

**D-10 — One mapping only.** The sole persistence→pure-type bridge becomes
`RuleProfile.fromVersion(RuleProfileVersionData version, {required String
profileName})`; `RuleProfile.fromData` is removed. The pure value type
exposes `versionId`, `profileId`, `name`, `version`, and the 14 thresholds;
the old bare `id` field is removed so nothing can read an ambiguous id.
`effectiveAt` is deliberately NOT on the pure value type — it is not a
threshold and nothing in classification or provenance display needs it.
(Supersedes standing Feature Invariant 11's factory and the
`RuleProfileData`-mirrors-the-table half of `docs/conventions.md` §6's
"one canonical type per concept" bullet.)

**D-11 — Provenance is displayed where the truth matters.** Position
detail (the sheet) shows the pinned profile + version (e.g. "Standard v1")
alongside the bucket/reason. Settings shows the active version — name,
version, effective date — and the **full append-only history** (each
version's values and effective date, newest first). The positions list is
NOT annotated with version labels this iteration; adding one there (and to
journal rows, where a closed cycle can span versions after rolls) is
deferred — the pinned row is the audit truth either way.

**D-12 — The roll-band asymmetry survives editing verbatim.** The
strict/inclusive chain in `lib/domain/rules/roll_band.dart` is untouched:
`iv > highCutoff` strict, `iv >= midCutoff` inclusive, `null` → base band —
now evaluated against user-edited values. D-9 deliberately does **not**
forbid `midIvCutoff == highIvCutoff`: equal cutoffs still split at the
boundary (equal → mid band; greater → high band), and forbidding equality
would invent doctrine the brief never stated. (Extends standing Invariant
3, which already promised this preservation for the M7 iteration.)

**D-13 — The built-in constants remain, reshaped.** `RuleProfile.standard`
becomes the built-in v1: the §4.4 defaults, `versionId =
'rule-profile-standard-v1'`, `profileId = 'rule-profile-standard'`,
`version = 1`, `name = 'Standard'` — built directly (no DTO needed) and used
as the D-7 fallback. `RuleProfile.conservative` / `.aggressive` remain as
constants with the same shape under their own ids for parity with the
seeded rows. `StandardProfileDefaults` remains the single source of the
seeded numbers (seeding + migration + the built-in constants), unchanged in
value.

## Feature Invariants

Only the invariants that bite in this feature. Project-wide rules live in
`docs/conventions.md` — referenced, not copied.

1. **No code path resolves thresholds for an existing leg from anywhere
   other than that leg's pinned version row.** The only place a
   *current* version is read is new-cycle creation (D-5). The two
   classification sites (`positions_list_controller`,
   `position_detail_controller`) and the two fallback sites
   (`screener_controller`) are the complete read surface; if a new reader
   appears, it must resolve through a pinned version id.
2. **`rule_profile` carries no threshold values.** After Phase 24, a grep
   for any threshold column name under `lib/domain/models/` and
   `lib/data/db/tables/` may match only the version model/table.
3. **Version rows are immutable.** No repository method updates or deletes
   one; the interface shape is the structural guard.
4. **Implementation parity** (`docs/conventions.md` §6): every new/extended
   repository method ships in `DriftWheelRepository` **and**
   `InMemoryWheelRepository` in the same phase, exercised by the shared
   contract suite (`test/data/wheel_repository_contract_test.dart`) — which
   still excludes the export surface (CR-7; parity there lives under
   `test/data/export/`).
5. **Precision at the boundary** (`docs/conventions.md` §1): the v4
   migration and the version round-trip are asserted integer-exact for
   `tailExtrinsicThreshold`; no `double` is introduced on any gate path.
6. **`now` is always a parameter.** `effectiveAt` is passed into
   `appendRuleProfileVersion` by the caller, and into the v1-import
   conversion via the optional `now`; no pure or repository code calls
   `DateTime.now()` except the outermost UI edge.
7. **Timestamps are `_ms` integers on disk** (naming table,
   `docs/conventions.md` §6) — `effective_at_ms`, via the existing
   `DateTimeMsConverter`.

## Requirements

- R1. Thresholds editable from Settings for the single `Standard` profile;
  every one of the 14 values; no new profile-management concepts (D-1, D-2).
- R2. Editing creates an immutable version; existing legs and their rolled
  successors keep the rules they were pinned under (D-3…D-6).
- R3. Classification, bucket reasons, and displayed roll bands for an
  existing position are truthful to its pinned version at all times (D-11,
  Invariant 1) — this is the journal-honesty requirement.
- R4. The history is visible: what each version's values were, when it took
  effect, and which one is active (D-11).
- R5. Import of everything the app has ever exported still works (D-8).
- R6. No behavior change to gates, formulas, scoring, or notifications —
  this iteration changes *where threshold values are stored and which one a
  leg reads*, nothing about what the engine computes with them.

## Acceptance Criteria

(Each maps to ≥ 1 scenario.)

1. A v3 database upgrades to v4 with every prior value preserved exactly and
   every leg re-pointed to its profile's v1 (S-190).
2. Appending a version and reading versions back behave identically in both
   implementations, ordered by version number (S-191).
3. Export v2 round-trips exactly through wipe-and-restore; v1 files import
   and convert; malformed files of either version change nothing (S-192,
   S-193, S-194).
4. The validator's bound table is enforced exactly, all violations reported
   (S-195).
5. After an edit, existing open positions still classify (and show reasons)
   under their pinned version while new cycles use the new one (S-196,
   S-198, S-200).
6. A no-op save writes no version (S-197).
7. Settings renders the current values as editable fields, the active
   version, and the append-only history; invalid input blocks the save with
   every violation shown (S-199, S-201).
8. Position detail shows the pinned profile + version, including the
   fallback path for a dangling id (S-202).
9. `flutter analyze` clean, full test suite green, iOS simulator build
   succeeds, tone grep clean, and the residue greps prove no reader of the
   replaced representation remains (S-204).

## Existing-Functionality Impact

Every row names the grep that found the readers, the effect, and the guard.
"Unaffected" rows carry the grep that proves it.

| Touched surface | Existing readers (grep) | Effect of the change | Guarded by |
|---|---|---|---|
| `leg.rule_profile_id` (field, column, JSON key) | `grep -rn "ruleProfileId" lib/`: drift repo (3 write sites, `_legFromRow`/`_legToCompanion`, line 630/654), in-memory repo (lines 129/158/261), `leg.g.dart`, `NewLegInput` (+generated), `ledger_export.dart:151–153`, state: positions_list:99, position_detail:199, screener:280, roll:247, assignment:249; ~25 test files | Renamed to `ruleProfileVersionId`; values become version ids; v4 migration rewrites legacy values | S-190, S-191, S-198 |
| `rule_profile`'s 14 threshold columns | `_ruleProfileFromRow`/`_ruleProfileToCompanion`, in-memory `_standardProfile`, `app_database.dart` seeding, `app_database_migration_test.dart` (asserts values) | Moved to `rule_profile_version`; `rule_profile` identity-only | S-190 (incl. fresh install) |
| `RuleProfile.fromData` (sole mapping, Invariant 11) | `lib/state/`: positions_list:100, position_detail:200, screener:376 + providers | Replaced by `fromVersion` (D-10) | S-191, S-196 |
| `getRuleProfile(id)` (returns 14-value DTO) | contract test:104–133; positions_list:99; position_detail:199 | DTO shrinks to identity; pins resolve via new `getRuleProfileVersion(versionId)`; `getRuleProfile` stays for the name lookup | S-191 |
| `defaultRuleProfileProvider` / `ruleProfilesProvider` | `screener_controller.dart:269,376` (+ its own file) | Resolve the standard profile's **current** version | S-198 |
| Export envelope v1 (`ruleProfiles` + `ruleProfileId` keys) | `ledger_export.dart`, `ledger_export_test.dart`, `ledger_import_test.dart`, settings import/export flow | Format v2; v1 accepted and converted (D-8) | S-192, S-193, S-194 |
| Settings read-only card + `standardProfileForSettings` | `settings_screen.dart`, `settings_screen_test.dart` (S-070) | Read-only card replaced by the editor; S-070's read-only clause superseded, its other clauses stand | S-199 |
| `RuleProfile.standard` constant (fallback + tests) | roll_band_test, classify_test, screener_test, iv_resolution_test, sbet_regression_test, decimal_rounding_test; 3 fallback call sites | Same values; now carries a `versionId` (D-13); field renames | S-196 |
| `lib/domain/rules/rule_profile.dart` field `id` | `screener_controller.dart:280` only | Renamed `versionId`; `profileId`/`version` added | S-198 |
| `app_database_migration_test.dart` fresh-install assertions | line ~60–75 (asserts 3 profiles + default values) | Assertions move to the v1 version rows; table-name set gains `rule_profile_version` | S-190 |
| Historical migration tests targeting v2/v3 (`leg_v3_migration_test`, `user_preferences_migration_test`, their `schema_v2/v3.dart` helpers) | their own files | **Unaffected — proven by the v4 step's `to >= 4` gate (D-6); `migrateAndValidate(db, 3)` never runs it.** No edits expected | S-190 (gate assertion included) |
| Journal, CSV export, notifications | `grep -n "profile\|Profile" lib/state/journal/journal_controller.dart` → **no matches**; `grep -n "Leg\|leg" lib/data/export/ledger_csv.dart` → leg-money fields only, no profile reads | Unaffected | proven above |

## Scenarios

### S-190: Migration v3→v4 (and v1→v4) — values preserved, legs re-pointed, columns gone
- **Fixture:** a real v3 database built via `SchemaVerifier.schemaAt(3)` with
  the generated `v3` helpers: 3 profile rows — Standard at §4.4 defaults;
  Conservative at defaults **except** `profitTargetPct: 55.0` and
  `tailExtrinsicThreshold: 1234`; Aggressive at defaults; 2 underlyings; 2
  cycles; 3 legs — A pinned `rule-profile-standard` (open put), B pinned
  `rule-profile-conservative` (closed, `rolledFromLegId = A`), C pinned
  `rule-profile-standard` (open call); 1 snapshot; 1 share lot; 1
  `user_preferences` row with every non-default value. A second case starts
  from a v1-era database (no `user_preferences` table) with the same
  profiles/legs.
- **Trigger:** open through the current `AppDatabase` (fresh install path
  covered separately: `onCreate` on an empty file).
- **Flow:** `migrateAndValidate(db, 4)`; re-read via the `v4` helpers.
- **Expected outcome:** `rule_profile` = 3 rows of `{id, name}` only;
  `rule_profile_version` = 3 rows, ids `…-v1`, all `version` 1, one shared
  `effectiveAt` equal to the migration timestamp, Conservative's `55.0` and
  `1234` preserved **integer-exact**; leg A/C values =
  `rule-profile-standard-v1`, leg B = `rule-profile-conservative-v1`; every
  other column of every other table byte-identical; schema validates
  against `drift_schema_v4.json`. Fresh install: 3 identity rows + 3 v1 rows
  from `StandardProfileDefaults`. Gating assertion: a test calls
  `migrateAndValidate(db, 3)` and confirms no `rule_profile_version` table
  is created (the v4 step did not run).
- **Edge case of:** S-031, S-092.

### S-191: `appendRuleProfileVersion` + version reads — parity and ordering
- **Fixture:** a fresh repository (both implementations), standard at v1.
- **Trigger:** `appendRuleProfileVersion(profileId: RuleProfileIds.standard,
  effectiveAt: DateTime(2026, 9, 19, 10), values: NewRuleProfileVersionInput(
  profitTargetPct: 60, …all other fields at §4.4 defaults…))`, repeated twice
  more with distinct values.
- **Flow:** read back via `getRuleProfileVersions(profileId)` and
  `getRuleProfileVersion(versionId)`.
- **Expected outcome:** returned row `id = 'rule-profile-standard-v2'`,
  `version = 2`, `effectiveAt` exactly the passed value; list ordered v1,
  v2, v3 ascending **even when two versions share the same `effectiveAt`**
  (ordering is by `version`, not time); `getRuleProfileVersion` for an
  unknown id (incl. `'rule-profile-standard-v99'` and a bare
  `'rule-profile-standard'`) → `null`; identical results in both
  implementations via the shared contract suite.
- **Edge case of:** none.

### S-192: Export v2 round-trips exactly
- **Fixture:** repo with standard edited once (v2, `profitTargetPct: 60`),
  leg A pinned v1, then leg B pinned v2 created after the edit,
  Conservative/Aggressive untouched; one snapshot, one fee value on a leg.
- **Trigger:** `exportToJson` → restore a different fixture (wipe) →
  `restoreFromJson`.
- **Flow:** re-export and re-read legs, profiles, versions.
- **Expected outcome:** envelope `formatVersion` 2, `ruleProfiles` = 3
  identity rows, `ruleProfileVersions` = 4 rows; re-export after restore is
  byte-equal to the first export (same ordering); leg A still resolves to
  `rule-profile-standard-v1` and classifies under 50%, leg B to `-v2` under
  60%; a further append creates v3.
- **Edge case of:** S-150.

### S-193: A format-1 file still imports, converted per D-8
- **Fixture:** a literal `formatVersion: 1` JSON string: 3 profiles (one
  with non-default `profitTargetPct: 55.0`), 1 underlying, 1 cycle, 1 leg
  with `ruleProfileId: 'rule-profile-conservative'`, 1 snapshot, 1
  preferences row. Built from the v1 envelope shape, not by serializing the
  current models.
- **Trigger:** `restoreFromJson(file, now: pinned)` on both implementations.
- **Flow:** read back profiles, versions, the leg; classify the leg.
- **Expected outcome:** 3 version rows at `<id>-v1` carrying the file's own
  values; every row's `effectiveAt` equals the pinned `now`; the leg's
  `ruleProfileVersionId` = `rule-profile-conservative-v1`; the leg
  classifies using `55.0`; re-export is `formatVersion` 2 and a second
  restore of *that* file is an exact round trip (idempotent conversion).
- **Edge case of:** S-152.

### S-194: Import rejection matrix — both formats, both implementations
- **Fixture:** six malformed files: (a) v2 leg referencing an unknown
  version id; (b) v2 with duplicate `(profileId, version)`; (c) v2 profile
  with zero versions; (d) v2 version with unknown `profileId`; (e) v1 leg
  referencing an unknown `ruleProfileId` (the existing check, still
  enforced after conversion); (f) `formatVersion: 3`. Plus a plain
  not-JSON string.
- **Trigger:** `restoreFromJson` with a pre-populated repository (counts of
  every table recorded before).
- **Expected outcome:** each file throws `LedgerImportFormatException`; every
  table's row count and contents are unchanged; no partial write observable.
- **Edge case of:** S-152.

### S-195: Threshold validator — bound table, table-driven
- **Fixture:** table rows covering every bound in D-9: each field at its
  boundary inside and outside (e.g. `profitTargetPct` 0 → fail, 0.01 → pass,
  100 → pass, 100.01 → fail); the §4.4 defaults (all pass); `NaN`/`∞` in
  each `double` field; `base > mid`, `mid > high`, `midCutoff >
  highCutoff` cross-field failures; `midCutoff == highCutoff` → pass
  (D-12); negative `tailExtrinsicThreshold`; `targetDteMin > targetDteMax`.
- **Trigger:** one multi-violation fixture with exactly 3 bad fields.
- **Expected outcome:** violations returned for all bad fields (count 3),
  in field order, each naming its field; valid input → empty; every
  rejection reason is one of the pinned bounds (no invented rules).
- **Edge case of:** none.

### S-196: The audit pin — an edit never reclassifies history
- **Fixture:** InMemory repo; Standard at v1 (50% target); leg A pinned v1:
  `openCreditPerShare = 1.00`, snapshot `optionMark = 0.45` → captured 55%,
  `deltaAsEntered = -0.20`, DTE > tail window, extrinsic above threshold
  (so only Gate 1 can fire). Then append v2 with `profitTargetPct: 60`.
- **Trigger:** open position detail for leg A, and a *new* cycle leg B with
  an identical snapshot, after the edit.
- **Flow:** classify both through `PositionsListController` and
  `PositionDetailController`.
- **Expected outcome:** leg A → `BucketClose` — Gate 1's reason quotes the
  **55** that was captured (not v1's 50% target; corrected in review below),
  in both controllers; what the pin decides is the verdict itself
  (`BucketClose` rather than `BucketLeave`); leg B (pinned v2) →
  `BucketLeave` (55 < 60); the positions list shows the same split in one
  view.
- **Correction (Phase 28 review, implementer-flagged at Phase 25 #1):** the
  original wording said the reason "quotes **50** (v1's number)" — wrong,
  because `classify`'s Gate 1 reason is `<capturedPct>% of credit captured`.
  The assertions live in `test/state/positions/positions_list_controller_test.dart`
  and `.../position_detail_controller_test.dart` (verdict + exact reason), and
  the render-path assertion is `## Feedback` #3.
- **Edge case of:** none — this is the money scenario for the iteration.

### S-197: No-op save writes nothing
- **Fixture:** repo, standard at v1; `ruleProfileVersions` count = 1.
- **Trigger:** save through the editor controller with all 14 values equal
  to v1 (including the "50" vs `50.0` representation difference).
- **Flow:** re-read versions.
- **Expected outcome:** still exactly 1 version; no repository append call
  fired; the UI reports a completed save-or-no-change state without an
  error; changing exactly one value afterwards creates exactly v2.
- **Edge case of:** none.

### S-198: Pinning across all four creation sites
- **Fixture:** leg A (v1, open) with a roll chain; after an edit to v2:
  the screener form, the roll planner for A, and the assignment flow for a
  v1-pinned put leg (each with valid inputs and snapshots).
- **Trigger:** (a) screener "Track this position" → new cycle; (b) roll of
  A; (c) covered call after assignment of the v1 put; (d) close the covered
  call and open another via the assignment path.
- **Expected outcome:** (a) pins `rule-profile-standard-v2`; (b) the new
  leg pins `rule-profile-standard-v1` and `acceptsAssignment` still
  inherits (S-102's other half unchanged); (c) and (d) pin
  `rule-profile-standard-v1`; no created leg ever carries a bare profile
  id. Update the S-102/S-125 tests' expectations to compare **version ids**.
- **Edge case of:** S-102, S-125.

### S-199: Editor renders the current values as editable fields
- **Fixture:** fresh repo (standard v1, §4.4 defaults).
- **Trigger:** open Settings.
- **Flow:** inspect the Active-profile section and the editor form.
- **Expected outcome:** the section shows the profile name, version, and
  effective date plus a one-entry history; the form's 14 fields pre-fill
  from the current version (profit target reads 50; roll bands 0.30 / 0.35
  / 0.40; etc.); each field is editable (not read-only text); the save
  action is inert until a value changes. **This supersedes S-070's
  read-only-card clause** — S-070's delta-convention, total-per-contract,
  and explainer clauses still stand and its test keeps asserting them.
- **Edge case of:** S-070 (partial supersedure).

### S-200: Save → v2 → new cycle uses it, open position does not
- **Fixture:** leg A open pinned v1; Settings open.
- **Trigger:** change profit target to 60 and save; then track a new
  position via the screener.
- **Flow:** read Settings, the repository, leg A's detail, and the new leg.
- **Expected outcome:** version count 2; Settings shows v2 active and the
  history lists both entries newest-first with each one's values and date;
  the new leg pins `-v2`; leg A's detail still classifies under 50% and its
  provenance line still reads v1; the positions list for A is unchanged
  (cross-screen liveness).
- **Edge case of:** S-196.

### S-201: Invalid input blocks the save with every violation shown
- **Fixture:** Settings/open editor; enter `profitTargetPct = 0` and
  `baseRollBand = 0.9` with `midIvRollBand = 0.3` (two violations, one
  cross-field).
- **Trigger:** save.
- **Flow:** inspect the form and the repository.
- **Expected outcome:** both messages are visible simultaneously (not
  first-only); no append occurred (version count unchanged); correcting
  both values and saving creates exactly one new version.
- **Edge case of:** S-195.

### S-202: Provenance line on position detail, including the fallback
- **Fixture:** three legs — one pinned `rule-profile-standard-v2`, one
  pinned `-v1`, one whose `ruleProfileVersionId` resolves to nothing
  (`'rule-profile-standard-v9'`).
- **Trigger:** open each leg's detail sheet.
- **Flow:** inspect the provenance text and classification.
- **Expected outcome:** "Standard v2" / "Standard v1" shown next to the
  bucket; the dangling leg renders with the built-in fallback values
  (versionId `rule-profile-standard-v1`) and does not crash; all new copy
  passes the tone grep.
- **Edge case of:** S-196, D-7.

### S-204: Iteration 5 integration sweep
- **Fixture:** the fully assembled app.
- **Trigger:** `flutter analyze`; `flutter test`; `flutter build ios
  --simulator --no-codesign`; the tone grep; the residue greps below.
- **Expected outcome:** 0 analyze issues; full suite green; build exit 0;
  tone grep returns nothing; residue greps return only the allowed
  matches: (a) `grep -rn "ruleProfileId" lib/` → only historical/handled
  sites (the v1-import conversion and its comments — no live field reads);
  (b) threshold column names under `lib/domain/models/` and
  `lib/data/db/tables/` → `rule_profile_version` only; (c)
  `grep -rn "StandardProfileDefaults" lib/` → seeding + migration + the
  D-13 constants only; (d) `grep -rn "fromData(" lib/` → no
  `RuleProfile.fromData`.
- **Edge case of:** S-090, S-180.

## Iteration 5

### Phase 24: Schema v4 + versioned persistence + export v2 (@data-architect)

> This phase carries a **mechanical pass** through `lib/domain/rules/`
> (factory signature), `lib/state/` (identifier rename + resolver call
> switch), and the tests, so the tree keeps compiling and every suite stays
> green. **Identifier/plumbing changes only — no behaviour may change.**
> Any doubt about behaviour is an Assumption Log entry, not a judgement
> call. Behavior work is Phase 25's.

1. [ ] `lib/domain/models/rule_profile_data.dart`: shrink to `{id, name}`;
       regenerate. Add `lib/domain/models/rule_profile_version_data.dart`
       (`@freezed` + JSON): `{id, profileId, version, effectiveAt, 14
       threshold fields}` — `tailExtrinsicThreshold` keeps
       `@DecimalJsonConverter()`.
2. [ ] `lib/domain/models/rule_profile_ids.dart`: add
       `RuleProfileVersionIds` constants (`standardV1`, `conservativeV1`,
       `aggressiveV1`) and document the `'<profileId>-v<n>'` convention as
       the id format.
3. [ ] `lib/data/db/tables/rule_profile_table.dart`: narrow to `id`, `name`.
       New `rule_profile_version_table.dart`: `id` (PK), `profileId`,
       `version`, `effectiveAtMs` (`DateTimeMsConverter`),
       `tailExtrinsicThreshold` (`TenThousandthsConverter`, non-null), the
       other 12 as `real`/`integer` exactly as today; unique key on
       `{profileId, version}`. No SQL foreign keys (convention).
4. [ ] `lib/data/db/app_database.dart`: register both tables; bump
       `schemaVersion` to 4; `onCreate` seeds identity + v1 rows (one
       install-time timestamp); the `4 -> *` upgrade step implements D-6 —
       **gated `if (from < 4 && to >= 4)`** with the same comment rationale
       the v2/v3 steps carry; bump generated code.
5. [x] Export `lib/data/db/schema/drift_schema_v4.json` and regenerate the
       helpers: `dart run drift_dev schema dump lib/data/db/app_database.dart
       lib/data/db/schema/drift_schema_v4.json` then `dart run drift_dev
       schema generate --data-classes --companions lib/data/db/schema
       test/data/db/generated` — **both flags are required**; without them
       the regenerated helpers lose their `*Companion` classes and every
       migration test stops compiling (Phase 24 assumption #3 explains why a
       full `build_runner` invocation was not used instead). v1–v3 dumps
       stay untouched.
6. [ ] `lib/data/wheel_repository.dart`: keep `getRuleProfile(id)`
       (identity read); add `getRuleProfileVersions(profileId)` (ascending
       by `version`), `getRuleProfileVersion(versionId)` (null when
       unknown), `appendRuleProfileVersion({required String profileId,
       required DateTime effectiveAt, required NewRuleProfileVersionInput
       values}) → RuleProfileVersionData` (id and `version` derived by the
       repository; one atomic write). Add the `@freezed`
       `NewRuleProfileVersionInput` (14 required fields) beside
       `NewLegInput`. Document append-only + the derived-id format.
       `restoreFromJson` gains an optional `{DateTime? now}` forwarded to
       the v1 conversion (D-8).
7. [ ] Rename `Leg.ruleProfileId` → `ruleProfileVersionId` (field, column,
       JSON key, doc) and `NewLegInput.ruleProfileId` →
       `ruleProfileVersionId`; update both implementations' write paths,
       row mappers, and seeders (seed identity + v1 in the in-memory repo
       too, one shared timestamp); regenerate.
8. [ ] `lib/data/export/ledger_export.dart`: `currentFormatVersion = 2`;
       add `ruleProfileVersions`; accept `formatVersion` 1 (convert per
       D-8, with the optional `now`) and 2; extend validation with the four
       new v2 rules; keep v1's existing referential checks running after
       conversion.
9. [ ] Replace `RuleProfile.fromData` with
       `RuleProfile.fromVersion(RuleProfileVersionData v, {required String
       profileName})`; `RuleProfile.standard` (+ conservative/aggressive)
       built inline from the §4.4 defaults with their v1 ids (D-13). Keep
       the value type's field names unchanged this phase.
10. [ ] Mechanical rename/resolver pass through `lib/state/`: the four read
        sites resolve `getRuleProfileVersion(leg.ruleProfileVersionId)` +
        `getRuleProfile(version.profileId)` for the name, fallbacks per
        D-7; `rule_profile_providers.dart` builds `RuleProfile` via
        `fromVersion` (current version = last of the ascending list);
        screener/roll/assignment write the renamed field. No logic change.
11. [ ] Tests: S-190 (new `test/data/db/rule_profile_v4_migration_test.dart`
        incl. the v1→v4 case and the `migrateAndValidate(db, 3)` gate
        assertion), S-191/S-194 contract additions, S-192/S-193 export
        tests (incl. the literal v1 fixture string), update
        `app_database_migration_test.dart`'s fresh-install assertions
        (table set + version rows), and the mechanical rename through
        every test file found by `grep -rl "ruleProfileId" test/`
        (historical schema-helper fixtures keep their old names — they
        build v1/v2/v3 shapes).

**Done Criteria** (run until green): `flutter analyze`; `flutter test`
(full suite — the rename touches everything); `flutter test
test/data/db/rule_profile_v4_migration_test.dart
test/data/wheel_repository_contract_test.dart test/data/export/` green for
S-190–S-194; `dart run drift_dev schema dump` produces a v4 dump that
`migrateAndValidate(db, 4)` accepts; both implementations pass the contract
suite unchanged.

**Predicted Files**: `lib/domain/models/rule_profile_data.dart` (+
generated), `lib/domain/models/rule_profile_ids.dart`,
`lib/domain/models/rule_profile_version_data.dart` (+ generated),
`lib/data/db/tables/rule_profile_table.dart`,
`lib/data/db/tables/rule_profile_version_table.dart`,
`lib/data/db/app_database.dart` (+ generated),
`lib/data/db/schema/drift_schema_v4.json`,
`lib/data/wheel_repository.dart` (+ generated),
`lib/data/db/drift_wheel_repository.dart`,
`lib/data/in_memory_wheel_repository.dart`,
`lib/data/export/ledger_export.dart`, `lib/domain/rules/rule_profile.dart`
(factory only), `lib/state/rule_profiles/rule_profile_providers.dart`,
`lib/state/positions/positions_list_controller.dart`,
`lib/state/positions/position_detail_controller.dart`,
`lib/state/screener/screener_controller.dart`,
`lib/state/roll/roll_planner_controller.dart`,
`lib/state/assignment/assignment_flow_controller.dart`,
`test/data/db/generated/` (regenerated), the migration/contract/export
tests named in step 11, and the mechanical rename across the remaining
test files.

**Phase 24 Assumption Log expectation:** any deviation from the predicted
file list (e.g. drift's column-drop mechanism), the chosen
`ALTER TABLE … RENAME COLUMN` vs `TableMigration` approach, or the exact
`drift_dev schema dump` invocation is logged here.

### Phase 25: Rules-engine version semantics + resolution + validator (@developer)

1. [ ] `lib/domain/rules/rule_profile.dart`: final field set (D-10) —
       `versionId`, `profileId`, `name`, `version`, 14 thresholds; remove
       `id`. `fromVersion` is the only persistence bridge. Update the sole
       `.id` reader (`screener_controller.dart:280`) and any test that
       reads it.
2. [ ] New `lib/domain/rules/rule_profile_validation.dart` implementing
       D-9's table — pure, zero Flutter imports, all violations in field
       order. Machine-readable violation type (field + message), not
       strings only.
3. [ ] Reshape `lib/state/rule_profiles/rule_profile_providers.dart`:
       `currentRuleProfileProvider` (standard's current version via
       `fromVersion`, D-7 fallback) replacing `defaultRuleProfileProvider`;
       `ruleProfileVersionsProvider(profileId)` family for the history UI;
       drop `ruleProfilesProvider` if nothing else reads it (grep first).
4. [ ] Tests: S-195 (`test/domain/rules/rule_profile_validation_test.dart`,
       table-driven); S-196 (extend
       `positions_list_controller_test.dart` +
       `position_detail_controller_test.dart` with the pinned-vs-current
       split); S-197 controller-level no-op rule (in the Phase-26
       controller if it lands there — state the timing in the Assumption
       Log if deferred); S-198 (update `roll_planner_controller_test.dart`
       S-102 expectations, `assignment_flow_controller_test.dart` S-125,
       `screener_controller_test.dart`) — all comparing version ids.
       Add the S-008 boundary table re-run against a **custom** version
       (moved cutoffs) to `roll_band_test.dart` per D-12.
5. [ ] Docs trail code by zero phases: update `docs/conventions.md` §6's
       "one canonical type per concept" bullet (factory +
       `RuleProfileData`/`RuleProfileVersionData` split) and
       `docs/architecture/wheel-triage.md`'s `RuleProfile` sentences
       (lines ~16, ~40, ~284). One sentence each; the policy text itself
       is unchanged.

**Done Criteria**: `flutter analyze`; `flutter test test/domain/ test/state/
test/data/` green; the S-196 test **shown red first** by temporarily
reverting the pin resolution to read the current version (recorded in the
Assumption Log), then green.

**Predicted Files**: `lib/domain/rules/rule_profile.dart`,
`lib/domain/rules/rule_profile_validation.dart` (new),
`lib/state/rule_profiles/rule_profile_providers.dart`,
`lib/state/screener/screener_controller.dart`, the four test files named in
step 4 + `test/domain/rules/rule_profile_validation_test.dart` (new),
`docs/conventions.md`, `docs/architecture/wheel-triage.md`.

### Phase 26: Settings editor + version history + provenance UI (@developer)

1. [ ] Editor controller (hand-written `StateNotifier`, per the standing
       code-gen deviation): draft state seeded from the current version,
       per-field validation from Phase 25's module (all violations shown),
       D-2 no-op suppression, save → `appendRuleProfileVersion` → invalidate
       the current-version + history providers. All copy passes the §4 tone
       grep; the "applies to your next new position; existing positions
       keep the rules they were opened under" statement is mandatory text
       (D-5).
2. [ ] Settings screen: replace the read-only card with the Active-profile
       section — current name/version/effective date, the editor form (14
       fields), and the append-only history (newest first, each entry's
       values + date). Reachable from Settings; a pushed sub-screen or an
       in-place expansion is the implementer's call (mechanic) — no new
       top-level navigation concept, and a **Save** that names what it will
       do.
3. [ ] `lib/features/positions/position_detail_sheet.dart`: provenance line
       (profile name + version) beside the bucket/reason (D-11), using the
       D-7 fallback for dangling ids.
4. [ ] Tests: S-199 (replaces the read-only clause of the S-070 test; the
       rest of S-070's assertions stay), S-200 (cross-screen liveness,
       including "new cycle sees v2, leg A does not"), S-201 (both
       violations visible, nothing written), S-202 (provenance + fallback),
       S-197's UI half.

**Done Criteria**: `flutter analyze`; `flutter test test/features/
test/state/` green; tone grep clean
(`grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/` returns nothing); the S-070 test
updated and green.

**Predicted Files**: `lib/features/settings/settings_screen.dart`, new
file(s) under `lib/features/settings/` for the editor/history (exact name
is the implementer's call — log it), `lib/app_router.dart` only if a route
is added, `lib/state/rule_profiles/` (controller — new file or extension,
log it), `lib/features/positions/position_detail_sheet.dart`,
`test/features/settings/settings_screen_test.dart`,
`test/features/positions/position_detail_sheet_test.dart`, the controller
test for S-197/S-201.

### Phase 27: Integration + iOS build + residue sweep (@developer)

1. [ ] Full `flutter analyze` + `flutter test`; fix nothing silently — any
       behavioural fix is a remediation sub-phase with its own guard.
2. [ ] S-204's four residue greps and the tone grep, with raw output pasted
       into `## Progress`.
3. [ ] `flutter build ios --simulator --no-codesign` (exit 0) and a manual
       simulator launch by the user: open Settings, edit the profit target,
       confirm the history entry, open an existing position and confirm its
       provenance line and unchanged bucket.
4. [ ] Consolidated doc pass: this plan's Assumption Log adjudicated,
       `docs/architecture/wheel-triage.md` re-read for stale threshold
       statements, `CLAUDE.md`'s "State of the build" section flagged to
       the user as stale (out of the conductor's writable scope — do not
       edit it).

**Done Criteria**: S-204 fully green; the greps' raw output recorded.

**Predicted Files**: docs only (`docs/architecture/wheel-triage.md`, this
plan's `## Progress` / `## Assumption Log`).

### Phase 28: Verification (@code-reviewer)

No new behaviour. The reviewer runs the standing battery: diff versus every
phase's Predicted Files (out-of-bounds and untouched-predicted are both
findings); per-S-x test + fixture conformance against this file; the Impact
Check table's greps re-run (any unlisted reader of `ruleProfileId`,
`fromData`, or a threshold column is a finding); parity of all new methods
across both implementations; **the S-196 audit test re-exercised through
the UI path** (open a position after an edit); Assumption Log adjudication
(ratify → promote to D-x; revert → Phase 28.1 remediation with a structural
guard); and one planner-only check — whether any defect traces to plan
imprecision, superseding the relevant scenario by S-id if so.

## Files Affected (whole feature)

- **Models/schema/persistence:** `rule_profile_data.dart`,
  `rule_profile_version_data.dart`, `rule_profile_ids.dart`,
  `rule_profile_table.dart`, `rule_profile_version_table.dart`,
  `app_database.dart`, `drift_schema_v4.json`, generated helpers.
- **Repository:** `wheel_repository.dart`, `drift_wheel_repository.dart`,
  `in_memory_wheel_repository.dart`.
- **Export:** `ledger_export.dart` (reader: settings import UI — untouched;
  `ledger_csv.dart` proven not to read profiles).
- **Rules engine:** `rule_profile.dart`, `rule_profile_validation.dart`
  (new). `roll_band.dart` untouched (D-12).
- **State:** `rule_profile_providers.dart`, `screener_controller.dart`,
  `positions_list_controller.dart`, `position_detail_controller.dart`,
  `roll_planner_controller.dart`, `assignment_flow_controller.dart`, plus
  the new editor controller.
- **UI:** `settings_screen.dart` (+ possible new settings files),
  `position_detail_sheet.dart`, possibly `app_router.dart`.
- **Tests:** new
  `test/data/db/rule_profile_v4_migration_test.dart` +
  `test/domain/rules/rule_profile_validation_test.dart`; extended
  contract/migration/export/controller/settings tests; mechanical rename
  across the ~25 files found by `grep -rl "ruleProfileId" test/`
  (historical schema fixtures excepted).
- **Docs:** this plan, `docs/conventions.md` §6 (Phase 25),
  `docs/architecture/wheel-triage.md`, `docs/plans/wheel-triage-plan.md`
  (M7 pointer + Iteration 5 pointer — done at planning time).

## Notes

- **Dependency graph:** 24 (schema/persistence/export, with the mechanical
  rename keeping the tree green) → 25 (engine value type + resolution +
  validator) → 26 (editor + provenance UI) → 27 (integration) → 28
  (verification). The user's own sequencing constraint is binding: **26
  does not start until 24 and 25 are fully green.** No user checkpoint is
  required by this iteration — the sequence above is the gate.
- **Intermediate state after 24:** versioning is fully live in storage and
  resolution (an edit performed via the repository API already leaves
  history truthful) but there is still no UI to edit — the app behaves
  exactly as before for a user, which is the point of splitting 24 from 26.
- **`TableMigration` vs `ALTER TABLE`:** the v4 step needs a column
  rename + a 14-column drop on `rule_profile` and a rename on `leg`.
  Whichever drift mechanism the implementer picks
  (`m.renameColumn`/`m.dropColumn` if available, `m.alterTable(
  TableMigration(...))`, or `customStatement`), the S-190 assertion set —
  schema validation plus integer-exact value preservation — is the
  acceptance bar, and the mechanism choice belongs in the Assumption Log.
- **Legacy row with an unknown profile id:** the migration appends `-v1`
  blindly (D-7); S-202 exercises the resulting dangling value.
- **Why the `leg` rename is not "just a rename":** the stored value's
  meaning changes (profile id → version id). Leaving the column named
  `rule_profile_id` would be a lie in every row; D-4 renames both.
- **Sorting/tie-breaks:** version ordering is by `version` (an integer),
  never by `effectiveAt`, so two versions saved in the same millisecond
  still order deterministically (S-191).
- **Out of scope, permanently:** multiple named profiles, clone, set-default,
  profile picker, per-underlying profiles, revert-to-version, wash-sale
  detection, tax-lot matching, multi-leg spreads (standing constraints).
  Adding a profile **selection** concept later would be a new brief, not an
  extension of this plan.

## Progress

### Phase 24: Schema v4 + versioned persistence + export v2 (@data-architect)
- [x] **Complete — 2026-09-19.** All 11 steps landed.
  - **Models/tables:** `RuleProfileData` shrunk to `{id, name}`;
    `RuleProfileVersionData` added (+ `.freezed`/`.g`); `RuleProfileTable`
    is 2 columns; `RuleProfileVersionTable` is 18 columns with
    `uniqueKeys = {(profileId, version)}`; `Leg.ruleProfileId` →
    `Leg.ruleProfileVersionId` (field, column, JSON key);
    `RuleProfileVersionIds.forVersion` is the one place the id format
    lives.
  - **Schema:** `schemaVersion = 4`; `onCreate` seeds 3 identity rows + 3 v1
    version rows (one shared install timestamp); the `from < 4 && to >= 4`
    step copies every profile's values into `<id>-v1` (raw `INSERT …
    SELECT`, one `migratedAt` for the whole run), renames the leg column and
    appends `-v1` to every legacy pin, then drops the 14 moved columns;
    `lib/data/db/schema/drift_schema_v4.json` written and the generated
    helpers regenerated with `--data-classes --companions`
    (`test/data/db/generated/schema_v4.dart`).
  - **Repository:** `getRuleProfileVersions` / `getRuleProfileVersion` /
    `appendRuleProfileVersion` (derives id + 1-based version; refuses an
    unknown profile) in the interface and **both** implementations;
    `restoreFromJson({DateTime? now})` on both; export/restore carry
    `ruleProfileVersions`.
  - **Export:** `LedgerExport` format 2 with `ruleProfileVersions`; format-1
    files converted in memory (`_convertFormat1`) and accepted; validation
    extended to every-profile-has-a-version, unique `(profileId, version)`,
    version `profileId` known, leg pin known; the v1 referential check
    (after conversion) kept.
  - **State (mechanical):** the four classification read sites and the
    default-profile provider now resolve the **pinned** version via
    `getRuleProfileVersion` + `RuleProfile.fromVersion` (D-7 fallback to
    `RuleProfile.standard`); all three leg-creation call sites write the
    renamed field; `RuleProfile`'s field set deliberately unchanged this
    phase (Phase 25 reshapes it).
  - **Tests added/extended:** S-190 (three cases: v3→v4, v1→v4 jump,
    `migrateAndValidate(db, 3)` gate), S-191 (append/derive/order incl. a
    shared-instant tie-break, unknown-profile refusal), S-192 (format-2
    round trip), S-193 (format-1 conversion + idempotence), S-194
    (four-case rejection matrix, DB untouched), the fresh-install
    assertions in `app_database_migration_test.dart`, the contract-suite
    profile group, and a new `RuleProfileVersionData` round-trip.
  - **Evidence:** `flutter analyze` → **No issues found!** (2.8s);
    `flutter test` → **405 tests, all passed** (`+405`, 0 failures);
    focused run of `test/data/db/ test/data/wheel_repository_contract_test.dart
    test/data/export/ test/state/screener/screener_controller_test.dart` →
    **115 passed**; `migrateAndValidate(db, 4)` green in all three S-190
    cases.
  - **Residue greps:** `RuleProfile.fromData` → none (only `XFile.fromData`);
    plain `ruleProfileId` in `lib/` → only the format-1 conversion code and
    its docs; threshold columns → `rule_profile_version_*` only (plus
    `rule_profile_defaults.dart`, the seed source, per D-13);
    `rule_profile_table.dart` = 2 column getters.
  - **Deliberately not run this phase:** the iOS simulator build and the
    tone grep — Phase 27 owns both (this phase changed no user-facing copy).
- [ ] iOS build — Phase 27.

### Phase 25: Rules-engine version semantics + validator (@developer)
- [x] **Complete.** All 5 steps landed.
  - **Rules value type (D-10):** `RuleProfile` is
    `{versionId, profileId, name, version}` + 14 thresholds; `fromVersion`
    is still the only persistence bridge; `hasSameThresholdsAs` compares
    the 14 values only (identity fields excluded — the D-2 no-op rule);
    the three D-13 constants carry their own v1 identity.
  - **Validator (D-9):** new `lib/domain/rules/rule_profile_validation.dart`
    — `RuleProfileField` (14, D-9 order),
    `RuleProfileViolation{field, message}`, `validateRuleProfile` returning
    every violation sorted by field order. Pure, zero Flutter imports.
  - **State:** `currentRuleProfileProvider` (was
    `defaultRuleProfileProvider`, which only the screener read) +
    `ruleProfileVersionsProvider(profileId)`; `ruleProfilesProvider`
    **dropped** (grep: no readers); the screener's two read sites and its
    `ruleProfileVersionId` write updated. Both position controllers keep
    their pinned-state + D-7 fallback resolution unchanged this phase.
  - **Tests added/extended:** S-195 (new table-driven file, 22 tests:
    per-field boundary rows, NaN/∞ for every double field, both Decimal/int
    fields, three ordering rules, equal-cutoff + equal-DTE legal cases,
    no-double-report, the 3-violation ordering case, S-201's 2-violation
    fixture); S-197's pure half (`hasSameThresholdsAs`, 3 tests); D-12's
    moved-cutoff table in `roll_band_test.dart` (6 tests, incl. the
    strict-`>` 60.0 row); S-196 in both position suites; S-198 in the
    screener, roll and assignment suites.
  - **Evidence:** `flutter analyze` → **No issues found!**; the two rules
    files → **44 passed**; `test/state/positions/ test/state/screener/
    test/state/roll/ test/state/assignment/ test/domain/rules/` → **220
    passed**; full suite → **`+441`, all passed** (was 405). Tone grep and
    `grep -rl "package:flutter" lib/domain/rules/` both empty.
  - **S-196 red run (Done Criterion):** with both position controllers
    temporarily resolving the standard profile's `versions.last` instead of
    `getRuleProfileVersion(leg.ruleProfileVersionId)`, both S-196 tests
    failed — list: `Expected: <Instance of 'BucketClose'>` vs `Actual:
    BucketLeave:<BucketLeave(reason: Delta 0.2 below the 0.30 band)>`;
    detail: `profile.versionId` `-v2` vs expected `-v1`. Restored, re-run
    green (same file pair in the 220-test run).
  - **Deferred:** S-197's controller half (no-append-fired + UI state) to
    the Phase 26 editor, which owns the save path; the iOS build and the
    residue sweep stay Phase 27's.

### Phase 26: Settings editor + history + provenance (@developer)
- [x] **Complete.** All 4 steps landed.
  - **Controller (new file, name chosen):**
    `lib/state/rule_profiles/rule_profile_editor_controller.dart` — draft
    seeded from the current version row, `validateRuleProfile` on every
    keystroke, violations surfaced only after a save attempt (S-201),
    D-2 no-op suppression, append → invalidate → reload. Save outcomes are
    an enum (`saved`/`noChange`/`invalid`/`failed`); the controller shows
    nothing itself.
  - **UI (new file, name chosen):**
    `lib/features/settings/rule_profile_section.dart` — the Active-profile
    section in place inside the existing Settings list (**no router
    change**): name, `Version n -- effective <date>`, the D-5 statement,
    the 14 fields (D-9 order and labels), the save button (inert until a
    value changes), and the append-only history newest-first with each
    version's own values and date.
  - **Provenance:** `position_detail_sheet.dart` renders
    `Rules: <name> v<version>` directly under the bucket/reason, resolved
    from the leg's pinned version — the D-7 fallback renders
    `Rules: Standard v1` for a dangling pin. Import invalidates the editor
    as well as the other screens' providers.
  - **Tests added:** `test/state/rule_profiles/rule_profile_editor_controller_test.dart`
    (10: draft seeding/formatting, history order, three S-197 cases with an
    append-counting repository subclass, four validation cases incl. the
    S-201 fixture and its correction, post-save baseline move); new
    `test/features/settings/rule_profile_editor_test.dart` (3: S-199, S-200,
    S-201 — **outside this phase's predicted files, added deliberately**:
    S-200/S-201 needed a widget home whose file name says what it tests,
    while S-070's file keeps that scenario; logged at Phase 28 review #5);
    S-202's three-leg case added to
    `position_detail_sheet_test.dart`. S-070's test updated — the read-only
    clause replaced by the section assertion, its delta-convention /
    toggle / explainer clauses intact (its viewport grew to 4000px because
    the lazy list now builds a 14-field form).
  - **Evidence:** `flutter analyze` → **No issues found!**;
    `test/state/rule_profiles/` → **10 passed**;
    `test/features/settings/rule_profile_editor_test.dart` → **3 passed**;
    `test/features/positions/position_detail_sheet_test.dart
    test/features/settings/settings_screen_test.dart` → **20 passed**;
    full suite → **`+455`, all passed** (was 441). Tone grep empty.
  - **A test caught a real defect:** the history first rendered ascending
    (straight from the provider), so v1 sat above v2; S-200's ordering
    assertion failed (`Actual: 1480` vs `Expected: less than 1416`) and the
    section now renders `history.reversed`.

### Phase 27: Integration + iOS build + residue sweep (@developer)
- [x] **Complete (manual simulator launch still owed by the user).**
  - **Analyze:** `flutter analyze` → **No issues found!** (2.9s).
  - **Suite:** `flutter test` → **`+455`, all passed**, 0 failures.
  - **Build:** `flutter build ios --simulator --no-codesign` →
    `Xcode build done. 18.5s` / `✓ Built build/ios/iphonesimulator/Runner.app`.
  - **Tone grep:** `grep -rniE "recommend|we suggest|our analysis|buy
    signal|sell signal|opportunity|guaranteed|you should" lib/` → no
    output (`exit 1`). Rules purity: `grep -rl "package:flutter"
    lib/domain/rules/` → no output (`exit 1`).
  - **Residue greps (S-204 a–d), raw:**
    - (a) `ruleProfileId` minus `ruleProfileVersionId` → five files, every
      hit allowed: `ledger_export.dart:169,179` (a local `Set` *name*),
      `ledger_export.dart:310,353,360` and `wheel_repository.dart:309` (the
      format-1 conversion and its doc, reading the legacy JSON key), and
      `drift_schema_v1/v2/v3.json` (historical schema snapshots). No live
      field read anywhere.
    - (b) threshold names under `lib/domain/models/` + `lib/data/db/tables/`
      → `rule_profile_version_data.{dart,g,freezed}`, the two version
      files' own docs, `rule_profile_ids.dart`/`rule_profile_data.dart`
      (doc comments pointing at the version table),
      `rule_profile_defaults.dart` (the D-13 seed source), and
      `rule_profile_table.dart` (a comment saying the columns **moved** —
      the table itself is 2 column getters).
    - (c) `StandardProfileDefaults` in `lib/` → `in_memory_wheel_repository.dart`
      + `app_database.dart` (seeding), `rule_profile_defaults.dart`
      (source), `rule_profile.dart` (the D-13 constants). Exactly the
      allowed set.
    - (d) `fromData(` → only `XFile.fromData` (`export_controller.dart:44,49`).
      No `RuleProfile.fromData`.
  - **Docs:** `docs/architecture/wheel-triage.md` re-read — its threshold
    statements are all in the version-row terms Phase 24–26 gave them; no
    stale number or read-only claim remained. `docs/conventions.md` §6's
    layer tree updated to name `validateRuleProfile` and
    `RuleProfileVersionData` (log entry 11 below). The standing plan's M7
    pointer (`docs/plans/wheel-triage-plan.md:3312`) already carries the
    Iteration 5 correction from planning time; its older Iteration-3 phase
    text saying profile CRUD "stays M7" is a historical phase record and is
    deliberately left as written.
  - **Owed:** the manual simulator launch (boot a simulator, open Settings,
    edit the profit target, confirm the history entry, open an existing
    position and confirm `Rules: <name> v<n>` with an unchanged bucket).
    No simulator was booted on this machine, so this is genuinely the
    user's step — Phase 28's UI-path re-exercise of S-196 depends on it.

### Phase 28: Verification (@code-reviewer)
- [x] **Complete.** Read-only battery run; findings in `## Feedback`
  (1 critical + 3 warnings + 3 suggestions + 2 stale documents).
  - **Diff vs Predicted Files:** conforms. Out-of-bounds files, all logged by
    their phases: `test/support/rule_profile_fixtures.dart` (25 #5),
    `lib/core/dates/date_text.dart` (26 #2), `docs/conventions.md` §6 (27
    #11), plus the two files Phase 26 #1 chose names for. Two not previously
    logged: the new `test/features/settings/rule_profile_editor_test.dart`
    (Feedback #5) and `lib/data/db/tables/leg_table.dart` /
    `lib/features/positions/positions_list_screen.dart` (mechanical-rename
    touches allowed by Phase 24 steps 7/11 though unnamed in its file list).
  - **Independent re-run:** `flutter analyze` → *No issues found!* (2.6s);
    `flutter test` → **+455, all passed**, 0 failures (matches the handoff's
    pasted counts); `flutter build ios --simulator --no-codesign` →
    `Xcode build done. 6.5s` / `✓ Built`; tone grep and
    `grep -rl "package:flutter" lib/domain/rules/` both empty.
  - **Scenario conformance (4b):** S-190 (three tests incl. the v3-target
    gate), S-191 (shared contract suite, both implementations), S-192
    (byte-equal re-export), S-193, S-195 (22 tests), S-196 (both position
    suites), S-197 (controller half — UI clause → Feedback #4), S-198
    (a/b/c-d), S-199/S-200/S-201 (widgets), S-202 (sheet — pin-through-UI
    assertion → Feedback #3). **S-194 runs 4 of its 6 rows → Feedback #2.**
  - **Impact (4g):** every table row's grep re-run; **0 unlisted readers**.
    `grep -rln ruleProfileVersionId lib/` resolves to exactly the table's
    surfaces; `getRuleProfileVersion` is called only by the two
    classification sites; `getRuleProfileVersions` only by the providers and
    each implementation's own version derivation;
    `currentRuleProfileProvider` read only by the screener (two sites) plus
    the editor's invalidate; the old providers and
    `standardProfileForSettings` are gone; journal/CSV "unaffected" claims
    hold (0 profile references in either file).
  - **Parity:** the three new methods and `restoreFromJson({now})` exist in
    the interface and **both** implementations, proven by the contract
    suite. **Layering (4f):** `fromVersion` has exactly four call sites
    (providers + three controllers) and the editor's draft candidate is not
    a persistence bridge; no concrete-repository import in `lib/state/` or
    `lib/features/` (comments only); `lib/domain/rules/` still Flutter-free.
  - **Doc falsification (4d):** no document under `docs/` declares a scope,
    so all seven were read. Clean: `conventions.md`,
    `architecture/wheel-triage.md`, `brief-followup.md` (its C3 "Everything
    is editable in Settings" became **true** this iteration),
    `brief-ledger.md` (§10 is the supersession this iteration implements).
    Stale: `docs/plans/wheel-triage-plan.md:40`, `CLAUDE.md:222/223/226/241`,
    `docs/brief.md:336/453` → `## Feedback` #8.
  - **Assumption Log adjudication:** 28 entries, **0 REVERT** (see
    `## Feedback` #7 for the two rulings the implementers asked the reviewer
    for, and the promotion recommendation for 25 #6).
  - **Owed:** the user's manual simulator launch — still the only
    unexercised path.

## Assumption Log

(Executors append: decision made, options considered, choice + why.
Coordinator marks each RATIFIED — promoted to a D-x — or REVERT with a
remediation sub-phase. An empty log after a complex phase is itself
suspicious.)

### Iteration 5 planning (@conductor, 2026-09-19)
- Q1–Q5 of the planning round were answered "all defaults" by the user;
  each default is recorded as a D-x (D-1, D-5, D-8/D-11, D-2/D-11, D-6)
  rather than an assumption. No derived interpretations remain open.

### Phase 24 (@data-architect, 2026-09-19)
1. **v4 migration mechanism** — chose `m.createTable` + raw
   `INSERT … SELECT` (version copy) + `m.renameColumn` + raw `UPDATE …
   || '-v1'` (leg re-pin) + `m.dropColumn` ×14 (profile shrink), over
   `alterTable(TableMigration(...))` with a rebuilt column list. Why: the
   raw path is shorter and keeps the value copy in SQL where ten-thousandths
   stay integers end-to-end; `dropColumn` needs SQLite ≥ 3.35, which
   `sqlite3_flutter_libs` and the test runner both satisfy. Verified by
   S-190's schema validation in all three cases.
2. **The leg re-pin is two statements, not one** — `renameColumn` changes
   the column *name*, never the stored values; without the follow-up
   `UPDATE`, every legacy pin would read `rule-profile-standard`, which no
   version row carries (S-190 caught exactly this on its first run). Anyone
   "simplifying" the migration back to a bare rename reintroduces silent
   dangling pins.
3. **build_runner toolchain gap (pre-existing, recorded not fixed)** — a
   full unfiltered rebuild crashes inside `riverpod_generator` with
   `Missing implementation of visitDotShorthandInvocation` (pinned analyzer
   language 3.9 vs SDK 3.11; riverpod_generator emits nothing in this repo —
   providers are hand-written per the standing code-gen deviation). Codegen
   for this phase was produced with targeted
   `--build-filter` runs, which never reach the crashing input and exit 0.
   **No source change was made to work around it.** Phase 27 should flag
   `flutter pub upgrade` (the warning's own suggestion) as a follow-up; a
   failed full rebuild is otherwise indistinguishable from a real codegen
   error, which is why this is written down.
4. **`RuleProfile`'s field set is untouched this phase** — `id` still holds
   the version id, as Phase 24's mechanical-rename constraint requires;
   Phase 25 renames it to `versionId`/`profileId`/`version` per D-10.
5. **Historical-shape tests keep the old column name** —
   `leg_v3_migration_test`, `user_preferences_migration_test`, and the
   v1/v3 insert portions of `rule_profile_v4_migration_test` deliberately
   still write `ruleProfileId`; they build v1–v3 rows where that *is* the
   column.
6. **Leg JSON key renamed** — `Leg.ruleProfileVersionId` serializes as
   `ruleProfileVersionId`; the format-1 import path rewrites the old key,
   so no exported file regresses (S-193 covers it with a non-default value
   on the pinned profile).

### Phase 25 (@developer)
1. **S-196's narrative wording was wrong about the reason string** — the
   register says leg A's bucket reason "quotes **50** (v1's number)".
   Gate 1's reason is `'${capturedPct.round()}% of credit captured'`, so it
   quotes the **55** that was captured, never the 50% target. The test
   asserts the real string; what the pin changes is the verdict itself
   (`BucketClose` rather than `BucketLeave`), and that split is asserted
   directly. No source change — only the plan's prose was inaccurate.
2. **S-197 is split across two phases** — the pure comparator
   (`hasSameThresholdsAs`: equal values in either direction, `0.05` vs
   `0.0500` equal, one value changed not equal, identity-only differences
   equal) is tested now; the controller-level clause (save with no change
   fires no append, reports a completed-save state) needs the editor that
   Phase 26 builds, so it is deferred there and S-197 stays open until then.
3. **`ruleProfilesProvider` dropped, not kept** — grep showed no reader
   outside its own file (the screener read `defaultRuleProfileProvider`
   only), and the Settings card resolves `RuleProfile.standard` directly.
   The renamed `currentRuleProfileProvider` is the single remaining
   current-version reader path for new legs (D-5/D-7).
4. **Validator takes a whole `RuleProfile`, not a value bag** — the Phase 26
   editor can validate a candidate built from its draft without a parallel
   argument list, and Phase 26 labels the fields from `RuleProfileField`
   directly. Bounds are `isFinite`-gated (NaN/∞ are rejections, never a
   silently-false comparison), and a cross-field ordering rule is only
   evaluated when both values pass their own bounds, so a field outside its
   range is never reported twice — the ordering violation is attributed to
   the *earlier* field in D-9 order (reachable only when that field is
   itself valid, base `0.9 > mid 0.3`).
5. **`test/support/rule_profile_fixtures.dart` added** — beyond the
   predicted files. Four suites need the same 14-field
   `NewRuleProfileVersionInput`; per-file copies would be one literal
   maintained four times.
6. **S-198(a) pins a contract on Phase 26** — appending a version through
   the repository notifies no provider, so the test calls
   `container.invalidate(currentRuleProfileProvider)` to stand in for the
   editor's save. Phase 26's save **must** invalidate
   `currentRuleProfileProvider` (and `ruleProfileVersionsProvider` for the
   history) or S-200's cross-screen liveness fails.
7. **S-198(c)/(d) are one test** — both register rows exercise the same
   assignment-path inheritance (`ruleProfileVersionId: leg.ruleProfileVersionId`),
   so one test covers the covered call after assignment and the same leg
   closed early + re-sold. (c)/(d) pin **v1** as the register states: the
   assignment path continues the cycle, it is not a new-cycle site.
8. **S-198(b) is a new top-level group** in
   `roll_planner_controller_test.dart` reusing the file's outer `setUp`
   rather than nesting inside the S-172 group, whose test builds its own
   local fixtures.
9. **Architecture doc corrected twice over** — `SettingsScreen` still reads
   the built-in `RuleProfile.standard` (line 343), so the doc says the card
   *becomes* the editor in Phase 26 rather than claiming it already
   resolves the current version; and the repository-surface paragraph now
   names the three v4 methods as append-only (no update/delete exists, so a
   pinned version cannot be rewritten out from under a leg).

### Phase 26 (@developer)
1. **File names (the plan left these to the implementer)** —
   `lib/features/settings/rule_profile_section.dart` and
   `lib/state/rule_profiles/rule_profile_editor_controller.dart`. The
   editor is an in-place section of the existing Settings list, so
   `app_router.dart` was **not** touched (the plan allowed either).
2. **`lib/core/dates/date_text.dart` added — beyond the predicted files.**
   The section needs the `yyyy-MM-dd` shape, which five feature files
   already carry as a private `_dateText`. The new file uses the shared
   helper; the five existing copies are **untouched** (renaming their call
   sites is a mechanical change outside this phase's predicted files).
   Flagged for the reviewer: either sweep them in Phase 27 or accept the
   duplication explicitly.
3. **S-202's register prose shows the provenance as `"Standard v1"`** —
   rendered as `Rules: Standard v1`, because a version name floating under
   a verdict reads as part of the reason. The test asserts the rendered
   string; no source ambiguity was hidden by this.
4. **D-2's "inert until a value changes" reads on values, not text** —
   re-typing `50` over a stored `50.0` leaves `canSave` false (the form is
   not an edit), while a direct `save()` call still reports `noChange`
   without an append. The first controller test asserted the text reading
   and was corrected, not the controller: numeric equality is the whole
   point of `hasSameThresholdsAs`.
5. **The editor provider is deliberately not `autoDispose`** — a draft must
   survive the section scrolling out of Settings' lazy `ListView` (and
   leaving the screen), which `autoDispose` would discard. The cost is a
   draft that outlives an import, so the import path invalidates it
   explicitly alongside the other screens' providers.
6. **The controller takes a clock closure (`DateTime Function()? now`)**, not
   the screener's fixed `DateTime`: `effectiveAt` has to record the moment
   of the *edit*, and a Settings screen can sit open for hours. Tests inject
   a fixed clock; the widget's provider uses the wall clock, so the widget
   tests match the date by shape (`\d{4}-\d{2}-\d{2}`) rather than by
   today's date — a seeded `effectiveAt` is `DateTime.now()`, and a literal
   date there would fail tomorrow.
7. **S-197's "no append call fired" is asserted as the mechanism, not just
   its effect** — the register asks for the call, so the test subclasses
   `InMemoryWheelRepository` with an append counter rather than only
   re-reading the version list (which the same test also does).
8. **Draft seeding formats per field** — two decimals for the ratios
   (`0.30`, matching S-199's wording), none for the point-valued fields
   (`50`, `70`), and never a rounding that would change the number (a
   stored 55.5 shows as `55.5`, not `56`). The display text is derived from
   the stored values on load and after each save; it never decides what is
   written — the parsed values do.
9. **Two reviewable pieces of copy landed here** (both tone-checked): the
   D-5 statement — "Saving applies the new numbers to the next new position
   you open; positions you already hold -- and legs rolled from them --
   keep the rules they were opened under." — and the save/no-op feedback
   ("Saved as v2.", "No changes to save.").
10. **The 14 editor fields carry no `HelpChip`, deliberately.** The help
   registry is 27 topics quoted verbatim from the brief's §C2, whose input
   table has no threshold-editor entries; writing chips for these fields
   would mean inventing copy the brief does not contain, which the registry
   forbids in its own header. Each field is labelled and the section carries
   the D-5 statement, so nothing is a bare unlabelled number. The reviewer
   should rule on whether the brief wanted the *screener's* input topics to
   extend here.

### Phase 27 (@developer)
11. **`docs/conventions.md` §6's layer tree updated — beyond this phase's
   predicted files.** The predicted list named only the plan and
   `docs/architecture/wheel-triage.md`, but §6 is the binding rule source
   and its tree still listed `RuleProfileData` alone and omitted
   `validateRuleProfile` — both made false by this iteration. Two lines,
   structure only, no rule text changed. Flagging it rather than leaving
   the binding doc stale. The `docs/plans/wheel-triage-plan.md` file was
   **not** touched: its M7 pointer already carries the Iteration 5
   correction (line 3312), and its older Iteration-3 phase text is a
   historical record of what that phase intended, which is not this
   iteration's to rewrite.
12. **`CLAUDE.md`'s "State of the build" is stale and is left alone**
   (out of the writable scope this plan gave the conductor): it still says
   schema **v2**, **240 tests**, and "M1–M4 complete … Iteration 3 shipped",
   and its deviations list still claims `Conservative`/`Aggressive` "need
   real numbers when M7 builds the profile editor" — Iteration 5 built that
   editor and D-1 keeps those two rows hidden and non-editable, so the
   numbers are no longer planned to change. Raised to the user in the
   handoff instead of edited here.
13. **The manual simulator launch is unresolved, not silently skipped.**
   `xcrun simctl list devices available | grep Booted` returned nothing on
   this machine, so the launch-and-eyeball step could not be performed from
   here even partially. The build artifact exists
   (`build/ios/iphonesimulator/Runner.app`); the user's check is the last
   piece of Phase 27.

## Feedback

**Phase 28 review findings — resolved.** Independently re-verified before the
fixes: `flutter analyze` clean, **455/455** tests, iOS build `✓ Built`,
tone/purity/residue greps clean, every Impact-table grep re-run with **0
unlisted readers**, `fromVersion` the only persistence bridge, both
implementations at parity. The four actionable items are fixed with their
guards; the advisory items are closed or explicitly accepted.

1. ✅ **FIXED — import left the version cache stale** (was 🔴 critical).
   `settings_screen.dart`'s import handler now invalidates
   `ruleProfileVersionsProvider(RuleProfileIds.standard)` and
   `currentRuleProfileProvider` alongside the existing four, with the reason
   in-line. **Guard shown red first:** S-162's trigger-B test was rewritten to
   import a profile-edited file (2 cycles + a v2 at 60%) over a 5-cycle
   destination and assert the section header, the history rows and the
   resolved current version afterwards. Against the unfixed source it failed
   with `Found 0 widgets with text containing RegExp: pattern=^Version` at the
   post-import `Version 2` assertion (the section still rendered v1); it is
   green now, S-162's original cycle-count assertion retained.
2. ✅ **FIXED — S-194's two missing rows.** The matrix now runs six rows:
   (a) unknown pin, (b) duplicate `(profileId, version)`, (c) profile with no
   versions, (d) unsupported format, **(e) a version whose `profileId` is
   listed nowhere**, **(f) a v1 leg naming an absent profile** — (f) built by
   downgrading a real export with `_legacyProfileIdFor`, so the conversion
   path's own referential check is the thing under test. Both rows pass on
   **both** implementations, so the shared post-conversion check does enforce
   them (previously an untested assumption).
3. ✅ **FIXED — S-196's render path.**
   `position_detail_sheet_test.dart`'s S-202 case now asserts the rendered
   verdict on each leg: the v2 leg reads `Delta 0.25 below the 0.30 band`
   where the v1 and dangling legs read `50% of credit captured` — 50%
   captured clears v1's target and misses v2's, so the verdict difference
   *is* the pin, asserted through the widget tree. (Both assertions passed
   against the unfixed source: the regression was latent, not live — the
   guard is what was missing.)
4. ✅ **FIXED — S-197's UI clause.** New widget test in
   `rule_profile_editor_test.dart`: re-typing `50.0` over the stored `50`
   leaves the action inert with no error text, no snackbar and still one
   version; a real edit then reports `Saved as v2.` and writes exactly v2.
   The controller's `noChange` branch stays as the public-API guarantee the
   controller test exercises directly (`save()` is callable without the
   button), now documented above `_violationsOf`'s neighbours.
5. ✅ **FIXED — the unlogged test file.** Phase 26's additions list now names
   `test/features/settings/rule_profile_editor_test.dart` with its rationale
   (S-200/S-201 needed a home; S-070's file keeps that scenario).
6. ✅ **CLOSED as accepted — mixed parse + bound violations.** Behaviour is
   unchanged by decision, now stated explicitly in
   `rule_profile_editor_controller.dart` above `_violationsOf`: fixing a typo
   is one save round-trip, and the alternative would run cross-field ordering
   rules against baseline numbers the user never typed, which can attribute a
   violation to an untouched field. Recorded rather than silently kept.
7. ✅ **RULINGS (ratified, no action):** (a) the five pre-existing private
   `_dateText` copies stay — `lib/core/dates/date_text.dart` exists for new
   code and a sweep must not ride on this iteration; (b) the 14 editor fields
   carry no `HelpChip` — the registry is 27 brief-verbatim topics and
   inventing threshold-editor topics would breach its own rule;
   (c) Phase 25 #6 is promoted in substance — **a save must invalidate
   `currentRuleProfileProvider` and `ruleProfileVersionsProvider`**, which the
   editor does and the import path now does too (finding #1).
8. **Documents — one fixed, one user-owned, one optional:**
   (a) ✅ FIXED — `docs/plans/wheel-triage-plan.md`'s "Next handoff:
   @data-architect (Phase 24)" now records Phases 24–28 complete; that file's
   status header also pointed at Iteration 4 as the newest work.
   (b) ✅ FIXED (user authorised) — **`CLAUDE.md`** now reads schema **v4**,
   **456 tests**, Iterations 1–5 complete, and the deferral list names only
   what is actually left (M6 portfolio/calendar, accessibility polish, OCR
   capture, broker CSV import). Three further stale claims in the same file
   were corrected while there: the rules engine's size (~540 → ~1,400 lines),
   `RuleProfile.fromData()` → the version-row split with
   `RuleProfile.fromVersion()` plus `validateRuleProfile` as the one bounds
   home, and the scenario-register paragraph (it claimed the register stopped
   at `S-033`; it now records that `S-001`–`S-180` live in the standing plan
   and `S-190`–`S-204` in this one — verified by grep, and the attribution
   corrected after a first draft wrongly credited the briefs, which carry no
   S-ids at all). The Conservative/Aggressive paragraph now states the rows
   are permanent placeholders rather than promising them "real numbers"
   later.
   (c) 💤 OPTIONAL — `docs/brief.md:336/453` promises clone/edit/set-default
   profiles; `brief-ledger.md` §10 supersedes that under the chain's declared
   precedence, so it is stale rather than contradictory. A one-line pointer
   would stop it reading as live scope.

**Evidence after the fixes:** `flutter analyze` → *No issues found!*;
`flutter test` → **456 passed, 0 failed** (455 + the new S-197 widget test);
S-194 alone → **2 passed** (one per implementation);
`flutter build ios --simulator --no-codesign` → `Xcode build done. 6.6s` /
`✓ Built`.
