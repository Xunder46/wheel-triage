# Feature: Pro Wave 3 — Portfolio and assignment calendar (Stage 7), and the share card (Stage 8)

> Status: **CLOSED** — all six phases complete
> Next handoff: none (wave closed)
> Binding conventions: `docs/conventions.md` (+ `docs/architecture/wheel-triage.md`, `docs/brief-pro.md` §2/§4)
> Supersedes: nothing. Wave 2 (`docs/plans/pro-wave-2-plan.md`) is closed at D-38 / S-289; this
> plan continues both registers from D-39 and S-290.

## Overview

Wave 3 of the Pro release adds the two stages that turn the app from a triage tool into
something a user opens when they are not triaging:

- **Stage 7 — Portfolio and assignment calendar (Pro).** One screen that answers "how much
  of my wheel capital is committed right now, to whom, how directional am I, and what comes
  due when". It reuses Stage 3's capital and concentration arithmetic and Wave 1's bucket
  classification rather than re-deriving either, adds signed net position delta across the
  book, and adds a month calendar of expirations carrying the obligation at each date.
- **Stage 8 — Share card (free).** One exported image of the month's closed cycles: five
  descriptive figures, dollars hidden unless the user turns them on, shared through the share
  sheet the app already has.

**Stage 6 (screenshot scan) is deliberately out of this wave.** Its two prerequisites are not
in place: the owner must name the broker it targets (D-P10), and its 95%-accuracy acceptance
criterion cannot be verified without 20+ real screenshots to use as fixtures. Planning it
blind would produce a plan whose central criterion is untestable. Nothing in this wave
designs its parsing, and nothing here adds an abstraction "ready for" it. The paywall's
feature list already promises "Screenshot scan"; after this wave that is the only promise on
that list that is not yet true, and it stays outstanding for Wave 4 unchanged (D-39).

Also out, and unchanged from the Wave 1/2 scope: Stage 4B (accessibility audit, haptics,
contrast work), the Android build and store listing (D-P9), broker CSV import (Stage 10),
and every permanently out-of-scope item in the working agreement.

**No schema change and no new dependency.** The schema stays at **v6**; both new surfaces are
read-only views over data the app already stores, and the one piece of new UI state (the
share card's two toggles) is session state, not a preference (D-52). The image is produced by
`dart:ui`'s own `toImage` and handed to `share_plus`, which is already declared (D-53).

Wave 3's own risk, in order: (1) the image capture — the only genuinely new technique in the
wave, and the reason Phase 2/3 are sequenced before Phase 4/5; (2) the signed-delta
conversion, which is the app's historical bug magnet and gets all four sign quadrants as
tests; (3) the capital figure drifting away from Today's, which the shared-implementation
decisions (D-42, D-45, D-46) and their cross-screen scenarios exist to prevent.

## Resolved Decisions (Ledger)

Entries are immutable once written. A change is a new superseding entry ("D-60 supersedes
D-46"), never an edit.

### D-39 — Wave scope *(derived from the brief — vetoable)*

This wave is Stage 7 and Stage 8, in that order of importance but not of execution (see
Notes). It includes:

- `/portfolio`, a Pro screen reusing Stage 3's capital and concentration calculations and
  Wave 1's bucket classification, plus signed net position delta and a month calendar of
  expirations.
- The share card: a fixed-size image of the month's closed cycles, exported through the
  existing share sheet.

It excludes, permanently or until a later wave: Stage 6 (screenshot scan), Stage 4B,
D-P9's Android build, the store listing, Stage 10, portfolio month navigation, a share-card
month picker, and any schema change. Reasons for the Stage 6 exclusion are in the Overview.

### D-40 — The Portfolio route and its one gate

**Route.** `GoRoute(path: '/portfolio')`, a top-level route in `lib/core/app_router.dart`,
pushed (not `go`-ed) from Today so Today stays alive underneath — the same behaviour
`AppBottomNav` uses for non-Today destinations (S-205). `initialLocation` is unchanged.

**Entry point.** Today's ledger strip, on the **"Committed now" tile**, which gains an
`onTap`. The other two tiles stay inert. The tile's figure, its definition line and the
concentration flags are unchanged for every user, free or Pro — the tap opens a *new* Pro
surface, it does not gate an existing free one. (Wave 2's Q8 decided that Today's
concentration line is not a paywall entry point; that decision stands, because the line
itself stays free and complete. What is new here is the tap target, which is the
"tapping a Pro feature" trigger Wave 2 D-30 defined.)

**The decision lives in the state layer, once.** New file
`lib/state/entitlements/pro_feature_gate.dart`, shaped exactly like
`lib/state/entitlements/new_cycle_gate.dart`:

```dart
sealed class ProFeatureAccess { const ProFeatureAccess(); }

final class ProFeatureOpen extends ProFeatureAccess { ... }

final class ProFeatureLocked extends ProFeatureAccess {
  const ProFeatureLocked({required this.feature, required this.line});
  final String feature;   // 'Portfolio'
  final String line;      // proFeatureLine(feature)
}

class ProFeatureGate {
  ProFeatureGate(this._ref);
  final Ref _ref;

  ProFeatureAccess evaluate(String feature) {
    final active = _ref.read(entitlementControllerProvider).isActive;
    if (active) return const ProFeatureOpen();
    return ProFeatureLocked(feature: feature, line: proFeatureLine(feature));
  }
}

ProFeatureAccess proFeatureGate(Ref ref) => ProFeatureGate(ref).evaluate;  // or a thin wrapper
```

- `ProFeatureOpen`/`ProFeatureLocked` are the only two outcomes. `inactive` **and** `unknown`
  both lock, matching D-26 — Pro is never forged from a store that has not answered.
- The locked variant carries **both** the feature name and the finished line, so the calling
  screen never names the feature twice and never builds copy. The caller passes
  `access.feature` straight into `ProFeaturePaywallTrigger`, whose own constructor calls
  `proFeatureLine` — so the sentence is built by the paywall module and the gate's `line`
  exists for tests and for any future inline rendering.
- `proFeatureGateProvider` lives in `lib/state/entitlements/entitlement_providers.dart`,
  beside `newCycleGateProvider`, for the same reason Wave 2 put it there: the whole
  entitlement story is reachable from one import.
- `kPortfolioFeatureName = 'Portfolio'` lives in `lib/core/purchases/paywall_copy.dart`,
  beside `proFeatureLine`. The rendered line is therefore exactly
  `Portfolio is part of Pro. Everything you've already recorded stays available on every plan.`
- **No widget** reads `purchaseGatewayProvider`, `entitlementControllerProvider.isActive`,
  or RevenueCat. The screen reads `ProFeatureGate`'s verdict and, when locked, calls
  `showPaywall(context, trigger: ProFeaturePaywallTrigger(access.feature))` — which makes
  `lib/features/today/today_screen.dart` the fourth `showPaywall(` call site and changes
  S-277's pinned file list. That change is the point of the guard, not a bypass of it.
- The paywall never opens on launch, and never opens from a route builder.

### D-41 — Nothing already recorded ever locks, and neither new surface writes

Extends Wave 2's Invariant 5. Portfolio and the share card are **read-only**: neither calls a
write method on `WheelRepository`, and the only new UI state in the wave (the card's two
toggles, D-52) is session state. A lapsed subscription therefore costs the user the *view*
and nothing else — every leg, cycle, snapshot and fee stays exactly where it was, Today keeps
working unchanged, and the paywall's own sentence ("Everything you've already recorded stays
available on every plan") is literally true.

Both surfaces must come back the instant the entitlement does, without a manual reload: the
screens read the entitlement through the same `entitlementControllerProvider` every other
Pro surface reads, and Wave 2's router-delegate listener (S-265) already handles the
"entitlement changed while a screen was open" case. Tested by S-292.

### D-42 — Capital committed and concentration reuse Stage 3's implementation; the bars are a second *render*, not a second calculation

The Portfolio card's figures come from the shipped functions, unmodified:

| Figure | Function (unchanged) |
|---|---|
| the big committed total | `capital_committed.currentCapitalCommitted` |
| per-underlying committed | `capital_committed.capitalCommittedByUnderlying` |
| the total's percentage of wheel capital | `capital_committed.concentrationPercent` |
| which underlyings breach the limit | `capital_committed.concentrationFlags` |
| the flag sentence | `capital_committed.concentrationFlagLine` |
| the definition sentence | `capital_committed.committedNowDefinition` |
| the no-wheel-capital invitation | `capital_committed.kConcentrationInviteLine` |

Three **additive** helpers go in `lib/domain/rules/capital_committed.dart`, used by Portfolio
and by nothing else:

```dart
/// The bar track's right-hand edge, as a percentage. limit × 1.2, so the default
/// limit of 25% produces a track that reads "bars run to 30%".
double concentrationTrackMaxPct(double concentrationLimitPct);

/// Every underlying with a committed figure greater than zero, each with its exact
/// Decimal capital and its rounded whole percent, ordered EXACTLY as
/// concentrationFlags orders its flags: rounded percent descending, ties by ticker A–Z.
List<({String ticker, Decimal committed, int percent})> concentrationBars({
  required Map<String, Decimal> capitalByUnderlying,
  required Decimal? wheelCapital,
  required double concentrationLimitPct,
});

/// committedNowDefinition(...) plus, when any past-expiration leg contributes,
/// " Includes A and B, past expiration and not yet recorded."
String portfolioCommittedDefinition({
  required Decimal committedNow,
  required Decimal? wheelCapital,
  required List<String> pastExpirationTickers,
});
```

The two signatures deliberately mirror `concentrationFlags`' own
(`required Map<String, Decimal> capitalByUnderlying, required Decimal? wheelCapital,
required double concentrationLimitPct`), so a caller that already has the arguments for one
has them for the other and the two cannot be fed different limits. The limit is a `double`
everywhere it is compared (`concentrationLimitPct`, `ConcentrationFlag.limitPct`) because the
preference stores it that way; it is a `Decimal` only inside the comparison itself, exactly as
`concentrationFlags` already does.

Rules that bite:

- **Underlyings at exactly zero are omitted from the bars but still counted in the total.**
  `capitalCommittedByUnderlying` returns every ticker including zeros; the bars are a visual
  ranking, so a zero is not a row. The total never drops them, because they contribute zero.
- **A bar's fill is its *unrounded* ratio over the track max**, so a book sitting at 24.999%
  fills 83.33% of the track and does not cross the limit mark. The fill and the mark cannot
  disagree about which is larger, which they would if the fill used the rounded whole percent.
- **The limit mark sits at `limitPct ÷ trackMaxPct` of the track** — 25/30 = 83.3% by default.
- **The key line** is `Limit 25% · bars run to 30%`, built from the limit and the track max
  through the file's existing private `_trimmedPct`, so `25.0` renders as `25%` and the two
  numbers in one sentence cannot drift apart.
- **No wheel capital set** → no bars, no percentages, no limit key, no flag line. The card
  lists per-underlying **dollars** descending (the only thing that is knowable) and shows the
  shipped `kConcentrationInviteLine`. This is the same degradation Today already has.
- **Past-expiration legs are included**, as `currentCapitalCommitted` has always included them
  (Wave 1's decision; OC-3). The definition sentence names them, tickers A–Z through
  `listPhrase` (D-43's helper): `Includes AAL and WBD, past expiration and not yet recorded.`
- The **sub-line** under the big figure is hand-built from `wholeDollars(committedNow)` and
  `concentrationPercent`, in the reference's own casing:
  `committed now · 83% of $30,000 wheel capital`.

`kCommittedNowDefinitionLine` and `committedNowDefinition` are **not forked**, not re-worded
and not duplicated into Portfolio. If the wording changes, both screens change together.

### D-43 — Net position delta: the conversion, the exclusions, the display

New pure rules file `lib/domain/rules/position_delta.dart`:

```
positionDelta(snapshot) =
    snapshot.deltaConvention == DeltaConvention.position
      ? snapshot.deltaAsEntered
      : -snapshot.deltaAsEntered          // option convention: the option's own sign

legShares(leg, latestSnapshot) = positionDelta(latestSnapshot) × 100 × leg.contracts
sharesHeld(cycle, lot)         = cycle.status == holdingShares ? lot.contracts × 100 : 0

netPositionDelta(book) = Σ legShares over INCLUDED legs
                       + Σ sharesHeld over the book's holdingShares cycles
```

- **The conversion, and why it is a sign flip.** A short leg's *position* delta is `+` for a
  put and `−` for a call. The *contract* convention records the option's own delta, which is
  `−` for a put and `+` for a call. For a short leg these are exact negations. The app models
  **one short leg at a time and no spreads** (`leg.dart`), so the negation is the whole
  conversion and no other case exists. This is the app's own help copy's claim
  (`help_topics.dart`, `delta_convention`): "Bucketing uses the absolute value either way;
  this only affects the portfolio exposure total."
- **The convention is read from the snapshot, never from Settings.** `deltaConvention` is
  stored per snapshot (conventions §3), so flipping the Settings default never silently
  reinterprets history.
- **INCLUDED**: `closedAt == null` **and** not past expiration
  (`expiry.isPastExpiration(leg, now)` is false) **and** a latest snapshot exists with a
  non-null `deltaAsEntered`. Everything else is **excluded and named**.
- **Exclusion reasons are evaluated in this order: past expiration first, then no reading.**
  A leg that is both is named **once**, under past expiration — that is the actionable list
  (the leg needs recording), whereas "no reading" on a leg that has already expired is not.
  A reason with no members renders no line at all.
- **The "Left out" line**: `Left out: PFE (no reading); WBD, AAL (past expiration)` — one
  clause per non-empty reason, tickers A–Z within a clause, reasons in the order above,
  clauses separated by `; `. When everything is included, the line is absent.
- **The aging note reuses `reading_age.agingLine` verbatim** — see D-44.
- **The total is a `double`** (delta is dimensionless, conventions §2). It reaches no gate, no
  money value, no persisted field and no repository method. Gates continue to read
  `formulas.deltaMagnitude` only; **no signed value is introduced upstream of a magnitude
  calculation**.
- **Display**: whole shares, halves away from zero, an explicit `+` for a positive total and
  `−` for a negative one; a total of zero renders `0 shares` with no sign. Formatting lives in
  `lib/core/format.dart` as `signedSharesText(double?)`, converting through
  `Decimal.parse(value.toString()).round()` exactly as `whole_dollars.dart` does, so the
  half-up rule is the app's one rule and not a second one.
- **Shares held are counted from the share lot**, not from the call leg: a covered-call cycle
  contributes its 100 × contracts shares and its short call's negative delta, which is the
  honest picture of a covered call.

New shared helper `lib/domain/rules/listing.dart`:

```dart
String listPhrase(List<String> items);   // 'A' | 'A and B' | 'A, B and C'
```

Used by the "Left out" line and by D-42's past-expiration sentence. `listing.dart` also gets
`listPhraseWithReason(List<String> tickers, String reason)` → `A, B (reason)`, so the two
callers cannot format the same shape two ways.

### D-44 — The aging note on Portfolio is Today's own string

Portfolio renders `reading_age.agingLine({legs, now})` **verbatim** over the same population
Today passes it — the live legs that have a snapshot — giving
`1 reading older than 7 days · T, from Sep 17`; `test/features/portfolio/portfolio_screen_test.dart`'s
S-302 case pins the two screens to that one string.

The population is identical to Today's by construction — Today adds to its aging list exactly
the live legs that have a snapshot (`today_controller.dart`'s `load`), and D-43's included set
is the same set — so the two screens cannot disagree, and there is one wording for one fact.

The reference's `Uses 1 reading older than 7 days: T, Sep 17` is **not** adopted. *(Vetoable:
adopting it means a second string for the same fact, which the architecture doc's drift-risk
table would then have to track forever.)*

`kAgingDays = 7` is **not** re-declared anywhere. Portfolio imports the constant; it does not
restate it.

### D-45 — The calendar's month, and the fallback

```dart
/// The calendar month the Portfolio calendar opens on.
DateTime calendarMonth({required DateTime now, required Iterable<Leg> openLegs}) =>
    // the calendar month containing the EARLIEST expiration among open legs whose
    // expiration is on or after today's calendar date;
    // otherwise the calendar month containing today.
```

- With today = Mon Sep 28 2026 and the next expiration Fri Oct 2, the calendar shows
  **October 2026**, and today falls in the greyed leading band. That is the reference's own
  case and it is the case S-299 pins.
- **No month navigation this wave.** Stage 7's criterion is one month with the obligation at
  each date; navigation is a product choice, not a mechanic, so it is an owner question (Q2).
- **The grid**: Sunday-first, seven columns. Every cell is a date; the cells before the first
  of the month and after the last are the neighbouring months' days, rendered muted, so every
  row is full. A leading day that happens to be today is **still outlined**.
- **Marked days**: every day **in the shown month** with at least one included leg expiring on
  it. A day outside the shown month is never marked, even when it is today.
- **Obligation rows**: one row per date in the shown month that has an included leg, ascending.
  Each leg on its own line:

  ```
  <ticker> <legContractText(leg)> · <obligationFor(leg).text>
  ```

  which renders `SOFI $14 put ×3 · $4,200 cash if assigned` and
  `T $28 call ×1 · 100 shares delivered at $28 if assigned`. Both halves are the shipped
  helpers (`format.legContractText`, `obligation.obligationFor`); no new formatter and no
  second obligation sentence exists. The reference's shorter call line
  (`100 shares delivered at $28`, without `if assigned`) is **superseded** — the shipped
  sentence is the one the Today card already shows.
- **Included legs** are `closedAt == null` **and** `expiration >= today` (calendar-date
  comparison through the same `daysBetween` the rest of the app uses, so a leg expiring today
  is included). Past-expiration legs are Today's card's job (Wave 1 D-13) and never appear
  here — even though the committed-capital figure above them *does* count them. The two
  surfaces answer different questions, and the calendar says which by naming today onward.
- The month grouping lives in `lib/domain/rules/obligation.dart`, beside `expiringThisWeek`,
  as `List<ExpiringGroup> expirationsInMonth({required Iterable<Leg> legs, required DateTime month, required DateTime now})`,
  reusing the existing `ExpiringGroup` record type and `obligationFor`.

### D-46 — The five bucket counts come from one shared source

`lib/domain/rules/bucket.dart` gains:

```dart
/// Assign, Roll, Close, Leave, No data. Wave 1's order (D-14 / OC-1).
const List<Bucket> kBucketOrder = <Bucket>[
  BucketAssign(), BucketRoll(), BucketClose(), BucketLeave(), BucketUnknown(),
];

/// One entry per bucket in kBucketOrder, including zeros.
List<({Bucket bucket, int count})> bucketCountsFor(Iterable<Bucket> buckets);
```

and `lib/state/today/today_controller.dart`'s private `_bucketOrder` (line 97) is **deleted**
in favour of them, with `TodayState.bucketCounts` delegating to `bucketCountsFor`.

- Order is Assign, Roll, Close, Leave, No data.
- **"No data" is its own count and its own tile**, never folded into another bucket
  (Feature Invariant 19).
- Each leg is classified under **its own pinned `ruleProfileVersionId`**, the Wave 1 D-7/D-8
  and Iteration 5 D-5 rule, so editing `Standard` never reclassifies an open position. A
  dangling pin degrades to `RuleProfile.standard`, exactly as Today does.
- **No widget extraction.** The reference renders the two count rows differently on purpose:
  Today's are filters over the ledger, Portfolio's are read-only tiles. What must be shared is
  the *order* and the *count*, and those are shared in `bucket.dart`. A widget test asserts
  both screens show the same five labels in the same order — the assertion is the guard, not a
  shared widget.

### D-47 — A cycle is in the share card's month by its end date *(pins OC-7's second half)*

```dart
final period = premium_collected.monthPeriodContaining(now);   // (first, last) of the month

bool inCardMonth(WheelCycle cycle) =>
    cycle.status == WheelCycleStatus.closed &&
    cycle.endedAt != null &&
    premium_collected.inPeriod(cycle.endedAt!, period.start, period.end);
```

- **Inclusive on both ends**, UTC-normalized through the same `daysBetween` the premium sum
  uses, so a cycle closed on the 1st and one closed on the month's last day are both in, and
  one closed on the previous month's last day is out. A roll that spans the boundary lands in
  the month its final leg closed — the cycle, not the leg, is the unit.
- **A `closed` cycle with a null `endedAt` is in no month.** The month is defined by the end
  date and there is no second date to fall back to; guessing `startedAt` would put a cycle on
  a card for a month in which nothing was closed. Tested (S-305), never guessed.
- **The month is the one containing `now`** — the same period Today's "Net premium · month"
  tile uses, so the strip and the card agree about which month "this month" is.
- `premium_collected.dart`'s private `_inPeriod` becomes a public `inPeriod` so the card and
  the premium sum share **one** containment rule. Its one existing caller is updated; the
  behaviour is identical.

### D-48 — The month's return on capital is the sum over the sum *(pins OC-7's first half)*

```
returnOnCapital(
  netResult:            Σ cycle.netResult            over the month's cycles,
  peakCapitalCommitted: Σ cycle.peakCapitalCommitted over the month's cycles,
)
```

`cycle_pnl.dart`'s own function, called **once on the totals** — not an average of per-cycle
percentages, which would weight a small cycle equally with a large one.

Reference arithmetic, which the fixture in S-306 reproduces exactly:
`(32 + 35 − 30 + 110 + 210) ÷ (3,800 + 6,250 + 4,000 + 7,000 + 1,800) = 357 ÷ 22,850 = 1.6%`.

- Both sums are `Decimal`. The division and the `double` live inside `returnOnCapital`, which
  is display-only and reaches no gate (conventions §2). Money never becomes a `double` on the
  way in.
- `returnOnCapital`'s own zero-denominator guard applies unchanged, so a month whose cycles
  all have zero peak capital reads `0.0%`, never `NaN` and never `∞`.
- Displayed to **one decimal place** (`1.6%`) through a new `format.percentText(double?, {decimals = 1})`,
  matching the Journal's own one-decimal rendering of `returnOnCapitalPct`
  (`lib/widgets/journal_row.dart:47`). The card is the only place a *monthly* return appears,
  so one decimal is what keeps 1.4% and 0.6% distinguishable. *(Vetoable: a whole percent
  would match the reference's other four figures.)*
- The numerator and denominator are **before fees**, exactly as `CyclePnl.netResult` is, and
  the card says so when there is a gap (D-50).

### D-49 — The card's five figures, exactly

Over the month's cycles (D-47):

| Figure | Value | Source |
|---|---|---|
| Return on capital | D-48, one decimal | `cycle_pnl.returnOnCapital` on the two sums |
| Cycles closed | the count | the month's cycle list |
| Closed positive | `N of M` | `N` = cycles with `netResult > 0` **strictly**; `M` = the count |
| Average days in cycle | whole days, half-up | `journal_aggregates.averageDaysInCycle` over the cycles' `daysHeld` |
| Median premium capture | whole percent | `journal_aggregates.medianPremiumCapturePct` over **all legs of the month's cycles** |

- **`netResult > 0` is strict**, so a cycle that closed at exactly zero is not "positive" —
  the same rule `winRate` already uses (`journal_aggregates.dart`). The card therefore cannot
  report `4 of 5` while the Journal's win rate says otherwise for the same set.
- **Median, never mean** for premium capture (Feature Invariant 29, Wave 1's own rule). The
  leg population is **every leg of the month's cycles**, which is exactly the Journal's
  `allClosedLegs` set (`journal_controller.dart:152`), so the two agree.
- **All five figures are the same size on the card**, so none reads as the headline — the same
  rule the "Sorting score" note exists to enforce for the screener.
- A figure with **no computable value** (a month whose legs carry no capture at all) renders
  `--`, never `0%` and never `0`. A zero would be a claim; `--` is the absence of one.

### D-50 — "Before fees" appears only when there is a gap *(pins `brief-ledger.md` §4.3)*

```
gapCount = Σ cycle.feeGapCount over the month's cycles          // cycle_pnl.dart
hasGap   = any cycle in the month has hasFeeGap true
clause   = hasGap
             ? ' Before fees: $gapCount closed legs have no fee recorded.'      // n > 1
             : ''                                                                 // n == 1 -> 'leg has'
```

- The clause is appended to the **definition paragraph** (D-51) and, when the dollars toggle
  is on, to the **net-result line** (D-52).
- With no gap the clause is **absent** — not "Fees included", which would be a claim the app
  has not verified for every leg in the month.
- Singular/plural is handled: `1 closed leg has no fee recorded`.
- `hasFeeGap` is true iff a **closed** leg lacks `closeFee`; `feeGapCount` counts those legs.
  Both are shipped and unchanged.

### D-51 — The card's definition paragraph, verbatim

```
'Return on capital: net result ÷ peak capital committed, over cycles closed in '
    '<Month Year>.' + clause
```

rendering `Return on capital: net result ÷ peak capital committed, over cycles closed in
September 2026. Before fees: 3 closed legs have no fee recorded.`

- It states the definition **on the card**, as Stage 8 requires, and names the month so a
  shared image is unambiguous a year later.
- It names no security, pairs no action verb with anything, and contains no banned word
  (conventions §4).
- `<Month Year>` comes from a new `format.monthYearText(DateTime)` → `September 2026`, which
  the calendar header uses too. There is currently no full-month formatter in
  `lib/core/format.dart` (only `monthAbbreviation`), and `intl`'s `DateFormat` is not used
  anywhere for display, so the helper is hand-rolled beside `_months`, matching the file.

### D-52 — The card's toggles are session state, not preferences

- Two toggles: `Show dollar amounts` and `Show tickers`. **Both off by default.**
- **They reset to off every time the screen opens.** They are not persisted, so this wave adds
  **no schema version** (the schema stays v6), no export/import change and no preference key.
  The privacy-safe default is then true by construction rather than by a stored flag a user
  could flip once and forget — which matters because the whole point of the default is what
  happens to an image someone else might see.
- `Show dollar amounts` on adds one line under the definition paragraph:
  `Net result $357.00 before fees` — two decimals through `format.moneyText`, plus D-50's
  clause when a gap exists. Two decimals because this is a row, not a tile (OC-12's rule,
  which is also why the five figures are whole).
- `Show tickers` on adds one line: the month's tickers, **deduplicated and A–Z**, joined by
  ` · ` → `BAC · CCL · KO · SNAP · UBER`. The ticker list is derived from the month's cycles'
  legs; it is never a stored list.
- **Neither toggle changes any of the five figures and neither changes the image's size.**

### D-53 — The image is 1080 × 1350 and goes through the existing share sheet

- **Fixed output 1080 × 1350 (4:5).** The card widget lays out at a fixed logical
  **360 × 450** and is captured at `pixelRatio: 3`.
- **One widget tree serves both the preview and the export**, so the image cannot drift from
  what the user saw. `RepaintBoundary` + `toImage` is the named approach; the exact capture
  wiring (key ownership, awaiting the first frame, disposing the image) is the implementer's
  choice, but the **observable contract is pinned**: the produced PNG decodes to exactly
  1080 × 1350 and its content is the card the screen previewed. A test decodes the PNG and
  asserts the dimensions (S-309).
- **No new dependency.** `toImage` is `dart:ui`; `share_plus` is already declared
  (`pubspec.yaml`, `share_plus ^13.3.0`). No new seam either: the bytes go to
  `ShareSheet.shareFiles` through `shareSheetProvider`
  (`lib/state/export/export_controller.dart`) — the same seam Settings' export already uses —
  as `XFile.fromData(bytes, mimeType: 'image/png', path: 'wheel-triage-<yyyy-MM>-ledger.png')`,
  exactly the `buildExportFiles()` precedent. Subject: `Wheel Triage — <Month Year> ledger`.
- **The card carries no timestamp, no device name, no account identifier and no app version**,
  so two exports of the same month produce byte-identical images (S-309). Nothing but the
  image the user chose to share leaves the device; no network call exists in this wave
  (conventions §5).
- **Correct in both themes**: the card draws its colours from `Theme.of(context)` /
  `AppTokens` and uses **no colour literal outside `lib/core/theme/`** (the standing grep must
  stay empty). Two goldens — `share_card_light.png`, `share_card_dark.png` — in
  `test/features/goldens/`, rendered at the fixed logical size, plus a test that renders the
  card under `AppTheme.light` and `AppTheme.dark` and asserts the same content.

### D-54 — The card's copy is descriptive only, and the footer carries D-P15 verbatim

- **No streaks, no badges, no praise, no comparison** — not to another month, not to another
  person, not to a benchmark. The five figures are descriptive statistics and the only
  sentence on the card is the definition paragraph (D-51). There is no "great month", no
  "keep it up", no emoji.
- **The footer is `lib/core/disclaimer.dart`'s `kAppDisclaimer` rendered verbatim** — the same
  constant Settings and the first-run explainer already render, pinned character-for-character
  by S-249. It names the app in its first three words, contains D-P15's "journal and
  calculator" wording and its "It is not investment advice." sentence, and is the app's one
  disclaimer. The card's own header also names the app (`Wheel Triage` / `Monthly ledger`).
- The reference's shorter footer
  (`Wheel Triage · a journal and calculator for the wheel strategy · not investment advice`)
  is **not** adopted, because the app would then hold two wordings of its own disclaimer and
  the brief asks for D-P15 verbatim. *(Vetoable — owner question Q4.)*

### D-55 — The empty month

A month with no closed cycles renders the screen's empty state
(`No cycles closed in <Month Year>`) and **no card**, so there is **no share button**: a card
of five dashes is noise, and an image of nothing is not worth sending to anyone. The screen
still names the month it is about, so the user knows why it is empty.

*(Vetoable: rendering the card with `--` figures and a working share button is the
alternative. The plan takes the stronger reading — nothing misleading is shareable.)*

### D-56 — The card's footer scales rather than overflows *(promoted from A-18)*

The card is a fixed 360 × 450 surface (D-53) and its footer is `kAppDisclaimer` verbatim
(D-54), which is ~300 characters. At the test environment's font — every glyph a square, so
text is far wider than real — the disclaimer alone measures 260px tall and the definition
line 140px, which overflows the fixed surface.

- **The footer is a `Flexible` wrapping a `FittedBox(fit: BoxFit.scaleDown)`**, so the two
  paragraphs shrink to fit rather than overflowing the surface or being clipped. It is a
  no-op at real font sizes and degrades by shrinking at large text scales.
- The alternatives are rejected: letting the card grow breaks the 1080 × 1350 export contract
  (D-53), and clipping the footer loses the disclaimer (D-54).
- A render-time transform in service of two rules is a decision, not an implementation
  detail, which is why this is numbered rather than left in the Assumption Log (review
  finding 14).

### D-57 — Deliberately not in this wave

Stage 6 (screenshot scan — no parser, no capture pipeline, no ML Kit, no abstraction for it),
Stage 4B (accessibility audit, haptics, contrast pass), D-P9's Android build, the store
listing, Stage 10 (broker CSV import), Portfolio month navigation, a share-card month picker,
persisting the card's toggles, a second share path, a portfolio export, and any change to the
schema (**v6 stays v6** — no table, column, seed or artifact changes; no v7).

Nothing in this wave adds a dependency, a network call, an analytics or crash SDK, an ad, a
social feature, wash-sale detection, tax-lot matching, or a multi-leg/spread concept.

## Feature Invariants

Only the invariants that *bite* in this wave. Project-wide rules live in
`docs/conventions.md` and are referenced, not copied.

1. **`lib/domain/rules/` stays pure Dart with zero Flutter imports, permanently.** Checked on
   every phase that touches it, not once:
   `grep -rl "package:flutter" lib/domain/rules/` returns nothing.
2. **No `double` for money, ever.** The only `double`s this wave adds are dimensionless:
   a snapshot's delta, a percentage, a day count. **None reaches a gate**, and the two money
   sums behind the month's return stay `Decimal` until `returnOnCapital` divides them.
3. **Gates read `deltaMagnitude` only.** The signed value is read by exactly one new
   calculation (D-43) and is never introduced upstream of a magnitude comparison.
   `TriageInput` and `formulas.deltaMagnitude` are untouched by this wave.
4. **One implementation, two views.** Portfolio's capital, concentration, per-underlying and
   bucket-count figures call Stage 3's and Wave 1's functions. If a number appears on both
   Today and Portfolio it is computed once. A cross-screen scenario (S-293, S-302) is the
   guard, not review.
5. **Nothing already recorded ever locks** (extends Wave 2 Invariant 5). Both new surfaces are
   read-only; a lapse costs the view, never data.
6. **The entitlement is read in exactly one place.** `EntitlementController` is the only
   reader of `purchaseGatewayProvider` (Wave 2 D-28); `ProFeatureGate` is a *consumer* of
   `EntitlementController`, never a second source, and no widget asks either the gateway or
   the SDK. One `showPaywall(` call site is added and it is the only new one.
7. **Repository parity is structural.** This wave adds **no** `WheelRepository` method, so
   parity is preserved trivially. If a phase finds it needs one, it ships in **both**
   implementations in the same change with contract coverage — never `UnimplementedError`.
8. **Tone is enforced, not reviewed.** No banned word in any new string, and no sentence pairs
   an action verb with a named security or with the user's own position. The card's copy is
   the wave's highest-risk new copy and gets a **unit test**, not only the grep.
9. **The card carries no money unless the user turned it on, and no identifier of any kind.**
   Dollars are off by default; there is no timestamp, device name or account reference
   anywhere on the card.
10. **Every number on a new screen carries a semantics label naming its quantity**
    (conventions §9): the committed total, the delta total, each bar, each date's obligation,
    each count tile, each of the card's five figures and the card itself.
11. **The colour-literal grep stays empty outside `lib/core/theme/`.** The card is rendered in
    two themes from the same widget, so this is a real risk here rather than a formality.
12. **No network, at all.** Neither new surface has a network user. The only thing that leaves
    the device is the image the user chose to share, through the OS share sheet.

## Requirements

Each requirement maps to at least one scenario. "§4" refers to `docs/brief-pro.md` §4.

| # | Requirement | Source | Scenarios |
|---|---|---|---|
| R1 | Current capital committed is shown as a total and per underlying, against wheel capital and the D-P6 concentration limit, **reusing Stage 3's one implementation** | §4 Stage 7 | S-293, S-294, S-295 |
| R2 | Net position delta is shown in share equivalents, from **signed position delta** using each snapshot's own stored `deltaConvention`, plus shares held | §4 Stage 7 | S-296 |
| R3 | All four sign quadrants are tested | §4 Stage 7 | S-296 |
| R4 | Readings older than 7 days (D-P11) are labelled with their date | §4 Stage 7 | S-298 |
| R5 | Positions with no reading are excluded from the total and counted beside it | §4 Stage 7 | S-297 |
| R6 | A month calendar of expirations shows the obligation at each date | §4 Stage 7 | S-299, S-300, S-301, S-303 |
| R7 | The bucket summary reports "No data" separately | §4 Stage 7 | S-302 |
| R8 | Portfolio is gated through the one entitlement place, never in a widget; a free user gets the Pro-feature paywall trigger; **nothing already recorded ever locks** | §4 Stage 7, D-P2 | S-290, S-291, S-292 |
| R9 | A monthly summary image is built from the month's closed cycles | §4 Stage 8 | S-305, S-306 |
| R10 | The five figures: return on capital, cycles closed, cycles closed positive, average days in cycle, **median** premium capture | §4 Stage 8 | S-306 |
| R11 | The return-on-capital **definition** is printed on the card | §4 Stage 8 | S-306, S-312 |
| R12 | "Before fees" appears when any cycle in the month lacks fee data | `brief-ledger.md` §4.3 | S-307 |
| R13 | Median premium capture, never a mean (Feature Invariant 29) | conventions / Wave 1 | S-306 |
| R14 | Dollar amounts are hidden by default, with toggles for dollars and tickers | §4 Stage 8 | S-308 |
| R15 | The card is shared as a fixed-size image through the existing share sheet and is correct in both themes | §4 Stage 8 | S-309, S-310 |
| R16 | Descriptive statistics only — no streaks, badges or praise | §4 Stage 8, conventions §4 | S-312 |
| R17 | The footer names the app and carries D-P15's disclaimer verbatim | §4 Stage 8, D-P15 | S-312 |
| R18 | The month's return on capital is `Σ net result ÷ Σ peak capital committed` over the month's cycles, before fees | D-48 (pins OC-7) | S-306 |
| R19 | A cycle belongs to a month by its **end date**, inclusive both ends; a closed cycle with no end date belongs to no month | D-47 (pins OC-7) | S-305 |
| R20 | The calendar opens on the month of the next upcoming expiration, falling back to the month containing today | D-45 | S-299, S-301 |
| R21 | The five bucket counts and their order come from one shared source, and an edited profile never reclassifies an open position | D-46 | S-302 |
| R22 | No schema change, no new dependency, no network | D-39, D-52, D-53 | S-305 (assertion), P6 residue sweep |

## Existing-Functionality Impact

Every row carries the grep that found its readers. A row may not read "unaffected" without
one. Line numbers are from the tree at the time of writing.

| Touched surface | What already reads it (grep) | Effect of this change | Guarded by |
|---|---|---|---|
| `lib/domain/rules/capital_committed.dart` | `lib/state/today/today_controller.dart` (`_capitalInputs`, `currentCapitalCommitted`, `concentrationFlags`), `lib/features/today/today_screen.dart` (`concentrationFlagLine`, `kConcentrationInviteLine`), `lib/features/settings/settings_screen.dart:371,381` (`wheelCapitalInRange`, `concentrationLimitInRange`), `lib/state/preferences/preferences_provider.dart`, `test/domain/rules/capital_committed_test.dart`, `test/state/today/today_controller_test.dart`, `test/features/today/today_screen_test.dart`, `test/features/settings/settings_screen_test.dart` | **Additive**: `concentrationBars`, `concentrationTrackMaxPct`, `portfolioCommittedDefinition`. No existing signature, string or number changes. The flag-ordering rule is now shared with the bars instead of restated | S-293, S-294, S-295 + all four existing suites green |
| `lib/domain/rules/bucket.dart` + `today_controller.dart:97` (`_bucketOrder`) | `lib/state/today/today_controller.dart:110` (`_bucketIndex`), `:202` (`bucketCounts`), `lib/features/today/today_screen.dart:204` (filters by `runtimeType`), `test/state/today/today_controller_test.dart`, `test/features/today/today_screen_test.dart` | The order list and the counting move into `bucket.dart`; `_bucketOrder`/`_bucketIndex` are deleted. Counts, order and labels are byte-identical for Today | S-302 + both Today suites green |
| `lib/domain/rules/obligation.dart` | `lib/features/today/expiring_this_week_card.dart`, `lib/state/today/today_controller.dart` (`_expiringGroups`), `lib/core/money/whole_dollars.dart` (doc mention), `lib/domain/rules/capital_committed.dart` (doc mention), `test/domain/rules/obligation_test.dart`, `test/state/today/today_controller_test.dart` | **Additive**: `expirationsInMonth`, built on the same `obligationFor` and reusing `ExpiringGroup`. `expiringThisWeek`/`expiringWithinSevenDays`/`kExpiringWindowDays` untouched | S-300, S-301 + the existing obligation suite green |
| `lib/domain/rules/reading_age.dart` | `lib/state/today/today_controller.dart` (the aging list), `lib/features/today/today_screen.dart` (`_AgingLine`), `lib/core/format.dart` (doc mention), `test/domain/rules/reading_age_test.dart` | **Unchanged.** Portfolio renders the same `agingLine` string. No new wording, no new threshold, `kAgingDays` not re-declared | S-298 |
| `lib/domain/rules/premium_collected.dart` (private `_inPeriod`) | `lib/state/today/today_controller.dart` (`monthPeriodContaining`, the month premium sum), `test/domain/rules/premium_collected_test.dart`, `test/state/today/today_controller_test.dart`, `test/state/positions/position_detail_close_test.dart`, `test/features/today/today_screen_test.dart` | `_inPeriod` is renamed to a **public** `inPeriod`; its one caller is updated. Behaviour identical, and the card now shares the rule instead of copying it | S-305 + the existing suite green |
| `lib/domain/rules/cycle_pnl.dart` | `lib/data/export/ledger_csv.dart`, `lib/domain/rules/{capital_committed,formulas,journal_aggregates,roll_chain}.dart`, `lib/state/journal/journal_controller.dart`, `lib/state/positions/position_detail_controller.dart`, `lib/widgets/cycle_summary_card.dart`, `lib/widgets/journal_row.dart`, 4 test files | **Unchanged.** The card calls `returnOnCapital`, `hasFeeGap` and `feeGapCount` as they are | S-306, S-307 + `test/domain/rules/cycle_pnl_test.dart` green |
| `lib/domain/rules/journal_aggregates.dart` | `lib/state/journal/journal_controller.dart`, `test/domain/rules/journal_aggregates_test.dart` | **Unchanged.** The card calls `averageDaysInCycle` and `medianPremiumCapturePct` as they are | S-306 |
| `lib/core/format.dart` | every screen and several state files (all display formatting), `test/core/format_test.dart` | **Additive**: `monthYearText`, `signedSharesText`, `percentText`. Nothing existing changes | S-300, S-306, S-308 + the existing format suite green |
| `lib/state/today/today_controller.dart` (`_capitalInputs`) | `test/state/today/today_controller_test.dart`, `test/state/entitlements/nothing_locks_test.dart` | Extracted to `lib/state/book/book_reads.dart` so Portfolio assembles its capital inputs the same way — including the `holdingShares`-only share-lot read. The loop's behaviour is unchanged | S-293 + both suites green |
| `lib/features/today/today_screen.dart` (`_LedgerStrip`) | `test/features/today/today_screen_test.dart`, `test/state/entitlements/nothing_locks_test.dart`, `test/features/paywall/paywall_entry_points_test.dart` | The "Committed now" tile gains an `onTap`. Its figure, the definition line, the flag lines and the invite line are unchanged for every user; the other two tiles stay inert | S-291 |
| `test/features/paywall/paywall_entry_points_test.dart` (S-277's guard) | the file itself | The pinned `showPaywall(` file list grows from four files to five (`lib/features/today/today_screen.dart` is added); `context.push('/paywall'` stays in exactly one file. Changing the pinned list is the guard doing its job | S-291 |
| `lib/core/purchases/paywall_copy.dart` (`kPaywallFeatures`) | `lib/features/paywall/paywall_screen.dart`, `test/core/purchases/paywall_copy_test.dart`, `test/features/paywall/paywall_screen_test.dart` | **`kPaywallFeatures` unchanged.** It already promises "Portfolio and assignment calendar / capital, concentration and net delta across your book", which this wave makes true. "Screenshot scan" stays outstanding for Wave 4. `kPortfolioFeatureName` is added beside `proFeatureLine` | S-290 + the copy suite green |
| `lib/state/entitlements/entitlement_providers.dart` | `lib/state/entitlements/new_cycle_gate.dart`, `lib/state/entitlements/new_cycle_gate_providers` consumers, `lib/features/settings/*`, `test/state/entitlements/*` | **Additive**: `proFeatureGateProvider` beside `newCycleGateProvider`. No existing provider changes | S-290 + `test/state/entitlements/*` green |
| `lib/features/settings/settings_screen.dart` (the wheel-capital and limit save path) | `test/features/settings/settings_screen_test.dart`, `test/features/settings/rule_profile_editor_test.dart` | The save path already invalidates `todayControllerProvider` and `journalControllerProvider`; it gains `portfolioControllerProvider`, or Portfolio would keep showing the old percentages after a limit change | S-292 + both suites green |
| `lib/core/app_router.dart` | `lib/main.dart:34`, `test/widget_test.dart`, `test/features/{today,screener,record,settings,paywall,onboarding}/*_test.dart` (8 files) | **Additive**: `/portfolio` and `/journal/share`. `initialLocation` unchanged; no existing navigation assertion moves | S-291, S-309 + those suites green |
| `lib/features/journal/journal_screen.dart` | `test/features/journal/*` (pumps the screen), `lib/widgets/app_bottom_nav.dart` (the `/journal` path) | One app-bar action added. The list, the aggregates, the refresh and the empty state are unchanged | S-309 |
| `lib/state/export/export_controller.dart` (`ShareSheet`, `shareSheetProvider`) | `lib/features/settings/settings_screen.dart`, `test/features/settings/settings_screen_test.dart` | **Unchanged.** The card is a second *caller* of the same seam, with `XFile.fromData` exactly as `buildExportFiles()` does | S-309 |
| `lib/data/db/app_database.dart:41` (`schemaVersion`) | every migration test, `test/data/db/*` | **Unchanged at 6.** No table, column or seed change; no `drift_schema_v7.json`; `build_runner` is not needed by this wave | P6 residue sweep + the full migration suite green |
| `lib/core/disclaimer.dart` (`kAppDisclaimer`) | `lib/features/settings/settings_screen.dart:248`, `lib/features/onboarding/first_run_explainer.dart:127`, `test/features/onboarding/*` (S-249's character-for-character pin) | **Unchanged.** The card renders the same constant verbatim | S-312 |
| `docs/architecture/wheel-triage.md` | the whole repo (the architecture index) | Gains the Portfolio and share-card surfaces and the drift-risk rows P6 adds | P6 |

## Scenarios

IDs continue from **S-290** (Wave 2 ends at S-289) and are stable and never reused.
Fixtures are enumerated, not described: if a fixture cannot be listed, the scenario is
underspecified and is fixed here rather than left to an implementer.

**A note on the reference's arithmetic.** `docs/design/pro-ui-reference.html` is non-binding
intent. Its share-card arithmetic (S-306) is internally consistent and is adopted verbatim.
Its **Portfolio figures are not**, in two ways: its per-underlying bar percentages cannot be
reproduced from the positions its own obligation rows name (SBET is drawn at 3%, which needs
$900, while the only SBET position listed is an `$11` call), and its delta sum
(76 + 156 + 156 − 28 − 25 + 200 = 535) includes a −25 term for PFE, which its own "Left out"
note excludes for having no reading. The Portfolio fixtures below are therefore **authored
here**, self-consistent, and the reference's illustrative percentages are not treated as
expected values.

### S-290: Portfolio is Pro, decided in exactly one place

- **Fixture**: a `ProviderScope` with the in-memory repository; a book of at least one open leg.
  Two runs: (a) `entitlementControllerProvider` overridden to `EntitlementStatus.active`;
  (b) `inactive`; (c) `unknown`.
- **Trigger**: `ref.read(proFeatureGateProvider).evaluate(kPortfolioFeatureName)`.
- **Flow**: the gate reads `EntitlementController` and returns one of two sealed outcomes.
- **Expected outcome**: (a) `isA<ProFeatureOpen>()`; (b) and (c) `isA<ProFeatureLocked>()` whose
  `feature == 'Portfolio'` and whose `line == proFeatureLine('Portfolio')`, i.e. exactly
  `Portfolio is part of Pro. Everything you've already recorded stays available on every plan.`
  A structural test also asserts that **no file under `lib/features/`** reads
  `purchaseGatewayProvider` or `.isActive` — the gate is the only decider.
- **Edge case of**: none

### S-291: Today's "Committed now" tile is the one entry point

- **Fixture**: `today_screen_test.dart`'s existing pump helper, with a book whose committed
  figure is non-zero and wheel capital set. Two runs: entitlement active, entitlement inactive.
- **Trigger**: tap the "Committed now" tile.
- **Flow**: the tap evaluates `proFeatureGateProvider`; an open verdict pushes `/portfolio`, a
  locked one calls `showPaywall(context, trigger: ProFeaturePaywallTrigger('Portfolio'))`.
- **Expected outcome**: active → `PortfolioScreen` is on screen; inactive → `PaywallScreen` is
  on screen and renders `proFeatureLine('Portfolio')`. In **both** runs the tile's figure, the
  strip's definition line and any concentration flag line are byte-identical to the pre-wave
  output, and the other two tiles are not tappable. `test/features/paywall/paywall_entry_points_test.dart`
  asserts the updated pinned file list (five files) and that `context.push('/paywall'` still
  appears in exactly one file.
- **Edge case of**: none

### S-292: Nothing locks, and the view returns with the entitlement

- **Fixture**: the `nothing_locks_test.dart` book (open legs, a closed cycle, a share lot) with
  the entitlement initially `active`; wheel capital `$30,000`, limit `25%`.
- **Trigger**: (a) flip the entitlement to `inactive` and re-read; (b) flip back to `active`;
  (c) while active, change wheel capital to `$40,000` in Settings.
- **Flow**: (a) Portfolio is no longer reachable without the paywall; (b) it is reachable again
  with no reinstall, no reload call and no navigation gymnastics; (c) the save path invalidates
  `portfolioControllerProvider`.
- **Expected outcome**: (a) `getAllLegs()`, `getClosedCycles()` and the snapshot counts are
  **identical before and after the lapse** — asserted by comparing the two full reads, not by
  checking one field — and Today still renders its ledger unchanged; (b) Portfolio renders the
  same figures it did before the lapse; (c) Portfolio's percentages and the flag line reflect
  `$40,000` on the next build with no manual refresh.
- **Edge case of**: none

### S-293: Portfolio's figures equal Today's for the same book

- **Fixture** (`bookFull`), wheel capital `$30,000`, concentration limit `25%`:
  INTC `$20` put ×4 open; SOFI `$14` put ×3 open; F `$12` put ×2 open; PFE `$25` put ×1 open;
  AAL `$15` put ×2 with expiration `2026-09-18` (past expiration, not recorded); WBD `$9` put
  ×1 with expiration `2026-09-18` (past expiration, not recorded);
  **T** on a `holdingShares` cycle whose only leg is the `$28` put ×1 that assigned (closed,
  `$100` credit) with a share lot of 1 contract at assignment strike `$28` → wheel basis `$27`
  → `$2,700`; **SBET** on a `holdingShares` cycle with the `$13` put ×1 that assigned (closed,
  `$100` credit), a share lot of 1 contract at assignment strike `$13` → wheel basis `$12`, and
  the `$11` call ×1 open (the covered call, which adds nothing to the put side). Today =
  `2026-09-28`.
- **Trigger**: build `PortfolioScreen` and `TodayScreen` over the same repository.
- **Flow**: both assemble capital inputs through `lib/state/book/book_reads.dart` and call
  `currentCapitalCommitted`.
- **Expected outcome**: committed = `$8,000 + $4,200 + $2,400 + $2,500 + $1,200 + $2,700 +
  $3,000 + $900 = $24,900` on **both** screens; the sub-line reads
  `committed now · 83% of $30,000 wheel capital` (24,900 ÷ 30,000 = 83.00%, half-up 83); the
  flag line is `INTC 27% of wheel capital · limit 25%` on both; the definition paragraph on
  Portfolio is `committedNowDefinition(...)` **plus**
  `Includes AAL and WBD, past expiration and not yet recorded.` The assertion is that the two
  screens' totals are `Decimal`-equal, not epsilon-equal.
- **Edge case of**: none

### S-294: The bars' order, fills and limit mark

- **Fixture**: `bookFull` from S-293, and a second book `bookTies` with two underlyings both at
  exactly 8% of wheel capital (`F` and `PFE`) plus one at exactly the limit.
- **Trigger**: build the concentration card.
- **Flow**: `concentrationBars` orders; the track max is `concentrationTrackMaxPct(25) = 30`.
- **Expected outcome**: bars in the order **INTC (27%), SOFI (14%), AAL (10%), T (9%), F (8%),
  PFE (8%), SBET (4%), WBD (3%)** — percent descending, and the 8% tie broken by ticker A–Z
  (`F` before `PFE`), which is the same order `concentrationFlags` uses; the key line reads
  `Limit 25% · bars run to 30%`; the limit mark sits at 25/30 of the track; INTC's fill is
  26.67/30 and **crosses** the mark, while an underlying at exactly 25.00% fills 25/30 and
  **does not** (equal is not a breach); `bookTies`' bar at exactly 25.00% is absent from
  `concentrationFlags` but present in the bars.
- **Edge case of**: S-293

### S-295: No wheel capital set

- **Fixture**: `bookFull` with the wheel-capital preference unset (and a second run with it set
  to `0`).
- **Trigger**: build the concentration card.
- **Flow**: `capitalCommittedByUnderlying` still returns every ticker.
- **Expected outcome**: the big figure is `wholeDollars(24,900)` = `$24,900`; per-underlying
  **dollar** rows appear in descending order; there are **no bars, no percentages, no limit
  key and no flag line**; `kConcentrationInviteLine` renders verbatim
  (`Concentration per underlying appears once wheel capital is set in Settings.`). Nothing
  renders `NaN`, `--%`, `0%` or an empty box.
- **Edge case of**: S-293

### S-296: Net position delta, all four sign quadrants

- **Fixture** (`bookSigns`), today = `2026-09-28`, wheel capital `$10,000`:
  | # | Leg / holding | `deltaConvention` | `deltaAsEntered` | position delta | shares |
  |---|---|---|---|---|---|
  | Q1 | `$10` put ×1, open | `position` | `+0.40` | `+0.40` | `+40` |
  | Q1 | `$10` put ×1, open | `option` | `−0.40` | `+0.40` | `+40` |
  | Q2 | `$10` call ×1, open | `position` | `−0.30` | `−0.30` | `−30` |
  | Q2 | `$10` call ×1, open | `option` | `+0.30` | `−0.30` | `−30` |
  | Q3 | `holdingShares` cycle, share lot 1 contract | — | — | — | `+100` |
  | Q4 | `$10` put ×2, open, `position`, `+0.20` **plus** a share lot of 2 contracts | `position` | `+0.20` | `+0.20` | `+40 + 200 = +240` |
- **Trigger**: `netPositionDelta`.
- **Flow**: each snapshot is read with its own stored convention; short legs only.
- **Expected outcome**: total = `40 + 40 − 30 − 30 + 100 + 240 = +360`, rendered `+360 shares`.
  The two Q1 rows are `Decimal`-equal to each other and the two Q2 rows are equal to each
  other — the same position described under either convention produces the same number — and
  the Q2 rows are the exact negation of a long call entered as `+0.30`. A second run with
  `Settings.deltaConvention` flipped changes **nothing**, proving the convention is read per
  snapshot and not from the preference.
- **Edge case of**: none

### S-297: The delta's exclusions, named once each

- **Fixture** (`bookExcluded`), today = `2026-09-28`: an open `PFE $25` put ×1 with **no
  snapshot**; an `AAL $15` put ×2 with expiration `2026-09-18` (past expiration) **with** a
  snapshot; a `WBD $9` put ×1 with expiration `2026-09-18` and **no** snapshot; and one
  included `INTC $20` put ×4 with a snapshot at `+0.19`, **`position`** convention.
  *(Corrected by A-22: this fixture originally said `option` convention, which records the
  option's own delta — the negation for the short leg this app models — and would have made
  INTC a long put yielding `−76`. The engine is right; the fixture was wrong.)*
- **Trigger**: `netPositionDelta`.
- **Flow**: inclusion is `closedAt == null` ∧ not past expiration ∧ a latest snapshot with a
  non-null delta; exclusion reasons are evaluated past-expiration first.
- **Expected outcome**: the total is `+76` (`0.19 × 100 × 4`) — AAL, WBD and PFE contribute
  nothing; the "Left out" line reads exactly
  `Left out: PFE (no reading); AAL, WBD (past expiration)` — **WBD appears once**, under past
  expiration, not under both; AAL's snapshot is not counted anywhere. *(Corrected by A-23:
  this line originally read `WBD, AAL`, transposing two tickers; `leftOutLine`'s own doc
  comment and `_sorted` pin **A–Z within a clause**.)* A second fixture with only an included
  leg renders **no** "Left out" line at all.
- **Edge case of**: S-296

### S-298: The aging label

- **Fixture**: three open legs each with one snapshot — T's 7 days old, SOFI's 8 days old,
  INTC's 1 day old — at today = `2026-09-28` (T's reading dated `2026-09-21`, SOFI's
  `2026-09-20`).
- **Trigger**: build Portfolio.
- **Flow**: `reading_age.agingLine` over the included legs.
- **Expected outcome**: the note reads exactly `1 reading older than 7 days · SOFI, from Sep
  20` — the 7-day-old reading is **not** named (the threshold is strictly older than 7) and
  the string is character-for-character the one Today renders for the same population. With no
  aging reading, no note is rendered.
- **Edge case of**: S-296

### S-299: The calendar opens on the month of the next expiration

- **Fixture**: today = `2026-09-28`; open legs expiring `2026-10-02`, `2026-10-09`,
  `2026-10-16`, `2026-10-16`, `2026-10-23`; past-expiration legs `2026-09-18` ×2.
- **Trigger**: build the calendar.
- **Flow**: `calendarMonth` picks the earliest future expiration's month.
- **Expected outcome**: the header reads `October 2026`; the grid is 7 columns wide and 5 rows
  tall (4 leading cells `Sep 27–30` + 31 days, no trailing cells); the leading cells are muted
  and **Sep 28 is outlined even though it is a leading cell**; `exp` marks appear on Oct 2, 9,
  16 and 23 and on no other day; the `Sep 18` legs are nowhere in the grid.
- **Edge case of**: none

### S-300: The calendar's obligations

- **Fixture**: S-299's fixture, with: SOFI `$14` put ×3 exp Oct 2; T `$28` call ×1 exp Oct 2;
  F `$12` put ×2 exp Oct 9; INTC `$20` put ×4 exp Oct 16; SBET `$11` call ×1 exp Oct 16;
  PFE `$25` put ×1 exp Oct 23.
- **Trigger**: build the calendar.
- **Flow**: `expirationsInMonth` groups ascending; each leg renders
  `<ticker> <legContractText(leg)> · <obligationFor(leg).text>`.
- **Expected outcome**: rows in ascending date order —
  `Fri Oct 2` with `SOFI $14 put ×3 · $4,200 cash if assigned` and
  `T $28 call ×1 · 100 shares delivered at $28 if assigned`;
  `Fri Oct 9` with `F $12 put ×2 · $2,400 cash if assigned`;
  `Fri Oct 16` with `INTC $20 put ×4 · $8,000 cash if assigned` and
  `SBET $11 call ×1 · 100 shares delivered at $11 if assigned`;
  `Fri Oct 23` with `PFE $25 put ×1 · $2,500 cash if assigned`.
  No row appears for a date with no expiration; a leg expiring **today** is included (the
  comparison is `expiration >= today`); a leg with a `closedAt` set is absent.
- **Edge case of**: S-299

### S-301: No future expiration at all

- **Fixture**: today = `2026-09-28`; every open leg has an expiration on or before `2026-09-18`
  (all past expiration).
- **Trigger**: build the calendar.
- **Flow**: `calendarMonth` falls back to the month containing today.
- **Expected outcome**: the header reads `September 2026`; the grid renders with today outlined
  and **no `exp` marks**; there are no obligation rows; the card still renders its header and
  the grid rather than disappearing. A second run with **no open legs at all** behaves the
  same.
- **Edge case of**: S-299

### S-302: The bucket summary cannot drift from Today's

- **Fixture**: seven open legs with pinned `ruleProfileVersionId`s such that the live
  classification is 1 Assign, 1 Roll, 1 Close, 2 Leave and 1 leg with no snapshot
  (`BucketUnknown`) — six counted, and `Standard` has since been edited to a new version so a
  leg pinned to `standard-v1` would classify differently under the current thresholds.
- **Trigger**: build `TodayScreen` and `PortfolioScreen` over the same repository.
- **Flow**: both call `bucketCountsFor` over legs classified under **their own pinned**
  version.
- **Expected outcome**: both screens render the five labels in the order **Assign, Roll, Close,
  Leave, No data** with counts **1, 1, 1, 2, 1**; "No data" is its own tile with its own count
  and is never folded into `Leave`; the `standard-v1`-pinned leg's bucket is the same on both
  screens and is **unchanged by the profile edit** (proving the pin is read, not the current
  profile). A structural test asserts that no file outside `lib/domain/rules/bucket.dart`
  declares a bucket-order list.
- **Edge case of**: none

### S-303: The grid's leading-day edges

- **Fixture**: today = `2026-08-15` with one open leg expiring `2026-08-21` (a month whose first
  day is a **Saturday**), and today = `2026-11-10` with one open leg expiring `2026-11-20` (a
  month whose first day is a **Sunday**).
- **Trigger**: build the calendar for each.
- **Flow**: the grid pads to full rows.
- **Expected outcome**: **August 2026** has 6 leading cells (`Sun Jul 26` … `Fri Jul 31`), with
  `Aug 1` in the last column of the first row, and 31 days → 6 rows; **November 2026** has
  **0** leading cells, with `Nov 1` in the first column, and 30 days → 5 rows. Both grids are
  7 columns wide in every row; the day count of the shown month is correct in both.
- **Edge case of**: S-299

### S-304: Every number on Portfolio is labelled

- **Fixture**: `bookFull`, entitlement active, with a reading older than 7 days and one
  excluded leg so both notes render.
- **Trigger**: pump the screen with `SemanticsBinding` enabled and walk the semantics tree.
- **Flow**: each figure carries a label naming its quantity.
- **Expected outcome**: the committed total's label names the quantity and the currency; each
  bar's label names its underlying, its dollar amount and its percent; the delta total's label
  names the unit (shares); each count tile's label names the bucket; each obligation row's
  label names the ticker, the contract and the obligation. No figure is reachable only by
  colour, and none truncates at the largest supported text scale (the test renders at
  `textScaler` 2.0 and asserts no overflow error).
- **Edge case of**: none

### S-305: Which cycles are in the card's month

- **Fixture** (today = `2026-09-28`): closed cycles with `endedAt` on `2026-08-31`
  (**out**), `2026-09-01` (**in**), `2026-09-15` (**in**), `2026-09-30` (**in**), plus one
  `closed` cycle with `endedAt == null` (**in no month**) and one `sellingPuts` cycle with
  `endedAt == null` (**out**).
- **Trigger**: build the card's month set.
- **Flow**: `inCardMonth` uses `monthPeriodContaining(now)` and `premium_collected.inPeriod`,
  inclusive both ends.
- **Expected outcome**: exactly three cycles are in September 2026 — the 1st, the 15th and the
  30th — and the `2026-08-31` cycle and both `endedAt == null` cycles are not. A second run at
  today = `2026-10-01` produces a set containing **none** of these three, proving the boundary
  is a real month boundary and not a rolling 30 days. The `endedAt == null` closed cycle is
  asserted to be absent from **every** month tested, and the app never throws on it.
- **Edge case of**: none

### S-306: The card's five figures

- **Fixture** (the reference's own card arithmetic, adopted verbatim), today = `2026-09-28`,
  five cycles closed in September 2026:

  | Cycle | ticker | `netResult` | `peakCapitalCommitted` | `daysHeld` | premium captures | `hasFeeGap` / `feeGapCount` |
  |---|---|---|---|---|---|---|
  | 1 | BAC | `+32` | `3,800` | 24 | `95%` | true / 2 |
  | 2 | CCL | `+35` | `6,250` | 31 | `88%` | false / 0 |
  | 3 | KO | `−30` | `4,000` | 18 | `82%` | true / 1 |
  | 4 | SNAP | `+110` | `7,000` | 35 | `61%` | false / 0 |
  | 5 | UBER | `+210` | `1,800` | 27 | `40%` | false / 0 |

- **Trigger**: build the card.
- **Flow**: the two `Decimal` sums feed `returnOnCapital`; the other four figures come from
  the shipped aggregate functions.
- **Expected outcome**: `Return on capital 1.6%` (357 ÷ 22,850 = 1.5627%, one decimal);
  `Cycles closed 5`; `Closed positive 4 of 5`; `Average days in cycle 27` (135 ÷ 5);
  `Median premium capture 82%` (the median of 95, 88, 82, 61, 40 — a **mean** would be 73.2%
  and would fail this assertion). The definition paragraph reads exactly
  `Return on capital: net result ÷ peak capital committed, over cycles closed in September
  2026. Before fees: 3 closed legs have no fee recorded.`
  A second fixture whose five cycles all have `peakCapitalCommitted == 0` reads `0.0%`, never
  `NaN`; a third whose legs carry no capture at all reads `--` for median premium capture.
- **Edge case of**: S-305

### S-307: "Before fees" appears only when there is a gap

- **Fixture**: S-306's month (a gap of 3); a second month with five cycles, every closed leg
  carrying a `closeFee` (no gap); a third with exactly one leg missing a fee.
- **Trigger**: build the card for each.
- **Flow**: `hasFeeGap` and `feeGapCount` per cycle, summed.
- **Expected outcome**: month 1 → the clause is present with `3 closed legs have no fee
  recorded`; month 2 → **no** clause anywhere on the card and **no** string containing "fees"
  except nothing at all (asserted by scanning every rendered `Text`); month 3 → the singular
  `1 closed leg has no fee recorded`. With the dollars toggle on, the clause appears on the
  net-result line too and carries the same count.
- **Edge case of**: S-306

### S-308: The toggles

- **Fixture**: S-306's month; `shareSheetProvider` overridden with a recording fake.
- **Trigger**: open the screen; read the card; turn `Show dollar amounts` on; read again; turn
  `Show tickers` on; read again; pop the screen; push it again.
- **Flow**: both toggles are session state initialised to off.
- **Expected outcome**: on open, the card shows **no** dollar figure and **no** ticker
  (`357`, `$`, `BAC` are all absent from the rendered text); `Show dollar amounts` on adds
  exactly `Net result $357.00 before fees` (two decimals) and changes none of the five figures;
  `Show tickers` on adds exactly `BAC · CCL · KO · SNAP · UBER` (A–Z, deduplicated — a
  duplicate ticker across two cycles appears once) and changes none of the five figures;
  after popping and pushing, **both toggles are off again** and the card is back to its
  default text. No preference is written (the repository's `updatePreferences` is never called
  — asserted on the fake repository).
- **Edge case of**: S-306

### S-309: The image, and the one share path

- **Fixture**: S-306's month, a fixed logical `360 × 450` surface, `shareSheetProvider`
  overridden with a fake that captures the `XFile` list and the subject.
- **Trigger**: tap `Share image`, twice.
- **Flow**: the card's `RepaintBoundary` is captured at `pixelRatio: 3` and the bytes go to
  `ShareSheet.shareFiles`.
- **Expected outcome**: the captured PNG decodes to exactly **1080 × 1350**; the fake receives
  exactly **one** file, whose `mimeType` is `image/png` and whose `path` is
  `wheel-triage-2026-09-ledger.png`; the subject is `Wheel Triage — September 2026 ledger`;
  the two runs produce **byte-identical** `Uint8List`s (the card carries no timestamp); a
  structural test asserts `ShareSheet.shareFiles` has exactly two call sites in `lib/` (the
  existing export and the card) and that no file under `lib/features/` imports `share_plus`
  directly. The empty state (S-311) is asserted to render no share button.
- **Edge case of**: none

### S-310: The card in both themes

- **Fixture**: S-306's month, rendered under `AppTheme.light` and `AppTheme.dark`.
- **Trigger**: pump the card in each theme; compare against `share_card_light.png` and
  `share_card_dark.png`.
- **Flow**: every colour comes from `Theme.of(context)` / `AppTokens`.
- **Expected outcome**: both goldens match, the two renderings are **not** byte-identical to
  each other (the dark one is genuinely dark, so the test cannot pass by ignoring the theme),
  and the five figure strings are identical in both. The standing colour-literal grep stays
  empty outside `lib/core/theme/`.
- **Edge case of**: none

### S-311: The empty month

- **Fixture**: today = `2026-09-28` with **no** closed cycle whose `endedAt` is in September
  2026 (one closed in August, one still open).
- **Trigger**: build the share screen.
- **Flow**: the month's cycle list is empty.
- **Expected outcome**: the screen renders the empty state `No cycles closed in September
  2026`; **no card is rendered** and **no share button exists** (asserted by `findsNothing`
  for both); the app bar still reads `Share September` so the user knows which month is empty;
  nothing is shareable and the share sheet fake receives nothing. A second run with a month
  that has cycles renders the card, so the test cannot pass by failing to build.
- **Edge case of**: S-305

### S-312: The card's copy

- **Fixture**: S-306's month, both toggles off, then on.
- **Trigger**: read every `Text` in the card's subtree.
- **Flow**: the copy is assembled from D-51 and D-50; the footer is `kAppDisclaimer`.
- **Expected outcome**: the concatenated copy matches
  `recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should`
  case-insensitively **zero** times (a unit test, not only the grep); it contains none of
  `streak`, `badge`, `congrat`, `great`, `keep it up`, `you're`, `your best`; the footer is
  **character-for-character** `kAppDisclaimer` (asserted by `equals(kAppDisclaimer)`, the same
  pin S-249 applies to Settings); the definition paragraph contains `Return on capital: net
  result ÷ peak capital committed`; and no string on the card names a security alongside an
  action verb (the hand-reviewed §10 check, discharged by reading the card's copy list, which
  is four strings long).
- **Edge case of**: none

## Iteration 1

### Dependency graph

```
Phase 1 (rules + formatters) ──┬──► Phase 2 (card figures) ──► Phase 3 (card screen, capture, share) ──┐
                               │                                                                      │
                               └──► Phase 4 (book reads, Portfolio state, Pro gate) ──► Phase 5 (Portfolio screen, Today entry, routes) ──┤
                                                                                                      │
                                                                                          Phase 6 (closeout) ◄──┘
```

- Phase 1 must land first: both later branches import its helpers.
- Phases 2→3 and 4→5 are two independent chains. Nothing in the card chain touches the
  Portfolio chain and vice versa, so they can be worked in either order or interleaved.
- Phase 6 needs all of 3 and 5.

**Re-ordering offered.** The phases are numbered in the recommended execution order —
**Stage 8 (the card) before Stage 7 (Portfolio)** — because the image capture in Phase 3 is
the wave's only genuinely new technique and the one thing that could fail outright (a
`toImage` behaviour, a font-loading race, a golden-environment surprise). Landing it third
means that failure surfaces in the second handoff, while the wave still has room, rather than
in the fifth. The cost is that the wave's Pro headline ships last, so a user following along
sees a free feature arrive before a Pro one. The alternative — Phase 4/5 before Phase 2/3 —
buys the Pro headline early at the cost of discovering an image-capture problem after the
Pro work is already merged. Both orders end at the same Phase 6; the choice is the
implementer's and changes nothing else in this plan.

### Phase 1: The rules and formatters both screens need (@data-architect)

1. [x] Add `lib/domain/rules/position_delta.dart`: `positionDelta(Snapshot)`,
       `legShares(Leg, Snapshot)`, `sharesHeld(WheelCycle, ShareLot?)`, and
       `netPositionDelta({required Iterable<...> book, required DateTime now})` returning both
       the total and the two named exclusion lists, per D-43. Pure Dart, no Flutter import, no
       `double` for money, `now` a parameter.
2. [x] Add `lib/domain/rules/listing.dart`: `listPhrase(List<String>)` and
       `listPhraseWithReason(List<String>, String)`, per D-43.
3. [x] In `lib/domain/rules/capital_committed.dart`, add `concentrationTrackMaxPct`,
       `concentrationBars` and `portfolioCommittedDefinition`, per D-42. **Change nothing
       existing**: `concentrationFlags`' ordering is now shared with `concentrationBars`
       rather than restated, and `kCommittedNowDefinitionLine`/`committedNowDefinition` are
       untouched.
4. [x] In `lib/domain/rules/obligation.dart`, add `expirationsInMonth({legs, month, now})`
       returning ascending `ExpiringGroup`s, reusing `obligationFor` and the existing
       `ExpiringGroup` type, per D-45. Do not touch `expiringThisWeek`,
       `expiringWithinSevenDays` or `kExpiringWindowDays`.
5. [x] In `lib/domain/rules/premium_collected.dart`, rename the private `_inPeriod` to a
       public `inPeriod` and update its one caller in
       `lib/state/today/today_controller.dart`. Behaviour identical.
6. [x] In `lib/domain/rules/bucket.dart`, add `kBucketOrder` and `bucketCountsFor`, per D-46.
7. [x] In `lib/state/today/today_controller.dart`, delete `_bucketOrder` (line 97) and
       `_bucketIndex` (line 110) in favour of `kBucketOrder`, and make `TodayState.bucketCounts`
       delegate to `bucketCountsFor`. Counts, order and labels must be byte-identical.
8. [x] In `lib/core/format.dart`, add `monthYearText(DateTime)` → `September 2026`,
       `signedSharesText(double?)` → `+535 shares` / `−25 shares` / `0 shares`, and
       `percentText(double?, {int decimals = 1})`. Hand-rolled beside `_months`, matching the
       file's existing style; no `intl` `DateFormat`.
9. [x] Unit tests for every new helper, including: the bar ordering with an 8%-tie broken
       A–Z, a bar at exactly the limit not crossing the mark, `portfolioCommittedDefinition`
       with and without past-expiration tickers, the four delta quadrants, the exclusion
       ordering, `expirationsInMonth` with a leg expiring today and a closed leg, and the three
       formatters' edge cases (0, negative, 1000+ separators).

**Done Criteria** (run until green): `flutter analyze`;
`flutter test test/domain/rules test/core/format_test.dart test/state/today/today_controller_test.dart`;
`grep -rl "package:flutter" lib/domain/rules/` returns nothing;
`grep -rnE "(^|[^A-Za-z])Colors\.|Color\(0x" lib/ --include='*.dart' | grep -v lib/core/theme/`
returns nothing.

**Done — observed.** `flutter analyze` → *No issues found!*;
`flutter test test/domain/rules test/core/format_test.dart test/state/today/today_controller_test.dart`
→ **382 passed, 0 failed**; both greps returned nothing; `grep -rn "_bucketOrder\|_bucketIndex\|_inPeriod" lib/`
returned nothing. Full suite → **1027 passed, 0 failed** (planning baseline 925).

**Predicted Files**: `lib/domain/rules/position_delta.dart` (new),
`lib/domain/rules/listing.dart` (new), `lib/domain/rules/capital_committed.dart`,
`lib/domain/rules/obligation.dart`, `lib/domain/rules/premium_collected.dart`,
`lib/domain/rules/bucket.dart`, `lib/core/format.dart`,
`lib/state/today/today_controller.dart`, `test/domain/rules/position_delta_test.dart` (new),
`test/domain/rules/listing_test.dart` (new),
`test/domain/rules/{capital_committed,obligation,premium_collected,bucket}_test.dart`,
`test/core/format_test.dart`.

### Phase 2: The card's month and figures (@data-architect)

1. [x] Add `lib/domain/rules/share_card.dart`: `cardMonthPeriod(DateTime now)` delegating to
       `premium_collected.monthPeriodContaining`, `cyclesInCardMonth(...)` per D-47,
       `ShareCardFigures` carrying the five values of D-49, `shareCardDefinitionLine(...)` per
       D-51, `beforeFeesClause(...)` per D-50, `cardTickerLine(...)` per D-52 and
       `netResultLine(...)` per D-52. Pure Dart, zero Flutter imports, `now` a parameter, the
       two money sums `Decimal`.
2. [x] Call `cycle_pnl.returnOnCapital` **once on the two sums** (D-48) — do not average
       per-cycle percentages and do not re-implement the division.
3. [x] Call `journal_aggregates.averageDaysInCycle` and
       `journal_aggregates.medianPremiumCapturePct` as they are (D-49). Never a mean for
       capture.
4. [x] Represent "no computable value" as `null` and render `--`; never coerce it to `0`.
5. [x] Unit tests covering S-305 (all four boundary cycles and the null-`endedAt` case),
       S-306 (the reference fixture's five figures, the zero-denominator month, the
       no-capture month), S-307 (gap, no gap, singular) and S-312's copy assertions.

**Done Criteria**: `flutter analyze`;
`flutter test test/domain/rules/share_card_test.dart test/domain/rules/cycle_pnl_test.dart test/domain/rules/journal_aggregates_test.dart`;
the rules-purity grep returns nothing.

**Done — observed.** `flutter test test/domain/rules/share_card_test.dart
test/domain/rules/cycle_pnl_test.dart test/domain/rules/journal_aggregates_test.dart`
→ **50 passed, 0 failed** (`share_card_test.dart` alone: 30). The rules-purity grep
returned nothing. The red state was observed first: all five new symbols failed to
compile before `share_card.dart` existed.

**Predicted Files**: `lib/domain/rules/share_card.dart` (new),
`test/domain/rules/share_card_test.dart` (new).

### Phase 3: The share card screen, the capture and the share (@developer)

1. [x] Add `lib/features/journal/share_card_screen.dart` with the app bar
       (`Journal` + back arrow), the title `Share September` and the sub
       `An image of this month's closed cycles`, the card, the two toggles and the
       `Share image` button, per D-52, D-54 and D-55.
2. [x] Add the card widget (fixed logical **360 × 450**) drawing only from
       `Theme.of(context)` / `AppTokens`, with no colour literal (D-53, Invariant 11).
3. [x] Wrap the card in a `RepaintBoundary` and capture it at `pixelRatio: 3`, producing
       exactly **1080 × 1350**; render the preview from the **same widget tree**, not a second
       painter (D-53).
4. [x] Send the bytes to `ShareSheet.shareFiles` through `shareSheetProvider` as
       `XFile.fromData(bytes, mimeType: 'image/png', path: 'wheel-triage-<yyyy-MM>-ledger.png')`
       with the subject from D-53. **Do not add a second share seam and do not import
       `share_plus` in `lib/features/`.**
5. [x] Render the footer as `kAppDisclaimer` verbatim — import it, do not restate it (D-54).
6. [x] Add the `GoRoute(path: 'share')` child under `/journal` and an app-bar share action on
       `JournalScreen` (D-53, D-57).
7. [x] Widget tests for S-308, S-309, S-311 and the two goldens for S-310, plus a test that
       the produced PNG decodes to 1080 × 1350 and that two captures are byte-identical.

**Done Criteria**: `flutter analyze`;
`flutter test test/features/journal test/features/goldens`;
`grep -rn "share_plus" lib/features/` returns nothing;
`grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/`
returns nothing.

**Predicted Files**: `lib/features/journal/share_card_screen.dart` (new),
`lib/features/journal/share_card.dart` (new, the card widget),
`lib/features/journal/journal_screen.dart`, `lib/core/app_router.dart`,
`test/features/journal/share_card_screen_test.dart` (new),
`test/features/goldens/share_card_light.png` (new),
`test/features/goldens/share_card_dark.png` (new),
`test/features/goldens/share_card_golden_test.dart` (new).

### Phase 4: The book reads, Portfolio's state, and the Pro gate (@developer)

1. [x] Add `lib/state/book/book_reads.dart` with `capitalInputsFor(WheelRepository, List<Leg>)`
       and `profileForLeg(WheelRepository, String)`, lifted **verbatim** out of
       `TodayController._capitalInputs`, including the `holdingShares`-only share-lot read
       (D-45's shared-read decision). `TodayController` calls them; its behaviour does not
       change.
2. [x] Add `lib/state/portfolio/portfolio_controller.dart` and its providers, assembling
       capital inputs, the concentration figures, the delta (D-43) and the bucket counts
       (D-46) through the shared helpers. Hand-written `StateNotifier`, matching the existing
       pattern (no `@riverpod`).
3. [x] Add `lib/state/entitlements/pro_feature_gate.dart` with the sealed
       `ProFeatureAccess` and `ProFeatureGate` exactly as D-40 specifies, and
       `proFeatureGateProvider` in `lib/state/entitlements/entitlement_providers.dart`.
4. [x] Add `kPortfolioFeatureName` to `lib/core/purchases/paywall_copy.dart`. **Change nothing
       in `kPaywallFeatures`** — it already promises Portfolio.
5. [x] In `lib/features/settings/settings_screen.dart`'s wheel-capital and concentration-limit
       save path, add `ref.invalidate(portfolioControllerProvider)` beside the two existing
       invalidations.
6. [x] Tests for S-290 (all three entitlement states, plus the structural assertion that no
       file under `lib/features/` reads the gateway or `.isActive`), S-292 (the full-read
       before/after comparison and the Settings invalidation) and S-302's state half.

**Done Criteria**: `flutter analyze`;
`flutter test test/state test/features/settings`;
`flutter test test/state/today/today_controller_test.dart` green with `_capitalInputs` gone.

**Predicted Files**: `lib/state/book/book_reads.dart` (new),
`lib/state/portfolio/portfolio_controller.dart` (new),
`lib/state/entitlements/pro_feature_gate.dart` (new),
`lib/state/entitlements/entitlement_providers.dart`,
`lib/core/purchases/paywall_copy.dart`, `lib/state/today/today_controller.dart`,
`lib/features/settings/settings_screen.dart`,
`test/state/portfolio/portfolio_controller_test.dart` (new),
`test/state/entitlements/pro_feature_gate_test.dart` (new),
`test/state/entitlements/nothing_locks_test.dart`,
`test/state/today/today_controller_test.dart`,
`test/features/settings/settings_screen_test.dart`.

### Phase 5: The Portfolio screen, Today's entry point and the routes (@developer)

1. [x] Add `lib/features/portfolio/portfolio_screen.dart` with the app bar (`Portfolio`, sub
       `Pro · as of Mon, Sep 28`), the concentration card, the delta card, the calendar card
       and the five count tiles, per D-42, D-43, D-44, D-45 and D-46.
2. [x] Make the "Committed now" tile in `lib/features/today/today_screen.dart`'s `_LedgerStrip`
       tappable: evaluate `proFeatureGateProvider`; open → `context.push('/portfolio')`;
       locked → `showPaywall(context, trigger: ProFeaturePaywallTrigger(access.feature))`
       (D-40). **Change nothing else about the strip.**
3. [x] Add `GoRoute(path: '/portfolio')` to `lib/core/app_router.dart`, pushed (D-40).
4. [x] Update `test/features/paywall/paywall_entry_points_test.dart`'s pinned file list to five
       files and keep the `context.push('/paywall'` single-file assertion.
5. [x] Widget tests for S-291, S-293, S-294, S-295, S-296, S-297, S-298, S-299, S-300, S-301,
       S-302 (the cross-screen half), S-303 and S-304, plus a structural assertion that no
       bucket-order list exists outside `lib/domain/rules/bucket.dart`.

**Done Criteria**: `flutter analyze`;
`flutter test test/features/portfolio test/features/today test/features/paywall test/state`;
the colour-literal grep returns nothing.

**Predicted Files**: `lib/features/portfolio/portfolio_screen.dart` (new),
`lib/features/portfolio/` (any new sub-widgets),
`lib/features/today/today_screen.dart`, `lib/core/app_router.dart`,
`test/features/portfolio/portfolio_screen_test.dart` (new),
`test/features/paywall/paywall_entry_points_test.dart`,
`test/features/today/today_screen_test.dart`.

### Phase 6: Closeout — docs, the residue sweep, the consolidated doc (@developer)

1. [x] Extend `docs/architecture/wheel-triage.md`: the Portfolio surface (its reuse of Stage
       3's calculations, its one gate), the share-card surface (its month rule, its capture
       contract, its share seam) and two drift-risk rows: the `_pct`/`_pctText`/`percentText`
       duplication (`lib/widgets/journal_row.dart:47`, `lib/widgets/cycle_summary_card.dart`,
       `lib/features/screener/screener_screen.dart:395` versus the new shared
       `format.percentText`) and the bucket-order/counting pair now shared through
       `bucket.dart`. Mark both as observations with their readers, not as work items.
2. [x] Update `docs/plans/pro-wave-3-plan.md`'s Progress table and Assumption Log, and mark
       Status CLOSED.
3. [x] Residue sweep — each command must return **nothing** (or exactly the named file):
       - `grep -rn "_bucketOrder\|_bucketIndex" lib/` → nothing
       - `grep -rn "_inPeriod" lib/` → nothing
       - `grep -rn "share_plus" lib/features/` → nothing
       - `grep -rl "package:flutter" lib/domain/rules/` → nothing
       - `grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/` → nothing
       - `grep -rnE "(^|[^A-Za-z])Colors\.|Color\(0x" lib/ --include='*.dart' | grep -v lib/core/theme/` → nothing
       - `grep -rn "context.push('/paywall'" lib/` → exactly one file
       - `grep -rn "showPaywall(" lib/` → exactly five files
       - `ls lib/data/db/schema/` → v1 … v6, no v7
4. [x] `flutter analyze` and the **full** `flutter test` suite, with the pass/fail counts
       pasted into the Progress table. Baseline for this wave: **925 passed, 0 failed**.

**Done Criteria**: `flutter analyze` clean; `flutter test` fully green with counts recorded;
every residue command above returning its expected result.

**Predicted Files**: `docs/architecture/wheel-triage.md`, `docs/plans/pro-wave-3-plan.md`.

## Files Affected

**New**

- `lib/domain/rules/position_delta.dart` — the signed-delta conversion, the exclusions, the total
- `lib/domain/rules/listing.dart` — `listPhrase` / `listPhraseWithReason`
- `lib/domain/rules/share_card.dart` — the month's cycles and the five figures
- `lib/state/book/book_reads.dart` — the capital-input and profile reads both screens use
- `lib/state/portfolio/portfolio_controller.dart` — Portfolio's state
- `lib/state/entitlements/pro_feature_gate.dart` — the one Pro-surface decision
- `lib/features/portfolio/portfolio_screen.dart` — the Portfolio screen
- `lib/features/journal/share_card_screen.dart` — the share screen
- `lib/features/journal/share_card.dart` — the card widget
- tests: `test/domain/rules/{position_delta,listing,share_card}_test.dart`,
  `test/state/portfolio/portfolio_controller_test.dart`,
  `test/state/entitlements/pro_feature_gate_test.dart`,
  `test/features/portfolio/portfolio_screen_test.dart`,
  `test/features/journal/share_card_screen_test.dart`,
  `test/features/goldens/share_card_golden_test.dart`,
  `test/features/goldens/share_card_{light,dark}.png`

**Modified**

- `lib/domain/rules/capital_committed.dart` (additive: bars, track max, portfolio definition)
- `lib/domain/rules/obligation.dart` (additive: `expirationsInMonth`)
- `lib/domain/rules/premium_collected.dart` (`_inPeriod` → public `inPeriod`)
- `lib/domain/rules/bucket.dart` (additive: `kBucketOrder`, `bucketCountsFor`)
- `lib/core/format.dart` (additive: `monthYearText`, `signedSharesText`, `percentText`)
- `lib/core/purchases/paywall_copy.dart` (additive: `kPortfolioFeatureName`)
- `lib/core/app_router.dart` (additive: `/portfolio`, `/journal/share`)
- `lib/state/today/today_controller.dart` (`_bucketOrder`/`_bucketIndex` removed;
  `_capitalInputs` lifted out; `bucketCounts` delegates)
- `lib/state/entitlements/entitlement_providers.dart` (additive: `proFeatureGateProvider`)
- `lib/features/today/today_screen.dart` (the "Committed now" tile gains an `onTap`)
- `lib/features/journal/journal_screen.dart` (one app-bar action)
- `lib/features/settings/settings_screen.dart` (one more `ref.invalidate`)
- `test/features/paywall/paywall_entry_points_test.dart` (the pinned list grows to five)
- `test/features/settings/settings_screen_test.dart`,
  `test/state/entitlements/nothing_locks_test.dart`,
  `test/domain/rules/{capital_committed,obligation,premium_collected,bucket}_test.dart`,
  `test/core/format_test.dart`
- `test/features/today/today_screen_test.dart` — **listed but not modified.** Phase 5's
  Predicted Files named it because the "Committed now" tile gains an `onTap`; the tile's
  existing assertions already cover the figure, the definition line and the flag lines, and
  S-291's push-versus-paywall behaviour is asserted in
  `test/features/paywall/paywall_entry_points_test.dart` (the pinned call-site list) and
  `test/features/portfolio/portfolio_screen_test.dart`. No assertion in the Today screen suite
  needed to move, so the file is untouched and the entry is recorded here rather than left as
  an unexplained gap (review finding 14).
- `docs/architecture/wheel-triage.md`
- `docs/plans/pro-wave-3-plan.md` (this file: Progress, Assumption Log, Status)

**Dependents that only *read* a touched surface — must stay green, no edits expected**

- `lib/features/today/expiring_this_week_card.dart` (reads `obligation.expiringThisWeek`)
- `lib/features/today/past_expiration_card.dart` (reads `todayControllerProvider`)
- `lib/state/preferences/preferences_provider.dart` (reads `capital_committed`'s range validators)
- `lib/data/export/ledger_csv.dart`, `lib/widgets/journal_row.dart`,
  `lib/widgets/cycle_summary_card.dart`, `lib/state/positions/position_detail_controller.dart`
  (read `cycle_pnl`)
- `lib/features/paywall/paywall_screen.dart` (reads `kPaywallFeatures`)
- `lib/main.dart:34` (`buildAppRouter`)
- `lib/features/settings/rule_profile_section.dart` (reads `format.dateText`)

**Explicitly not touched**

`pubspec.yaml`, `lib/data/db/**` (schema stays v6, no new artifact),
`lib/data/wheel_repository.dart` and both implementations (no new method),
`lib/domain/rules/{formulas,triage_input,classify,expiry,reading_age,journal_aggregates,cycle_pnl}.dart`,
`lib/core/disclaimer.dart`, `lib/core/theme/**`, `.claude/**`, `.github/**`.

## Notes

**Phase dependency graph.** See the diagram in Iteration 1. Phase 1 gates both chains; the
card chain (2→3) and the Portfolio chain (4→5) are independent; Phase 6 gates on both.

**Predicted intermediate states.**

- After Phase 1: `bucket.dart`, `capital_committed.dart`, `obligation.dart`,
  `premium_collected.dart` and `format.dart` carry new public helpers that nothing calls yet,
  and `TodayController` has lost two private members with no behaviour change. The app builds
  and Today is byte-identical. `flutter analyze` must be clean — dead-code lint is off for
  public API in this project, but an unused **private** member is not permitted, which is why
  `_bucketIndex` is removed in the same phase as the list it indexes.
- After Phase 2: `share_card.dart` exists and is fully unit-tested with no UI. Nothing imports
  it yet.
- After Phase 3: Stage 8 is **shippable on its own**. `/journal/share` works end to end, the
  card exports, and no Pro code exists. If the wave had to stop here, the free feature is
  complete and the Pro feature is untouched.
- After Phase 4: the Portfolio state and the Pro gate exist and are unit-tested; the screen
  does not. `proFeatureGateProvider` has exactly one caller in tests and none in `lib/`, which
  is the expected intermediate state, and Phase 5 adds its real caller in the same change that
  adds the screen.
- After Phase 5: the wave's behaviour is complete. Phase 6 is docs and residue only.

**Legacy handling.** No migration, no backfill, no data change. Both new surfaces read the
schema-v6 tables the app already writes. A book recorded before Wave 3 renders identically on
both new screens because neither depends on anything added in this wave — the delta reads
`Snapshot.deltaConvention`, which has been per-snapshot since the first iteration, and the
card reads `WheelCycle.endedAt` and the fee columns added in v3.

**A cycle with no legs is invisible, by design.** `capitalInputsFor` derives its inputs from
legs, so a `WheelCycle` row with no legs contributes no committed capital, no bucket and no
delta. That is the existing behaviour (Today's ledger does the same) and this wave does not
change it. Recorded here so it is not mistaken for a defect during verification.

**The paywall's outstanding promise.** `kPaywallFeatures` lists "Screenshot scan" with a
detail line. After this wave that entry is the only one on the list that describes work not
yet built. It is left in place deliberately: removing and re-adding it would churn the paywall
copy twice, and the Pro release's plan has Stage 6 in Wave 4. Flagged as owner question Q6 so
the choice is visible rather than silent.

**The reference's Portfolio arithmetic is not a fixture.** The percentages in
`docs/design/pro-ui-reference.html`'s per-underlying bars cannot be reproduced from the
positions its own obligation rows name, and its delta sum includes a term its own "Left out"
note excludes. The reference is non-binding intent for *layout and copy*; the fixtures in
S-293…S-303 are authored in this plan and are the expected values. Verification compares
against the plan, not against the HTML.

**Goldens are Mac-only.** `test/features/goldens/` renders differently on other operating
systems; the two new goldens follow the existing policy (generated and verified on the Mac
that owns this repo). Phase 3's `Done Criteria` name the golden suite explicitly so a
non-Mac run is not mistaken for a failure.

**`now` stays a parameter.** Every new rules function takes `now`; no new code calls
`DateTime.now()` inside `lib/domain/rules/`. The screen passes its own `now` down, so every
scenario above is deterministic.

**What "one implementation, two views" costs.** Portfolio and Today now share
`book_reads.capitalInputsFor` and `bucket.bucketCountsFor` across a state-layer boundary, so a
future change to how a cycle's capital inputs are assembled lands once and both screens move
together — which is the point. The cost is that a defect there shows on two screens at once,
which is why S-293 and S-302 assert the two screens against **each other** rather than each
against a literal: a literal would let both drift together.

## Progress

| Phase | Owner | Status | Evidence |
|---|---|---|---|
| 1 — Rules and formatters | @data-architect | **Complete** | `flutter analyze` clean; `flutter test test/domain/rules test/core/format_test.dart test/state/today/today_controller_test.dart` → 382 passed, 0 failed; purity + colour greps empty |
| 2 — Card month and figures | @data-architect | **Complete** | `flutter test test/domain/rules/share_card_test.dart test/domain/rules/cycle_pnl_test.dart test/domain/rules/journal_aggregates_test.dart` → 50 passed, 0 failed |
| 3 — Card screen, capture, share | @developer | **Complete** | `flutter analyze` clean; `flutter test test/features/journal test/features/goldens test/features/settings` → 54 passed, 0 failed; `share_plus`-in-`lib/features/`, tone and rules-purity greps empty |
| 4 — Book reads, Portfolio state, Pro gate | @developer | **Complete** | `flutter analyze` clean; `flutter test test/state test/features/settings test/features/today` → 291 passed, 0 failed |
| 5 — Portfolio screen, Today entry, routes | @developer | **Complete** | `flutter analyze` clean; `flutter test test/features/portfolio test/features/today test/features/paywall test/state` → 315 passed, 0 failed; colour-literal grep empty |
| 6 — Closeout | @developer | **Complete** | `flutter analyze` clean; full `flutter test` → **1070 passed, 0 failed**; every residue command returned its expected result |
| Review fix round 1 | @developer | **Complete** | `flutter analyze` clean; full `flutter test` → **1076 passed, 0 failed**; tone, rules-purity, colour-literal, `share_plus`-in-`lib/features/` and `\.shareFiles(`-call-site greps all as expected. All 14 review findings closed: 1 Blocker, 6 Major, 7 Minor. Red-first evidence for findings 1–4 and 7: `+19 -6` with the four `lib/` fixes reverted, `+25` with them restored. See `## Feedback` for the per-finding guards. |

Full suite after Phases 1–2: **1027 passed, 0 failed**; `flutter analyze` clean; the tone,
rules-purity and colour-literal greps all empty.

Full suite at closeout: **1070 passed, 0 failed**; `flutter analyze` clean; the tone,
rules-purity, colour-literal, `share_plus`-in-`lib/features/`, `_bucketOrder`/`_bucketIndex`
and `_inPeriod` greps all empty; `context.push('/paywall'` in exactly one file;
`showPaywall(` in exactly five; `lib/data/db/schema/` holds v1–v6 with no v7.

Full suite after review fix round 1: **1076 passed, 0 failed**; `flutter analyze` clean; the
tone, rules-purity, colour-literal, `share_plus`-in-`lib/features/` and `\.shareFiles(`
call-site greps all as expected. The two S-310 goldens were regenerated (A-27).

Baseline at planning time: `flutter analyze` clean; `flutter test` **925 passed, 0 failed**;
`AppDatabase.schemaVersion == 6`; schema artifacts v1–v6 present; the tone, rules-purity and
colour-literal greps all empty.

## Assumption Log

Executors append here and never stop on ambiguity: pick the option most consistent with the
Ledger and the Feature Invariants, record the decision, the options considered and the
rationale, and continue. The Conductor then marks each entry **RATIFIED** (promoted to a D-x)
or **REVERT** (remediation opened). An empty log after a complex phase is itself suspicious.

_(Phases 1–2, @data-architect. Each entry awaits **RATIFIED** / **REVERT**.)_

**A-1 — `leftOutLine` names the no-reading clause first, but decides the single reason
past-expiration-first.** D-43 says "reasons in the order above" (past expiration, then no
reading), yet its own pinned example and S-297 both read the no-reading clause first
(`AAL, WBD (no delta reading) · INTC (past expiration)`). Options: follow the ordering
sentence, or follow the pinned string. Chose the pinned string, since a pinned fixture is
the more specific statement; the ordering sentence still governs *which* reason a leg that
is both past expiration and unread is named under, so such a leg appears once, under "past
expiration". S-297 pins both facts.

**A-2 — tickers inside a `leftOutLine` clause are sorted A–Z, contradicting S-297's literal
`WBD, AAL`.** D-43 states normatively that tickers are A–Z within a clause; S-297's pinned
string is `WBD, AAL (past expiration)`. Options: preserve the fixture's insertion order, or
apply the stated rule. Chose the stated rule (`AAL, WBD`), because an unstable order would
make the line depend on book order and the rule is stated as a rule. **The owner should
confirm**: if the literal fixture string is normative, this is a one-line revert.

**A-3 — S-297's delta sign is internally inconsistent with D-43's convention rule.** S-297
gives an INTC put ×4 with `deltaConvention: option` and a delta of `+0.19`, then asserts a
net of `+76`. Under D-43 an option-convention delta is entered with the position's own sign,
so a short put is entered negative; `+0.19` with the `option` convention reads as a *long*
put. Options: store the fixture's `+0.19` verbatim and expect `−76`, or take the fixture's
own `+76` as the intent and enter `−0.19`. Chose the latter, because the scenario's title and
its two other legs are all about a short book, and because the test then pins the conversion
`positionDelta` actually performs. The test comment records the discrepancy.

**A-4 — the input shapes of `netPositionDelta`'s `book` and the share card's cycle list.**
The plan writes `Iterable<...>` and `List<...>`. Chose record typedefs
(`DeltaCycleEntry`, `DeltaLegEntry`, `ShareCardCycle`) over new model classes, since none of
these are persisted or serialized and the state layer already assembles their inputs — a
model class would be a persisted-looking type with no persistence, and the plan does not put
them in `{{MODEL_DIR}}`. `DeltaLegEntry` carries `(Leg, Snapshot?)` rather than a precomputed
magnitude so the conversion stays inside the rules layer.

**A-5 — `concentrationKeyLine` is a fourth additive helper in `capital_committed.dart`.**
The plan names three (`concentrationTrackMaxPct`, `concentrationBars`,
`portfolioCommittedDefinition`) but S-294 pins the rendered string
`Limit 25% · bars run to 30%`. Options: let the Phase 5 screen assemble the string, or add
the formatter beside its inputs. Chose the helper, so the string is asserted where the
numbers are and the screen keeps no copy of it. `concentrationBars` takes
`concentrationLimitPct` although it does not read it — the plan pins the signature to mirror
`concentrationFlags`, so a caller has the same arguments for both.

**A-6 — `calendarMonth` returns the first of the month.** D-45 fixes the month but not the
day. Chose the 1st, because the calendar renders a grid and the day is never displayed;
returning `now` would make the value look like a date that means something. It is also the
fallback for "no open legs at all" (the month containing `now`), per S-301.

**A-7 — `kBucketOrder`'s five prototypes carry `reason: ''`.** D-46 needs a five-row order
independent of any book. Options: a `List<Type>`, or a `Bucket` prototype list. Chose
prototypes so `bucketCountsFor` can return the same value type it counts and Phase 4 can
render the label from the row itself; the empty reason is never displayed, since the counts
are rendered as labels, not as bucket results.

**A-8 — the "before fees" clause is appended to the net-result line even though D-52's
pinned copy already ends in `before fees`.** D-50 says the clause is appended to the
net-result line when a gap exists; S-307 pins `Net result $357.00 before fees` for the
no-gap case. Implemented literally: the line always ends `before fees`, and the gap sentence
follows it when there is one, giving `Net result $357.00 before fees Before fees: 3 closed
legs have no fee recorded.` This reads badly and is probably an unintended duplication — see
Open questions. The alternative (drop the trailing `before fees` when the gap sentence
follows) contradicts neither fixture but contradicts D-52's stated reason for the word.

**A-9 — `shareCardDefinitionLine` takes a rendered `String monthYear`, and `netResultLine`
keeps a private `_money`.** `lib/domain/rules/` may import only `lib/domain/models/`, so
`lib/core/format.dart` is out of reach from the engine. Chose to pass the already-formatted
month and to keep the two-decimal money formatter private in `share_card.dart`, mirroring
`obligation.dart`'s `_dollars` and `capital_committed.dart`'s `_wholeDollars`. The callers
(Phase 3's screen) do the `monthYearText` call.

**A-10 — `ShareCardFigures.averageDaysInCycle` is `int?`.** `journal_aggregates.averageDaysInCycle`
returns `0` for an empty list, which would render as `0 days` for a month with no cycles.
D-55 says an empty month renders no card at all, so this is unreachable from the screen, but
the rule returns `null` anyway so a caller cannot mistake "no cycles" for "zero days". The
other four figures are non-null by construction.

**A-11 — `signedSharesText` groups thousands.** The plan pins `+535 shares` / `−25 shares` /
`0 shares` and the edge case "1000+ separators". Chose `+1,200 shares`, matching
`format.dart`'s existing grouped-money style. Zero renders with no sign (`0 shares`) since a
signed zero would be noise.

**A-12 — two plan statements about existing code are inaccurate.** `_inPeriod` has **both**
call sites inside `premium_collected.dart` (not "its one caller in
`lib/state/today/today_controller.dart`"), and the today controller's rank helper is named
`_rank`, not `_bucketIndex`. Implemented against the code as it is; the residue sweep for
`_bucketOrder`, `_bucketIndex` and `_inPeriod` is empty.

**A-13 — `listPhraseWithReason` uses a bare comma join, not `listPhrase`'s "and" form.**
D-43 states `A, B (reason)` explicitly, so `listPhraseWithReason(['WBD','AAL'], 'past
expiration')` renders `AAL, WBD (past expiration)` rather than `AAL and WBD (past
expiration)`. The two functions therefore share no join helper.

_(Phase 3, @developer. Each entry awaits **RATIFIED** / **REVERT**.)_

**A-14 — the share screen's app bar reads `Share September`, and `monthName` was added to
`lib/core/format.dart` to produce it.** D-53 pins the title as `Share <month>` and S-311 pins
the literal `Share September`, but the only month formatter that existed was
`monthAbbreviation` (`Sep`). Options: use the abbreviation and fail S-311, or add a full-name
formatter. Chose the formatter, since S-311's literal is the more specific statement and the
abbreviation would also read oddly in an app bar. `monthName` sits beside `monthAbbreviation`
and shares its `_monthsFull` table, so the two cannot drift. This is one line outside Phase
3's Predicted Files.

**A-15 — `XFile` is re-exported from `lib/state/export/export_controller.dart`.** D-53 requires
`XFile.fromData` in the screen, but S-309's structural test forbids `share_plus` under
`lib/features/`. Options: import `share_plus` in the screen (fails the structural test),
import `cross_file` directly (a new direct dependency, and the working agreement says ask
first), or re-export `XFile` from the file that already owns the share seam. Chose the
re-export: `share_plus` already does `export ... show XFile`, so the screen gets the same type
the seam takes, from the same import, with no new dependency and no second seam. One line
outside Phase 3's Predicted Files.

**A-16 — the two toggles are local `State` on a `ConsumerStatefulWidget`, not a controller.**
D-52 says the toggles are session state that resets on open and are never persisted. Options:
a `StateNotifier` (a controller for two booleans, and one more thing to dispose), or local
`State`. Chose local `State`, which makes "resets on open" true by construction rather than by
a reset call someone can forget, and which S-308 pins by asserting a re-push starts both off
and that `updatePreferences` is never called.

**A-17 — S-306's month is built through the repository, and its loss cycle carries the loss as
a close *fee*.** The reference card's five figures are not reproducible from a plain
`closeLeg` book: a single-leg cycle's capture is `netCredit / openCredit`, so a close debit
large enough to make the cycle a loss also drives its capture negative, and the reference's
loss cycle reports 100%. Options: change the fixture's capture (fails S-306's median of 82%),
or route the loss through a fee. Chose the fee: KO is assigned and then called away, its put
leg carries `closeFee: Decimal.zero` (so it is not a fourth fee gap) and its call leg carries
`closeFee: 62.00`, giving `0.32 x 100 + 0.00 x 100 - 62 = -30` with a 100% capture. This also
exercises the assignment → call-away path, which is the only way a cycle reaches `closed` on
the call side. The fixture lives in `test/support/share_card_fixtures.dart` so the screen test
and the golden test cannot drift onto different months.

**A-18 — the card's footer is a `Flexible` + `FittedBox(scaleDown)`.** *(Promoted to **D-56**
by review finding 14; the entry is kept so the log's numbering stays stable.)* The card is a
fixed 360 × 450 surface (D-53) and the footer is `kAppDisclaimer` verbatim (D-54), which is
~300 characters. At the test environment's font — every glyph a square, so text is far wider
than real — the disclaimer alone measures 260px tall and the definition line 140px, which
overflows the fixed surface. Options: let the card grow (breaks the 1080 × 1350 contract),
clip the footer (loses the disclaimer), or scale the footer down. Chose
`FittedBox(scaleDown)` inside a `Flexible`, which is a no-op at real font sizes and degrades
by shrinking rather than by overflowing at large text scales.

**A-19 — S-308 asserts A-8's duplicated string.** The rendered net-result line is
`Net result $357.00 before fees Before fees: 3 closed legs have no fee recorded.` — the
duplication A-8 already logs. Phase 2 shipped it literally and S-307 pins the no-gap half, so
the screen test asserts what the engine produces rather than a string the engine does not.
Fixing the duplication is A-8's open question, not this phase's.

**A-20 — `PortfolioScreen` takes an optional `now`.** The screen's clock was `DateTime.now()`
inside `load()`, which made every date-bearing assertion (the aging note, the calendar's month,
the "as of" sub-line) drift with the day the suite ran. Options: leave the clock real and date
the fixtures relative to `DateTime.now()`, or add a seam. Chose the seam — `PortfolioScreen({this.now})`
and `buildAppRouter({DateTime? portfolioNow})` — matching `ShareCardScreen`'s existing pattern.
Production passes nothing. See Open questions.

**A-21 — the calendar's obligation rows use `shortWeekdayDateText`, not `weekdayDateText`.**
S-300 pins `Fri Oct 2` (D-13's expiry-card form, no comma); `weekdayDateText` is Today's own
comma-bearing header form. Chose the D-13 formatter, which already existed.

**A-22 — S-297's fixture is corrected to the `position` convention.** The plan's S-297 fixture
says INTC is `option` convention with `deltaAsEntered: +0.19` and expects `+76`. S-296's own
table pins `option` convention as recording the option's own delta, which for the short leg
this app models is the negation — so `+0.19` under `option` is a *long* put and yields `−76`.
The engine is right and the fixture was wrong; the test uses `position` convention to reach the
pinned `+76`. Flagged rather than "fixed" in the engine.

**A-23 — S-297's "Left out" example string transposes two tickers.** The plan's S-297 expected
outcome reads `Left out: PFE (no reading); WBD, AAL (past expiration)`, but `leftOutLine`'s own
doc comment (and `_sorted`) pin **A–Z within a clause**. The engine renders `AAL, WBD`; the test
asserts the engine's documented order.

**A-24 — the calendar grid's rows carry `ValueKey('portfolio-calendar-row-<n>')`.** S-303 pins
the leading-pad count, which is only observable from the grid's own cells. The pad cells carry
the previous month's day numbers, so the count is the index of the cell reading `1`. The key is
the seam the test reads; it is not a visual change.

_(Review fix round 1, @developer. Each entry awaits **RATIFIED** / **REVERT**.)_

**A-25 — the duplicate "before fees" wording is left exactly as written.** Review finding 13
raises that the card renders `Net result $357.00 before fees` and the definition paragraph ends
`Before fees: 3 closed legs have no fee recorded.`, so the phrase appears twice on one image.
Both strings are pinned by two decisions (D-50 appends the clause to the net-result line; D-52
pins the line's own trailing `before fees`) and by S-306/S-307/S-308, and A-8/A-19 already log
the duplication. Options: change one of the two strings (contradicts a pinned fixture and one
of the two decisions), or leave it and escalate. Chose to **leave it and escalate** — the
brief's finding 13 says explicitly not to change it, and giving the clause one home is a
plan-level decision the owner has to make, not a developer edit. Recorded here as an
owner-decision item; see Open questions.

**A-26 — `signedSharesText` now rounds through `Decimal.parse(value.toString()).round()`.**
Review finding 11: the function used `value.round()` where D-43 pins the `Decimal` form, which
is a second rounding code path in a rule whose stated purpose is that the app have one.
Verified empirically that `Decimal.round()` is half-away-from-zero (`2.5 → 3`, `−2.5 → −3`,
`0.5 → 1`, `−0.5 → −1`), so the two forms agree on every value in play and the change is
behaviour-preserving; `_grouped` now takes a `BigInt` because `Decimal.round()` returns a
`Decimal`. The existing `format_test.dart` cases (including the half-away-from-zero and
four-figure-grouping ones) pass unchanged.

**A-27 — the card's toggle lines moved into the footer's inner `Column`, and the goldens were
regenerated.** Review finding 10: D-52 says the dollars and tickers lines sit "one line under
the definition paragraph", but they rendered above the footer that holds it. Options: move the
lines (changes the rendered tree) or correct D-52 (contradicts the decision's own wording).
Chose to move them, which is what the decision says. The lines now render in the order
definition → dollars → tickers → disclaimer, and they inherit the footer's `labelSmall` style
so the footer reads as one block. **The two S-310 goldens were regenerated** — the lines are
visible in the golden fixture (`showDollars: true, showTickers: true`), so the images
genuinely changed; the goldens are untracked files from this wave, so regenerating them is the
correct action rather than a baseline edit. The card's fixed 360 × 450 surface and the
1080 × 1350 export contract are unaffected (S-309 still passes).

**A-28 — the S-309 call-site count greps `lib/` for `\.shareFiles(` and expects exactly two
hits.** Review finding 9: the plan pins a call-site count for `ShareSheet.shareFiles`, and the
structural test only asserted the `share_plus` import ban. The two call sites are
`lib/features/journal/share_card_screen.dart:69` and
`lib/features/settings/settings_screen.dart:50`; the declaration and the implementation in
`lib/state/export/export_controller.dart` do not match the leading dot. The test asserts the
count and names both files, so a third caller fails with a message that says why.

## Feedback

### Review fix round 1 — remediation guards

The Pro Wave 3 review (`.work/runs/20260929-200036-code-reviewer/output.log`, verdict
CHANGES_REQUESTED: 1 Blocker / 6 Major / 7 Minor) is closed by
`.work/pro-wave-3/brief-fix-1.md`. Each finding that could regress carries a guard, so the
next agent reads the guard rather than re-deriving it:

| Finding | Guard |
|---|---|
| 1 (Blocker) — Portfolio's DTE was a raw instant difference | `test/state/portfolio/portfolio_controller_test.dart`, group *"the DTE gate reads the same calendar difference Today does"*: a leg whose raw `difference().inDays` and calendar DTE disagree must classify the same on both screens. `_dte` is deleted; `formulas.dte` is the only DTE in the app. |
| 2 (Major) — the count population could drift from Today's | The same file's S-302 tests: a past-expiration open leg is in **neither** the five counts nor the aging note, and both screens' counts are asserted equal. `today_controller.dart`'s `bucketCounts` doc comment names the shared population. |
| 3 (Major) — the calendar read the wall clock | `test/features/portfolio/portfolio_screen_test.dart`, S-299's *"today is outlined even as a leading cell"*: the outline is asserted on a pinned clock, so a `DateTime.now()` regression fails on any day but the fixture's. |
| 4 (Major) — a refresh dropped the injected clock | The same file's *"a reload reads the screen's own clock, not the wall clock"*: the rendered text is asserted byte-identical across a `RefreshIndicator` refresh. |
| 7 (Major) — S-302's screen half did not test the scenario | The same file's S-302 test: the enumerated 7-leg fixture, a profile edit, a pinned `standard-v1` leg, and counts + order + pin asserted on both screens. |
| 8 (Minor) — S-304 asserted 3 of 5 label families | The same file's S-304 test asserts all five: the committed total, the bar's ticker + dollars + percent, the delta's shares, the count tiles and the obligation rows. |
| 9 (Minor) — S-309's structural half was incomplete | `test/features/journal/share_card_screen_test.dart` asserts `\.shareFiles(` has exactly two call sites in `lib/` and names both files. |
| 11 (Minor) — a second rounding path | `lib/core/format.dart`'s `signedSharesText` uses D-43's pinned `Decimal` form; `test/core/format_test.dart` pins the half-away-from-zero and grouping cases. |

Findings 5, 6 and 14 are documentation corrections with no runtime guard; 10 and 12 are
cosmetic/dead-code fixes; 13 is escalated to the owner (A-25).

**Red-first evidence.** Findings 1–4 and 7 were written as tests before the fix and confirmed
red: with the four `lib/` fixes temporarily reverted, the two portfolio suites ran
`+19 -6` with exactly the six intended failures (past-expiration counts, past-expiration aging,
the DTE gate, the calendar's today outline, the refresh clock, and S-302's counts/order/pin).
Restoring the fixes gave `+25` all green.

## Open questions

Split into questions only the owner can answer, and questions this plan resolved with a logged
assumption that the owner may veto before the phase that depends on it.

### Owner-only

1. **Stage 6's broker and screenshot fixtures.** The brief's D-P10 requires the owner to name
   the broker the screenshot scan targets, and its 95%-accuracy criterion needs 20+ real
   screenshots to test against. Neither is available, which is why Stage 6 is out of this
   wave. When both exist, Stage 6 can be planned as its own wave with a real fixture set.
2. **Does the Portfolio calendar need month navigation?** This plan shows one month (D-45),
   because Stage 7's criterion is "a month calendar". Navigation would let a user look ahead
   past the nearest expiration; it also adds a control to a screen whose purpose is "what
   comes due next".
3. **Should the share card gain a month picker?** This plan shares the month containing today
   (D-47). A picker would let a user share any closed month; it also makes the screen's app bar
   ("Share September") a control rather than a label.
4. **The card's footer.** This plan renders `kAppDisclaimer` verbatim (D-54), because the brief
   asks for D-P15 verbatim and the app should hold one wording of its own disclaimer. The
   reference draws a shorter three-part line instead. If the shorter line is wanted, the app
   then has two disclaimer wordings and the architecture doc's drift-risk table should carry
   that fact.
5. **The card's return on capital precision.** This plan shows one decimal (`1.6%`, D-48),
   matching the Journal's own rendering of the same quantity and keeping small months
   distinguishable. A whole percent would match the other four figures' style.
6. **The paywall's "Screenshot scan" promise.** `kPaywallFeatures` currently lists it, and
   after this wave it is the only listed feature that is not built. This plan leaves it
   unchanged (D-39). Say if you would rather it be removed until Stage 6 ships.
7. **"Before fees" appears twice on one shared image.** The card renders
   `Net result $357.00 before fees` and the definition paragraph ends
   `Before fees: 3 closed legs have no fee recorded.` Both strings are pinned by two decisions
   (D-50 appends the clause to the net-result line; D-52 pins the line's own trailing
   `before fees`) and by S-306/S-307/S-308. Review finding 13 asks for the clause to have one
   home; the fix round left both strings exactly as written (A-25) because changing either
   contradicts a pinned fixture and one of the two decisions. **This is the one review finding
   that needs an owner call:** drop the trailing `before fees` from the net-result line when
   the gap sentence follows, or drop the clause from the definition paragraph, or accept the
   duplication as written.

### Resolved with a logged assumption — vetoable

7. **Portfolio's entry point is Today's "Committed now" tile, not a bottom-bar destination.**
   The reference says "reached from Today's ledger strip", and the bottom bar is fixed at five
   destinations (Wave 1 D-14). Assumed the tile is the right affordance and that the other two
   tiles stay inert. (D-40)
8. **The calendar shows the month of the next upcoming expiration, so today may fall outside
   the shown month.** Assumed from the reference's own Sep 28 / October 2026 case, and because
   the question the calendar answers is "what comes due next". (D-45)
9. **Portfolio reuses Today's aging-note wording verbatim** rather than the reference's
   "Uses 1 reading older than 7 days: …" phrasing. Assumed one fact should have one wording.
   (D-44)
10. **Exclusion reasons are evaluated past-expiration-first, so a leg that is both past
    expiration and unread is named once.** Assumed the actionable list (needs recording) is
    the more useful one. (D-43)
11. **A closed cycle with a null `endedAt` belongs to no month** rather than falling back to
    `startedAt`. Assumed a card should never claim a cycle closed in a month in which nothing
    closed. (D-47)
12. **A cycle whose net result is exactly zero is not "closed positive."** Assumed the strict
    `> 0` rule `winRate` already uses, so the card and the Journal cannot disagree. (D-49)
13. **The bar track's maximum is `limit × 1.2`, not a fixed 30%.** Assumed from the
    reference's `Limit 25% · bars run to 30%` reading as a consequence of the limit rather than
    a constant, so a user with a 50% limit does not see every bar clipped. (D-42)
14. **Portfolio's count tiles are read-only, not filters, and are not the same widget as
    Today's.** Assumed the shared thing is the order and the count, asserted by a test rather
    than by a shared widget. (D-46)
15. **A month with no closed cycles renders no card and no share button.** Assumed nothing
    misleading should be shareable. (D-55)
16. **"Before fees" is omitted entirely when there is no fee gap**, rather than rendering
    "Fees included". Assumed the app should not claim something it has not verified for every
    leg. (D-50)
17. **The card's two toggles are session state and are not persisted**, so this wave adds no
    schema version. Assumed a privacy-safe default should be true by construction rather than
    by a stored flag. (D-52)
18. **The card's header and the calendar's header both use a new hand-rolled
    `format.monthYearText`** rather than `intl`'s `DateFormat`. Assumed the app's existing
    hand-rolled, locale-independent date formatting should be kept. (D-51)
19. **The card's `Net result` line shows two decimals** while the five figures are whole.
    Assumed OC-12's tile-versus-row rule applies. (D-52)
20. **The reference's shorter obligation line for calls** (`100 shares delivered at $28`,
    without `if assigned`) is superseded by the shipped `obligationFor` text. Assumed the app
    should keep the sentence the Today card already renders. (D-45)
21. **The card's toggle lines moved into the footer's inner `Column`**, so they render under
    the definition paragraph and above the disclaimer, and the two S-310 goldens were
    regenerated. Assumed D-52's "one line under the definition paragraph" is the binding
    statement and that a golden regenerated for a deliberate layout change is correct rather
    than a baseline edit. (A-27)
22. **`signedSharesText` rounds through `Decimal.parse(value.toString()).round()`**, D-43's
    pinned form, rather than `double.round()`. Assumed the rule's stated purpose — one rounding
    rule in the app — outweighs the two forms' agreement on every value in play. (A-26)
