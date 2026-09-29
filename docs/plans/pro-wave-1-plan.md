# Feature: Wheel Triage Pro — Wave 1 "Daily use" (Stages 0 → 4A → 1 → 2 → 3)

> Status: DRAFT — five derived interpretations marked *(derived — vetoable)* below; nothing else is open.
> Next handoff: @data-architect (Phase 1)
> Binding conventions: `docs/conventions.md` (+ `docs/architecture/wheel-triage.md`; spec: `docs/brief-pro.md` §2/§4/§5; UI reference: `docs/design/pro-ui-reference.html`, non-binding)
> S-ids: S-211 … S-254 (continue after the highest existing id, S-210; never reused)

## Overview

The ledger release made the app correct; this wave makes it cheap to use daily.
Three user-visible surfaces change and one foundation is replaced:

- **Stage 0** removes the unused Riverpod codegen stack (`riverpod_annotation`,
  `riverpod_generator`, `riverpod_lint`, `custom_lint`) so a full
  `build_runner` run works again, and drops the unused `fl_chart`.
- **Stage 4A** lands the theme (dark by default, light supported, one token
  set) *before* the new screens, so Record, the snapshot sheet and Today are
  built once.
- **Stage 1** adds **Record a trade** — log a trade already placed at the
  broker without touching the screener's eleven fields — and makes the
  screener's own save path follow D-P12 so the two cannot diverge.
- **Stage 2** makes the snapshot sheet reachable straight from Today with a
  live, `classify()`-backed preview of the bucket the numbers would produce.
- **Stage 3** replaces Positions with **Today**: bucket counts, an aging
  count, the ledger strip, concentration, "Expiring this week", and the
  past-expiration batch card, with bottom navigation and the D-P15
  disclaimer.

Nothing already recorded is ever locked or rewritten by this wave. Two
existing behaviours change, both because the brief requires it: the
screener's call save path (D-P12) and the date `Mark expired` records
(D-P13). Everything else is additive.

## Resolved Decisions (Ledger)

Entries are enforceable contracts. Immutable once written; changes are new
superseding entries.

**D-1 — Wave scope** *(derived — vetoable)*. This plan file covers Wave 1
only, in the brief's order: Stage 0 → 4A → 1 → 2 → 3. Wave 2 (Stage 5,
purchases) and Wave 3 (Stages 6–8) get their own plan files, planned when
this wave is done. Nothing here implements the free-tier limit D-P2, a
paywall, screenshot scan, portfolio view or the share card.

**D-2 — Stage 0 removal set.** Remove `riverpod_annotation` from
`dependencies` and `riverpod_generator`, `riverpod_lint`, `custom_lint` from
`dev_dependencies`; remove `fl_chart`; remove the `analyzer.plugins:
- custom_lint` entry from `analysis_options.yaml`. `build_runner`,
`drift_dev`, `freezed`, `json_serializable`, `mocktail` and their pinned
versions stay exactly as they are. The stale pubspec comment that explains
the "mutually-compatible analyzer era" must be rewritten to cover only the
keep set — leaving a comment that explains why a removed package is pinned
is residue. After removal, `dart run build_runner build
--delete-conflicting-outputs` must exit 0 and `git status --porcelain` must
show **no** modified file under `lib/data/db/schema/`,
`test/data/db/generated/`, or any `*.g.dart` / `*.freezed.dart`.

**D-3 — Theme mode** *(derived — vetoable)*. `MaterialApp.router` gets
`theme:` (light), `darkTheme:` (dark) and `themeMode: ThemeMode.system`; the
dark tokens are the design's primary set, so a device in dark mode sees the
reference's palette and a device in light mode gets the light one.

**D-4 — One token set, exact values.** All colour lives in
`lib/core/theme/`; **no colour literal appears anywhere else in `lib/`**
(the single current literal, `Colors.teal` in `main.dart`, is deleted).
Flutter `ColorScheme` carries the neutral/accent roles; a
`BucketColors` `ThemeExtension` carries the five bucket treatments.

| Token | Dark | Light |
|---|---|---|
| background (screen ground) | `#101717` | `#F2F6F6` |
| card surface | `#171F1F` | `#FFFFFF` |
| raised surface (carried fields, tracks) | `#1F2A2A` | `#E4EDED` |
| outline (non-text borders) | `#404E4E` | `#A3B4B4` |
| divider | `#243030` | `#DCE5E5` |
| text | `#E1EAE9` | `#192424` |
| muted text | `#9CAFAF` | `#526464` |
| accent | `#60D3C6` | `#007C76` |
| on-accent | `#082D29` | `#FFFFFF` |
| accent container | `#1C3F3B` | `#C3EAE4` |
| caution (soft warn, debit rolls) | `#FAA96A` | `#B0561D` |
| error (hard reject) | `#F98C8B` | `#BF3B3F` |

Bucket fills are one set for both themes, stepped in lightness:
Close `#A5EDB7` (ink `#192626`), Roll `#E8AF51` (ink `#192626`), Assign
`#7D8FDD` (ink `#192626`), Leave `#5A6E72` (ink `#F4F7F7`). Assign must
**stop** borrowing the error role (assignment is part of the strategy, not a
failure). "No data" keeps no fill — muted text plus a dashed outline — and
stays visually distinct from Leave (Feature Invariant 19). In the light
theme each bucket pill gets a hairline edge; the dark theme does not (OC-10
ratified).

**D-5 — Theme guards are permanent tests, not a one-off audit.** The
contrast requirement (≥ 4.5:1) is enforced by a pure unit test over the
token pairs in both themes, and the bucket badge gets goldens in all five
states in both themes. Both are generated/compared on the Mac only.

**D-6 — Two new preferences (schema v5).**
`UserPreferencesData.wheelCapital`: `Decimal?`, `null` means *not set*,
stored as **integer cents** (`CentsConverter` — the equity-price unit, never
ten-thousandths). `UserPreferencesData.concentrationLimitPct`: `double`,
default `25.0`, accepted range `> 0` and `<= 100`; a value outside that range
is refused at entry (never silently clamped). Both mirror through
`UserPreferencesDefaults`, the Drift table, the migration, and **both**
repository implementations in the same phase.

**D-7 — Export compatibility** *(derived — vetoable)*. The export shape
change is additive with defaults, so `LedgerExport.currentFormatVersion`
**stays 2**; the two new keys are always written by a new build, and a file
written before this wave (no such keys) imports to `wheelCapital = null`,
`concentrationLimitPct = 25.0`. The existing "future formatVersion is
refused" scenario keeps its meaning untouched.

**D-8 — "Net premium · <month>" and "Year to date" (pins OC-2).** For a
period `[start, end]` over calendar dates:

```
credits  = Σ (openCreditPerShare × 100 × contracts)   for legs with start ≤ date(openedAt) ≤ end
buybacks = Σ ((closeDebitPerShare ?? 0) × 100 × contracts)  for legs with start ≤ date(closedAt) ≤ end
net      = credits − buybacks
```

Fees never enter this figure. Legs of open and closed cycles both count; a
leg opened in an earlier period belongs to that period's figure, not this
one's. An assigned leg records no close debit, so it contributes no buyback.
Month = the calendar month containing `now`; year to date = 1 January of
`now`'s year through `now`. The definition is stated on screen, in the
reference's words: "Premium: credits received minus buybacks paid, by trade
date, before fees."

**D-9 — "Committed now" (pins D-P14 and OC-3).**

```
for each cycle:
  putSide  = Σ (strike × 100 × contracts) over its open put legs   (closedAt == null)
  shareSide = cycle is holdingShares ? wheelBasis(put legs + active share lot, no calls
                                    since assignment) × 100 × shareLot.contracts : 0
  capital(cycle) = putSide + shareSide
total = Σ capital(cycle) ; per underlying = Σ over that ticker's cycles
```

- Legs whose expiration has passed but are still open **are included**; the
  on-screen definition says so ("includes legs past expiration until
  recorded").
- A `holdingShares` cycle with **no** open call still counts — the shares
  are held.
- The share side uses the active lot (`getShareLotForCycle`); a cycle with
  neither an open put leg nor a share lot contributes zero.
- This figure is always named **"Committed now"** and never displayed as a
  bare "capital committed": the Journal's peak figure keeps that name
  (D-P14). Screen definition line: "Committed now: open puts at strike,
  shares at wheel-adjusted basis" — extended with `; N% of your $X wheel
  capital` when wheel capital is set.

**D-10 — Concentration and its flag.**
`concentration(underlying) = capitalCommitted(underlying) ÷ wheelCapital ×
100`. The flag appears only when `wheelCapital != null` **and**
`concentration > concentrationLimitPct` — strictly greater, matching
`brief.md` §5.6's "exceeds"; a book exactly at the limit is not flagged.
Flags are one line per exceeding underlying, largest first, in the neutral
surface colour, worded as a fact: `INTC 27% of wheel capital · limit 25%`
(percentages rounded to the nearest whole percent). With no wheel capital
set there is no flag anywhere, and Today shows the one-line invitation:
"Concentration per underlying appears once wheel capital is set in
Settings." No link to a Portfolio screen exists yet (Wave 3 adds it).

**D-11 — "Needs a reading" and the aging count (D-P11).** One named
constant, `kAgingDays = 7`, in one place. For an open leg with a latest
snapshot:

```
readingAgeDays = daysBetween(snapshot.takenAt, now)        // calendar days, existing helper
needsReading   = latestSnapshot == null || readingAgeDays > kAgingDays
olderThan7     = latestSnapshot != null && readingAgeDays > kAgingDays
```

- A reading exactly 7 calendar days old is **not** counted; 8 is.
- The aging count is **overlapping**: those legs stay in their bucket's
  count. It is rendered separately and names the legs and dates it counts.
- "No data" stays its own, exclusive count (Feature Invariant 19) and is
  never part of the aging count.
- `needsReading` is the same predicate that puts the inline Update on a row
  (OC-4 ratified).

**D-12 — A call attaches to a waiting share-holding cycle (D-P12).** When
the side is Call and the ticker is non-empty, resolve the host cycle:

```
candidates = cycles with status == holdingShares for that underlying
openCall(cycle) = cycle has a leg with closedAt == null && optionType == call
eligible = candidates where !openCall(cycle)
```

- **Exactly one eligible** → the leg is saved as that cycle's next leg
  (never a new cycle, never counted as a new cycle), at the standard
  profile's current version, with the reminders scheduled exactly as the
  screener's covered-call path schedules them.
- **More than one eligible** *(derived — vetoable)* → the most recently
  `startedAt` cycle wins; this is a data-repair edge case, not a feature.
- **No candidate at all** → refused, one line, nothing written: "Calls are
  recorded against shares held from an assignment, and there are no
  \<TICKER> shares on record."
- **Candidates exist but all have an open call** → refused, one line,
  nothing written: "\<TICKER> already has an open call; close or roll it
  first."
- Puts are unaffected: a put always opens a new cycle.
- **One shared save path** serves Record and the screener's "Track this
  position", so the two save paths cannot diverge; the screener's call path
  changes from "creates a put-style cycle holding a call leg" to this rule.

**D-13 — Expiry records the expiration date (D-P13).**

```
recordedCloseDate(leg, now) = daysBetween(leg.expiration, now) >= 0 ? leg.expiration : now
```

- The single-leg "Mark expired" action records `closedAt =
  recordedCloseDate(leg, now)`; before the expiration date it keeps today's
  behaviour (the tap time). Reason stays `expiredWorthless`, close debit
  stays `$0`, the close fee field stays optional and null when blank.
- A batch action is **one atomic repository write**: either every selected
  leg is recorded or none is. Each leg is recorded exactly as the single-leg
  action records it, with `closedAt = leg.expiration`, close debit `$0`,
  close fee `null`; a put leg still ends its owning cycle.
- Past-expiration open legs (`daysBetween(leg.expiration, now) > 0`) appear
  **only** on the past-expiration card — never in the bucket counts and
  never in the open-positions list. They *are* still counted in "Committed
  now" (D-9).
- Eligible for "Mark all expired": past expiration **and** a latest reading
  exists **and** that reading was out of the money
  (`intrinsic(strike, spot, type) == 0`; a reading exactly at the strike is
  not in the money). Legs with no reading, and legs whose last reading was
  in the money, are listed on the card with their own actions and are never
  included in "Mark all".

**D-14 — Today, navigation and the route** (pins OC-1, OC-4, OC-5). Today
replaces Positions as the start screen. The route path stays `/positions`
with its existing `:legId` children — the detail, roll and assignment routes
and every deep link from first-run and the assignment flow keep working
unchanged. Bottom navigation is fixed and reads, in order: Today, Journal,
Record (centre, the raised item), Screener, Settings. The Today app bar's
Screener/Journal/Settings icons are deleted; sorting moves into the list
header as a compact control reading **"By bucket"**, "By DTE", "By ticker"
("Bucket severity" is retired — severity is language the bucket names
avoid). Counts appear in the list's own sort order — Assign, Roll, Close,
Leave, No data — each filters the list when tapped and clears when tapped
again. Rows keep badge + reason together; rows where `needsReading` is true
carry the inline Update, every other row opens the detail sheet. The export
reminder banner stays above the counts; the empty state reads "Nothing
recorded yet" with "Record a trade" and "Open screener".

**D-15 — Rounding** (pins OC-12). Summary tiles (the Today ledger strip, the
Record preview tiles) round money to whole dollars, half-up; position rows
and the detail sheet keep two decimals (`brief-ledger.md` §8). Percentages
on the concentration line round to the nearest whole percent.

**D-16 — Record a trade** *(derived pre-selection — vetoable)*. Fields:
ticker (with up to six recently used ticker chips, most recently opened leg
first, from open **and** closed cycles), put/call, strike, expiration,
credit, contracts. Required at save: ticker, strike, credit, expiration,
contracts — a put needs no stock price (its bound is the strike). Optional,
collapsed behind a disclosure: stock price, IV, IV rank, open fee; blank
optional values persist as `null`, never zero. Expiration offers the next
four Fridays (strictly after today) as chips plus "Other date…", which opens
the existing picker and keeps its non-Friday warning and derived DTE; the
chip pre-selected is the farthest of the four (the closest of them to the
existing 30–45-day default window). "Happy to be assigned on this one?"
defaults on and writes `acceptsAssignment`. The credit field honours the
total-per-contract preference and the no-arbitrage bound (Feature Invariant
20) — a put is bound-checked with no stock price, a call with no stock price
skips the check rather than guessing. Before saving, the screen shows the
screener's annualised yield (`screenerAnnualisedYield`) and capital
committed (`strike × 100 × contracts`) with their definitions. Saving writes
exactly what "Track this position" writes — one underlying, one cycle (or
one attached leg per D-12), the first leg, and its reminders — and the
reminder line names the milestones that will actually fire for this leg. The
screener is linked ("Run the numbers first in the screener") and stays as
built.

**D-17 — The snapshot preview (pins OC-6).** Before saving, the sheet shows
the bucket the entered numbers *would* produce — badge, reason string,
captured %, roll band with its source, extrinsic remaining — computed by
`classify()` against a transient, unpersisted `Snapshot` built from the
form's values, the leg's **pinned** rule version, and real `now`, never
`takenAt`. No rule logic may live in a widget: the preview is a pure
function in `lib/domain/rules/`, and it reuses the same `TriageInput`
assembly the live classifications use (one implementation, three callers).
When the preview's bucket differs from the leg's current bucket, one line
says so ("Was Leave on the Sep 17 reading"). Carried-forward values (stock
price, IV) stay visually marked until the user edits them; option mark and
delta are never carried. Clearing IV falls the band back to IV at open and
the source line says so.

**D-18 — The disclaimer (D-P15).** The exact string lives once, as
`kAppDisclaimer` in `lib/core/disclaimer.dart`, and is rendered in Settings
(below every section) and as a persistent footer on the first-run explainer
visible on every card — never paraphrased, never moved behind a tap. A test
pins the string character-for-character:

> Wheel Triage is a journal and calculator for your own options trades. It
> keeps a record of what you enter and checks those numbers against the
> thresholds you set. It is not investment advice. It has no market data
> connection and no view on any security.

**D-19 — One save path for a new leg.** Record and the screener both call
one state-layer entry point that owns: the D-12 host-cycle resolution,
`createCycle` vs `openNextLeg`, the standard-profile version pin, and
reminder scheduling. Wave 2's free-tier check (D-P2) and Wave 3's scan
entry therefore land in exactly one place.

**D-20 — Deliberately not in this wave.** Paywall, entitlement, D-P2 limits,
screenshot scan, portfolio view, share card, the Stage 4B accessibility
audit, the Android build, and any change to gate ordering, thresholds, money
units or the profile model. Inline Update on Today is *not* a substitute for
the detail sheet, and no new notification type is introduced.

## Feature Invariants

Only the invariants that bite here. Project-wide rules stay in
`docs/conventions.md` — referenced, not copied.

1. `lib/domain/rules/` stays pure Dart with **zero Flutter imports**
   (`grep -rl "package:flutter" lib/domain/rules/` returns nothing) and
   every new function takes `now` as a parameter.
2. No `double` for money: wheel capital is `Decimal`/integer cents end to
   end; every premium, capital and obligation figure is `Decimal`, converted
   to `double` only inside a display formatter.
3. Repository parity: `getAllLegs` and the atomic batch expire ship in
   `DriftWheelRepository` **and** `InMemoryWheelRepository` in the same
   phase, with contract coverage. Neither may throw `UnimplementedError`.
4. Never a bare verdict: every new place a bucket is shown, the reason
   string is in the same view.
5. The preview, Today's rows and Record's preview all read the rules engine;
   no widget computes a gate, a percentage or a band.
6. Every number on a screen added by this wave has a semantics label naming
   its quantity ("Delta 0.25", "Capital committed 3,800 dollars") —
   `docs/conventions.md` §9, standing from this wave on.
7. Nothing already recorded is rewritten. Two existing behaviours change and
   only these: the screener's call save path (D-12) and the date recorded by
   "Mark expired" (D-13).
8. Gate order in `classify()` and every threshold default stay exactly as
   built; this wave adds no threshold.

## Requirements

From `docs/brief-pro.md` §4 (Stage 0, 4A, 1, 2, 3), each bullet an
acceptance criterion:

| # | Requirement | Scenarios |
|---|---|---|
| R1 | Unfiltered `build_runner` succeeds; schema JSONs and migration tests unchanged | S-211, S-212 |
| R2 | `fl_chart` removed | S-213 |
| R3 | Dark default, light supported, follows the system; one token place | S-218, S-220 |
| R4 | Bucket colours differ in lightness; Assign is not the error colour; No data ≠ Leave | S-218, S-219 |
| R5 | Badge goldens ×5 states ×2 themes; text contrast ≥ 4.5:1 both themes | S-218, S-219 |
| R6 | Existing screens pick up the theme without layout changes | S-220 |
| R7 | Record reachable in one tap from the start screen | S-242, S-228 |
| R8 | Required inputs only; optional fields optional | S-228 |
| R9 | Recent ticker chips | S-229 |
| R10 | Four Friday chips + Other date, non-Friday warning, derived DTE | S-230 |
| R11 | Total-per-contract + credit bound (put without stock price; call skips) | S-231, S-232 |
| R12 | Calls follow D-P12, with the one-line explanation | S-233, S-234, S-235, S-236 |
| R13 | "Happy to be assigned" defaults on; missing fee stays null | S-228, S-237 |
| R14 | Yield and capital committed shown before saving | S-237 |
| R15 | Saves exactly what "Track this position" saves | S-228, S-233 |
| R16 | Screener stays as built and is linked | S-236, S-237 |
| R17 | Owner timing check: median < 20 s | owner item, Phase 6 |
| R18 | Snapshot sheet ≤ 2 taps from Today, saved at 3 | S-244 |
| R19 | Live preview from the rules engine, pinned version, real `now` | S-238, S-240 |
| R20 | Carried-forward marking, help chips, sign handling, backdating preserved | S-239 |
| R21 | Return where you came from with the badge updated | S-244 |
| R22 | Today replaces Positions; list, sort and badge+reason rows live inside | S-242, S-243 |
| R23 | Bucket counts; No data separate; >7-day count overlapping | S-243, S-244 |
| R24 | Ledger strip with the premium definition on screen | S-246 |
| R25 | Concentration flag + the no-wheel-capital invitation; Settings fields | S-247, S-248 |
| R26 | Expiring this week card with obligations | S-250 |
| R27 | Batch expiry + per-leg review; D-P13 dates; excluded legs | S-251, S-252, S-253, S-254 |
| R28 | Bottom navigation with five destinations | S-242 |
| R29 | Export banner + first-run explainer retained; empty state invites the first trade | S-245 |
| R30 | Disclaimer verbatim in Settings and the first-run explainer | S-249 |

## Existing-Functionality Impact

Each row: touched surface → what already reads it (with the grep that found
it) → effect → guard.

| Touched surface | Existing readers (grep) | Effect | Guarded by |
|---|---|---|---|
| `ScreenerController.trackThisPosition` | `lib/features/screener/screener_screen.dart:163`; `test/state/screener/screener_controller_test.dart`, `screener_controller_notifications_test.dart`, `test/features/screener/screener_screen_test.dart` | Call-side saves now follow D-12; put-side byte-for-byte unchanged | S-236 + every existing screener scenario stays green |
| `positionsListControllerProvider` | `lib/features/positions/positions_list_screen.dart:49,61,62`; `lib/features/settings/settings_screen.dart:75` (`ref.invalidate`); `test/features/settings/settings_screen_test.dart:396-417`, `test/features/settings/rule_profile_editor_test.dart:238-240` | Renamed to the Today controller; Settings' post-edit invalidate and both tests updated in the same phase | S-242, S-243 + the profile-edit re-classification test |
| Route `/positions` and its `:legId` children | `lib/core/app_router.dart:30`; `lib/features/assignment/assignment_flow_screen.dart:78,231`; `lib/features/onboarding/first_run_explainer.dart:60`; `lib/main.dart:28`; `test/features/positions/positions_list_screen_test.dart:19`; S-205 arrival-reload listener | Path retained by D-14 — no reader changes | S-242 + S-205's existing arrival test |
| `UserPreferencesData` | `lib/state/preferences/preferences_provider.dart` (all screens), `settings_screen.dart`, `screener_controller.dart`, `position_detail_sheet.dart`, `lib/data/export/ledger_export.dart`, `user_preferences_table.dart`, `app_database.dart`, `test/domain/models/user_preferences_test.dart`, `test/data/user_preferences_migration_test.dart` | Two additive fields; nothing existing changes meaning | S-214, S-215 + the prefs migration/round-trip tests |
| `LedgerExport.currentFormatVersion` | `test/data/export/ledger_export_test.dart:301,448`, `ledger_import_test.dart:212,235,286,315` | Version stays 2 (D-7); the refusal scenario at :286 keeps its fixture | S-215 |
| `BucketBadge` colour source | `position_detail_sheet.dart`, `positions_list_screen.dart` (trailing), `test/features/positions/*` | Reads `BucketColors` instead of `ColorScheme` roles; label/reason behaviour unchanged | S-218 goldens + existing widget tests |
| `_confirmMarkExpired` → `closeDirect` | `test/state/positions/position_detail_close_test.dart`, `position_detail_controller_test.dart` | `closedAt` becomes the expiration date on/after it (D-13) | S-253 |
| `help_coverage_test.dart` fixture | `test/features/help_coverage_test.dart` | New chips added only where a §C2 topic id exists (each new screen wired deliberately) | S-238 (preview chips), fixture update in the same phase |
| `docs/architecture/wheel-triage.md` | whole repo | Gains the Wave 1 surfaces (Today, Record, theme, expiry batch) | Phase 11 |

## Scenarios

Fixtures are enumerated as required. No narrative arithmetic may override a
fixture (conventions §7).

### S-211: Stage 0 — unfiltered `build_runner` is green
- Fixture: the repo as of `f61b540`; the four Riverpod codegen/lint packages still declared; `analysis_options.yaml` still listing the `custom_lint` plugin.
- Trigger: `dart run build_runner build --delete-conflicting-outputs` after the removals in D-2.
- Flow: remove the packages and the plugin entry; `flutter pub get`; run a full, unfiltered build.
- Expected outcome: exit 0, no crash; `lib/data/db/schema/drift_schema_v1..v4.json` and `test/data/db/generated/**` are byte-identical to before (`git status --porcelain` clean for those paths); `flutter analyze` clean.
- Edge case of: none.

### S-212: Stage 0 — no codegen/lint package is referenced
- Fixture: the repo after S-211.
- Trigger: grep `riverpod_annotation|riverpod_generator|riverpod_lint|custom_lint|@riverpod` across `pubspec.yaml`, `analysis_options.yaml`, `lib/`, `test/`.
- Expected outcome: zero hits; `flutter test` green.
- Edge case of: S-211.

### S-213: Stage 0 — `fl_chart` is gone
- Fixture: the repo after S-211 (the only occurrence today is `pubspec.yaml:55`; `lib/` and `test/` have none).
- Trigger: grep `fl_chart` across the repo.
- Expected outcome: zero hits; the hand-painted `CustomPainter` sparkline is untouched.
- Edge case of: S-211.

### S-214: schema v5 — fresh install and v4→v5 migration agree
- Fixture (both paths): one `user_preferences` row carrying every v4 field set to a non-default value (`totalPerContractToggle = true`, `deltaConventionDefault = option`, `firstRunExplainerShown = true`, `ivResolutionNoticeDismissed = true`, `exportReminderDismissed = true`, `lastExportAt` set, `notificationMilestones = [7, 0]`), plus one underlying, one cycle, one closed leg with fees, one snapshot, one share lot and the three seeded profiles + v1 versions.
- Trigger: (a) open a fresh database; (b) migrate that v4 database to v5.
- Flow: read the preferences row back through `WheelRepository.getPreferences()`.
- Expected outcome: both report `wheelCapital == null`, `concentrationLimitPct == 25.0`, and every pre-existing field byte-identical to the fixture; every other table's rows unchanged.
- Edge case of: none.

### S-215: preferences round-trip through export/import, new and legacy files
- Fixture: (a) a database with `wheelCapital = 30000.00` and `concentrationLimitPct = 20.0`; (b) a format-2 export captured **before** this wave (no `wheelCapital` / `concentrationLimitPct` keys anywhere).
- Trigger: `exportToJson()` on (a); `restoreFromJson()` of (b) into a populated database.
- Flow: read the preferences row back after each.
- Expected outcome: (a) re-imports to exactly `30000.00` / `20.0`, and the file's `formatVersion` is still 2; (b) imports successfully to `wheelCapital == null` / `concentrationLimitPct == 25.0` with nothing else disturbed.
- Edge case of: S-214.

### S-216: `getAllLegs` — every leg, deterministic order, both implementations
- Fixture: two cycles — one open (legs sequence 0 and 1, leg 1 created later the same minute), one closed (legs sequence 0 and 1); four legs total; one of them backdated a month earlier than the rest.
- Trigger: `getAllLegs()` against `DriftWheelRepository` and `InMemoryWheelRepository`.
- Flow: compare the two results element-for-element.
- Expected outcome: identical lists; the backdated leg sorts first (ascending `openedAt`, ties broken by `sequence`); open and closed legs both present.
- Edge case of: none.

### S-217: the batch expire is atomic
- Fixture: three open legs past expiration across two cycles (two puts, each on its own cycle, and one call on a `holdingShares` cycle), plus one open leg that is *not* in the batch.
- Trigger: (a) `markExpired` with two valid legs; (b) `markExpired` with one valid leg and one unknown id; (c) with an empty list; (d) with an already-closed leg.
- Flow: inspect every leg, cycle and share lot before and after each call.
- Expected outcome: (a) both legs closed with `closedAt` equal to the supplied dates, `closeReason == expiredWorthless`, `closeDebitPerShare == 0`, `closeFee == null`, and every put leg's own cycle ended exactly as `closeLeg(reason: expiredWorthless)` ends it, while a call leg on a `holdingShares` cycle does not end it; (b) throws, and **no** leg or cycle changed; (c) throws `ArgumentError`; (d) throws, nothing changed. Both implementations behave identically.
- Edge case of: none.

### S-218: bucket badge goldens, five states × two themes
- Fixture: the five `Bucket` variants (Close, Roll, Assign, Leave, `BucketUnknown` with its "No snapshot yet" reason).
- Trigger: golden comparison in both themes.
- Expected outcome: five distinct fills stepped in lightness (Close/Roll/Assign light-ink, Leave light-ink), Assign painted from the bucket token — never the error colour — and No data as a dashed outline with muted text; images match.
- Edge case of: none.

### S-219: token contrast holds in both themes
- Fixture: the token table of D-4.
- Trigger: the pure contrast test computes WCAG ratios for text-on-background, text-on-card, muted-on-card, accent-on-background, on-accent-on-accent, caution-on-card, error-on-card, and each bucket fill against its own ink.
- Expected outcome: every ratio ≥ 4.5:1 (and the bucket fills remain distinguishable in greyscale by their L* steps).
- Edge case of: S-218.

### S-220: the theme reaches every existing screen without layout change
- Fixture: one of every existing screen with a seeded book (positions, detail, roll planner, assignment flow, journal, screener, settings, first-run).
- Trigger: pump each screen under the dark theme and under the light theme.
- Flow: run the existing widget suites plus a no-exception smoke pass in both themes.
- Expected outcome: no overflow/exception; the only colour source is `lib/core/theme/` (`grep -rn "Colors\.\|Color(0x" lib/ --include='*.dart'` outside that directory returns nothing); `main.dart`'s `Colors.teal` is gone.
- Edge case of: S-218.

### S-221: current capital committed
- Fixture: INTC — open put $20 ×4; SOFI — open put $14 ×3 expiring **before** today (still open); PFE — open put $25 ×1; T — `holdingShares` cycle (put legs netting $0.45/share at $27 assignment, one share lot ×1) with an open call; SBET — `holdingShares` cycle (put credits $0.50−$0.62 + $0.92, assignment $11.50, lot ×1); BAC — closed cycle with no open leg; WBD — open put $11 ×1 closed already.
- Trigger: `currentCapitalCommitted(...)` per cycle and in total.
- Expected outcome: INTC $8,000; SOFI $4,200 (included despite the passed expiration); PFE $2,500; T and SBET at wheelBasis × 100 × contracts; BAC $0; WBD $0; total equals the sum, and the per-underlying map keys by ticker.
- Edge case of: none.

### S-222: concentration and the limit boundary
- Fixture: wheel capital $30,000; limit 25; underlyings at $7,500 (exactly 25%), $7,500.01 (just over), $0 (a closed cycle).
- Trigger: the concentration reducer.
- Flow: compute per-underlying percentages and the flag set.
- Expected outcome: exactly-at-limit is **not** flagged; just-over is; the zero-capital underlying is absent from the flag set and its percentage is 0; with `wheelCapital == null` the flag set is empty and the invite line is what renders.
- Edge case of: S-221.

### S-223: net premium for a month and year to date
- Fixture: the sample book's September — credits INTC $0.62×4, SOFI $0.41×3, F $0.35×2, T call $0.30×1, SBET call $0.35×1, PFE $0.48×1, WBD $0.27×1, AAL $0.29×2, CCL $0.40×2; buybacks BAC $0.28×1, CCL $0.55×2, KO $0.20×1; an August credit (UBER $1.10×1) and a closed leg with a recorded fee that must not move the figure.
- Trigger: the reducer for September 2026 and for the year to date.
- Expected outcome: month = $719 $−$158 = $561; fees never subtracted; the August credit is excluded from the month and included in the year; an assigned leg contributes no buyback.
- Edge case of: none.

### S-224: reading age and the needs-a-reading predicate
- Fixture: five open legs — no snapshot; taken 1 hour ago; taken today; taken exactly 7 calendar days ago; taken 8 calendar days ago.
- Trigger: the aging predicate at a fixed `now`.
- Expected outcome: needs-reading = {no snapshot, 8 days}; aging count = 1 and it names the 8-day leg and its date; the exactly-7-day leg is **not** counted; the no-snapshot leg is not in the aging count.
- Edge case of: none.

### S-225: expiry batch eligibility
- Fixture: past-expiration open legs — WBD put $11 with a last reading of $12.10 (OTM); AAL put $13 with a last reading of $12.60 (ITM); PFE put $25 with no reading; a put exactly at its strike in its last reading; a leg expiring today (not yet past).
- Trigger: the eligibility reducer.
- Flow: partition into "Mark all expired" and "per-leg only".
- Expected outcome: WBD and the at-strike leg are eligible (a reading exactly at the strike is not in the money); AAL and PFE are not; the leg expiring today is absent from the card entirely.
- Edge case of: none.

### S-226: obligations at an expiration
- Fixture: SOFI put $14 ×3 and T call $28 ×1, both expiring Friday.
- Trigger: the obligation reducer.
- Expected outcome: "cash if assigned" $4,200 for the put; "100 shares delivered at $28 if assigned" for the call; a leg with no open position contributes nothing.
- Edge case of: none.

### S-227: one `TriageInput` assembly, three callers
- Fixture: one leg plus one persisted snapshot with a known mark, spot, delta and IV, and (a) the same values supplied as a transient snapshot.
- Trigger: the shared assembly via the positions list path, the detail path and the preview path.
- Expected outcome: all three produce equal `TriageInput` values (captured %, delta magnitude, resolved IV, dte, extrinsic); a null snapshot yields the "no snapshot yet" input in all three.
- Edge case of: none.

### S-228: Record a trade — the minimum path
- Fixture: an empty database except the seeded profiles and a preferences row with default milestones; the user picks the ticker CCL from a chip, Put, strike $19, the third Friday chip, credit $0.34, 2 contracts, leaves every optional field blank.
- Trigger: save.
- Flow: `createCycle` through the shared save path.
- Expected outcome: exactly one underlying, one cycle (`sellingPuts`) holding one leg (`sequence = 0`) with those values, `openFee == null`, `ivAtOpen == null`, `ivRankAtOpen == null`, `underlyingPriceAtOpen == null`, `acceptsAssignment == true`, `ruleProfileVersionId` = the standard profile's current version; reminders scheduled for the milestones after this leg's DTE; the user lands back on Today with a confirmation naming the recorded trade.
- Edge case of: none.

### S-229: recently used ticker chips
- Fixture: open cycles CCL and INTC, closed cycles KO and SNAP; KO's last leg was opened after INTC's.
- Trigger: opening Record.
- Expected outcome: distinct tickers ordered by most recent leg `openedAt` (KO before INTC), capped at six, closed-cycle tickers included; tapping one sets the ticker field.
- Edge case of: S-228.

### S-230: expiration chips
- Fixture: today Friday 2026-10-02 and, separately, Monday 2026-09-28; the four chips are the next four Fridays strictly after today.
- Trigger: opening Record and tapping "Other date…".
- Flow: read the chips, the derived DTE, and the non-Friday warning.
- Expected outcome: 09-28 → Oct 2, 9, 16, 23; 10-02 → Oct 9, 16, 23, 30 (today itself is not offered); the last chip is pre-selected; the displayed DTE matches `expiration − today`; picking a Thursday through the picker shows the existing non-Friday warning and is not blocked.
- Edge case of: S-228.

### S-231: the credit bound on Record
- Fixture: a put with strike $19 and credit $34.00 (total typed while the toggle is off); the same leg with the toggle on; a call with strike $19, credit $0.50 and **no** stock price; the same call with stock price $18.00.
- Trigger: the preview and the save.
- Expected outcome: the put is hard-rejected with the existing bound message **without** any stock price; with the toggle on, $34.00 is divided by 100 before the check and passes; the call without a stock price skips the check (no block, no guessed value); the call with a stock price below the credit hard-rejects.
- Edge case of: S-228.

### S-232: total per contract on Record
- Fixture: the toggle on, credit typed as $34.00 for one contract.
- Trigger: save.
- Expected outcome: the persisted `openCreditPerShare` is $0.34; the preview's yield uses $0.34; the field's label says "total for contract".
- Edge case of: S-231.

### S-233: a call attaches to a waiting share-holding cycle
- Fixture: ticker T with a `holdingShares` cycle (one share lot ×1, no open call) and a put-side history; a separate ticker with an open `sellingPuts` cycle.
- Trigger: Record side = Call, ticker T, strike $28, credit $0.30, save.
- Expected outcome: no new cycle and no new underlying; one new leg on T's existing cycle (`rolledFromLegId == null`, `sequence` = highest + 1, the standard profile's current version, `acceptsAssignment` from the toggle); reminders scheduled for it; the pre-save line names the cycle, the shares and the wheel-adjusted basis.
- Edge case of: S-228.

### S-234: a call with no shares on record is refused
- Fixture: a ticker with only `sellingPuts`/closed cycles or no history at all.
- Trigger: Record side = Call, save.
- Expected outcome: the one line of D-12 ("Calls are recorded against shares held from an assignment, and there are no \<TICKER> shares on record."); no cycle, underlying, leg or notification is created; the form keeps its values.
- Edge case of: S-233.

### S-235: a call on shares with an open call is refused
- Fixture: ticker F with a `holdingShares` cycle that already has an open call leg.
- Trigger: Record side = Call, save.
- Expected outcome: the one line of D-12 ("F already has an open call; close or roll it first."); nothing is written.
- Edge case of: S-233.

### S-236: the screener's call path follows D-P12
- Fixture: (a) ticker T as in S-233; (b) ticker CCL with no shares on record; (c) a put-side screener fixture exactly as an existing screener scenario builds it.
- Trigger: "Track this position" with side = Call on (a) and (b), and with side = Put on (c).
- Expected outcome: (a) one new leg on the existing holding cycle, no new cycle; (b) refused with the D-12 line, nothing written; (c) byte-identical to the existing scenario's persisted shape and counts.
- Edge case of: S-233.

### S-237: Record's preview figures
- Fixture: CCL $19 put, credit $0.34, 2 contracts, expiration at 18 DTE; the screener's formula also exercised at a second DTE.
- Trigger: reading the preview before saving.
- Expected outcome: annualised yield = credit ÷ strike × 365 ÷ DTE (0.34 ÷ 19 × 365 ÷ 18 = 36%, displayed rounded), capital committed = $3,800 with its definition ("strike × 100 × contracts"); the tiles round to whole dollars (OC-12); the screener link is present.
- Edge case of: S-228.

### S-238: the snapshot preview matches `classify()`
- Fixture: T $28 call, credit $0.30, 4 DTE, Standard v1, now Mon 2026-09-28; four readings — mark 0.12 / spot 27.05 / delta −0.21 (Close, "60% of credit captured"); mark 0.20 / delta −0.35 (Roll, 0.35 band); mark 0.25 / delta −0.72 (Assign, "Delta 0.72 at or above 0.70"); mark 0.10 / delta −0.10 (Leave); plus the IV-blank variant which must fall back to IV at open (22%).
- Trigger: the preview function and, for each case, a real saved snapshot through the existing save path.
- Flow: compare the preview's bucket, reason, captured %, band (with source) and extrinsic with `classify()`'s own output for the persisted snapshot.
- Expected outcome: identical bucket and reason string for all four cases and the fallback variant; the band source line reads "from this snapshot's IV (21%)" or "from IV at open (22%)" accordingly.
- Edge case of: none.

### S-239: carried-forward marking and sign handling survive
- Fixture: a leg whose previous snapshot has a stock price and an IV; then only the stock price edited; then only the IV edited.
- Trigger: opening the sheet and typing.
- Expected outcome: both fields arrive marked carried-forward with the previous snapshot named; each keeps its mark until the user edits that field; option mark and delta are never carried; the delta field still shows the live magnitude readout and stores the value exactly as typed with its own convention; backdating bounds `[openedAt, expiration]` still apply.
- Edge case of: S-238.

### S-240: the preview uses the leg's pinned version
- Fixture: a leg pinned to `rule-profile-standard-v1`; then the Standard profile is edited to a v2 with a different profit target.
- Trigger: opening the sheet for the old leg and, separately, for a leg opened after the edit.
- Expected outcome: the old leg's preview classifies with v1 (unchanged bucket for the same numbers); the new leg's preview uses v2; neither screen reads the profile's current version for the old leg.
- Edge case of: S-238.

### S-241: the change line
- Fixture: T $28 call whose current bucket is Leave from the Sep 17 reading; a new reading that produces Close.
- Trigger: opening the sheet.
- Expected outcome: the preview shows "Was Leave on the Sep 17 reading"; when the preview matches the current bucket, the line is absent.
- Edge case of: S-238.

### S-242: Today replaces Positions
- Fixture: eight open legs and five closed cycles (the sample book), plus an empty database variant.
- Trigger: launching to `/positions` with `firstRunExplainerShown = true`.
- Expected outcome: the screen is Today (date + title) with bottom navigation Today / Journal / Record / Screener / Settings; the list below carries the eight legs with badge + reason and the sort control reading "By bucket" (plus "By DTE" and "By ticker"); the app bar no longer has Screener/Journal/Settings/sort icons; the empty variant shows "Nothing recorded yet" with its two buttons; the route path is unchanged and every `/positions/:legId` flow still resolves; a leg tracked elsewhere is visible on return (S-205's arrival reload preserved under the new provider name).
- Edge case of: none.

### S-243: bucket counts and filters
- Fixture: the sample book — 1 Assign, 1 Roll, 1 Close, 2 Leave, 1 No data, plus one past-expiration leg excluded from all counts.
- Trigger: tapping each count in turn, then tapping it again.
- Expected outcome: counts render in sort order (Assign, Roll, Close, Leave, No data); each tap filters the list to exactly those legs and clears on the second tap; the past-expiration leg is in none of the counts and not in the list; the No data count contains only the no-reading leg.
- Edge case of: S-242.

### S-244: the aging count and the inline Update
- Fixture: T with an 11-day-old reading (Leave), PFE with no reading, plus legs read today; a second variant where T's reading is exactly 7 days old.
- Trigger: reading the aging line; tapping it; tapping T's inline Update; saving.
- Flow: count, filter, open the sheet, save, return.
- Expected outcome: "1 reading older than 7 days · T, from Sep 17"; T is still counted under Leave; tapping the line filters to T; the inline Update appears only where the predicate is true (not on the exactly-7-day variant); tapping it opens the snapshot sheet directly (one tap) and saves in two; saving returns to Today with T's badge and reason updated and the counts recomputed.
- Edge case of: S-243, S-224.

### S-245: kept behaviour on Today
- Fixture: preferences with `lastExportAt` 31 days old and an earliest open position older than that; separately, a database with nothing recorded at all.
- Trigger: opening Today.
- Expected outcome: the export reminder banner renders above the counts and dismisses permanently; the first-run explainer still opens on a fresh install (`firstRunExplainerShown = false` → `/first-run`); the empty state invites the first trade with both buttons working.
- Edge case of: S-242.

### S-246: the ledger strip
- Fixture: the sample book (September $561 net premium; year-to-date credits and buybacks), wheel capital $30,000.
- Trigger: opening Today.
- Expected outcome: three tiles — "Net premium · Sep" $561, "Year to date" (D-8 over 1 Jan → now), "Committed now" (D-9 total, whole dollars) — with the definition line on screen naming the premium rule and the capital rule, percentages and totals matching the reducers exactly.
- Edge case of: S-242.

### S-247: concentration on Today
- Fixture: (a) wheel capital $30,000 with INTC at 27% and no other underlying over 25%; (b) the same book with wheel capital unset; (c) two underlyings over the limit, 27% and 26%.
- Trigger: opening Today.
- Expected outcome: (a) one neutral line "INTC 27% of wheel capital · limit 25%", no warning colour, no link; (b) no flag line at all plus the invitation line pointing at Settings; (c) two lines, largest first; the limit from preferences is named in each.
- Edge case of: S-246.

### S-248: Settings gains wheel capital and the limit
- Fixture: preferences with defaults; then wheel capital $30,000 and limit 30.
- Trigger: entering both, leaving wheel capital blank, and typing 0 or 101 into the limit.
- Expected outcome: blank wheel capital persists as `null` and produces no flag anywhere; $30,000 persists as 3,000,000 cents and survives a restart; 0 and 101 are refused with a message and nothing is written; the concentration lines on Today update immediately.
- Edge case of: S-247.

### S-249: the disclaimer verbatim
- Fixture: a fresh install; and Settings with a populated book.
- Trigger: reading Settings and paging through the first-run explainer.
- Expected outcome: D-18's exact string appears character-for-character in both, on every explainer card as a visible footer; a test asserts the constant and both render sites; the tone grep passes.
- Edge case of: none.

### S-250: "Expiring this week"
- Fixture: today Mon 2026-09-28; SOFI put $14 ×3 and T call $28 ×1 expiring Fri 2026-10-02; F expiring Oct 9; a leg expiring yesterday (past expiration, elsewhere).
- Trigger: opening Today.
- Expected outcome: the card lists only the two legs inside the next seven days, grouped by date, showing "$4,200 cash if assigned" and "100 shares delivered at $28 if assigned"; nothing outside the window appears; the card is absent when nothing expires within the window.
- Edge case of: S-242.

### S-251: the past-expiration card and what "Mark all" covers
- Fixture: WBD put $11 ×1 past expiration, last reading Sep 24 spot $12.10 (OTM); AAL put $13 ×2 past expiration, last reading Sep 23 spot $12.60 (ITM); a third past-expiration leg with no reading.
- Trigger: opening Today.
- Expected outcome: one card listing all three; "Mark all expired (1)" covering only WBD, with the descriptive line naming its last reading and date; AAL and the unread leg shown separately with their own "Mark expired" / "Mark assigned" actions; the card's explanation says the close fee stays blank; none of the three appears in the counts or the list.
- Edge case of: S-225, S-243.

### S-252: the batch records the expiration date
- Fixture: S-251's book, two eligible legs on the card (extend with a second OTM leg) on different cycles, one of them a put with an earlier roll in its chain.
- Trigger: "Mark all expired (2)".
- Flow: one repository call; then inspect legs, cycles and the Today counts.
- Expected outcome: both legs closed with `closedAt` = their own expiration dates (not the tap time), `closeReason = expiredWorthless`, close debit $0, `closeFee = null`; put legs' cycles ended exactly as a single Mark expired ends them; the ineligible legs untouched; the card now empty; "Committed now" reduced by the recorded legs' capital; a forced failure in the middle leaves **nothing** changed.
- Edge case of: S-251.

### S-253: the single-leg Mark expired date
- Fixture: a leg expiring Fri 2026-09-25, marked on Mon 2026-09-28; a second leg expiring in five days marked today; a third expiring today marked today.
- Trigger: the "Mark expired" action on each.
- Expected outcome: the first records `closedAt = 2026-09-25` and therefore lands in September; the second records the tap time (unchanged behaviour); the third records the expiration date (today, on/after); days-held, month attribution and the ledger strip follow the recorded dates.
- Edge case of: S-252.

### S-254: past-expiration legs are only on the card
- Fixture: the sample book with WBD and AAL past expiration.
- Trigger: opening Today and reading counts, list and ledger strip.
- Expected outcome: neither leg appears in the bucket counts or the list; both are on the past-expiration card; both are still inside "Committed now"; the aging count does not include them (they belong to the card).
- Edge case of: S-251.

## Iteration 1 — Wave 1

Phases run in order. Phase 4A (P4) must precede every screen phase; P1–P3
are the data foundation; P5 is pure rules and may be built in parallel with
P2–P3 if the implementer prefers (it depends on neither).

```
P1 (Stage 0) ─┬─► P2 (schema v5) ─► P3 (repo reads/writes) ─┐
              └─► P4 (theme 4A) ─► P5 (rules) ───────────────┼─► P6 (Stage 1: Record + save path)
                                                            ├─► P7 (Stage 2: preview + sheet)
                                                            ├─► P8 (Stage 3a: Today) ─► P9 (Stage 3b: strip/concentration/Settings/disclaimer)
                                                            └────────────────────────────► P10 (Stage 3c: expiry cards + D-P13) ─► P11 (closeout)
P4 must land before P6–P10 (D-3/D-4: screens are built once, on the final look).
```

### Phase 1: Stage 0 — foundation hygiene (@data-architect)

1. [ ] `pubspec.yaml`: delete `riverpod_annotation`; delete `fl_chart`; delete
       `riverpod_generator`, `riverpod_lint`, `custom_lint`; rewrite the
       comment block above `build_runner` so it explains only the keep set
       (D-2). Leave every pinned version of the kept packages untouched.
2. [ ] `analysis_options.yaml`: remove the `analyzer.plugins: - custom_lint`
       entry and its now-dangling comment.
3. [ ] `flutter pub get`, then `dart run build_runner
       build --delete-conflicting-outputs` — must exit 0 (S-211).
4. [ ] Prove the regeneration is a no-op for every artifact: `git status
       --porcelain` shows only `pubspec.yaml`, `pubspec.lock` and
       `analysis_options.yaml`.
5. [ ] `flutter analyze` clean; `flutter test` green (S-212, S-213).

**Done Criteria**: `flutter analyze`; `flutter test`; `dart run
build_runner build --delete-conflicting-outputs` exit 0; `grep -rn
"riverpod_annotation\|riverpod_generator\|riverpod_lint\|custom_lint\|fl_chart"
pubspec.yaml analysis_options.yaml lib/ test/` empty; `git status
--porcelain` limited to the three files above.

**Predicted Files**: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`.

**Owner check (recorded in `## Progress`)**: full wheel loop walked end to
end on a physical iPhone — first run → screen → track → snapshot → roll →
assign → covered call → called away → journal → export → restore, with the
notification permission prompt and the restore file picker exercised. This
closes Stage 0 and gates launch; it does not block Phase 2.

### Phase 2: schema v5 — wheel capital and the concentration limit (@data-architect)

1. [x] `lib/domain/models/user_preferences.dart`: add
       `@NullableDecimalJsonConverter() Decimal? wheelCapital` and
       `@Default(25.0) double concentrationLimitPct`, each documenting its
       unit (integer cents on disk; `null` means not set) and that a value
       outside `(0, 100]` is refused at entry (D-6). Regenerate freezed/json.
2. [x] `lib/domain/models/user_preferences_defaults.dart`: the two defaults.
3. [x] `lib/data/db/tables/user_preferences_table.dart`: `wheelCapitalCents`
       integer nullable via `NullAwareTypeConverter.wrap(const
       CentsConverter())`; `concentrationLimitPct` real with the SQL-level
       default 25 (D-6 unit rule: cents, never ten-thousandths).
4. [x] `lib/data/db/app_database.dart`: `schemaVersion => 5`; a
       `if (from < 5 && to >= 5)` step adding both columns (same gating and
       comment rationale as v2/v3); `seedDefaultPreferences` extended.
       Regenerate.
5. [x] `dart run drift_dev schema dump lib/data/db/app_database.dart
       lib/data/db/schema/drift_schema_v5.json`, then `dart run drift_dev
       schema generate --data-classes --companions lib/data/db/schema
       test/data/db/generated` (both flags required). v1–v4 dumps untouched.
6. [x] Both repositories map the new fields; `updatePreferences` persists
       them (parity).
7. [x] Export/import: the two keys ride the existing preferences object;
       `currentFormatVersion` stays 2 (D-7).
8. [x] Tests: S-214 (fresh + v4→v5 migration), S-215 (round-trip and the
       legacy file).

**Done Criteria**: `flutter analyze`; `flutter test test/data/db
test/data/export test/domain/models/user_preferences_test.dart
test/data/wheel_repository_contract_test.dart`; the schema diff against v4
shows exactly the two new columns.

**Predicted Files**: `lib/domain/models/user_preferences.dart` (+ generated),
`lib/domain/models/user_preferences_defaults.dart`,
`lib/data/db/tables/user_preferences_table.dart`,
`lib/data/db/app_database.dart` (+ `.g.dart`),
`lib/data/db/schema/drift_schema_v5.json` (new),
`test/data/db/generated/schema.dart`, `schema_v5.dart` (new),
`test/data/db/user_preferences_v5_migration_test.dart` (new),
`lib/data/db/drift_wheel_repository.dart`,
`lib/data/in_memory_wheel_repository.dart`,
`test/domain/models/user_preferences_test.dart`,
`test/data/export/ledger_export_test.dart`, `ledger_import_test.dart`.

### Phase 3: repository reads and the atomic expiry batch (@data-architect)

1. [x] `WheelRepository.getAllLegs()`: every leg, ordered by `openedAt`
       ascending with `sequence` as the tie-break; documented ordering (S-216).
2. [x] `WheelRepository.markExpired({required List<({String legId, DateTime
       closedAt})> legs})`: one atomic write recording each leg exactly as
       `closeLeg(reason: expiredWorthless, closeDebitPerShare: Decimal.zero,
       closeFee: null, closedAt: <supplied>)` records it, including the
       put-leg-ends-its-cycle rule; throws `ArgumentError` on an empty list,
       an unknown id, or an already-closed leg, changing nothing; returns the
       closed legs (D-13, S-217).
3. [x] `DriftWheelRepository`: implement both inside one Drift transaction,
       reusing the existing close path rather than a second copy of it.
4. [x] `InMemoryWheelRepository`: implement both identically.
5. [x] `test/data/wheel_repository_contract_test.dart`: a shared block per
       method running against both implementations (S-216, S-217).

**Done Criteria**: `flutter analyze`; `flutter test
test/data/wheel_repository_contract_test.dart`; `grep -c
"UnimplementedError" lib/data/*.dart lib/data/db/*.dart` matches the
pre-phase count. Also run `test/domain/rules/sbet_regression_test.dart`
(S-015) — a failure there is a genuine break.

**Predicted Files**: `lib/data/wheel_repository.dart` (+ `.freezed.dart`),
`lib/data/db/drift_wheel_repository.dart`,
`lib/data/in_memory_wheel_repository.dart`,
`test/data/wheel_repository_contract_test.dart`.

### Phase 4: Stage 4A — theme foundation (@developer)

1. [x] `lib/core/theme/app_theme.dart` (new): the D-4 token table as the one
       colour source — a `ColorScheme` per brightness plus a `BucketColors`
       `ThemeExtension` with the five bucket treatments (fill, ink, outline
       flag) — and `lightTheme` / `darkTheme` `ThemeData`s.
2. [x] `lib/main.dart`: `theme`, `darkTheme`, `themeMode:
       ThemeMode.system`; delete `Colors.teal`.
3. [x] `lib/widgets/bucket_badge.dart`: read `BucketColors` — Assign from its
       own token, never the error role; "No data" keeps no fill and the
       dashed outline; the light theme's hairline edge (D-4).
4. [x] Existing screens: no layout change; replace any role that no longer
       has a contrast-safe equivalent with the token that does (list them in
       the phase's Assumption Log).
5. [x] Tests: `test/core/theme/app_theme_contrast_test.dart` (S-219, S-220's
       grep is a Done Criterion below) and
       `test/features/goldens/bucket_badge_golden_test.dart` with committed
       PNGs for five states × two themes (S-218). Goldens are generated and
       compared on the Mac only.

**Done Criteria**: `flutter analyze`; `flutter test test/core/theme
test/features/goldens`; `flutter test
test/features/positions/position_detail_sheet_test.dart
test/features/screener/screener_screen_test.dart
test/features/settings/settings_screen_test.dart`; `grep -rn
"Colors\.\|Color(0x" lib/ --include='*.dart' | grep -v "lib/core/theme/"` empty.

**Result.** All five items done. `flutter analyze` clean; `flutter test
test/core/theme test/features/goldens` 59 passed / 0 failed (36 S-219 + 13
S-218); the three screen test files 22 passed / 0 failed; full suite **533
passed / 0 failed** (was 484; +49 = 36 + 13). The Done Criterion's grep needs
one character class to mean what it says — `grep -rnE
"(^|[^A-Za-z])Colors\.|Color\(0x" lib/ --include='*.dart' | grep -v
lib/core/theme/` is empty; the literal form also matches `BucketColors.of(...)`
in `lib/widgets/bucket_badge.dart`, which is the extension lookup, not a
literal (A-4).

**Predicted Files**: `lib/core/theme/app_theme.dart` (new),
`lib/main.dart`, `lib/widgets/bucket_badge.dart`,
`test/core/theme/app_theme_contrast_test.dart` (new),
`test/features/goldens/bucket_badge_golden_test.dart` (new) + PNG fixtures.

### Phase 5: Wave 1 rules — pure functions only (@developer)

Every item is a pure function in `lib/domain/rules/` with `now` passed in
(S-221 … S-227). No Flutter import may enter the directory.

1. [x] `capital_committed.dart`: `currentCapitalCommitted(...)` and
       `concentrationByUnderlying(...)` implementing D-9 and D-10 exactly,
       taking legs/share lots (never pre-summed per-share values).
2. [x] `premium_collected.dart`: `netPremiumCollected(...)` implementing D-8.
3. [x] `reading_age.dart`: `kAgingDays = 7`, `readingAgeDays(...)`,
       `needsReading(...)`, `olderThanAging(...)` per D-11.
4. [x] `expiry.dart`: `isPastExpiration(...)`, `expiryBatchEligible(...)`,
       `recordedCloseDateForExpiry(...)` per D-13 (intrinsic-based
       in-the-money test, at-the-strike is not in the money).
5. [x] `obligation.dart`: the expiring-within-seven-days selection and the
       per-leg obligation line (D-13's card, S-226).
6. [x] `triage_input.dart`: add the shared `triageInputFor(...)` assembly and
       point `lib/state/positions/positions_list_controller.dart` and
       `position_detail_controller.dart` at it, deleting both private copies
       (S-227). Behaviour of both callers must not change.
7. [x] Unit tests for each file, table-driven.

**Result.** `flutter analyze` clean; `flutter test test/domain/rules
test/state/positions` 255 passed / 0 failed; `flutter test` **602 passed / 0
failed** (was 533; +69); `grep -rl "package:flutter" lib/domain/rules/` empty;
`test/domain/rules/sbet_regression_test.dart` (S-015) green. All six new
suites were red before implementation (six compile failures, `Method not
found: 'triageInputFor'` among them) and each was shown falsifiable by
mutation — 19 failures across the six files from six one-line mutations. See
A-5 for the two decisions the plan left open.

**Done Criteria**: `flutter analyze`; `flutter test test/domain/rules
test/state/positions`; `grep -rl "package:flutter" lib/domain/rules/` empty;
`flutter test test/domain/rules/sbet_regression_test.dart` green.

**Predicted Files**: `lib/domain/rules/capital_committed.dart`,
`premium_collected.dart`, `reading_age.dart`, `expiry.dart`,
`obligation.dart` (all new), `lib/domain/rules/triage_input.dart`,
`lib/state/positions/positions_list_controller.dart`,
`lib/state/positions/position_detail_controller.dart`, + `test/domain/rules/`
tests for each new file.

### Phase 6: Stage 1 — Record a trade + one save path (@developer)

1. [x] `lib/state/record/record_save_service.dart` (new): the single entry
       point of D-19 — D-12 host-cycle resolution, `createCycle` vs
       `openNextLeg`, the standard profile's current version pin, and
       reminder scheduling — returning a result that distinguishes
       created / attached / refused-with-reason.
2. [x] `lib/state/record/record_controller.dart` (new): the form state, the
       recent-ticker chips (D-16), the Friday chips and DTE, the
       total-per-contract conversion, the credit-bound check (put without
       spot; call without spot skips), the optional disclosure, the
       `acceptsAssignment` toggle, and the yield/capital preview.
3. [x] `lib/features/record/record_trade_screen.dart` (new): D-16's layout,
       the live one-line call explanation, the preview tiles, "Record trade",
       the reminder line, the screener link. Semantics labels name every
       number (Feature Invariant 6).
4. [x] `lib/state/screener/screener_controller.dart`: "Track this position"
       routes through the same service; a refused call writes nothing and
       surfaces the D-12 line.
5. [x] `lib/features/screener/screener_screen.dart`: render that line.
6. [x] `lib/core/app_router.dart`: the `/record` route (wired to Today's nav
       in Phase 8).
7. [x] Tests: S-228 … S-237, plus every existing screener scenario re-run
       unchanged (S-236c).

**Done Criteria**: `flutter analyze`; `flutter test test/state/record
test/state/screener test/features/screener`; the tone grep of
`docs/conventions.md` §4 clean; `grep -rl "package:flutter"
lib/domain/rules/` empty.

**Predicted Files**: `lib/state/record/record_save_service.dart`,
`lib/state/record/record_controller.dart`,
`lib/features/record/record_trade_screen.dart` (all new),
`lib/core/app_router.dart`,
`lib/state/screener/screener_controller.dart`,
`lib/features/screener/screener_screen.dart`,
`test/state/record/**` (new),
`test/state/screener/screener_controller_test.dart`,
`test/features/screener/screener_screen_test.dart`.

**Owner check (recorded in `## Progress`)**: manual timing check on a
device — median under 20 seconds for a repeat ticker, at least five runs.
Closes Stage 1; does not block Phase 7.

### Phase 7: Stage 2 — the preview and a shareable snapshot sheet (@developer)

1. [x] `lib/domain/rules/snapshot_preview.dart` (new): the pure preview of
       D-17 — build a transient `Snapshot` from the entered values, reuse
       `triageInputFor`, call `classify()` with the leg's pinned profile, and
       return bucket, reason, captured %, band + source, extrinsic and
       whether it differs from the leg's current bucket. No rule logic
       elsewhere (S-238, S-240, S-241).
2. [x] `lib/features/positions/snapshot_sheet.dart` (new): the existing sheet
       extracted from `position_detail_sheet.dart`, taking a `legId` and
       rendering a loader until the controller's leg arrives — it must never
       dereference an unloaded leg — plus the preview card, the change line
       and the carried-forward marking until edited (S-239). Existing help
       chips, delta handling and backdating are preserved verbatim.
3. [x] `lib/features/positions/position_detail_sheet.dart`: use the extracted
       sheet; the FAB keeps working (R18's two-tap path).
4. [x] Tests: S-238 … S-241, plus the existing
       `position_detail_sheet_test.dart` green.

**Done Criteria**: `flutter analyze`; `flutter test
test/domain/rules/snapshot_preview_test.dart
test/features/positions test/state/positions`; `grep -rl
"package:flutter" lib/domain/rules/` empty; the tone grep clean.

**Predicted Files**: `lib/domain/rules/snapshot_preview.dart` (new),
`lib/features/positions/snapshot_sheet.dart` (new),
`lib/features/positions/position_detail_sheet.dart`,
`test/domain/rules/snapshot_preview_test.dart` (new),
`test/features/positions/position_detail_sheet_test.dart`.

### Phase 8: Stage 3a — Today replaces Positions (@developer)

1. [x] `lib/state/today/today_controller.dart` (new): load the open legs,
       classify each (pinned version, real `now`), compute the bucket counts,
       the aging count and the filtered list; the filter state; the
       post-save reload. Rename from `positionsListControllerProvider`;
       update `lib/features/settings/settings_screen.dart:75`'s invalidate.
2. [x] `lib/features/today/today_screen.dart` (new): the header, the export
       reminder banner, the counts row, the aging line, the list (badge +
       reason, sort control "By bucket"/"By DTE"/"By ticker", inline Update
       where `needsReading`, row tap → detail sheet), the empty state
       (D-14).
3. [x] `lib/widgets/app_bottom_nav.dart` (new): the fixed five-item bar with
       Record raised in the centre; wire it on Today, Journal, Screener,
       Settings and Record.
4. [x] Delete `lib/features/positions/positions_list_screen.dart` and
       `lib/state/positions/positions_list_controller.dart`; the `/positions`
       path and its children stay (D-14). Move
       `test/features/positions/positions_list_screen_test.dart` to
       `test/features/today/today_screen_test.dart` and the controller test
       likewise.
5. [x] Inline Update opens the Phase 7 sheet directly and reloads Today on
       success (S-244).
6. [x] Tests: S-242 … S-245; the two settings tests that use the renamed
       provider; S-205's arrival-reload assertion re-pointed at the new
       provider name.

**Phase 0 red run** (recorded before implementation): `flutter test
test/state/today test/features/today` → **0 passed, 2 failed**, both failures
compile errors naming the not-yet-written `lib/state/today/today_controller.dart`,
`lib/features/today/today_screen.dart` and `lib/widgets/app_bottom_nav.dart`.

**Done Criteria**: `flutter analyze`; `flutter test test/features/today
test/state/today test/features/settings test/features/positions
test/features/roll`; `grep -rn "positionsListControllerProvider" lib/ test/`
empty; the tone grep clean.

**Predicted Files**: `lib/state/today/today_controller.dart` (new),
`lib/features/today/today_screen.dart` (new),
`lib/widgets/app_bottom_nav.dart` (new),
`lib/features/positions/positions_list_screen.dart` (deleted),
`lib/state/positions/positions_list_controller.dart` (deleted),
`lib/core/app_router.dart`, `lib/features/settings/settings_screen.dart`,
`test/features/today/**` (new),
`test/features/settings/settings_screen_test.dart`,
`test/features/settings/rule_profile_editor_test.dart`,
`test/features/roll/roll_planner_screen_test.dart`.

### Phase 9: Stage 3b — ledger strip, concentration, Settings, disclaimer (@developer)

1. [x] Today's ledger strip (D-8, D-9, D-15): the three tiles, the definition
       line, and the concentration lines with their flag rule and the
       no-wheel-capital invitation (D-10).
2. [x] `lib/features/settings/settings_screen.dart`: a "Your book" section
       with wheel capital (blank = not set) and the concentration limit,
       refused outside `(0, 100]` with a message (D-6).
3. [x] `lib/core/disclaimer.dart` (new): `kAppDisclaimer`, D-18's exact
       string; render it in Settings and as the persistent first-run
       footer.
4. [x] Tests: S-246 … S-249, including a character-for-character assertion
       on the disclaimer at both render sites.

**Done Criteria**: `flutter analyze`; `flutter test test/features/today
test/features/settings test/features/onboarding`; the tone grep clean; the
disclaimer test green.

**Predicted Files**: `lib/features/today/today_screen.dart`,
`lib/state/today/today_controller.dart`,
`lib/features/settings/settings_screen.dart`,
`lib/core/disclaimer.dart` (new),
`lib/features/onboarding/first_run_explainer.dart`,
`test/features/settings/settings_screen_test.dart`,
`test/features/onboarding/first_run_explainer_test.dart`,
`test/core/disclaimer_test.dart` (new).

### Phase 10: Stage 3c — expiration cards and D-P13 dates (@developer)

1. [x] `lib/features/today/expiring_this_week_card.dart` (new): the next
       seven days grouped by date with each leg's obligation (S-250).
2. [x] `lib/features/today/past_expiration_card.dart` (new): the batch
       action, the descriptive line per leg, and the separate per-leg
       section for in-the-money and unread legs with their own actions
       (S-251).
3. [x] The batch calls `markExpired` once (D-13's atomicity) and reloads
       Today; "Mark assigned" routes to the existing assignment flow.
4. [x] `lib/features/positions/position_detail_sheet.dart`: the single-leg
       "Mark expired" passes `closedAt = recordedCloseDateForExpiry(...)`
       (S-253).
5. [x] Keep past-expiration legs out of the counts and the list (S-254).
6. [x] Tests: S-250 … S-254.

**Done Criteria**: `flutter analyze`; `flutter test test/features/today
test/state/today test/features/positions test/state/positions`; the tone
grep clean.

**Predicted Files**: `lib/features/today/expiring_this_week_card.dart`,
`lib/features/today/past_expiration_card.dart` (both new),
`lib/features/today/today_screen.dart`,
`lib/state/today/today_controller.dart`,
`lib/features/positions/position_detail_sheet.dart`,
`test/features/today/**`, `test/state/positions/position_detail_close_test.dart`.

**Result.** `flutter analyze` clean; `flutter test test/domain/rules
test/state/today test/state/positions test/features/today` 88 passed /
0 failed; `flutter test` **733 passed / 0 failed** (was 709; +24 = 6
`expiry.dart` copy + 4 today-controller S-250 + 4 today-controller S-252 +
5 today-screen S-250/251 + 1 today-screen S-252 + 1 today-screen S-254 + 4
S-253 close-date); every Phase 10 suite confirmed red before implementation
(3 compile-failed suites + 9 widget failures); tone grep of §4 empty;
`grep -rl "package:flutter" lib/domain/rules/` empty. Two files outside
Predicted Files (`lib/domain/rules/expiry.dart`, `lib/core/format.dart`,
`lib/state/positions/position_detail_controller.dart`,
`lib/widgets/leg_title.dart`) — see A-25…A-32.

### Phase 11: closeout — docs and the residue sweep (@developer)

1. [x] `docs/architecture/wheel-triage.md`: Today, Record, the theme tokens,
       the new repository methods, the new preferences and the expiry batch
       — added to the existing sections, with the drift-risk areas named.
2. [x] Residue sweep (each a command, pasted into the phase report):
       `grep -rn "Bucket severity" lib/ test/` empty;
       `grep -rn "positionsListControllerProvider" lib/ test/` empty;
       `grep -rn "fl_chart\|riverpod_annotation\|custom_lint" pubspec.yaml
       analysis_options.yaml lib/ test/` empty;
       `grep -rn "Colors\.\|Color(0x" lib/ | grep -v lib/core/theme/` empty;
       `grep -rl "package:flutter" lib/domain/rules/` empty;
       the §4 tone grep empty.
3. [x] `## Progress` completed with the two owner checks' results, or an
       explicit "not yet run" note.
4. [x] `flutter analyze`, the full `flutter test`, and
       `flutter build ios --simulator --no-codesign` (exit 0).

**Done Criteria**: the six sweeps above; `flutter analyze`; `flutter test`;
`flutter build ios --simulator --no-codesign`.

**Result.** All six sweeps exit 1 (no matches), with one documented
false positive on sweep 4 — see the phase report in `## Progress` row 11.
`flutter analyze` clean; `flutter test` **733 passed / 0 failed** (unchanged
from Phase 10 — Phase 11 adds no tests); `flutter build ios --simulator
--no-codesign` exit 0.

**Predicted Files**: `docs/architecture/wheel-triage.md`,
`docs/plans/pro-wave-1-plan.md`.

## Files Affected (whole wave; dependents marked)

- Data: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
  `lib/domain/models/user_preferences.dart` (+ generated),
  `user_preferences_defaults.dart`,
  `lib/data/db/tables/user_preferences_table.dart`,
  `lib/data/db/app_database.dart` (+ generated),
  `lib/data/db/drift_wheel_repository.dart`,
  `lib/data/in_memory_wheel_repository.dart`, `lib/data/wheel_repository.dart`,
  `lib/data/db/schema/drift_schema_v5.json`, `test/data/db/generated/*`.
- Rules: `capital_committed.dart`, `premium_collected.dart`,
  `reading_age.dart`, `expiry.dart`, `obligation.dart`,
  `snapshot_preview.dart`, `triage_input.dart`.
- State: `record/*`, `today/*` (new), `positions/position_detail_controller.dart`
  *(dependent: shared triage input)*, `screener/screener_controller.dart`,
  `preferences/preferences_provider.dart` *(reader of the new prefs)*.
- UI: `lib/core/theme/app_theme.dart`, `lib/core/disclaimer.dart`,
  `lib/core/app_router.dart`, `lib/main.dart`, `lib/widgets/bucket_badge.dart`,
  `lib/widgets/app_bottom_nav.dart`, `lib/features/record/*`,
  `lib/features/today/*`, `lib/features/positions/snapshot_sheet.dart`,
  `lib/features/positions/position_detail_sheet.dart`,
  `lib/features/settings/settings_screen.dart`,
  `lib/features/onboarding/first_run_explainer.dart` *(dependent: disclaimer
  footer)*, `lib/features/screener/screener_screen.dart`.
- Docs: `docs/architecture/wheel-triage.md`.

## Notes

- **Phase dependency graph** is in the Iteration block. The visible win
  (Record) arrives after four foundation phases; running P5 (pure rules) in
  parallel with P2/P3 is safe and recommended for a single implementer with
  spare capacity. Running P6 before P4 would mean building Record twice — the
  brief's §5 explicitly pays one phase to avoid that.
- **Route paths.** `/positions` keeps its name because four files
  (`app_router.dart`, `main.dart`, `first_run_explainer.dart`,
  `assignment_flow_screen.dart`) and the S-205 arrival-reload test key off
  it; the *screen* is renamed. Renaming the path is a later cosmetic change
  with no user-visible effect.
- **Intermediate states.** After P3 the repository carries methods nothing
  calls yet — expected, and visible only in `lib/data/`. After P8 the ledger
  strip and the expiry cards are absent from Today; the screen must not
  render empty shells for them until P9/P10.
- **`help_coverage_test.dart`.** New chips are added only where a §C2 topic
  id exists (the preview card's captured % / roll band / extrinsic and the
  Record screen's stock price / IV / delta fields). Extend that test's
  fixture in the same phase that adds a chip, never later.
- **Goldens** are generated and compared on the Mac; a run on another
  operating system is not a valid Done Criterion.
- **Owner checks** (Stage 0's device walk, Stage 1's timing) close their own
  stage and gate launch; they never block the next agent phase.

## Progress

| Phase | Owner | Status | Evidence |
|---|---|---|---|
| 1 — Stage 0 hygiene | @data-architect | Complete | `flutter analyze` clean; `flutter test` 464 passed / 0 failed; `dart run build_runner build --delete-conflicting-outputs` exit 0 (326 outputs, 13s); residue grep empty; `git status --porcelain` limited to `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` (+ the untracked plan file) |
| Owner — physical-iPhone wheel loop (Stage 0) | owner | not yet run | agent cannot run a physical-device check |
| 2 — schema v5 preferences | @data-architect | Complete | `flutter analyze` clean; `flutter test` 472 passed / 0 failed; `drift_schema_v5.json` vs v4 differs only by `wheel_capital_cents` (nullable int, `CentsConverter`) and `concentration_limit_pct` (real, default `25.0`); `currentFormatVersion` still 2; 8 migration tests green (`test/data/db`); the three pre-existing migration tests were retargeted to v5 and `test/data/user_preferences_migration_test.dart` likewise — see A-2 |
| 3 — repository reads + expiry batch | @data-architect | Complete | `flutter analyze` clean; `flutter test` 484 passed / 0 failed (was 472; +12 = 2 implementations × (2 S-216 + 4 S-217)); `flutter test test/data/wheel_repository_contract_test.dart` 88 passed / 0 failed against both implementations; `test/domain/rules/sbet_regression_test.dart` (S-015) passes; `grep -c "UnimplementedError" lib/data/*.dart lib/data/db/*.dart` = 0 (unchanged); both S-216 and S-217 shown falsifiable by mutation — see A-3 |
| 4 — Stage 4A theme | @developer | Complete | `flutter analyze` clean; `flutter test test/core/theme test/features/goldens` 59 passed / 0 failed (36 S-219 + 13 S-218); the three screen test files 22 passed / 0 failed; `flutter test` **533 passed / 0 failed** (was 484); refined colour-literal grep empty outside `lib/core/theme/`; 10 S-218 PNGs + 5 regenerated S-032 PNGs committed — see A-4 |
| 5 — Wave 1 rules | @developer | Complete | `flutter analyze` clean; `flutter test test/domain/rules test/state/positions` 255 passed / 0 failed; `flutter test` **602 passed / 0 failed** (was 533; +69 = 69 new across S-221…S-227); `grep -rl "package:flutter" lib/domain/rules/` empty; S-015 green; all six suites red before implementation and each falsified by mutation (19 failures from 6 mutations) — see A-5 |
| 6 — Stage 1 Record + save path | @developer | Complete | `flutter analyze` clean; `flutter test test/state/record test/state/screener test/features/screener` 62 passed / 0 failed; `flutter test` **640 passed / 0 failed** (was 602; +38 = 21 record state + 12 record screen + 3 S-236 + 1 screener-screen refusal + 1 Record help-coverage group); tone grep of §4 empty; `grep -rl "package:flutter" lib/domain/rules/` empty; the two call-side screener fixtures retargeted to put-side by D-12 — see A-7 |
| Owner — timing check (Stage 1) | owner | not yet run | agent cannot time a manual device walk |
| 7 — Stage 2 preview + sheet | @developer | Complete | `flutter analyze` clean; `flutter test test/domain/rules/snapshot_preview_test.dart test/features/positions test/state/positions` 73 passed / 0 failed (12 new S-238/240/241 + 14 new S-239/238/241 widget + 47 pre-existing position tests); `flutter test` **667 passed / 0 failed** (was 640; +27); `grep -rl "package:flutter" lib/domain/rules/` empty; tone grep of §4 empty; the S-238 widget suite shown red (7 failures) with the preview card disabled; two S-238 fixture corrections and one extraction logged — see A-8, A-9, A-10 |
| 8 — Stage 3a Today | @developer | Complete | `flutter analyze` clean; `flutter test test/features/today test/state/today` 34 passed / 0 failed; `flutter test` **688 passed / 0 failed** (was 667; +21 = 18 today-controller + 16 today-screen, less 13 deleted positions-list tests); `grep -rn "positionsListControllerProvider" lib/ test/` empty; tone grep of §4 empty; `grep -rl "package:flutter" lib/domain/rules/` empty; three pre-existing tests retargeted (S-163 fixture, S-073 nav tap, `test/widget_test.dart`) — see A-11…A-17 |
| 9 — Stage 3b strip/concentration/Settings/disclaimer | @developer | Complete | `flutter analyze` clean; `flutter test test/features/today test/features/settings test/features/onboarding test/state/today test/core` 100 passed / 0 failed; `flutter test` **709 passed / 0 failed** (was 688; +21 = 6 today-controller + 7 today-screen + 5 settings + 1 onboarding + 1 disclaimer + 1 `_ledgerBook`-driven S-248 round trip); tone grep of §4 empty; `grep -rl "package:flutter" lib/domain/rules/` empty; every Phase 9 suite confirmed red before implementation (2 compile failures + 6 behavioural failures); three collateral test edits (S-199's field count scoped to `RuleProfileSection`, S-073's viewport, S-248's limit direction) — see A-18…A-24 |
| 10 — Stage 3c expiry cards + D-P13 | @developer | Complete | `flutter analyze` clean; `flutter test test/domain/rules test/state/today test/state/positions test/features/today` 88 passed / 0 failed; `flutter test` **733 passed / 0 failed** (was 709; +24 = 6 `expiry.dart` copy + 4 S-250 + 4 S-252 controller + 5 S-250/251 + 1 S-252 + 1 S-254 screen + 4 S-253 close-date); red before implementation (3 suites compile-failed on the new API, 9 widget tests failed behaviourally); tone grep of §4 empty; `grep -rl "package:flutter" lib/domain/rules/` empty; both cards wired into `_Body`'s list between the ledger strip and the list header; four files beyond Predicted Files — see A-25…A-32 |
| 11 — closeout docs + residue sweep | @developer | Complete | `docs/architecture/wheel-triage.md` extended in place (header, layering, schema v5, `snapshot_preview`/`expiry` copy builders, a new "Today, Record and the theme" section with a **drift-risk** table, the state-layer conventions and the Settings paragraph) — no new file. Six sweeps, each pasted: `grep -rn "Bucket severity" lib/ test/` → exit 1, no output; `grep -rn "positionsListControllerProvider" lib/ test/` → exit 1, no output; `grep -rn "fl_chart\|riverpod_annotation\|custom_lint" pubspec.yaml analysis_options.yaml lib/ test/` → exit 1, no output; `grep -rn "Colors\.\|Color(0x" lib/ \| grep -v lib/core/theme/` → **one false positive**, `lib/widgets/bucket_badge.dart:37: final colors = BucketColors.of(context);` (the substring `Colors.` inside `BucketColors`, which is defined in `lib/core/theme/app_theme.dart`; the refined `grep -rnE '(^\|[^A-Za-z])Colors\.\|Color\(0x' lib/ \| grep -v lib/core/theme/` is empty — so no literal colour exists outside the token file); `grep -rl "package:flutter" lib/domain/rules/` → exit 1, no output; §4 tone grep `grep -rniE "recommend\|we suggest\|our analysis\|buy signal\|sell signal\|opportunity\|guaranteed\|you should" lib/` → exit 1, no output. `flutter analyze` → `No issues found!` (exit 0); `flutter test` → **733 passed / 0 failed** (`All tests passed!`, exit 0; unchanged from Phase 10 — Phase 11 adds no tests); `flutter build ios --simulator --no-codesign` → `✓ Built build/ios/iphonesimulator/Runner.app`, exit 0. Owner checks remain **not yet run** (see their rows above) — an agent cannot perform a physical-iPhone wheel-loop walk or a manual timing check |

## Assumption Log

*(executors append: decision made, options considered, choice and why. The
Conductor marks each RATIFIED — promoted to a D-x — or REVERT, opening
remediation.)*

### A-1 — `analyzer` pinned to 7.6.0 as a direct dev dependency (Phase 1)

**Decision.** Add `analyzer: 7.6.0` to `dev_dependencies` in `pubspec.yaml`.

**Options considered.**
1. Leave resolution alone and let pub pick the newest `analyzer` (7.7.1).
2. Pin `analyzer: 7.6.0` directly.
3. Bump the whole codegen set to `analyzer` 8.x.

**Why.** Removing `custom_lint` / `riverpod_lint` / `riverpod_generator` in
Stage 0 also removed their `analyzer` upper bounds, so `flutter pub get`
re-resolved `analyzer` from 7.6.0 to 7.7.1. In 7.7.1,
`ThrowingAstVisitor.visitDotShorthandInvocation` throws unconditionally
(`analyzer/lib/dart/ast/visitor.dart:2538`), and `BundleWriter._writeNode`
routes every serialized AST node through that visitor. The Dart 3.11 SDK parses
dot-shorthand syntax into `DotShorthandInvocation` nodes, so `build_runner`
crashed on the first library it linked (`lib/core/app_router.dart`) with
`Exception: Missing implementation of visitDotShorthandInvocation`, and the run
never terminated. 7.6.0 has a working implementation; 8.x removes the method
entirely but is outside every kept codegen package's constraint
(`freezed` / `json_serializable` / `source_gen` `>=6.9.0 <8.0.0`, `drift_dev`
`>=7.3.0 <8.0.0`). Option 2 is the only one that both regenerates the committed
artifacts and keeps the pinned codegen set intact.

This is a **new direct pin**, not a change to a kept package's version, so it
does not contradict D-2. It is recorded here because it is a `pubspec.yaml`
edit the plan did not predict.

**Residual risk.** The pin is a workaround for an upstream analyzer defect, not
a fix. It must be re-evaluated when the codegen set is next bumped; the comment
above the pin in `pubspec.yaml` says so.

### A-2 — every v1-start migration test now targets v5, not the version it was written for (Phase 2)

**Decision.** `test/data/user_preferences_migration_test.dart`,
`test/data/db/rule_profile_v4_migration_test.dart` (its v1-jump case) and
`test/data/db/rule_profile_v4_migration_test.dart`'s gate case were retargeted:
the v1-start tests migrate to and validate against **v5**, and the v4 gate test
now starts at **v2** instead of v1.

**Options considered.**
1. Leave the tests targeting v3/v4 and accept the `SchemaMismatch`.
2. Retarget the v1-start tests to the current version (v5) and re-anchor the
   v4 gate test one version up (v2 start).
3. Make `onUpgrade`'s `from < 2` step create `user_preferences` from a
   version-pinned definition.

**Why.** `SchemaVerifier.migrateAndValidate(db, N)` validates the migrated
database against N's schema snapshot, and drift offers no way to relax that
(`verifier_common.dart`: `ValidationOptions` carries only the deprecated
`validateDropped`). The `from < 2` step calls
`m.createTable(userPreferencesTable)`, and a Dart `Table` always describes its
*current* column set — so a database that starts at v1 gets a `user_preferences`
carrying v3's and now v5's columns, and can only be validated against the
current version. Option 3 is not expressible in drift (there is no "table at
version N" form), and option 1 loses schema validation entirely. The v4 gate
test starts at v2 because that is the lowest version whose
`user_preferences` is genuinely v3-shaped — the point of that test is that
`to < 4` leaves the v4 step unrun, and a v2 start still runs the v3 step on the
way, so the gate assertion keeps its meaning.

**Deviation from the task brief.** `brief-fix-1.md` said to "keep
`migrateAndValidate(..., 5)`" while restoring the original `schemaAt`
arguments. That combination cannot work: N must equal the version the
`DatabaseAtV*` check-helper reads through, so a test validating through
`DatabaseAtV3` must pass 3. The brief's other instruction — restore the original
`schemaAt` arguments — is satisfied.

**Note.** This is a property of the drift testing API, not of the app's
migration code: the shipped `onUpgrade` is unchanged by this decision, and a
real device always migrates from its own version to `schemaVersion`.

### A-3 — `getAllLegs` ties break on `(openedAt, sequence)` only, and `markExpired` pre-validates the whole batch (Phase 3)

**Decision.** Two choices the plan left open:

1. `getAllLegs()` orders by `openedAt` ascending, then `sequence` ascending,
   and stops there — no `id` third key.
2. `markExpired` validates **every** leg in the batch (unknown id, already
   closed) before writing **any** of them, in both implementations; the Drift
   implementation then performs every close inside one `_db.transaction`.

**Options considered (1).** Add `id` as a third tie-break so the order is total
regardless of fixture; or require callers to supply a fixture whose
`(openedAt, sequence)` is already total.

**Why (1).** `id` is implementation-chosen (UUIDs in the Drift path, generated
ids in memory), so it is not comparable *across* implementations — a third key
would make the shared contract test pass on one and fail on the other for a
reason that has nothing to do with the contract. `(openedAt, sequence)` is
already unique within a cycle, so the only ambiguity is two cycles' first legs
sharing an instant, and the S-216 fixture deliberately creates that case (the
closed cycle's sequence-1 leg is written before the open cycle's sequence-0 leg
at the same `openedAt`) so the tie-break is falsifiable on both implementations.

**Why (2).** S-217 requires "throws … changing nothing". Validating inside the
write loop would satisfy the throw but leave earlier legs in the batch closed —
a partially applied bulk action over a user's selection. Pre-validating costs
one extra read per leg and makes the guarantee structural rather than a
consequence of transaction rollback, which also means the in-memory
implementation (which has no transaction) gets it for free.

**Falsification recorded.** Both new contract groups were shown red under a
deliberate mutation and green after restoring: dropping the `sequence`
tie-break from `InMemoryWheelRepository.getAllLegs` fails both S-216 tests on
that implementation while the Drift ones still pass; moving
`_validateMarkExpiredTarget` inside `markExpired`'s write loop fails both
"changes nothing" cases (b and d) by leaving the first leg closed.

**Note.** `_rejectEmptyExpiryBatch` and `_validateMarkExpiredTarget` are
duplicated verbatim in both repository files, matching the existing
`_validateLegMetadataUpdate` precedent — parity is proven by the shared
contract suite, not by sharing code (conventions §6).

### A-4 — theme foundation: derived containers, the FAB pair, the `BucketColors.of` fallback, and the S-032 goldens (Phase 4)

**Decision.** Four choices the plan left open, plus one refinement of a Done
Criterion:

1. **Derived container roles.** D-4's table names no `*Container` value, so
   `accentContainer`/`cautionContainer`/`errorContainer` and their `on*` inks
   are written into `AppTokens` as literals derived from the table: each
   container is `Color.lerp(surface, fill, 0.18)`, and each ink is the same
   hue darkened until it clears 4.5:1 on that container.
2. **The FAB uses the accent pair, not M3's default.** `floatingActionButtonTheme`
   sets `backgroundColor: accent`, `foregroundColor: onAccent`.
3. **`BucketColors.of(context)` falls back to the light set** when no
   extension is installed, rather than throwing.
4. **`test/widgets/bucket_badge_test.dart` (S-032) now renders under
   `lightTheme` and its five PNGs were regenerated.**
5. **The Done Criterion's grep gains a character class** —
   `grep -rnE "(^|[^A-Za-z])Colors\.|Color\(0x"` instead of
   `grep -rn "Colors\.\|Color(0x"`.

**Options considered (1).** (a) Leave the roles to `ColorScheme.fromSeed`;
(b) give each container and ink a hand-picked literal; (c) derive the
container by lerp and the ink from the table's own colour, darkened.

**Why (1).** `fromSeed` picks its own values, which is exactly the "framework
default where the design specifies a value" the phase forbids, and the
screener's `_GateChip` paints text onto `primaryContainer`/`errorContainer`
today. A hand-picked literal is a second palette with no derivation story.
Option (c) keeps the source of truth in D-4's table and makes the derivation
reproducible. Dark: `#1C3F3B`/`#40382C`/`#403332`, inks `#60D3C6`/`#FAA96A`/
`#F98C8B`. Light: `#C3EAE4`/`#F1E1D6`/`#F3DCDC`, inks `#00665F`/`#8F4314`/
`#9E2A2E`. The light inks are **darker than the table's `accent`/`caution`/
`error`**: reusing those gave 3.91 / 3.93 / 4.11, all below 4.5. The S-219
guard pins every one of these pairs in both themes, so this choice cannot
silently regress.

**Why (2).** M3's FAB default is `primaryContainer` + `onPrimaryContainer`,
which after (1) is 3.91:1 in the light theme — below the bar. The accent pair
is 8.20:1 / 5.07:1 and is the design's own primary affordance.

**Why (3).** S-032's harness wrapped the badge in a bare `MaterialApp`; a
throw would break every such test and a hard-coded fallback would be a second
palette. The fallback returns `AppTheme.lightBucketColors`, which is built from
the same tokens, so a badge rendered outside the app's themes still gets the
designed colours. It is not a silent default for the app — `main.dart` always
supplies one of the two themes.

**Why (4).** S-032's goldens were rendered under Flutter's default theme, which
is neither of the design's. They now pin the light theme, which is what they
were approximating. Their content is byte-identical to S-218's `*_light`
goldens (`md5` equal): the two scenarios overlap in fixture, not in claim —
S-032 pins the badge's five states under the app theme, S-218 pins both themes
and the token set. Recorded because the plan's
`## Existing-Functionality Impact` table lists only
`test/features/positions/*` as badge readers.

**Why (5).** `BucketColors` is the name D-4 and the plan give the extension, and
`BucketColors.of(context)` contains the substring `Colors.`, so the literal
pattern matches the extension lookup. The character class preserves the
criterion's meaning (no colour literal outside `lib/core/theme/`) without
forcing a rename away from the plan's own name.

**No screen needed a role replaced (item 4).** The one role pair that was
below the bar was the badge's Assign (`errorContainer` + `onErrorContainer`),
which item 3 already moves to its own token; and the FAB, which is (2). Every
other role an existing screen reads — `error`, `onSurfaceVariant`, `primary`,
`primaryContainer`, `secondaryContainer`, `surfaceContainerHighest`,
`surfaceContainerLowest` — clears 4.5:1 in both themes, so no layout or copy
changed. `test/features/positions/position_detail_sheet_test.dart`,
`test/features/screener/screener_screen_test.dart` and
`test/features/settings/settings_screen_test.dart` all pass unchanged.

**Falsification recorded.** The S-219 guard was red before
`lib/core/theme/app_theme.dart` existed (`'BucketColors' isn't a type`) and the
S-218 suite was red on `Undefined name 'darkTheme'`; both green after. The
light-theme `on*Container` inks were chosen by measurement — reusing the
table's `accent`/`caution`/`error` fails S-219 at 3.91 / 3.93 / 4.11.

**Note.** `MaterialApp` cross-fades a theme change over 200ms, so the two
S-218 assertion tests that loop over both themes `pumpAndSettle` after
`pumpWidget`; without it the second iteration reads a half-lerped theme.
Caught by the "No data" test failing on the light iteration.

### A-5 — the concentration comparison is unrounded, and `currentCapitalCommitted` takes `now` (Phase 5)

**Decision 1 — the flag compares the unrounded ratio.** D-10 says the flag
appears when `concentration > concentrationLimitPct`, strictly greater, and
that percentages are *displayed* rounded to the nearest whole percent. S-222's
fixture makes the two readings diverge: $7,500.01 of $30,000 is 25.0000333%,
which rounds to 25 — so a comparison on the rounded integer would leave the
scenario's "just over" case unflagged, contradicting its stated outcome.

**Options considered.**
1. Compare the rounded whole percent (`25 > 25` is false → not flagged).
2. Compare the unrounded ratio, round only for display.

**Why (1).** Option 2 is what D-10's own wording says ("strictly greater",
with rounding scoped to the rendered percentage) and what S-222 asserts. The
ratio is kept exact through `Decimal`'s `Rational` division and rounded once at
the end, the same pattern `formulas.dart`'s `capturedPct` uses (S-012) — a
ratio landing on `24.999999…` instead of `25` would mis-flag a book. The
rounded integer is still what `ConcentrationFlag.percent` carries, so the
rendered line is unchanged.

**Decision 2 — `currentCapitalCommitted` accepts an optional `now` it does not
read.** The plan's item 1 names the function with `(...)`, and Feature
Invariant 1 says every new function in the directory takes `now` as a
parameter. "Committed now" is genuinely a function of what is open, not of the
clock — a past-expiration leg is included *because* the clock has moved past
it — so the parameter is accepted for signature parity and deliberately unused,
documented as such, and pinned by a test asserting the figure is identical with
and without it.

**Decision 3 — the share side uses `wheelBasis` with no calls since
assignment.** D-9's pseudocode says `wheelBasis(put legs + active share lot, no
calls since assignment)`, which is the shares' wheel-adjusted basis at the
moment of assignment. This matches `cycle_pnl.dart`'s `peakCapitalCommitted`,
which uses the same term for its own share side, and the on-screen definition
D-9 mandates ("shares at wheel-adjusted basis"). A call sold after assignment
therefore does not reduce "Committed now" — the shares are still held at the
basis the assignment created.

**Decision 4 — `triageInputFor` resolves IV even with no snapshot.** The two
private copies it replaces differed here: the list controller's returned a bare
`TriageInput(dte:, acceptsAssignment:)` when the snapshot was null, while the
detail controller's resolved IV from the leg's `ivAtOpen` first. Feature
Invariant 18 makes the resolution order a *classification* input, not a
display-only one, and the detail controller's behaviour is the one that honours
it — a leg opened at a known high IV must not silently drop to the profile
default just because no reading has been taken yet. The shared assembly
therefore resolves IV in both branches. This is a behaviour change for the
positions list on exactly one input (a leg with `ivAtOpen` set and no snapshot),
it is the direction Feature Invariant 18 requires, and it is pinned by S-227's
"a null snapshot still resolves IV from the leg when it has one". No existing
test changed.

**Falsification recorded.** Six one-line mutations — dropping the
past-expiration inclusion, treating at-the-strike as in the money, `>=` for the
aging threshold, subtracting fees from net premium, swapping the put/call
obligation branches, and dropping the null-snapshot IV resolution — produced 19
test failures across the six new files, then all 69 passed again on restore.

**Note.** `test/domain/rules/premium_collected_test.dart`'s August and
year-to-date expectations were corrected during implementation: by D-8 a credit
belongs to the period its own `openedAt` falls in, so the fixture's August
figure is $325 (UBER $110, BAC $55, CCL $80, KO $30, the assigned leg's $50),
not the $285 a first pass assumed, and the year to date is $886. The September
figure S-223 pins ($561) was correct from the start.

### A-6 — S-231's credit fixture uses a $50.00 call credit, not $0.50 (Phase 6)

S-231's row reads *"a call with strike $19, credit $0.50 and no stock price; the
same call with stock price $18.00"* with the expected outcome *"the call with a
stock price below the credit hard-rejects"*.

Those two halves cannot both hold: with credit $0.50 and spot $18.00 the credit
is *far* below the spot, so the call-side bound (half of spot, $9.00) is not
crossed and nothing rejects. The outcome is the load-bearing half — it is what
the row exists to pin, and it is the row that pins the deliberate asymmetry that
a missing spot must **skip** the call-side check rather than guess a bound.

**Decision:** implement and test the stated *outcome* with a call credit of
**$50.00** against spot $18.00 (hard reject: $50.00 > $18.00), and the no-spot
row unchanged (the check is skipped, so the form is never blocked on a value the
user did not enter). Test:
`test/state/record/record_controller_test.dart` (S-231, four rows).

**Options considered:** (a) keep $0.50 and invert the expectation — rejected, it
would pin the opposite of the stated outcome; (b) treat the credit as already
per-contract — rejected as a silent reinterpretation of the fixture rather than
of the arithmetic.

**Reviewer:** ratify the fixture correction, or re-specify the row's numbers.

### A-7 — two call-side screener fixtures moved to put-side under D-12 (Phase 6)

D-12 refuses a call on a ticker with no share-holding cycle on record. Two
pre-existing screener fixtures fill the form call-side and then save, so they
would now assert a refusal instead of what they were written for:

- `test/state/screener/screener_controller_test.dart` S-051 ("soft-warn never
  blocks") — the soft-warn *outputs* assertions are unchanged in kind; the form
  is now put-side (strike $50, credit $30, spot $45), which crosses the same
  soft-warn band on the same bound and still saves successfully.
- `test/state/screener/screener_controller_notifications_test.dart`
  `fillForm()`, used by S-170/S-174/S-175/S-176 — those scenarios are about
  scheduling and permission, not the side, so the fixture is now put-side.

S-050's hard reject is untouched: it blocks before the save path is reached.
Neither edit weakens a scenario; both keep the scenario's stated outcome under
the new rule. `test/state/screener/screener_controller_test.dart` gains S-236
(a/b/c) to pin the call path's three outcomes explicitly.

**Reviewer:** ratify, or specify replacement fixtures.

### A-8 — `lib/core/format.dart` extracted, and three test files outside the Predicted Files (Phase 7)

The extracted sheet would otherwise have carried a *second* copy of the four
private formatters `position_detail_sheet.dart` already had (`_moneyText`,
`_pctText`, `_trimTrailingZeros`, `_dateText`), so they moved to
`lib/core/format.dart` (`moneyText`, `pctText`, `trimTrailingZeros`,
`dateText`) and both callers now import them. `lib/core/format.dart` is not in
Phase 7's Predicted Files; it is `{{CORE_DIR}}`'s stated home for formatting
shared by two callers, and Phase 9's ledger strip needs the same helpers.

Also outside the Predicted Files: `test/features/positions/snapshot_sheet_test.dart`
(new — the S-238/S-239/S-241 widget coverage of the extracted sheet, which the
Predicted Files named only through `position_detail_sheet_test.dart`) and
`test/domain/rules/snapshot_preview_test.dart`'s companion edits to
`lib/domain/rules/bucket.dart` (`bucketLabel`) and `lib/widgets/bucket_badge.dart`
(now sourced from it, so the badge, Today's counts and the change line cannot
drift apart).

**Reviewer:** ratify, or move the formatters back behind the sheet.

### A-9 — S-238's Leave row is mark 0.18, not 0.10 (Phase 7)

S-238's fourth row reads "mark 0.10 / delta −0.10 (Leave)". Against the row's
own $0.30 credit, a mark of 0.10 is 66.7% captured, which fires Gate 1 (Close)
before Gate 3 or the fall-through is ever reached — so the row as written
cannot produce a Leave bucket under any gate order. The row exists to pin the
fall-through, so the mark is **0.18** (40% captured, below the 50% target and
inside the 0.30 band at IV 21), which leaves every other gate unfired and
lands on Leave. S-241's fixture uses the same corrected reading for its
"previous" snapshot. The row's stated *outcome* is unchanged; only the number
that can produce it moved.

S-238's second row's parenthetical "(0.35 band)" is likewise a slip: 0.35 is
the *delta* in that row, and the band in force at IV 21 is 0.30.

**Reviewer:** ratify, or replace the row with a delta that reaches the
fall-through at mark 0.10.

### A-10 — the sheet parses its fields at press time, not from build-time locals (Phase 7)

Extracting the sheet as a `ConsumerStatefulWidget` (rather than the
`StatefulBuilder` the old inline function used) exposed a latent staleness bug:
the save button's closure captured the build-time `mark`/`spot`/`delta` locals,
and `tester.enterText` does not pump, so a press that followed the last
keystroke before a rebuild silently read the *previous* text and returned
early — the S-142 backdating tests failed with no snapshot written. The handler
now re-parses `_markController`/`_spotController`/`_deltaController` at press
time, which is what the pre-extraction code did (it parsed inside `onPressed`)
and is the only reading that is correct for a user who types and taps without
waiting a frame. The preview card keeps using the build-time values, so it is
at worst one keystroke behind — the same behaviour the old sheet had.

**Reviewer:** ratify.

### A-11 — the bottom nav pushes, and takes its route as a parameter (Phase 8)

Two choices in `lib/widgets/app_bottom_nav.dart`. First, the four non-Today
destinations use `context.push`, not `go`, so the screen underneath stays
mounted and Today keeps its S-205 arrival-reload behaviour (a `go` would rebuild
Today from scratch and make the router-delegate listener the only reload path).
Second, the bar takes `currentPath` as a constructor argument instead of reading
`GoRouterState` itself: the screen that owns the route already knows which one
it is, and a bar that read the router would be untestable outside one and would
render a duplicate of itself when the selected item was tapped.

**Reviewer:** ratify.

### A-12 — Today's app bar carries no actions; the nav is the only Settings door (Phase 8)

The plan's Phase 8 item 2 gives the header a date and a title and nothing else,
and D-14's nav lists Settings as one of the five items. The old
`find.byTooltip('Settings')` affordance is therefore gone; S-073's reopening
test now taps the nav's `Settings` label. `test/features/onboarding/first_run_explainer_test.dart`
is outside the Predicted Files and is edited for exactly this reason.

**Reviewer:** ratify.

### A-13 — filters clear on reload, `sort` does not (Phase 8)

`load()` resets `bucketFilter` and `agingOnly`. A reload is a fresh statement of
the book: keeping a filter across it can leave the screen showing a subset with
no visible cause after a save, which is the same "list that renders nothing when
it should render something" failure the empty-state rule exists to prevent.
`sort` is a display preference, not a query, so it survives.

**Reviewer:** ratify.

### A-14 — the reading line's age suffix, and the header's total (Phase 8)

Two display calls the plan does not pin down. The row's reading line reads
`From Sep 17 reading`, and appends ` · 11 days old` **only** once
`readingAgeDays > kAgingDays` — an age that is not yet aging is not worth the
space, and the aging line above the list is the aggregate. The list header
always reports `state.items.length`, the full open book, even while a filter
narrows the rows: the header states the book, the chips state the filter.

**Reviewer:** ratify, or move the age suffix to always-on.

### A-15 — S-242's fixture is seven open legs, not eight (Phase 8)

The scenario text says "every open leg"; the fixture enumerates one leg per
bucket plus a past-expiration leg, which is six in the list and seven in the
repository. The test asserts six `BucketBadge`es and `findsNothing` for the
expired leg's ticker, which is the property the scenario is about. No
behavioural difference.

**Reviewer:** ratify.

### A-16 — three pre-existing tests retargeted to the new surfaces (Phase 8)

`test/features/settings/settings_screen_test.dart` S-163 used a leg expiring
`2026-03-01` to stand in for "a position on screen"; Today excludes
past-expiration legs, so the fixture is now `now + 30 days` — the assertion
(the list is unchanged after a failed import) is the same. `test/widget_test.dart`
(also outside the Predicted Files) asserted `find.text('Positions')` and now
asserts `find.text('Today')`. The S-073 change is A-12.

**Reviewer:** ratify.

### A-17 — S-244's post-save count is two Roll rows, not one (Phase 8)

Saving a reading for the aging `T` leg moves it from Leave to Roll, so the
Roll count goes from 1 to 2 after the save, not to 1. The test asserts 2. The
scenario's stated outcome (the leg is re-classified on save) is unchanged; only
the arithmetic of the count followed from the fixture.

**Reviewer:** ratify.

### A-18 — `Decimal.zero` is not `const`, so the four ledger fields are `required` (Phase 9)

`decimal`'s `Decimal.zero` is a `static final`, so it cannot be a default
parameter value. `TodayState` therefore declares `netPremiumMonth`,
`netPremiumYearToDate`, `committedNow` and `ledgerMonthLabel` as `required`,
and the pre-load state comes from a named `TodayState.initial()` factory.
`TodayController`'s constructor calls it. This is a Dart language constraint,
not a design choice: the alternative (nullable fields) would put a null check
in the strip for a state that always exists.

**Reviewer:** ratify.

### A-19 — the ledger strip's figures are read from `getAllLegs()`, and cycles are derived from the legs (Phase 9)

D-8's premium figure counts a buyback, which is a *closed* leg's own debit, so
the ledger reads `getAllLegs()` rather than `getOpenLegs()`. D-9's committed
capital needs a `WheelCycle` per cycle, and `WheelRepository` has no
`getAllCycles` (the Phase 9 Predicted Files keep `lib/data/` out of this
change), so `_capitalInputs` groups the legs it already has by `cycleId` and
reads each cycle by id. A cycle with no legs commits nothing, so nothing is
lost. `getShareLotForCycle` is read only for `holdingShares` cycles, as D-9
says. **If a later phase adds `getAllCycles`, this should use it.**

**Reviewer:** ratify.

### A-20 — the rules layer gained the definition line and the range checks; `lib/core/format.dart` gained `monthAbbreviation` (Phase 9)

Three edits outside the plan's Predicted Files, all in the direction the
architecture already runs:

1. `lib/domain/rules/capital_committed.dart` gained
   `kCommittedNowDefinitionLine`, `committedNowDefinition(...)`,
   `wheelCapitalInRange`, `kWheelCapitalRefusal`, `concentrationLimitInRange`
   and `kConcentrationLimitRefusal`. The definition paragraph is composed in
   `TodayState.ledgerDefinitionLine` (a getter), not in the widget, so the
   screen renders one string it did not build. The refusal messages live with
   the ranges they describe — the same "bounds in exactly one place" rule
   `validateRuleProfile` follows — and the Settings fields read them from
   there. `_wholeDollars` is a deliberate private copy of
   `lib/core/money/whole_dollars.dart`, because the rules layer may import only
   `lib/domain/models/` (the same copy `obligation.dart` keeps).
2. `lib/core/format.dart` gained `monthAbbreviation`, because the tile label
   and the figure must describe the same period: the controller derives both
   from `monthPeriodContaining(now).start`.
3. `lib/state/preferences/preferences_provider.dart` gained
   `setWheelCapital` / `setConcentrationLimit`, which ignore an out-of-range
   value rather than clamping it (D-6). The refusal *message* belongs to the
   field that refused the entry, so a caller that validates first sees no
   difference; the guard is what makes "never clamped" structural rather than
   a property of the widget.

**Reviewer:** ratify.

### A-21 — the on-screen committed-now definition is D-9's literal line, without the parenthetical clause (Phase 9)

D-9's bullet says "the on-screen definition says so ('includes legs past
expiration until recorded')", but the same decision's *literal* screen
definition line is "Committed now: open puts at strike, shares at
wheel-adjusted basis" — extended with `; N% of your $X wheel capital`. The
literal line is what S-246 pins character-for-character, so that is what is
rendered; the past-expiration clause is a property of the rule
(`capitalCommittedForCycle` includes open past-expiration puts), not a clause
in the sentence. Flagged rather than silently chosen because the two sentences
in D-9 do not agree.

**Reviewer:** ratify or amend D-9.

### A-22 — S-246/S-247's fixtures are purpose-built, and the register's $561 is not asserted (Phase 9)

S-246's register entry names the sample book and a September figure of $561.
The ledger tests use a purpose-built book built relative to `now` instead
(`_ledgerBook` in the widget suite, an equivalent inline fixture in the
controller suite): INTC $20×4 + SOFI $14×3 + T $28×1 credited this month, F
$12×2 opened 40 days ago and closed today, and — in the controller suite only
— SBET's July credit and buyback. Those give month $405, year to date
$545 (controller: $570) and committed now $12,200 (41% of $30,000, INTC 27%).
The reason is date stability: the sample book's dates are relative to `now`,
so its month and year-to-date figures would change with the run date and the
assertion would be a different test in September than in January. Every
behaviour S-246 and S-247 name is asserted (three tiles with the month in the
first label, the definition line, exact reducer agreement, the flag line's
words and neutral styling, no link, the invitation, largest-first ordering,
the limit-raised case); only the register's illustrative arithmetic is
replaced.

**Reviewer:** ratify.

### A-23 — three pre-existing tests needed a change because Settings grew (Phase 9)

1. `test/features/settings/rule_profile_editor_test.dart` (S-199) counted
   `find.byType(TextFormField)` across the whole screen and expected 14. The
   finder is now scoped to `RuleProfileSection` — which is what the assertion
   always meant ("all 14 fields are real inputs"), and Settings legitimately
   has two more fields now.
2. `test/features/onboarding/first_run_explainer_test.dart` (S-073) asserted
   the "How this app works" button was built in a lazily-built `ListView` at a
   2400px viewport. The new section pushes the button past the viewport plus
   its cache extent, so the test now uses the same 4000px viewport S-070
   already uses. Nothing about the behaviour under test changed.
3. `test/features/today/today_screen_test.dart` (S-248): the scenario's
   "the concentration lines on Today update immediately" is asserted by
   *lowering* the limit to 20 (the line's text changes) and then raising it to
   30 (the line disappears entirely), because D-10 flags only what is
   *over* the limit — a 30% limit against a 27% share shows no line at all.

**Reviewer:** ratify.

### A-24 — the first-run disclaimer is a footer of the screen, not of a card (Phase 9)

S-249 requires the disclaimer on every explainer card. It is placed in the
body `Column` *after* the Next/Done button, outside the `PageView`, so it is
one widget that no page turn can hide — rather than three copies inside the
three cards, which would drift. The button's bottom padding shrank from 24 to
12 to keep the fixed chrome inside the default 600px test viewport.

**Reviewer:** ratify.

### A-25 — the card's copy builders live in `lib/domain/rules/expiry.dart`, not in the widgets (Phase 10)

`expiryReadingLine` and `expiryBatchExplanation` are in the rules layer beside
the predicates they describe, so the two sentences the reference draws
(`Last reading Sep 24: stock $12.10, above the strike`, `Records WBD as
expired worthless on Sep 25, no close debit. The close fee stays blank.`) are
unit-testable without a widget harness and cannot drift between the card, the
confirmation dialog and the detail sheet. `lib/domain/rules/` cannot import
`lib/core/format.dart` (`obligation.dart`'s `_dollars` is the precedent), so
the file carries private `_shortDate`/`_money`/`_months` helpers rather than
the shared formatter.

The per-leg sentence names the ticker only when there is exactly one eligible
leg — `ExpiryCardEntry` carries no ticker — so `expiryBatchExplanation` takes
a `singleTicker` the card supplies. With two or more it says "each leg",
which is correct for N and matches the drawn case for one.

**Options considered.** (1) Build the strings in the widget. (2) Put them in
`lib/core/format.dart`. (3) In the rules layer, with private local formatters.
**Choice:** 3 — it keeps the D-13 wording in the same file as the D-13 rule,
and the §4 tone review has one place to look.

**Reviewer:** ratify.

### A-26 — the card caption is the latest date; per-group labels appear only with more than one group (Phase 10)

The reference draws a single-group card with the date in the header
(`Expiring this week` · `Fri Oct 2`) and no label above the rows. Rendering
both would print the same date twice. So the header's `sub` is always the
latest date the card covers, and each group carries its own label **only when
there is more than one group** — the two-group case then reads
`Fri Oct 9` (caption) over the later group and `Wed Oct 7` over the earlier,
which S-250 asserts as `findsNWidgets(2)` and `findsOneWidget`.

**Reviewer:** ratify.

### A-27 — the past-expiration card is one card with two sections, not two cards (Phase 10)

The reference draws a single bordered card: the eligible legs, the
`Mark all expired (N)` button, the explanation paragraph, a divider, then the
left-out legs under their own caption with their own two buttons. That is what
ships. Which section a left-out leg belongs in is read off its own data — no
reading, or a reading in the money — rather than re-derived from
`expiryBatchEligible`, so the widget holds no rule.

**Reviewer:** ratify.

### A-28 — the two actions confirm first, and a failure never touches `TodayState.error` (Phase 10)

`Mark all expired` opens an `AlertDialog` titled `Mark all expired?` carrying
the same explanation the card prints; each per-leg `Mark expired` opens
`Mark expired?`. Both were added for this phase (the reference draws the
buttons without a dialog) because a write that closes positions on a past date
is not undoable from this screen.

`TodayController.markAllExpired` and `markExpiredLeg` return `String?` — `null`
on success, the message on failure — and on failure deliberately leave
`state.error` unset and `state.items`/`state.pastExpiration` untouched, so the
card reports the failure inline and survives it (S-252's failing-repository
case). A batch with nothing eligible returns `null` without writing, because
`markExpired` treats an empty list as an `ArgumentError`.

**Reviewer:** ratify.

### A-29 — `TodayController` takes a `Ref`, and the notification cancel moves into the controller (Phase 10)

The controller's constructor became `TodayController(this._ref, this._repo)`,
matching `PositionDetailController(this._ref, this._repo, this._legId)`, so
both mark-expired paths can cancel the closed leg's scheduled reminders
exactly as `closeDirect` does (S-171). `notificationGatewayProvider` already
defaults to `NoOpNotificationGateway`, so no existing test needed a new
override, and no test constructs `TodayController` directly.

**Options considered.** (1) Cancel from the widget via `ref.read`. (2) Pass
the scheduler in as a constructor argument. (3) Take the `Ref`. **Choice:** 3
— it is the pattern the sibling controller already uses and keeps the
orchestration in the state layer.

**Reviewer:** ratify.

### A-30 — a card row is one `Text.rich`, and its date comes from the header (Phase 10)

Each row is a single `Text.rich` whose plain text is `WBD $11 put ×1` — the
ticker as a bold span, the contract from the new `legContractText` — so
`find.text('WBD')` still matches only the *list* row's own ticker widget and
the S-242 sort test's `find.text('SOFI')` keeps matching exactly one widget.
The obligation (`$4,200 cash if assigned`) is a separate, right-aligned
`Text`, matching the reference's `kv` row.

`LegTitle` is shared by both cards and lives in `lib/widgets/` (the
conventions' shared-UI layer) rather than being duplicated; it takes a ticker
string and a `Leg`, so it imports nothing from `lib/state/`.

**Reviewer:** ratify.

### A-31 — `expiringThisWeek` is a state type, not a call into the rules layer at render time (Phase 10)

`TodayState.expiringThisWeek` is a `List<ExpiringDateGroup>` built in `load()`
by mapping `obligation.expiringThisWeek`'s own grouping back to the
`TodayItem`s already built — the seven-day window and the date order stay
stated once, in the rules layer, and the card re-reads no repository and
re-derives no window. The group's date is rebuilt as a local
`DateTime(y, m, d)` from the rules layer's UTC-keyed group, so it compares
equal to the leg's own stored expiration date (which is what the tests assert
and what `shortWeekdayDateText` renders).

`TodayItem` gained `batchEligible` (computed once per leg in `load()`) and a
`cardEntry` getter that wraps it back into the rules layer's
`ExpiryCardEntry`, so the card's copy builders are callable without the widget
knowing how eligibility is decided.

**Reviewer:** ratify.

### A-32 — four files landed outside Phase 10's Predicted Files (Phase 10)

The plan predicted `expiring_this_week_card.dart`,
`past_expiration_card.dart`, `today_screen.dart`,
`today_controller.dart` and `position_detail_sheet.dart`. Four more were
touched, each for a reason the plan's own rules require:

1. `lib/domain/rules/expiry.dart` — the card's copy builders had to live
   somewhere; the rules layer is the only place both the card and its
   confirm dialog can read one string (A-25).
2. `lib/core/format.dart` — `shortWeekdayDateText` (`Fri Oct 2`, no comma —
   a different shape from the existing `weekdayDateText`) and
   `legContractText`; both are display-only and both are used by more than
   one file, so per the conventions they belong in `lib/core/`.
3. `lib/state/positions/position_detail_controller.dart` — S-253 requires the
   detail sheet's own "Mark expired" to record the expiration date rather
   than the tap date. The sheet called `closeDirect` directly; a controller
   method (`markExpired`) is what makes that one behaviour reachable from the
   sheet without the sheet holding the rule. `_confirmMarkExpired` now calls
   it, so the sheet's orchestration shrank rather than grew.
4. `lib/widgets/leg_title.dart` — the two cards render the identical
   ticker + contract row; the conventions' "repeated UI → shared layer" rule
   makes a shared `LegTitle` mandatory rather than optional.

A single combined `lib/features/today/expiry_cards.dart` was written first
and then deleted in favour of the plan's two files, once the batch action
needed a stateful widget and the two cards stopped sharing a body.

**Reviewer:** ratify.

## Feedback

*(empty — the only trigger to re-invoke the planner: a D-x contradiction, a
scope change, or an assumption the reviewer cannot adjudicate.)*
