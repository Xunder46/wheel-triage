# Third brief: Wheel Triage — the ledger release

Continues `docs/brief.md` and `docs/brief-followup.md`. **Where this document
disagrees with either, this one wins** — §1 explains why the product thesis
changed.

Work §3 first (schema), then §4 (the reason this release exists), then the rest
in any order.

## 1. What changed, and why

The original brief scoped a triage tool: type in numbers, get a bucket. That half
works and is shipped. It is not what makes the app worth having.

Two things became clear:

**The triage rules are simple enough to hold in your head.** Close at 50%
captured, roll if delta is high, take assignment if it's very high, otherwise
leave. Four rules. A user can apply those looking at their broker screen. The
app's marginal value there is saving arithmetic, at the cost of opening a second
app.

**The accounting is not simple and no broker does it.** Cumulative credit across
a roll chain, wheel-adjusted basis after assignment, fees, and whether a
completed cycle actually made money — these are hard by hand, wrong in most
spreadsheets, and absent from every broker UI.

So the centre of the product moves. The app is a **wheel ledger that happens to
include a triage calculator**, not a triage calculator that happens to store
history.

### The architectural consequence

The ledger runs on **transaction facts** — what the user did, what they were
paid, what it cost. Those are the user's own records. They never go stale, never
need refreshing, and carry no licensing obligation of any kind.

Only triage needs **market observations** — mark, delta, IV, stock price — and it
needs them at the moment the user looks, not continuously.

The correct description of this architecture is **"no market-data dependency"**,
not "no market data". The app does process market data. It never purchases,
licenses, streams, or redistributes it. That distinction is the whole boundary,
and it is what keeps this a local app rather than a company whose main job is
paying an OPRA bill.

## 2. Permanently out of scope

Not "later". Not "phase two". These are closed, and any design that starts
reaching toward one of them has gone wrong:

- **Broker API integration of any kind.** Requires a backend, custody of
  long-lived credentials to other people's brokerage accounts, and per-broker
  approval — and the primary user's broker has no public API anyway.
- **Any market-data vendor or feed**, real-time or delayed. Showing licensed
  options data to users requires a direct OPRA vendor agreement with a
  four-figure monthly floor that does not scale down.
- **Market-wide or watchlist candidate screening.** It's the one feature that
  cannot run on user-supplied numbers, and the one with a genuine
  advisory-boundary problem.
- **Backend, accounts, sync, subscriptions.** There is no recurring cost to fund,
  so there is nothing to subscribe to.
- **AI-generated trade selection.**

The existing screener screen **stays as built** — it runs entirely on numbers the
user types. Do not extend it, do not add data sources to it, do not grow it
toward ranking a universe.

Monetisation, for context only: one-time purchase. Break-even is one sale. Do not
build subscription plumbing, entitlement checks, or tiering.

## 3. Schema v3

Two additions. Both need a migration, a migration test, and an exported
`drift_schema_v3.json` alongside the untouched v1 and v2.

### 3.1 Fees on `Leg`

Fees are currently nowhere in the schema, which makes every P&L figure the app
produces incomplete. Accurate cycle accounting is now the product, so this is a
correctness gap, not a nicety.

Add to `Leg`:

- `openFee` — `Decimal?`, integer cents, **total for the opening transaction**
  (not per share, not per contract)
- `closeFee` — `Decimal?`, integer cents, total for the closing transaction

Both are nullable, and **null means "not recorded", not "zero"**. The codebase
already makes exactly this distinction with `Bucket.unknown` versus
`Bucket.leave`; make it here too. A leg with unknown fees must not silently
report a net figure as though fees were zero — see §4.3.

Existing rows migrate to `null`, not `0`.

**Fees never touch `classify()`.** `capturedPct` stays exactly as it is: premium
decay on the option itself, leg-only, per Feature Invariant 1. Gate 1 does not
move because a commission was paid. Fees are a cycle-level cost and appear only
in cycle accounting.

**Do not add a `CashFlow` table in this iteration.** Two fields cover manual
entry, where each leg has exactly one opening and one closing event. Revisit when
partial closes or bulk transaction import arrive — that is when multi-event legs
become real, and building the ledger table before then is speculative.

### 3.2 Assignment preference on `Leg`

This is the one input the four thresholds genuinely cannot express, and the
reason the triage tree needed a manual override every time the underlying was one
the user actually wanted to hold.

Add to `Leg`:

- `acceptsAssignment` — `bool`, default `true`

Semantics: "if this leg goes deep in the money, am I content for it to be
assigned?" For a cash-secured put in the wheel, yes is the normal answer —
willingness to own the shares is the strategy's premise. For a covered call on a
holding the user means to keep, no.

**Set once when the leg opens.** A leg created by a roll **inherits** it from the
leg it rolled from, exactly as `ruleProfileId` already does (Feature Invariant
8). Editable from the position detail sheet, because the answer can legitimately
change.

**Asked again at the assignment transition.** When a put is assigned and the
covered-call side opens, the question is a different one — "happy to sell these
at that strike?" — so the assignment flow prompts for it rather than carrying the
put's answer across.

### 3.3 The classification change

Gate 2 currently returns `assign` whenever `deltaMagnitude >= 0.70`. It now
branches:

```dart
// Gate 2 — assignment likely.
if (deltaMagnitude != null && deltaMagnitude >= p.assignThreshold) {
  return input.acceptsAssignment
      ? Bucket.assign(reason: 'Delta ${fmt(deltaMagnitude)} at or above ${p.assignThreshold}')
      : Bucket.roll(
          reason: 'Delta ${fmt(deltaMagnitude)} at or above ${p.assignThreshold}, '
              "and you'd rather keep this position — roll it out or buy it back",
        );
}
```

`TriageInput` gains `acceptsAssignment` (non-nullable, default `true` so existing
call sites stay valid).

**Do not add a sixth bucket.** "Buy it back outright" is a real action the four
verbs don't name, but it belongs in the reason string and in the detail sheet's
existing Close action, not in a new classification. Five buckets is already at
the limit of what a user holds in their head.

Gate ordering is unchanged and still load-bearing.

## 4. Cycle P&L — the reason this release exists

This is the original brief's M5, promoted to the centre. Without it the app is
the triage calculator, which is the half that doesn't justify itself.

### 4.1 Per-cycle figures

For every closed cycle, compute **live from leg history** — nothing persisted
(Feature Invariant 12 extends to all of this):

```
totalPremium   = cycleCumulativeCredit(legs)          // already implemented
totalFees      = SUM (openFee ?? 0) + (closeFee ?? 0) // see §4.3 on nulls
stockPnL       = calledAway ? (callStrike - assignmentStrike) x 100 x contracts : 0
netResult      = totalPremium x 100 x contracts - totalFees + stockPnL
daysHeld       = endedAt - startedAt
rollCount      = legs.where((l) => l.closeReason == rolled).length
```

`callStrike` is the strike of the call leg closed with `closeReason: assigned`;
`assignmentStrike` comes from the consumed `ShareLot`. A cycle that ended on the
put side has `stockPnL == 0` and no share lot.

### 4.2 Capital committed and return

`journalAnnualisedReturn(...)` is a name reserved by Feature Invariant 4 for
exactly this moment. Implement it now. Do not rename or overload
`screenerAnnualisedYield`, which stays strike-denominated for screening.

Capital committed differs by phase, so compute the **maximum committed at any
point in the cycle**:

- Put side: `strike x 100 x contracts`
- After assignment: `wheelBasis x 100 x contracts`

```
returnOnCapital  = netResult / maxCapitalCommitted x 100
annualisedReturn = returnOnCapital x (365 / daysHeld)
```

**Label which definition is in use, on screen.** A return number without its
denominator stated is meaningless, and this one changes mid-cycle.

Guard `daysHeld == 0` (opened and closed same day) — return the unannualised
figure with a note rather than dividing by zero.

### 4.3 Unknown fees

If any leg in a cycle has a null `openFee` or `closeFee`, the cycle's net figure
is incomplete. Show it as **"Before fees"** with a one-line note naming how many
legs are missing fee data, and offer to fill them in. Never present a
fee-incomplete figure as a final net result.

### 4.4 Journal screen

Closed cycles, newest first. Per row: ticker, duration, leg count, total premium,
outcome, net result, return on capital.

Aggregates across all closed cycles:

- Win rate (net result > 0)
- Average days in cycle
- Average premium capture
- Total premium collected, total fees paid
- Net result by underlying
- Roll-count distribution

Keep it factual. No insights, no coaching, no streaks, no badges, no "you're
doing great". Descriptive statistics about the user's own history and nothing
else — that framing is also what keeps this clear of advisory territory.

### 4.5 Open cycles

The journal covers closed cycles. Open ones get the same figures, marked
**unrealised**, on the position detail sheet — the user shouldn't have to close a
position to see where it stands.

## 5. Export and backup

On-device-only storage means a lost phone is a lost ledger. The original brief
(§9) called this a correctness requirement; with no cloud sync anywhere on the
roadmap, it is now the only protection there is.

- **Export**: full JSON of every cycle, leg, snapshot, share lot, fee and rule
  profile. Plus a flat CSV of closed cycles for spreadsheet use.
- **Restore**: JSON only, **replace-all**, behind a hard confirmation that names
  how many cycles will be destroyed. **Do not build merge in this iteration** —
  merge is a genuinely hard problem and the use case here is "my phone died", not
  "combine two devices".
- **Validate hard on import.** Refuse the whole file rather than partially
  applying it.
- **Reminder**: if no export in 30 days and there are open positions, one
  dismissable prompt. Once. Not a recurring nag.
- **iOS**: do not set `NSURLIsExcludedFromBackupKey` — the default template
  already omits it, which satisfies iCloud device backup for free.

**Dependency authorisation**: `share_plus` and `file_selector` were deliberately
excluded in Phase 1 and are **approved now**. No others without asking (§12 of
the original brief still stands).

## 6. Expiration notifications

`flutter_local_notifications` is already in `pubspec.yaml` and unused. This is the
cheapest real feature in the app: entirely local, no server, no market data, no
cost.

- Schedule at leg creation from the stored `expiration`
- Default milestones: 21 DTE, 7 DTE, expiration morning. User-configurable in
  Settings.
- Cancel on leg close. Derive notification IDs **deterministically** from `legId`
  + milestone so cancellation is possible without a lookup table.
- Reschedule on roll. The closing leg's notifications cancel; the new leg's
  schedule from its own expiration.

**Wording.** These describe a date arriving, never a market condition:

> SBET $11 call is at 21 DTE — worth a look.

Never "your position needs rolling". The app has no idea what the position is
doing; it knows what day it is.

Delta-crossing alerts are impossible in this architecture and that's correct.
Evaluating a rule requires a fresh observation, and observations only arrive when
the user provides one. Don't fake it with a stale snapshot.

`timezone` is likely needed for `zonedSchedule` — **approved if so**. Exact-alarm
permissions on recent Android and notification authorisation on iOS behave
differently; test both rather than assuming parity, and **degrade gracefully when
permission is refused** (the app must stay fully usable without notifications).

## 7. Snapshot dates and staleness

The whole design now rests on the user knowing how old a reading is. Right now
`updateSnapshot` takes `takenAt` and silently defaults it to `DateTime.now()`,
and nothing on screen says so.

- **Show the date.** The arithmetic card displays when the latest snapshot was
  taken, with a freshness indicator: fresh (under an hour), recent (today), old
  (yesterday), stale (older). When stale, the bucket verdict carries a line
  saying which snapshot it was computed from.
- **Allow backdating.** An optional date field in the snapshot sheet, defaulting
  to now, for entering a reading taken earlier. Validate that `takenAt` falls
  between the leg's `openedAt` and its `expiration`.
- **Fix the classification date.** `updateSnapshot` currently calls
  `load(now: effectiveTakenAt)`, so the bucket shown right after saving is
  classified as of the snapshot's date, while reopening the sheet later
  classifies against the real clock. Identical for same-day entry, divergent the
  moment anyone backdates. **Classification always uses real `now`**; `takenAt`
  governs only that snapshot's own historical figures (its own DTE, its own
  one-sigma move).

## 8. Display fixes

All visible in the current build:

- **Raw `Decimal` values reaching the UI.** The position detail sheet shows
  `-45.16129%` and `$2.343134203865` because `_Row` passes values straight
  through, while the screener formats via `_pctText`/`_moneyText`. Apply the same
  formatting in the detail sheet: percentages to zero decimals, money to two.
- **The roll-band row's label collapses to `Rol...`.** Its value string
  ("0.40 — from this snapshot's IV (85%)") is long enough to squeeze the
  `Flexible` label to nothing. Stack that row vertically, or wrap, rather than
  forcing label and value onto one line.
- **Audit every other `_Row` call site** for the same overflow shape.

## 9. Testing

Extending the existing scenario register. Required:

1. Migration v2 -> v3: new columns exist, every pre-existing row survives
   byte-identical, `openFee`/`closeFee` default to null, `acceptsAssignment`
   defaults to true.
2. Fees excluded from `capturedPct` and from every gate — a leg with a $10 fee
   classifies identically to one with none.
3. Gate 2 branch: delta 0.85 with `acceptsAssignment: true` -> `assign`; delta
   0.85 with `false` -> `roll`, reason names the preference.
4. Roll inherits `acceptsAssignment` from the leg it rolled from.
5. Cycle P&L on a full wheel: put sold, rolled twice (one at a net debit),
   assigned, one covered call, called away. Assert total premium, total fees,
   stock P&L, net, days held, roll count, return on capital.
6. A cycle with one null fee reports "before fees" and names the gap.
7. `daysHeld == 0` doesn't divide by zero.
8. Export -> wipe -> restore reproduces the database exactly, including fees and
   preferences.
9. Import of a malformed JSON leaves the database untouched.
10. Notification scheduled on leg creation, cancelled on close, rescheduled on
    roll.
11. Backdated snapshot: historical figures use `takenAt`, classification uses
    `now`.

Golden tests for the journal row and the cycle summary card.

## 10. Milestones, restated

The original brief's M5–M8 predate the reframe. What they become:

- **M5 Journal** -> this release, §4. The centre of the product.
- **M6 Portfolio** -> deferred, low priority. Concentration and net delta are
  nice; neither is why anyone would install this. Feature Invariant 19's
  portfolio bucket-summary clause stays logged and unbuilt.
- **M7 Export/import** -> this release, §5. Promoted because it's the only
  protection a local-only ledger has.
- **M7 Notifications** -> this release, §6.
- **M7 Profile CRUD** -> deferred. One Standard profile with editable thresholds
  covers the need; multiple named profiles do not.
- **M8 Polish** -> still M8. Dark mode, dynamic type, VoiceOver labels on every
  number, empty states.

Next after this release, in order: OCR snapshot capture (camera -> on-device text
recognition -> confirm-and-correct -> snapshot), then broker CSV import for one
broker. Both reduce typing without adding a dependency on anyone's data. Neither
belongs in this iteration — manual entry is the experiment, and if nobody keeps
typing, neither of those would have saved it.

## Acceptance checklist

- [ ] Schema v3 with migration test; v1 and v2 JSON untouched
- [ ] `openFee`/`closeFee` nullable, null != zero, excluded from all gates
- [ ] `acceptsAssignment` on `Leg`, inherited on roll, re-asked at assignment
- [ ] Gate 2 branches on it; both directions tested
- [ ] Cycle P&L: premium, fees, stock P&L, net, days, rolls, return on capital
- [ ] `journalAnnualisedReturn` implemented; `screenerAnnualisedYield` untouched
- [ ] Capital-committed definition labelled on screen
- [ ] Fee-incomplete cycles say "before fees" and name the gap
- [ ] Journal screen with factual aggregates, no coaching copy
- [ ] JSON export + restore round-trips exactly; CSV export of closed cycles
- [ ] 30-day export reminder, once, dismissable
- [ ] Expiration notifications schedule, cancel, and reschedule correctly
- [ ] Notification copy describes dates, never market conditions
- [ ] App fully usable with notification permission denied
- [ ] Snapshot date shown with freshness indicator; backdating supported and
      validated
- [ ] Classification uses real `now`; `takenAt` governs only historical figures
- [ ] Detail sheet formats percentages and money; no raw `Decimal` on screen
- [ ] Roll-band row no longer truncates its label
- [ ] `flutter analyze` clean; whole-repo `flutter test` green;
      `flutter build ios --simulator --no-codesign` exits 0
- [ ] Banned-vocabulary grep clean across `lib/`, no file exemptions
- [ ] `grep -rl "package:flutter" lib/domain/rules/` returns nothing
