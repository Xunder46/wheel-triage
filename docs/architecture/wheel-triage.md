# Wheel Triage — Architecture

Consolidated reference for the shape of the codebase after Iterations 1–4
(M1–M4 plus the brief-followup corrections, the help system, fees/
`acceptsAssignment`, cycle P&L and the journal, snapshot staleness,
export/import, and expiration notifications). This is a map
of *where things live and why*, not a walkthrough of what they do —
`docs/brief.md` and `docs/brief-followup.md` are the spec of record;
`docs/plans/wheel-triage-plan.md` carries the phase-by-phase decisions and
scenario register.

## Layering

```
lib/domain/rules/    pure logic — formulas, classify(), resolveIv,
                     checkCreditBound, RuleProfile, validateRuleProfile,
                     Bucket, screener scoring, cycle P&L, journal aggregates,
                     snapshot freshness. Zero Flutter imports (enforced by
                     grep every phase).
lib/domain/models/   plain persisted data classes (freezed). No business
                     logic beyond serialization.
lib/data/            WheelRepository interface + DriftWheelRepository +
                     InMemoryWheelRepository + Drift schema/tables/migrations;
                     lib/data/export/ holds the ledger envelope and CSV
                     builder.
lib/state/           Riverpod controllers/providers — orchestration between
                     domain/models and domain/rules, and the repository.
lib/features/        Screens.
lib/widgets/         Shared UI (BucketBadge, HelpChip, DeltaSparkline).
lib/core/            Cross-cutting, dependency-free utilities (date/money
                     helpers, the app router, the help-topic registry, the
                     notification id/copy/gateway layer, the export-reminder
                     rule).
```

Dependency direction is one-way: `rules ← models ← data ← state ← features`.

## Domain model (§3)

`Underlying → WheelCycle → Leg → Snapshot`, plus `ShareLot`,
`RuleProfileData` (identity: id + name) and `RuleProfileVersionData` (one
immutable version's 14 threshold values). A `Leg` is one short option; a
roll closes one `Leg` and opens the next (never mutates in place).
`Snapshot` is append-only history. A `Leg` also pins the
`ruleProfileVersionId` it was opened under, which is what keeps a later
threshold edit from reclassifying an existing position. `ShareLot` stores
only raw facts — `wheelBasis`/`taxBasis` are always computed live from a
cycle's leg history, never persisted (Feature Invariant 12).

Schema v2 (Iteration 3) adds one table, `user_preferences`, a single
fixed-id row (`UserPreferencesData`: `totalPerContractToggle`,
`deltaConventionDefault`, `firstRunExplainerShown`,
`ivResolutionNoticeDismissed`). `WheelRepository.getPreferences()`/
`updatePreferences()` is the only way anything above `lib/data/` touches it.

Schema v3 (Iteration 4, Phase 15) adds no table, only columns: `Leg` gains
`openFee`/`closeFee` (`Decimal?`, integer cents, total per transaction —
`null` means "not recorded," never zero) and `acceptsAssignment` (`bool`,
defaults `true`); `UserPreferencesData` gains `exportReminderDismissed`,
`lastExportAt`, and `notificationMilestones` (`List<int>`, default
`[21, 7, 0]`). A pre-v3 row backfills to exactly these defaults
(`test/data/db/leg_v3_migration_test.dart`, S-092). The money-formula
fixes and the UI these fields feed are Iteration 4's Phases 16/17 (see
the cycle-P&L and journal sections below).

Schema v4 (Iteration 5, Phase 24) splits the profile instead of extending
it: the 14 threshold columns leave `rule_profile` (now just `id` + `name`)
for the new `rule_profile_version` table (`id`, `profile_id`, `version`,
`effective_at` + the thresholds; unique on `(profile_id, version)`), and
`Leg.rule_profile_id` is renamed `rule_profile_version_id` with every legacy
value rewritten to its own `-v1` id. Versions are append-only — there is no
update or delete method. Seed rows: three identities + three v1 versions
(`test/data/db/rule_profile_v4_migration_test.dart`, S-190).

## Rules engine (`lib/domain/rules/`)

- `formulas.dart` — `capturedPct`, `oneSigmaMove` (takes `spot`, not
  `strike` — brief-followup A1), `cushionSigmas`, `intrinsic`/`extrinsic`,
  `deltaMagnitude`, `dte(expiration, referenceDate)`. Every function is a
  pure function of its inputs; "now" is always a parameter.
- `roll_band.dart` / `rule_profile.dart` — the IV-adjusted roll band and the
  profile that carries its cutoffs. `rule_profile_validation.dart` holds
  `validateRuleProfile`, the one gate on threshold-entry values (D-9): every
  bound in one table, all violations returned at once in field order. It is
  an entry gate only — import deliberately does not call it.
- `iv_resolution.dart` — `resolveIv({snapshot, leg})` returns a
  `ResolvedIv(value, source)`, resolving snapshot IV → leg's `ivAtOpen` →
  `null`. This feeds `TriageInput.iv` in both `positions_list_controller.dart`
  and `position_detail_controller.dart` (brief-followup A3) — never
  `snapshot?.iv` directly. `oneSigmaMove`'s own IV source is unaffected;
  the resolution order is scoped to Gate 3 only. `rollBandLabel(band,
  resolvedIv)` renders the three source-aware display templates.
- `credit_bound.dart` — `checkCreditBound({value, side, spot, strike})`
  implements the no-arbitrage bound (brief-followup A2): a call can't be
  worth more than the stock, a put can't be worth more than its strike.
  Returns `ok` / `softWarn` / `hardReject` with the exact user-facing
  message; wired at the four entry points named in Feature Invariant 20.
- `bucket.dart` / `classify.dart` — the five-way verdict (`close`, `roll`,
  `assign`, `leave`, `unknown`) and the fixed gate order. `Bucket.unknown`
  is returned iff both `capturedPct` and `deltaMagnitude` are null — "no
  snapshot yet" — and is not a verdict (Feature Invariant 19).
- `screener.dart` — `screenerAnnualisedYield`, the two hard gates, and the
  0–9 sorting-score components.
- `basis.dart` / `roll_chain.dart` — `wheelBasis`/`taxBasis` and cumulative
  roll-chain credit, both computed on demand from leg history.
  `wheelBasis`/`taxBasis` take the raw `List<Leg>` + `ShareLot` (not a
  pre-summed per-share `Decimal`) so each leg's own `contracts` is weighted
  correctly (Feature Invariant 25); `roll_chain.dart`'s `cycleTotalPremium`
  is the contract-weighted dollar total this and every other cycle-P&L
  figure use, kept separate from the deliberately unweighted, per-share
  `cycleCumulativeCredit`.
- `cycle_pnl.dart` — the §4.1/§4.4 cycle-P&L figures: `totalFees`,
  `hasFeeGap`/`feeGapCount`, `stockPnL`, `netResult`, `peakCapitalCommitted`
  (the max of every put-side leg's `strike × 100 × contracts` and the
  holding phase's `wheelBasis × 100 × shares`, Feature Invariant 27),
  `returnOnCapital`, `daysHeld`, `rollCount`, and `journalAnnualisedReturn`
  (guards `daysHeld == 0`, S-107), plus a `computeCyclePnl` aggregate the
  state layer consumes whole. `journal_aggregates.dart` — the §4.2 journal
  figures: win rate, average/median premium capture (median, per Feature
  Invariant 29 — never a bare mean), total premium collected, total fees
  paid, net result by underlying, roll-count distribution. Both operate on
  `WheelCycle` + its legs only; a fee is never part of `capturedPct`, so
  Gate 1 always reads credit only (S-103).
- `classify()`'s Gate 2 reads `TriageInput.acceptsAssignment`: `true` keeps
  the `assign` verdict, `false` returns `roll` with the coordinator's
  override string (Feature Invariant 30). The `roll` reason is the one
  place this iteration deliberately overrides `docs/brief-ledger.md`.
- `snapshot_freshness.dart` — `freshnessOf({takenAt, now})` returns
  `fresh`/`recent`/`old`/`stale` on calendar-day boundaries; feeds the
  position sheet's freshness label and names the snapshot date when a
  verdict is stale (S-141's boundary matrix pins the tiers).

## Repository surface (`lib/data/`)

`WheelRepository` is the sole interface `lib/state/` depends on;
`DriftWheelRepository` and `InMemoryWheelRepository` implement it
identically (`test/data/wheel_repository_contract_test.dart` is the shared
parity suite). Every write that spans more than one row is one atomic
method (`createCycle`, `recordRoll`, `recordAssignment`, `recordCallAway`,
`closeLeg`) — callers never sequence two writes themselves. `getPreferences`/
`updatePreferences` were schema v2's additions; `getClosedCycles()` (newest-
`endedAt`-first, schema v3) followed; `getRuleProfileVersions`,
`getRuleProfileVersion` and `appendRuleProfileVersion` (schema v4) are the
newest, and deliberately append-only — no update or delete method exists,
so the version a leg pinned can never be rewritten out from under it.
`getClosedCycles()` returns cycles only, never
pre-aggregated per-leg totals, so a caller needing contract-weighted
figures still calls `getLegsForCycle` per cycle rather than losing each
leg's own `contracts` to a repository-side sum (Feature Invariant 25).
`recordRoll`/`closeLeg`/`recordAssignment`/`recordCallAway` also take an
optional `closeFee`, and `NewLegInput` an optional `openFee` and
`acceptsAssignment` (schema v3) — inheritance/re-asking policy for
`acceptsAssignment` across a roll is `lib/state/`'s job, not the
repository's.

A cycle's `ShareLot` is **retained past call-away** (CR-1): the share
position ends, but the assignment's own recorded
`assignmentStrike`/`contracts` are history. So the interface carries two
accessors with different questions: `getShareLotForCycle` is the **active**
lot (non-null only while the cycle is `holdingShares`, so it is still null
once the shares are sold, exactly as before), and `getAssignmentForCycle`
is the cycle's assignment record for its whole life and after it closes —
the one any closed-cycle figure derived from the assignment must use, since
the assigned leg's own `strike`/`contracts` need not match what was
recorded. Both consumers read it and keep the old leg-derived value only as
a documented legacy fallback: `ledger_csv.dart`'s `_peakCapitalCommitted`
and `journal_controller.dart`'s `_reconstructShareLot` (for a cycle closed
before the record was retained, or a hand-built import — an approximation,
never a preferred path). No schema change was needed: the row was already
being written, only deleted.

Iteration 4 adds the export surface to the same interface:
`exportToJson()`, `countCyclesForReplace()`, and `restoreFromJson(json)` —
the last a replace-all, atomic operation (a real Drift transaction in one
implementation, validate-into-locals-then-swap in the other). Structural
and referential validation runs before any row is touched and a
`LedgerImportFormatException` leaves the database byte-for-byte unchanged
(S-151/S-152).

## Journal, cycle P&L, and fees (Iteration 4)

`lib/state/journal/journal_controller.dart` is the only thing the journal
screen talks to: it loads closed cycles via `getClosedCycles()`, assembles
each cycle's figures through `computeCyclePnl`, and feeds
`lib/features/journal/journal_screen.dart` (route `/journal`) — the screen
does no arithmetic of its own. `PositionDetailController` owns the two
Iteration 4 writes: `updateLegFees` fills whichever of `openFee`/
`closeFee` a closed leg is missing, anywhere in the cycle rather than just
the leg currently shown (a fee gap can belong to an already-rolled-out
leg), and `setAcceptsAssignment` re-triages through a full `load()` with
no new snapshot — and short-circuits a same-value call, since the
repository treats a no-op write as an error. A cycle missing any closed
leg's fee renders "Before fees" and names the gap, with an edit-fees
affordance on the summary card that asks only for the field(s) each leg is
actually missing; the figure is never presented as fee-complete.

## Export/import (`lib/data/export/`, `lib/state/export/`)

`ledger_export.dart` defines the `LedgerExport` envelope — every persisted
model through its own `toJson`/`fromJson`, no new codegen — plus
`restoreFromJson`'s validation and `LedgerImportFormatException`.
`ledger_csv.dart`'s `buildClosedCyclesCsv()` is the human-readable
companion: closed cycles only, newest-`endedAt`-first, seven columns
matching the journal row, decimal dollars (never the stored cents).
`ExportController` is the only thing Settings talks to: `ShareSheet` and
`ImportFilePicker` are narrow interfaces over the two platform plugins
(`share_plus`, `file_selector`) so no screen touches a plugin directly,
exporting records `lastExportAt`, and import is a confirmation that names
the exact `countCyclesForReplace()` count before calling
`restoreFromJson` — cancelling is a genuine no-op. A format error surfaces
inline without disturbing any other provider's state.
`lib/core/dates/export_reminder.dart`'s `exportReminderDue` is pure
(`now` is a parameter): it fires after its `thresholdDays` with
`lastExportAt` as the reference, or — when nothing has ever been exported —
the earliest open position's own `openedAt`, the only "something worth
protecting" timestamp the schema persists. The banner in
`lib/features/export/` renders it on the positions list; dismissing sets
`exportReminderDismissed` permanently.

## Notifications (`lib/core/notifications/`, `lib/state/notifications/`)

`notification_scheduler.dart` owns everything except the platform call:
deterministic `notificationIdFor(legId, milestoneDte)` ids (FNV-1a-style,
not `Object.hashCode`), date-only `notificationTitleFor`/`notificationBodyFor`
copy, and the `NotificationGateway` interface. `DarwinNotificationGateway`
is the real iOS implementation (`flutter_local_notifications`'s
`zonedSchedule`, with the `timezone` database initialized once in
`main.dart`); `NoOpNotificationGateway` is the provider default —
deliberately, unlike `wheelRepositoryProvider`'s throw-by-default: a
missing gateway is an expected runtime state (permission denied, desktop
dev) the app must survive, while a missing repository is a wiring bug.
Cancellation sweeps the fixed `kSupportedNotificationMilestones` universe,
so no lookup table is ever needed. Permission is requested once, lazily,
at the first leg creation (`ScreenerController.trackThisPosition`, Feature
Invariant 32); scheduling happens there and in `openCoveredCall`,
cancellation in `closeDirect` and `confirmRoll` (old leg) and
`confirmPutAssignment`/`confirmCallAway`. Milestones are read from the
preferences at leg-creation time only and never rewrite an existing leg's
schedule (Feature Invariant 31); the Settings note for a denied permission
shows only for `denied`, never for `notDetermined` — a warning before the
user has even been asked would be a false signal.

## State layer conventions worth knowing

- `lib/state/preferences/preferences_provider.dart`'s `PreferencesController`
  is the single shared source for every preference-backed field across four
  screens (screener, snapshot sheet, roll planner, assignment flow) plus
  Settings and the first-run explainer — never a per-screen copy.
  `update()` awaits its own `ready` first, so a caller that reaches the
  notifier and calls `update()` immediately can never have the write
  silently dropped by an in-flight initial load.
- Money-typed no-arbitrage conversion (`lib/core/money/total_per_contract.dart`'s
  `perShareValue`) and the expiration-picker default
  (`lib/core/dates/nearest_friday.dart`'s `nearestFriday`/`defaultExpiration`)
  are dependency-free `lib/core/` helpers shared across screens rather than
  duplicated per screen — the DTE-derives-expiration bug (brief-followup A5)
  existed at two independent call sites in the first build precisely because
  the logic wasn't shared.
- UI code that needs a controller method's just-written result reads it
  back via `ref.read(providerFamily(id))`, never the `StateNotifier`'s own
  `.state` getter (`@protected`/`@visibleForTesting`).

## Help system (`lib/core/help/`, `lib/widgets/help_chip.dart`)

`help_topics.dart` is a `Map<String, HelpTopic>` — the single source of
truth for all 27 topics in brief-followup §C2 (12 inputs, 10 outputs, 5
buckets), content verbatim. `HelpTopic` is `{title, body, whereToFind}`;
only the Inputs table has a "Where to find it" column, so `whereToFind` is
`null` for every Output and Bucket topic.

`HelpChip(topicId)` renders a small "?" with
`Semantics(button: true, label: 'Help: <title>')` and opens
`showHelpSheet` — a modal bottom sheet, never a `Tooltip` (unreadable on
phones, unreachable for screen readers). `BucketBadge` reuses the same
`showHelpSheet` function for its own tap-to-help behavior (S-083) so the
sheet layout is never duplicated between the two entry points.

Chips are wired at every (screen, topic) location the scenario register
names: the screener (14 topics), the snapshot sheet (5), the position
detail arithmetic card (5), and the assignment flow's covered-call step (1)
— `test/features/help_coverage_test.dart` is a table-driven check against
exactly that fixture. The roll planner has no chips: none of its fields
(`New strike`, `Buyback debit`, `New credit`, `New expiry`) map to a §C2
topic id, and the scenario register does not name it as a chip location.

## Onboarding (`lib/features/onboarding/`, `lib/features/settings/`)

`FirstRunExplainerScreen` is a 3-card `PageView`, content verbatim from
§C3. Finishing or skipping always sets `firstRunExplainerShown = true`;
reopening it from Settings when the flag is already `true` is therefore an
idempotent no-op, not a special-cased second code path — the automatic
first-launch trigger only fires on `!firstRunExplainerShown`, so an
already-true flag can never be "re-armed."

`lib/main.dart` loads preferences once, before `runApp`, specifically to
decide the router's initial location (`/first-run` vs `/positions`)
synchronously — simpler and more robust than an async-aware `redirect`
callback for a decision made exactly once per process lifetime.
`lib/core/app_router.dart` exposes `buildAppRouter({initialLocation})` as a
function rather than a `final` singleton for exactly this reason.

`SettingsScreen` holds every preference surface: the delta-convention
default, the total-per-contract toggle, the Active-profile section, the
first-run explainer re-run entry point, plus Iteration 4's additions —
Export and Import entries (through `ExportController`, never the plugins or
the repository directly) and the notification-milestone checkbox editor
with its denied-permission note. Profile create/clone/edit stays out of
scope; Iteration 5's D-1 narrows the feature to editing the single
`Standard` profile's thresholds in place (multiple named profiles are
dropped, so there is no picker).

That Active-profile section (`lib/features/settings/rule_profile_section.dart`
over `lib/state/rule_profiles/rule_profile_editor_controller.dart`) is the
whole of the profile UI: it resolves the profile's current version row
through `currentRuleProfileProvider`'s sibling `ruleProfileVersionsProvider`,
renders the 14 thresholds as editable fields, and saves by appending a new
immutable version — a save whose values equal the current version writes
nothing (D-2), and invalid values are refused with every violation shown at
once (S-201). The version history sits below the form, newest first, and the
position detail sheet names the version each leg was classified under
("Rules: Standard v2"), which is what makes an edit an audit event rather
than a silent rewrite.
