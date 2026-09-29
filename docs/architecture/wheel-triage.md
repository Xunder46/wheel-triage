# Wheel Triage — Architecture

Consolidated reference for the shape of the codebase after Iterations 1–5
(M1–M4 plus the brief-followup corrections, the help system, fees/
`acceptsAssignment`, cycle P&L and the journal, snapshot staleness,
export/import, expiration notifications, and rule versioning) and Pro Wave 1
Stages 0–3 (the dependency cleanup, the D-4 theme, Record a trade, the
snapshot preview sheet, and the Today screen). This is a map
of *where things live and why*, not a walkthrough of what they do —
`docs/brief.md` and `docs/brief-followup.md` are the spec of record;
`docs/brief-ledger.md` wins over both where they disagree, and
`docs/brief-pro.md` §2's decisions win over everything earlier;
`docs/plans/pro-wave-1-plan.md` carries the phase-by-phase decisions and
scenario register.

## Layering

```
lib/domain/rules/    pure logic — formulas, classify(), resolveIv,
                     checkCreditBound, RuleProfile, validateRuleProfile,
                     Bucket, screener scoring, cycle P&L, journal aggregates,
                     snapshot freshness, the shared triageInputFor assembly,
                     capital committed/concentration, net premium, reading
                     age, expiry and obligations. Zero Flutter imports
                     (enforced by grep every phase).
lib/domain/models/   plain persisted data classes (freezed). No business
                     logic beyond serialization.
lib/data/            WheelRepository interface + DriftWheelRepository +
                     InMemoryWheelRepository + Drift schema/tables/migrations;
                     lib/data/export/ holds the ledger envelope and CSV
                     builder.
lib/state/           Riverpod controllers/providers — orchestration between
                     domain/models and domain/rules, and the repository.
lib/features/        Screens (screener, positions + Today, record, journal,
                     settings, onboarding, export, paywall).
lib/widgets/         Shared UI (BucketBadge, HelpChip, DeltaSparkline,
                     LegTitle, LabeledNumberField, AppBottomNav,
                     CycleSummaryCard, JournalRow).
lib/core/            Cross-cutting, dependency-free utilities (date/money
                     helpers and `format.dart`'s display formatters, the app
                     router, the theme and its colour tokens, the help-topic
                     registry, the notification id/copy/gateway layer, the
                     export-reminder rule, the D-P15 disclaimer text, and
                     `purchases/` — the store seam, the product ids, the
                     free-tier limit and every Pro string).
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

Schema v5 (Pro Wave 1 Phase 2) adds no table either, only the two columns
the Pro screens read: `user_preferences.wheel_capital_cents` (`int?`, the
`CentsConverter` boundary — `null` means "not set", never zero) and
`user_preferences.concentration_limit_pct` (`real`, default `25.0`). Both
reach the UI through `UserPreferencesData`/`PreferencesController` and
nowhere else; `lib/domain/models/user_preferences_defaults.dart` holds the
one default (`wheelCapital` unset, 25%), and a value outside
`wheelCapitalInRange` (`capital_committed.dart`) is ignored rather than
written (`test/data/db/user_preferences_v5_migration_test.dart`, S-214).

Schema v6 (Pro Wave 2, Phase 1) adds the single-row `entitlement_cache` table
(D-25): `id` (always `'default'`), `is_active`, `plan_kind` (stored as the
enum's `.name` through `ProPlanKindConverter`, never an index), `expires_at_ms`,
`will_renew`, `billing_issue`, `purchased_at_ms` and `checked_at_ms`. The three
timestamps are nullable and carry no default, so "never checked", "no expiry"
and "no purchase date" backfill to `null` rather than to an epoch; every other
column carries a SQL-level `withDefault` drawn from
`lib/domain/models/entitlement_cache_defaults.dart`, which is what makes a
fresh `onCreate` and the `5 -> 6` migration produce the same row from the same
constants (`test/data/db/entitlement_v6_migration_test.dart`, S-255).
`checked_at_ms` is the column that makes the state tri-valued: `null` means no
read has ever succeeded, which is `unknown`, not `inactive` (D-26). The row is
deliberately outside the export envelope — `exportToJson` never carries it and
`restoreFromJson` never deletes or rewrites it, so a hand-edited backup cannot
grant Pro and restoring an old ledger cannot revoke it (S-257).

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
  `null`. This feeds `TriageInput.iv` in both `today_controller.dart`
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
- `triage_input.dart` — `TriageInput` plus `triageInputFor({leg, snapshot,
  dte})`, the **one** assembly of a `TriageInput` from a leg and its latest
  reading. Three callers share it: the positions list, the position detail
  sheet, and Record's pre-save preview (Pro Wave 1 D-17), so a preview
  cannot drift from a live classification. It resolves IV through
  `resolveIv` in both branches, including the null-snapshot one — a leg
  opened at a known high IV keeps it for Gate 3 rather than dropping to the
  profile default (Feature Invariant 18).
- `capital_committed.dart` — `capitalCommittedForCycle`,
  `currentCapitalCommitted`, `capitalCommittedByUnderlying`,
  `concentrationPercent`/`concentrationRatio` and `concentrationFlags`
  (Pro Wave 1 D-9/D-10). "Committed now" is the live figure — open puts at
  strike plus a `holdingShares` cycle's shares at wheel-adjusted basis —
  and is deliberately **not** `cycle_pnl.dart`'s `peakCapitalCommitted`,
  which keeps the Journal's "capital committed" name (D-P14). The
  concentration flag compares the **unrounded** ratio against the limit
  (strictly greater, so a book exactly at the limit is not flagged) and
  rounds only for display (A-5).
- `premium_collected.dart` — `premiumCredits`, `premiumBuybacks`,
  `netPremiumCollected` and the two period helpers (Pro Wave 1 D-8). Credits
  and buybacks are attributed by each leg's own trade date, and **fees never
  enter** the figure.
- `reading_age.dart` — `kAgingDays = 7`, `readingAgeDays`, `needsReading`,
  `olderThanAging` and `agingLine` (Pro Wave 1 D-11). `needsReading` is the
  predicate that puts the inline Update on a row; `olderThanAging`
  deliberately excludes the no-reading case, which stays its own exclusive
  count (Feature Invariant 19).
- `expiry.dart` / `obligation.dart` — the expiry card's two halves (Pro Wave
  1 D-13). `expiry.dart` holds `isPastExpiration`,
  `recordedCloseDateForExpiry` (the expiration date on or after it, the tap
  time before it), `expiryBatchEligible` (past expiration **and** a reading
  exists **and** that reading was out of the money — at-the-strike is not in
  the money), `pastExpirationCard`, and the card's two sentences
  (`expiryReadingLine` per leg, `expiryBatchExplanation` for the batch), so
  the D-13 wording lives beside the D-13 rule and cannot drift from it
  (A-25). `obligation.dart` holds
  `expiringWithinSevenDays`, `expiringThisWeek` and `obligationFor`, whose
  put line is cash-if-assigned and whose call line is shares-delivered.
- `snapshot_preview.dart` — `buildSnapshotPreview(...)`, Record's pre-save
  classification (Pro Wave 1 D-17): it builds a not-yet-persisted `Snapshot`,
  runs the **same** `triageInputFor` + `classify` path a saved reading takes,
  and returns the bucket, captured %, roll band, resolved IV, extrinsic and
  the previous reading's own verdict for the "was … on the … reading" line.
  Nothing here writes or reads storage; the sheet is a preview of a rule, not
  a second implementation of it.

## Repository surface (`lib/data/`)

`WheelRepository` is the sole interface `lib/state/` depends on;
`DriftWheelRepository` and `InMemoryWheelRepository` implement it
identically (`test/data/wheel_repository_contract_test.dart` is the shared
parity suite). Every write that spans more than one row is one atomic
method (`createCycle`, `recordRoll`, `recordAssignment`, `recordCallAway`,
`closeLeg`, `markExpired`) — callers never sequence two writes themselves.
`getPreferences`/`updatePreferences` were schema v2's additions;
`getClosedCycles()` (newest-`endedAt`-first, schema v3) followed;
`getRuleProfileVersions`, `getRuleProfileVersion` and
`appendRuleProfileVersion` (schema v4) are deliberately append-only — no
update or delete method exists, so the version a leg pinned can never be
rewritten out from under it. `getAllLegs()` is the open-and-closed
counterpart to `getOpenLegs()`, ordered by `openedAt` then `sequence` so
both implementations agree; it carries no `id` tie-break because ids are
implementation-chosen (A-3), and it is what Today's ledger strip reads
instead of issuing a query per leg and what Record reads to build its
recent-ticker chips and to resolve a call's host cycle (D-12).
`markExpired` is `closeLeg`'s bulk form: it
records each supplied leg as `expiredWorthless` with a zero close debit and
no close fee, honours the same put-leg-ends-its-cycle rule, and validates
the whole batch before writing any of it, so an unknown id or an
already-closed leg throws `ArgumentError` with nothing changed (A-3). It is
called from exactly two places — `TodayController.markAllExpired` (one call
for the whole batch, D-13) and `PositionDetailController.markExpired` (one
leg, from the detail sheet's own action) — and neither sequences a second
write around it.
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
being written, only deleted. `stockPnL` (`cycle_pnl.dart`) and its
`ledger_csv.dart` mirror `_stockPnL` follow the same rule for the put-side
strike — `shareLot?.assignmentStrike ?? assignedPutLeg.strike` (Feature
Invariant 36).

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

## Today, Record and the theme (Pro Wave 1, Stages 1–3)

**Today** (`lib/features/today/today_screen.dart`,
`lib/state/today/today_controller.dart`) replaces the Positions screen at the
unchanged `/positions` route, so the detail, roll and assignment flows under
it are untouched. `TodayController.load()` is the only place a row's display
data is derived: it reads `getOpenLegs()`, classifies each leg through the
shared `triageInputFor` assembly, and hands the screen a `TodayItem` carrying
the bucket, the DTE, the reading age, D-11's `needsReading`/`olderThanAging`
predicates and D-13's `batchEligible`. The screen renders counts, the aging
line, the D-9 ledger strip, the two expiry cards and the list; it re-derives
nothing, so a change to a predicate is a change in one file. The five count
chips are built from one `_bucketOrder` list, so the row order and the sort
order are stated once, and `bucketLabel` supplies the wording. Coming back to
the route reloads explicitly through a router-delegate listener — the screen
stays alive underneath every pushed route, so `autoRefresh` never fires
(S-205).

D-P13 splits the book in `load()` rather than at render time: a leg past its
expiration leaves `state.items` (and therefore the counts and the list) and
appears only in `state.pastExpiration`, oldest first. `state.expiringThisWeek`
is `obligation.expiringThisWeek`'s own grouping mapped back to the built
items, so the seven-day window stays stated in the rules layer. Past
expiration is read from `expiry.isPastExpiration`, not from a negative DTE,
because a calendar day and a signed day count are not the same question.

The two cards (`lib/features/today/expiring_this_week_card.dart`,
`lib/features/today/past_expiration_card.dart`) are pure presentation over
those two lists plus the rules layer's copy builders: no repository read, no
re-derived rule, no local string. `PastExpirationCard` is the only stateful
one — it holds its own inline error and disables its buttons while
`todayControllerProvider.isLoading` — and both actions confirm before
writing. The batch is **one** `markExpired` call (D-13's atomicity), then one
notification cancel per leg, then a `load()`; a failure returns a message and
deliberately leaves `TodayState.error` unset, so a failed batch cannot blank
the screen (A-28). `TodayItem.cardEntry` is what lets a card call
`expiryReadingLine`/`expiryBatchExplanation` without knowing how eligibility
is decided.

**Record** (`lib/features/record/record_trade_screen.dart`,
`lib/state/record/record_controller.dart`,
`lib/state/record/record_save_service.dart`) is D-16's day-after-the-fill
form. `RecordController` holds the unset-by-default form state and every
derived figure (credit bound, annualised yield, capital, the reminder line,
D-12's host line) — the screen computes nothing (Feature Invariant 5).
`RecordSaveService.save` is D-19's **single** write path for a new leg:
Record and the screener's "Track this position" both call it, so the two
cannot diverge on D-12's host-cycle resolution (`createCycle` vs
`openNextLeg`), the standard profile's current version pin, or reminder
scheduling. A refusal writes nothing — the refusal line is discovered by
reading, never by creating an `Underlying` the user did not ask for (S-234).

The snapshot preview is shared, not duplicated: `buildSnapshotPreview`
(`lib/domain/rules/snapshot_preview.dart`) runs the entered numbers through
the same `triageInputFor` + `classify` path a saved reading takes, and
`lib/features/positions/snapshot_sheet.dart` hosts it for both entry points
(Record's pre-save preview and the position sheet's inline Update), taking a
`legId` and completing with `true` only on a real save.

**The theme** (`lib/core/theme/app_theme.dart`, Pro Wave 1 D-4) is the one
place a colour value is written down: `AppTokens` holds the surface/text
roles plus the accent, caution and error roles and their containers;
`AppTheme.dark`/`AppTheme.light` carry the reference's `--a-*` values (the
dark set is primary, so a device in dark mode sees the design's own palette);
`BucketPalette` plus the `BucketColors` `ThemeExtension` resolve the five
bucket fills and their inks per theme; `AppTheme.dark`/`AppTheme.light` are
the two assembled `ThemeData`s. `main.dart` sets `themeMode: ThemeMode.system`
and the app follows the device. Nothing outside that file names a colour —
the sweep is `grep -rn "Colors\.\|Color(0x" lib/ | grep -v lib/core/theme/`
(a bare `Colors.` in a widget is the residue that spreads), and every surface
reads a token or a `ColorScheme` role rather than a literal that happens to
look right in one theme.

**The new preferences** (`UserPreferencesData.wheelCapital`,
`concentrationLimitPct`, schema v5) are reached only through
`PreferencesController.setWheelCapital`/`setConcentrationLimitPct`, which
refuse an out-of-range value instead of clamping it — a silently corrected
number is worse than a refused one. `wheelCapital` unset is a normal state
every consumer renders as "not set", never as zero.

**The disclaimer** (`lib/core/disclaimer.dart`, D-P15 as fixed by D-18) is
one `const String`, rendered verbatim at the foot of Settings and as a footer
under every first-run explainer card — never paraphrased, trimmed or placed
behind a dismiss (S-249).

## Pro (`lib/core/purchases/`, `lib/state/entitlements/`, `lib/features/paywall/`)

Pro Wave 2 adds one capability — a paid tier — behind a seam thin enough to
read in one sitting, and every rule below exists to keep the app's own
arithmetic free of the store.

**The seam** (`lib/core/purchases/purchase_gateway.dart`) is six methods and no
more: `configure()`, `loadOfferings()`, `currentEntitlement()`,
`purchase(String productId)`, `restore()`, `showManageSubscriptions()`. It
imports exactly three things — `package:decimal/decimal.dart` and the
`entitlement_status`/`pro_plan_kind` enums — so the interface cannot express a
trade, a snapshot or a ledger row, and the only value that ever crosses it is a
product-id `String`. `RevenueCatPurchaseGateway` is the one implementation that
names `purchases_flutter`; `UnconfiguredPurchaseGateway` is the one that names
nothing and is what a build with no store key gets, so the free tier and an
empty store show the same honest nothing instead of a broken paywall
(`test/core/purchases/network_boundary_test.dart`, S-265/S-287;
`test/state/record/record_save_service_test.dart` and
`test/state/entitlements/new_cycle_gate_test.dart`, S-264;
`test/core/purchases/recording_gateway_isolation_test.dart`, S-288). Every Pro
string lives in `lib/core/purchases/paywall_copy.dart`, which is pure Dart and
never hard-codes a price, a period or a trial length — those come from the
offer the store returned (D-31).

The RevenueCat public key is **not** in the repository.
`lib/core/purchases/purchase_configuration.dart` reads it from the environment,
so the owner's build carries it and a checked-out tree can never reach a real
store account by accident:

```
flutter build ios --simulator --no-codesign \
  --dart-define=REVENUECAT_IOS_API_KEY=<the owner's public iOS key>
```

A build without the define gets `UnconfiguredPurchaseGateway` — the free tier,
nothing for sale, no broken paywall. What the store does and does not receive is
written down once, in `docs/privacy.md` (D-36).

**The state** is tri-valued and deliberately never guesses (D-26).
`EntitlementStatus` is `active` / `inactive` / `unknown`, and `unknown` is what
a failed read produces: Pro is never forged from an absent answer, and the free
tier is never inferred from one either. `EntitlementController`
(`lib/state/entitlements/`) owns the whole story: `initialize()` configures the
store, loads the cached row and *then* reads the store once — that order is what
makes a lapsed-connection launch show the right plan instead of the free tier;
`refresh()` re-reads; the cache row is written **only after a successful read**;
and the store's own entitlement-update listener is registered in the
constructor, which is why the provider is deliberately not `.autoDispose`. There
are exactly three refresh points — launch, `AppLifecycleState.resumed` (through
`EntitlementLifecycleScope`, which refreshes on nothing else) and a store push —
plus one conditional read after a purchase or restore that reported a purchase
(`test/widgets/entitlement_lifecycle_scope_test.dart`, S-270).

**The gate** is D-P2's free-tier limit, and it is evaluated in exactly one place:
`NewCycleGate.evaluate()` (`lib/state/entitlements/new_cycle_gate.dart`) returns
`NewCycleAllowed` or `NewCycleBlocked(line:, openCycleCount:)`, and is allowed
iff the entitlement is active **or** the open-cycle count is under
`kFreeTierOpenCycles`. `kFreeTierOpenCycles` is written down once, in
`lib/core/purchases/pro_plans.dart`; the copy builders take it as a *parameter*
rather than reading it, so a second evaluation site cannot appear by accident.
`RecordSaveService.save` — D-19's single write path for a new leg — is its only
production caller, and it sets `paywallTrigger` on the refusal, which both
`RecordController` and `ScreenerController` surface as a getter. Nothing is
written when the gate refuses (S-260).

**The paywall** (`lib/features/paywall/`) is reached three ways, all of them
through `showPaywall(context, trigger:)` — the only `context.push('/paywall')`
in `lib/`: a refused save or track (which carries the D-24 line the state layer
produced), a Pro-only feature that does not exist yet (`ProFeaturePaywallTrigger`),
and the Settings row's own door (`SettingsPaywallTrigger`). The screen decides
nothing: `PaywallController` maps the visible offers through `planRowFor` into a
`PaywallPlanRow` display DTO, so no `lib/features/` file names a store type or
reads the entitlement to decide what to sell. It never opens on launch — a
paywall is an answer to something the user did, never a greeting
(`test/features/paywall/paywall_entry_points_test.dart`, S-277).

**The Settings row** (`lib/features/settings/pro_plan_section.dart`) renders what
the user is on and the ways out of it (D-34): the plan and its renewal or
purchase line, the billing-retry note when the store reports one (display only —
a subscription in billing retry is still Pro), the free tier's count as
`Free · 2 of 3 open cycles`, and Manage subscription / Restore purchases /
See Pro plans as the state allows. It reads the count through
`openCycleCountProvider` — a **count, not a gate evaluation** — because
`lib/features/` never reaches into persistence, and it reads
`kFreeTierOpenCycles` itself so `paywall_copy.dart` stays out of the limit's
business.

### Drift-risk areas

These are the places where the same fact is reachable from two directions,
so a change must land in both or neither. Each is deliberately single-sourced
rather than synchronized by discipline:

| Fact | The one owner | What would drift |
|---|---|---|
| Every colour value | `lib/core/theme/app_theme.dart` | A widget literal that looks right in dark mode |
| A `TriageInput` | `triageInputFor` | The list, the detail sheet and Record's preview classifying differently |
| A bucket's wording | `bucketLabel` | The badge, the counts and the preview line naming the same verdict differently |
| A leg's contract text | `legContractText` (`lib/core/format.dart`) | Today's rows, the expiry cards and the sheet formatting `×3` three ways |
| The D-13 card sentences | `lib/domain/rules/expiry.dart` | The card, the confirm dialog and the detail sheet disagreeing |
| The 7-day expiry window | `obligation.dart` | The card's grouping and a second "due soon" caller disagreeing on the boundary |
| A new leg's write | `RecordSaveService.save` | Record and the screener creating different rows for the same trade |
| A preference | `PreferencesController` | A per-screen copy that stops tracking Settings |
| Repository behaviour | `WheelRepository` + its contract suite | One implementation gaining a method the other lacks |
| A threshold bound | `validateRuleProfile` | A widget re-implementing a range check |
| An entitlement fact | `EntitlementController` | A screen caching `isActive` and keeping its own idea of Pro |
| A Pro string | `lib/core/purchases/paywall_copy.dart` | The paywall and the Settings row wording the same state two ways |

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
  is the single shared source for every preference-backed field across six
  screens (screener, snapshot sheet, roll planner, assignment flow, Today,
  Record) plus Settings and the first-run explainer — never a per-screen
  copy. `update()` awaits its own `ready` first, so a caller that reaches the
  notifier and calls `update()` immediately can never have the write
  silently dropped by an in-flight initial load. The two Pro fields
  (`wheelCapital`, `concentrationLimitPct`) go through the same controller and
  its own setters, which refuse an out-of-range value rather than clamping it.
- Two state classes own a whole feature's writes rather than a screen:
  `RecordSaveService.save` (D-19) is the single path that creates a leg, and
  `TodayController.markAllExpired`/`markExpiredLeg` are the single paths that
  close one as `expiredWorthless`. A screen that calls the repository itself
  for either is the defect these exist to prevent.
- Money-typed no-arbitrage conversion (`lib/core/money/total_per_contract.dart`'s
  `perShareValue`), the whole-dollar tile rounding
  (`lib/core/money/whole_dollars.dart`'s `wholeDollars`, which rounds rather
  than truncates), the display formatters (`lib/core/format.dart` — money,
  percentages, the three date shapes, the month abbreviation and a leg's
  contract text), the expiration-picker default
  (`lib/core/dates/nearest_friday.dart`'s `nearestFriday`/`defaultExpiration`)
  and the shared form field (`lib/widgets/labeled_number_field.dart`) are
  dependency-free helpers shared across screens rather than duplicated per
  screen — the DTE-derives-expiration bug (brief-followup A5) existed at two
  independent call sites in the first build precisely because the logic
  wasn't shared. `lib/widgets/leg_title.dart`'s `LegTitle` is the same
  pattern for a row's ticker + contract, shared by both expiry cards.
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
with its denied-permission note — plus Pro Wave 1's two: the wheel capital
(whole dollars) and the concentration limit (a percentage), both written
through `PreferencesController` and both refusing an out-of-range value
rather than clamping it — plus Pro Wave 2's plan section
(`pro_plan_section.dart`, D-34) at the very top of the list, above
"Defaults for new entries". `lib/core/disclaimer.dart`'s D-P15 text is the
screen's footer, and the same string is the footer of every first-run
explainer card. Profile create/clone/edit stays out of
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
