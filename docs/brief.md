# Build brief: Wheel Triage (Flutter, iOS)

> Scope note for this build: **iOS only.** The user will run it in the macOS
> iOS Simulator. Android-specific work in §9 (allowBackup, data_extraction_rules)
> is out of scope for now; do not delete the requirement, just defer it.

---

## 1. What this app is

A decision-support tool for a self-directed options trader running the **wheel
strategy** (sell cash-secured puts -> take assignment -> sell covered calls ->
get called away -> repeat).

The app does exactly three things:

1. **Screen** a candidate trade before it is opened, and score how appealing it looks.
2. **Triage** open positions into one of four buckets by applying fixed arithmetic
   rules to numbers the user types in.
3. **Record** what happened, so the user can see realised performance and
   portfolio-level exposure.

**All market data is entered by hand.** The app never fetches quotes, never calls a
broker API, never scrapes. The user reads numbers off their broker screen and types
them in. This is a deliberate constraint, not a limitation to be designed around --
do not add network data fetching, and do not build abstractions "ready for" a data
feed. Build for manual entry.

**All storage is on-device.** No accounts, no cloud sync, no backend. Because of
this, **backup/restore via file export is a first-class feature, not a nice-to-have**
(see §9).

### The tone that matters

This is a calculator that applies the user's own thresholds. It is **not** an
advisor. It has no view on any security, makes no predictions, and forecasts
nothing. The bucket labels are the output of arithmetic the user configured.

This must show up in the code and the copy:

- Never use the words "recommend", "should", "buy", "sell signal", "opportunity",
  "we suggest", or "our analysis".
- Bucket names are neutral verbs describing an action the user might take:
  `Close`, `Roll`, `Assign`, `Leave`.
- Every bucket verdict in the UI must be accompanied by the *reason*, stated as the
  rule that fired: "50% of credit captured", "Delta 0.72 above your 0.70 threshold".
  Never a bare verdict.
- The screener's 0-9 score is a **sorting aid**, not a verdict. Label it as such in
  the UI. It must never be the largest element on the screen.

---

## 2. Tech stack

Use these unless you hit a concrete blocker, in which case stop and explain.

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.x / Dart 3.x | Target iOS + Android from one codebase |
| State | Riverpod 2.x (code-gen, `@riverpod`) | Compile-safe DI, easy to test the rules engine in isolation |
| Persistence | **Drift** (SQLite) | Relational data with real migrations. Positions -> legs -> snapshots is genuinely relational |
| Routing | go_router | Deep-link ready, declarative |
| Models | freezed + json_serializable | Immutable value types, exhaustive union handling for bucket results |
| Money/precision | **`decimal` package** | See the warning below |
| Charts | fl_chart | Delta history, P&L curves |
| Notifications | flutter_local_notifications | Local-only DTE reminders |
| Testing | flutter_test + mocktail | Rules engine gets exhaustive unit tests |

### Precision warning -- read this before writing any math

**Do not use `double` for money or for any value that feeds the rules engine.**
Binary floats will produce `0.1 + 0.2 = 0.30000000000000004`, and a credit-captured
calculation that lands on 49.999999% instead of 50% will silently fail to fire a
gate. That is a real bug class in financial apps and it is hard to spot.

Use the `decimal` package for: strikes, credits, option marks, underlying prices,
and all P&L. Store them in SQLite as **integer cents** (or integer ten-thousandths
for option marks, which quote in pennies but can have sub-penny fills) and convert
at the boundary.

Greeks (delta, gamma, theta, vega) and IV are dimensionless statistics, not money --
`double` is fine for those, but round to a fixed number of places for display and
comparison. Compare deltas with a small epsilon rather than exact equality.

---

## 3. Domain model

This is the part most likely to be got wrong, so it is specified in detail. Read
the whole section before creating any tables.

### 3.1 The entities

```
Underlying        ticker, display name, user notes
  |__ WheelCycle  one full loop: put -> (assignment) -> calls -> (called away)
        |__ Leg   one option contract as opened; a roll closes one Leg and opens the next
        |     |__ Snapshot   a dated reading of the numbers off the broker screen
        |__ ShareLot         100 x contracts shares, created on assignment
```

### 3.2 WheelCycle

A cycle is the unit the user actually cares about for P&L. It starts when the first
put is sold and ends when shares are called away (or the user manually closes it
out). A cycle that never gets assigned still ends -- it just ends on the put side.

Fields: `id`, `underlyingId`, `startedAt`, `endedAt?`, `status`
(`sellingPuts` | `holdingShares` | `closed`), `outcome?`
(`expiredWorthless` | `closedEarly` | `calledAway` | `abandoned`).

### 3.3 Leg -- and the roll chain

**This is the piece the naive version of this app gets wrong.** A leg is one
contract as it was opened. When the user *rolls*, they are not modifying the leg --
they are closing one leg and opening another, in a single transaction. The chain
matters because the credit on the current leg is **not** the cumulative credit on
the trade.

Fields:

- `id`, `cycleId`, `sequence` (0, 1, 2... within the cycle)
- `optionType`: `put` | `call`
- `strike` (integer cents)
- `expiration` (date)
- `contracts` (int, always positive; the app only models short premium)
- `openedAt`, `openCreditPerShare` (integer, ten-thousandths)
- `closedAt?`, `closeDebitPerShare?`
- `closeReason?`: `rolled` | `closedEarly` | `expiredWorthless` | `assigned`
- `rolledFromLegId?` -- back-pointer forming the chain
- `ivAtOpen?`, `ivRankAtOpen?`, `deltaAtOpen?`, `underlyingPriceAtOpen?`

Derived, never stored:

```
legNetCredit      = openCreditPerShare - (closeDebitPerShare ?? 0)
cycleCumulativeCredit = SUM legNetCredit over all legs in the cycle
```

When a roll is recorded, it is **one user action producing two writes**: close leg
N with `closeReason: rolled` and its buyback debit, and create leg N+1 with its new
credit and `rolledFromLegId = N`. The UI must show the net of the pair
(`newCredit - buybackDebit`) and refuse to describe a net debit as a credit.

### 3.4 Snapshot

A dated reading. The user opens a position, types what their broker currently shows,
and the app stores it. Snapshots are append-only history -- this is what lets the app
chart how delta moved over the life of a trade.

Fields: `id`, `legId`, `takenAt`, `optionMark`, `underlyingPrice`, `delta`,
`gamma?`, `theta?`, `vega?`, `iv?`, `openInterest?`, `volume?`.

`dte` is **not** stored -- it is computed as `expiration - takenAt.date`. Storing it
guarantees it goes stale.

### 3.5 Delta sign convention -- specify this once and enforce it everywhere

This is a genuine bug magnet. Brokers differ, and the same number means different
things in different places.

- A **call option** has delta in `[0, +1]`. A **put option** has delta in `[-1, 0]`.
- A **short** position inverts the sign. A short call has *position* delta in
  `[-1, 0]`; a short put has *position* delta in `[0, +1]`.
- Robinhood displays **position delta** on a position you hold -- a short call shows
  as negative.

Rules for the codebase:

1. Store snapshot delta **exactly as the user typed it**, sign included, in a field
   named `deltaAsEntered`.
2. On entry, show the user which convention you are assuming and let them flip it
   with one tap. Default to interpreting the sign as position delta.
3. **The rules engine gates on `deltaMagnitude = abs(delta)` only.** Never on the
   signed value. Thresholds are always expressed as magnitudes.
4. **Portfolio exposure aggregation uses the signed position delta.** Getting this
   wrong makes a hedged book look directional.
5. Write unit tests for all four quadrants (short call, short put, entered positive,
   entered negative).

### 3.6 ShareLot and cost basis

Created when a put is assigned. `shares = 100 x contracts`.

Two different basis numbers exist and **they are not the same**. The app must show
both and label them clearly:

**Wheel-adjusted basis** (the management number -- use this for the covered-call
strike floor):

```
wheelBasis = assignmentStrike - (cycleCumulativeCredit at time of assignment)
           - (credits from covered calls sold since)
```

**Tax basis** (the reporting number):

```
taxBasis = assignmentStrike - putPremiumReceived
```

Covered-call premiums are generally their own taxable events and do **not** reduce
the stock's tax basis unless the call is exercised. Assignment of a short call also
has its own treatment, and **wash-sale rules can apply** when a cycle is re-opened
on the same underlying inside 30 days of a realised loss.

Put a short, plain note in the UI wherever tax basis appears:

> Tax treatment of options is genuinely complicated and varies by jurisdiction and
> account type. These figures are for your own tracking. Check them against your
> broker's 1099 and talk to a tax professional before filing.

Do not attempt to implement wash-sale detection or tax-lot matching. Flag it, don't
compute it.

---

## 4. The rules engine

This is the core of the app. It must be a **pure Dart library with zero Flutter
imports**, in its own package or `lib/domain/rules/`. Every function is a pure
function of its inputs. No I/O, no clock access -- pass `now` in as a parameter so
tests are deterministic.

### 4.1 Derived metrics

```dart
capturedPct = (openCredit - currentMark) / openCredit x 100

annualisedYield = (credit / strike) x (365 / dteAtOpen) x 100

oneSigmaMove = strike x (iv / 100) x sqrt(dte / 365)

cushionSigmas = (strike - spot).abs() / oneSigmaMove

intrinsic = optionType == call
              ? max(0, spot - strike)
              : max(0, strike - spot)

extrinsic = currentMark - intrinsic

deltaMagnitude = delta.abs()
```

Every one of these must return a nullable/`Result` type when inputs are missing.
A position with no snapshot yet is a normal state, not an error, and must not crash
or display `NaN`. `oneSigmaMove` with `dte == 0` is zero -- guard the division in
`cushionSigmas`.

### 4.2 The IV-adjusted roll band

The point of this: delta is a probability estimate under the market's own volatility
assumption. On a high-IV underlying, delta 0.30 arrives while the strike is still
far away, so a fixed 0.30 threshold fires constantly on positions that were never
actually threatened.

```dart
double rollBand(double? iv) {
  if (iv == null) return 0.30;
  if (iv > 70)    return 0.40;
  if (iv >= 40)   return 0.35;
  return 0.30;
}
```

**These cut points (40, 70) and band values are a reasonable starting heuristic, not
established doctrine.** They are not derived from anything published. Make every one
of them user-configurable in settings, and ship this as the default profile. Do not
present them in the UI as though they were standard.

### 4.3 Bucket classification -- gates fire in order, first match wins

```dart
BucketResult classify(TriageInput i, RuleProfile p) {
  // Gate 1 -- profit target. Checked continuously, independent of DTE.
  if (i.capturedPct != null && i.capturedPct! >= p.profitTargetPct) {
    return Bucket.close(reason: '${i.capturedPct!.round()}% of credit captured');
  }

  // Gate 2 -- assignment likely. MUST be checked before the roll band.
  if (i.deltaMagnitude != null && i.deltaMagnitude! >= p.assignThreshold) {
    return Bucket.assign(reason: 'Delta ${fmt(i.deltaMagnitude)} at or above ${p.assignThreshold}');
  }

  // Gate 3 -- strike threatened.
  final band = p.rollBandFor(i.iv);
  if (i.deltaMagnitude != null && i.deltaMagnitude! >= band) {
    return Bucket.roll(reason: 'Delta ${fmt(i.deltaMagnitude)} at or above the ${fmt(band)} band');
  }

  // Gate 4 -- tail. Almost nothing left to collect.
  if (i.dte != null && i.dte! <= p.tailDteDays &&
      i.extrinsic != null && i.extrinsic! <= p.tailExtrinsicThreshold) {
    return Bucket.close(reason: 'Only ${money(i.extrinsic)} of time value left');
  }

  // Fall-through.
  return Bucket.leave(reason: i.deltaMagnitude == null
      ? 'Enter current numbers to triage'
      : 'Delta ${fmt(i.deltaMagnitude)} below the ${fmt(band)} band');
}
```

**Gate ordering is load-bearing and the order above is deliberate.** An earlier
draft of these rules put the roll band before the assignment check. Because the
roll band (0.30-0.40) is *lower* than the assignment threshold (0.70), a delta of
0.85 matched the roll gate first and the assignment branch was unreachable dead
code. Write a test that specifically asserts delta 0.85 classifies as `assign`.

Gate 1 is checked **continuously**, from the moment the position is opened. There is
no DTE at which it "becomes active". Any design that only evaluates buckets at a
particular DTE is wrong.

### 4.4 RuleProfile -- everything is configurable

```dart
class RuleProfile {
  String name;                    // 'Standard', 'Conservative', user-defined
  double profitTargetPct;         // default 50
  double assignThreshold;         // default 0.70
  double baseRollBand;            // default 0.30
  double midIvRollBand;           // default 0.35
  double highIvRollBand;          // default 0.40
  double midIvCutoff;             // default 40
  double highIvCutoff;            // default 70
  int    tailDteDays;             // default 3
  Decimal tailExtrinsicThreshold; // default $0.05
  double minIvRank;               // default 30
  double minAnnualisedYield;      // default 20
  int    targetDteMin;            // default 30
  int    targetDteMax;            // default 45
  double targetDelta;             // default 0.30
}
```

Ship three built-in profiles (Conservative / Standard / Aggressive) and let the user
clone and edit. A position stores **which profile it was opened under**, so changing
a profile later doesn't silently re-classify historical trades.

### 4.5 Entry screener

Two hard gates and a soft score. Keep them visually distinct -- the gates decide, the
score only sorts.

**Hard gates:**
- `ivRank >= profile.minIvRank` (default 30)
- `annualisedYield >= profile.minAnnualisedYield` (default 20)

**Soft score, 0-9**, three components at 0-3 each:

| Component | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| Annualised yield | < 20% | 20-35% | 35-50% | > 50% |
| IV rank | < 30 | 30-50 | 50-70 | > 70 |
| Cushion (sigmas) | < 0.5 | 0.5-1.0 | 1.0-1.5 | > 1.5 |

**These bucket edges are invented for this app.** The two hard gates have some
grounding in common practice; the 0/1/2/3 cut points do not. Label the score
"Sorting score" in the UI, never "rating" or "grade", and put a one-line note under
it saying the thresholds are the user's own and editable.

---

## 5. Screens

### 5.1 Screen (entry)

Inputs: ticker, side (put/call), strike, spot, credit, DTE, IV, IV rank, contracts.

Outputs: annualised yield, one-sigma move, strike distance in dollars and sigmas,
the two hard gates as pass/fail, the sorting score with its three components.

Primary action: **Track this position** -> creates a WheelCycle + first Leg.
Secondary: **Just calculating** -> computes without saving. This matters; most uses
of a screener are hypothetical and forcing a save pollutes the journal.

### 5.2 Positions

A list, each row showing ticker, strike, type, expiry, DTE, and its bucket badge
with the reason underneath. Sort options: by bucket severity (assign -> roll -> close
-> leave), by DTE, by ticker.

Tapping a row opens the detail sheet:

- **Update snapshot** -- the numbers off the broker screen. This is the primary
  action and should be reachable in one tap from the list.
- Current triage verdict with the rule that fired, and the arithmetic shown openly
  (captured %, roll band in use and why, one sigma, extrinsic remaining).
- **Roll chain** -- every leg in the cycle with its net credit, and the cumulative
  total. If the current leg came from a roll, say so prominently; the credit on
  screen is the current leg only.
- Delta history sparkline from the snapshots.
- Actions: **Roll**, **Close**, **Mark assigned**, **Mark expired**.

### 5.3 Roll planner

Given the open leg and a candidate replacement the user types in (new expiry, new
strike, and the two prices they can see):

```
netCredit = newCredit - buybackDebit
```

Show the net, whether it is a credit or a debit, how many strikes up/down the move
is, and the new annualised yield on the extended duration. Let the user enter two
or three candidates and compare side by side.

**Hard rule to surface in the UI:** if `netCredit <= 0`, mark the candidate clearly
as a debit roll. Do not block it -- the user may have a reason -- but never present a
debit as though it were income.

### 5.4 Assignment flow

When the user marks a leg assigned, walk them through it:

1. Confirm shares acquired (`100 x contracts`) and the assignment strike.
2. Create the ShareLot; compute and display both basis numbers.
3. Transition the cycle to `holdingShares`.
4. Offer to open the covered-call side immediately, **pre-filtered to strikes at or
   above the wheel-adjusted basis**, with the reason shown: selling below basis
   locks in a loss on assignment.

This flow is the wheel loop made concrete and is the app's most valuable moment.
Make it good.

### 5.5 Journal

Closed cycles, newest first. Per cycle: underlying, duration in days, number of
legs, total credits collected, outcome, realised P&L in dollars and as a percentage
of capital committed, and annualised return on that capital.

Aggregates: win rate, average days in trade, average premium capture %, total
credits collected, P&L by underlying. Keep it factual. No "insights", no coaching,
no streak gamification.

**Capital committed** for a cash-secured put is `strike x 100 x contracts`. For the
covered-call side it is the wheel-adjusted basis x shares. State which definition is
in use -- return numbers are meaningless without it.

### 5.6 Portfolio

- **Capital committed** in total and per underlying, with concentration as a
  percentage. Flag when one underlying exceeds a user-set share of the book.
- **Net position delta** in share-equivalent terms:
  `SUM (signedPositionDelta x 100 x contracts) + SUM shares held`.
  This is the number that tells the user how long they actually are.
- **Assignment calendar** -- a month view of expirations with the obligation at each:
  dollars needed if puts are assigned, shares at risk if calls are called away.
- **Bucket summary** -- how many positions currently sit in each bucket.

### 5.7 Settings

Rule profiles (create, clone, edit, set default), display preferences, delta sign
convention, notification preferences, export/import, and the disclaimer.

---

## 6. Notifications

Local only. Because there is no data feed, the app cannot detect that delta moved --
it can only remind the user to look.

- DTE milestones (default 21 and 7 days): "SBET $11 call is at 21 DTE -- worth a look."
- Expiration morning for anything still open.
- Optional weekly nudge to update snapshots on stale positions.

Never phrase a notification as though the app knows what the position is doing. It
does not. "Worth a look" is right; "Your position needs rolling" is not.

---

## 7. What NOT to build

Explicitly out of scope. If you think one of these is needed, stop and ask.

- Any network call for market data, quotes, or Greeks.
- Broker integration or order placement.
- Price prediction, trend analysis, technical indicators, or backtesting.
- Social features, leaderboards, shared watchlists.
- Any copy that recommends a trade or characterises a security.
- Wash-sale detection or tax-lot matching.
- Multi-leg spreads beyond the wheel's single short leg (no verticals, iron condors,
  straddles). The domain model is deliberately shaped around one short leg at a time.
  If the user wants spreads later that is a real redesign, not an extension.

---

## 8. Testing

The rules engine is the product. It gets tested like it.

**Required unit tests** (table-driven, pure functions, no widget tests needed):

1. Each gate firing in isolation.
2. **Gate precedence**: delta 0.85 with 10% captured -> `assign`, not `roll`.
3. Gate 1 wins over everything: 60% captured with delta 0.90 -> `close`.
4. Roll band selection at IV = 39.9, 40, 40.1, 69.9, 70, 70.1.
5. All four delta sign quadrants -> correct `deltaMagnitude`.
6. Null/missing snapshot -> `leave` with the "enter numbers" reason, no crash.
7. `dte == 0` and `dte < 0` (expired but not yet recorded) -> no division by zero.
8. Decimal rounding: a credit of 0.35 and mark of 0.175 -> exactly 50.0% captured and
   the gate fires.
9. Roll chain cumulative credit across three legs including a debit roll.
10. Wheel-adjusted basis after assignment plus two covered-call credits.

**Fixture from a real position** -- use this as a regression test:

```
SBET $11 call, short 1, opened at $0.35 credit, 36 DTE
Snapshot: mark $0.27, spot $9.29, delta -0.2534, IV 87.61%, DTE 21
Expected: capturedPct ~ 22.9, deltaMagnitude 0.2534, rollBand 0.40 (IV > 70),
          oneSigma ~ $2.31, extrinsic $0.27 (strike is OTM so intrinsic is 0),
          bucket = LEAVE, reason cites 0.2534 below the 0.40 band
```

Also add golden tests for the bucket badge widget in all four states, and a
migration test for every Drift schema version.

---

## 9. Export, import, and data safety

On-device-only storage means **the user's entire history dies with the phone**.
Treat this as a correctness requirement.

- **Export**: full JSON dump of all cycles, legs, snapshots, share lots and rule
  profiles, plus a flat CSV of closed cycles for spreadsheet use. Share sheet.
- **Import**: restore from the JSON export, with a clear merge-or-replace choice.
  Validate hard and refuse partial imports rather than corrupting the DB.
- **Reminder**: if no export has happened in 30 days and there are open positions,
  a single, dismissable, non-nagging prompt.
- iOS: ensure the DB file is included in iCloud device backup (do not set
  `NSURLIsExcludedFromBackupKey`). Android: configure `allowBackup` and a
  `data_extraction_rules` XML. **(Android deferred -- iOS only for this build.)**

---

## 10. Store submission notes

- **Do not describe the app as providing financial advice, signals, or
  recommendations** in the listing copy, screenshots, or the app itself. Position it
  as a personal calculator and record-keeper. This is the single biggest review risk.
- Apple requires privacy nutrition labels even when nothing is collected. Declare
  "Data Not Collected" -- and make sure that stays true (no analytics SDK, no crash
  reporter that ships user content).
- A privacy policy URL is required by both stores even for a fully offline app.
- Include a persistent disclaimer in Settings and on first run, something like:

  > This app performs arithmetic on numbers you enter. It does not provide
  > investment advice, does not receive market data, and has no view on any
  > security. Options trading involves substantial risk of loss, including losses
  > exceeding your initial investment. You are responsible for your own decisions.

- Age rating: both stores have a "simulated gambling"/financial category question.
  This is a tracking tool, not trading -- answer accordingly, but expect a reviewer
  to look closely.

---

## 11. Milestones

Build in this order. Each milestone should be independently runnable and tested
before moving on.

**M1 -- Rules engine, pure Dart, no UI.** All formulas, `rollBand`, `classify`,
`RuleProfile`. Full unit test suite from §8 green. This is the foundation; do not
start UI until these tests pass.

**M2 -- Persistence.** Drift schema, entities from §3, migrations, DAOs. Tests for
the roll chain and basis calculations against a real DB.

**M3 -- Screener + single position tracking.** Entry form, score, save a cycle,
update a snapshot, see a bucket. The app becomes useful here.

**M4 -- Roll chain, roll planner, assignment flow.** The wheel loop closes.

**M5 -- Journal and closed-cycle P&L.**

**M6 -- Portfolio view and assignment calendar.**

**M7 -- Notifications, export/import, settings, profiles.**

**M8 -- Polish**: dark mode, dynamic type, VoiceOver labels on every number
(a screen reader saying "0.25" without "delta" is useless), haptics on bucket
changes, empty states written as invitations to act rather than apologies.

---

## 12. Working agreement

- Ask before adding a dependency not listed in §2.
- Ask before changing any threshold default -- they are documented here deliberately.
- If a rule in §4 seems wrong to you, **say so before implementing it**. Several of
  these numbers are heuristics, and one of them (gate ordering) was a bug found
  during design. Another may be wrong too.
- Keep the rules engine free of Flutter imports permanently. If something wants to
  reach into it, that is a signal the boundary is in the wrong place.
- Commit per milestone with the tests green.

---

## Appendix: formula reference

```
capturedPct       = (openCredit - currentMark) / openCredit x 100
annualisedYield   = (credit / strike) x (365 / dte) x 100
oneSigmaMove      = strike x (iv / 100) x sqrt(dte / 365)
cushionSigmas     = |strike - spot| / oneSigmaMove
intrinsic (call)  = max(0, spot - strike)
intrinsic (put)   = max(0, strike - spot)
extrinsic         = mark - intrinsic
deltaMagnitude    = |delta|
rollBand(iv)      = iv > 70 -> 0.40 ; iv >= 40 -> 0.35 ; else 0.30
wheelBasis        = assignmentStrike - cumulativeCreditsOnCycle
netRollCredit     = newLegCredit - buybackDebit
positionDeltaShares = SUM(signedDelta x 100 x contracts) + SUM shares
```

Defaults: profit target 50%, assign threshold 0.70, tail 3 DTE / $0.05,
IV rank floor 30, yield floor 20%, target 30-45 DTE at 0.30 delta.
