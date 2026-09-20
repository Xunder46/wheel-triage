# Follow-up brief: Wheel Triage — corrections and help system

Continues `docs/brief.md`. Part A fixes defects found in the first build, several
of which came from errors in that brief. Part B is a terminology cleanup. Part C
adds the in-app help system.

Work Part A first — two of those defects produce wrong numbers.

---

## Part A — Corrections

### A1. One-sigma move uses the wrong price. **Formula error in the original brief.**

The original brief specified `strike x IV x sqrt(DTE/365)`. That is wrong. The
expected move measures how far the *underlying* can travel from where it currently
trades. The strike is an arbitrary level the user picked and has no business in the
formula.

```dart
// WRONG -- as originally specified
oneSigmaMove = strike * (iv / 100) * sqrt(dte / 365);

// CORRECT
oneSigmaMove = spot * (iv / 100) * sqrt(dte / 365);
```

`cushionSigmas` is unchanged in form (`|strike - spot| / oneSigmaMove`) but its
value changes because the denominator does.

**This means the SBET regression fixture in §8 of the original brief is also
wrong.** It asserts `oneSigma ~ $2.31`, computed from the strike. Replace with:

```
spot 9.29, iv 87.61%, dte 21
oneSigmaMove = 9.29 x 0.8761 x sqrt(21/365) ~ $1.95
cushionSigmas = |11 - 9.29| / 1.95 ~ 0.88
```

All other assertions in that fixture stand.

Add a unit test asserting the formula responds to spot and is invariant to strike:
holding spot/IV/DTE fixed, `oneSigmaMove` must return the same value for strikes of
$8, $11 and $15.

### A2. Credit accepts values that are arithmetically impossible

The field is labelled "$ per share" but accepts `31`, producing an annualised yield
of 3214.5%. A user thinking in total dollars per contract will hit this constantly.

Add validation to the screener and to leg entry:

- **Hard reject**: `credit > spot`. For a call this violates put-call parity -- the
  premium can never exceed the underlying's price. For a put, reject
  `credit > strike`. Show: *"A premium can't exceed the share price. Did you enter
  the total for the contract? Divide by 100 -- one contract covers 100 shares."*
- **Soft warn, not blocking**: `credit > spot x 0.5`. Legitimate on a deep-ITM or
  very-high-IV contract, but usually a units mistake.
- Add a **"total per contract" toggle** beside the credit field. When on, the user
  types 31 and the app stores 0.31. Persist the toggle state as a user preference --
  whichever way they think, they think that way every time.

Same treatment for `Option mark` in the snapshot sheet, which has the identical
failure mode.

### A3. Roll band falls back to the default instead of the leg's IV

A position with no snapshot yet shows "Roll band in use: 0.30" even when it was
opened at 83% IV, which should give 0.40.

Resolution order for the IV that feeds `rollBand()`:

1. Most recent snapshot's `iv`
2. Leg's `ivAtOpen`
3. Profile default (0.30)

Display which source was used: "0.40 -- from IV at open (83%)" or "0.30 -- no IV on
file". A threshold the user can't trace back to an input is a threshold they won't
trust.

### A4. `Leave` is displayed when nothing has been evaluated. **Spec error in the original brief.**

The original brief's `classify()` returns `Bucket.leave` for the null-input case.
That renders as a verdict -- it looks like the app assessed the position and cleared
it, when it has no data at all.

Add a fifth state to the `Bucket` union:

```dart
Bucket.unknown(reason: 'No snapshot yet')
```

- Neutral grey, visually distinct from the four action states.
- **No verb.** Label it "No data", never a word that reads as an instruction.
- Returned whenever both `capturedPct` and `deltaMagnitude` are null.
- Sorts last in the positions list and is excluded from the portfolio bucket summary
  counts (report it separately as "N positions need a snapshot").

Update the `classify()` fall-through and add a test: a leg with no snapshots returns
`unknown`, not `leave`.

### A5. Expiration is derived from DTE, producing non-trading dates

The first build took DTE as input and computed an expiration of 2026-10-20 -- a
Tuesday. Listed equity options expire on Fridays (plus month-end and some weeklies
on other days, but never arbitrarily).

Invert the relationship:

- **Expiration is the stored field**, entered via a date picker.
- **DTE is always derived**: `expiration.difference(asOfDate).inDays`.
- Default the picker to the nearest Friday 30-45 days out.
- Warn (don't block) if the chosen date is not a Friday -- index and month-end
  products legitimately differ.
- The screener may still offer a DTE field as a convenience that *moves the picker*,
  but the picker is the source of truth.

Everything downstream recomputes DTE from the stored expiration against the snapshot
date, so a position's DTE is correct on every screen without a refresh job.

---

## Part B — Terminology consistency

The app currently uses two names for one quantity: the screener says **Spot ($)**,
the snapshot sheet says **Underlying price ($)**. Both mean the current share price.

Pick one term and use it in every label, tooltip, export header and variable name.
**Use "Stock price"** -- "spot" is jargon and "underlying" is ambiguous to anyone who
hasn't read an options textbook. Keep `spot` as the internal Dart identifier if you
prefer brevity, but no user-facing string should say it.

Audit for the same problem in: credit / premium, mark / price / option price,
DTE / days to expiry.

---

## Part C — Help system

The app's core loop is not self-evident. A user who doesn't already know what a mark
or a delta convention is cannot complete a snapshot correctly, and a wrong snapshot
produces a confidently wrong bucket.

### C1. The widget

```dart
HelpChip(topicId: 'option_mark')
```

- Renders a small circled `?` at the trailing edge of a field label or output row.
- Tap opens a bottom sheet, not a tooltip overlay -- tooltips are unreadable on
  phones and unreachable for screen readers.
- Sheet contains: title, one-line definition, "Where to find it" (the broker-screen
  location), and optionally "Why it matters" (2-3 sentences max).
- Dismiss by tap-outside or swipe-down.
- Fully accessible: the chip gets `Semantics(button: true, label: 'Help: <title>')`.

Content lives in a single `help_topics.dart` map keyed by `topicId`, not inline in
widgets. One file to review, translate, or correct.

### C2. Topic content

Write these verbatim. They are the actual explanatory value of this work.

**Inputs**

| id | Title | Definition | Where to find it |
|---|---|---|---|
| `ticker` | Ticker | The stock symbol the option is written on. | Top of your broker's position or chain screen. |
| `side` | Put or call | A put obligates you to buy shares at the strike; a call obligates you to sell them. The wheel sells puts first, then calls after assignment. | The contract name, e.g. "SBET $11 Call". |
| `strike` | Strike | The price at which the shares change hands if the option is exercised. | In the contract name. |
| `stock_price` | Stock price | What the share trades at right now. | The underlying's quote, not the option's. |
| `credit` | Credit | The premium you receive, **per share**. One contract covers 100 shares, so a $0.31 credit pays $31. | Your fill price, or the bid when you're deciding. |
| `expiration` | Expiration | The date the contract dies. Listed equity options expire on Fridays. | In the contract name. |
| `contracts` | Contracts | How many you sold. Each is 100 shares. | Your position quantity, ignoring the minus sign. |
| `iv` | Implied volatility | The annualised move the market is currently pricing in. Higher IV means fatter premiums and a wider expected range. | The option's detail screen. Robinhood lists it as "IV". |
| `iv_rank` | IV rank | Where today's IV sits within its own past year, 0-100. This is the number that says whether premium is rich or cheap -- raw IV alone can't tell you. | Not on Robinhood. Barchart, Market Chameleon, Tastytrade or Thinkorswim. |
| `option_mark` | Option mark | The contract's current price per share -- the midpoint of bid and ask. This is roughly what you'd pay to buy the position back. | Robinhood labels it "Mark". |
| `delta` | Delta | How much the option's price moves per $1 move in the stock. Useful shorthand: its absolute value is roughly the market's estimate of the chance the option finishes in the money. | Under "The Greeks" on the option's detail screen. |
| `delta_convention` | Delta convention | Brokers differ on sign. **Position** delta is signed for the position you hold, so a short call shows negative. **Contract** delta is the option's own, always positive for calls and negative for puts. Robinhood shows position delta -- leave this on Position. Bucketing uses the absolute value either way; this only affects the portfolio exposure total. | -- |

**Outputs**

| id | Title | Content |
|---|---|---|
| `annualised_yield` | Annualised yield | `(credit / strike) x (365 / DTE)`. What this trade would return if you could repeat it all year. You can't -- it's a comparison tool for sizing one candidate against another, not a forecast. |
| `one_sigma` | One-sigma move | `stock price x IV x sqrt(DTE / 365)`. Roughly how far the stock could move by expiration, with about a 68% chance of staying inside that range. |
| `strike_distance` | Strike distance | How far your strike sits from the stock price, in dollars and in sigmas. Sigmas matter more: on a high-IV name a strike 18% away can still be well inside one sigma, which means the market genuinely thinks it's reachable. |
| `hard_gates` | Hard gates | Both must pass before you sell. IV rank says you're being paid enough for the risk; annualised yield says the premium is worth the capital. A failed gate means skip the trade, not adjust the trade. |
| `sorting_score` | Sorting score | Ranks candidates against each other, 0-9. It is **not** a verdict and doesn't override the gates. The band edges were chosen for this app, not drawn from any published standard -- edit them in Settings. |
| `captured` | Credit captured | `(opening credit - current mark) / opening credit`. How much of the premium you've actually banked. Closing at 50% is the default because the second half takes disproportionately longer to earn while the risk keeps rising. |
| `roll_band` | Roll band | The delta at which this app flags the strike as threatened. It scales with IV, because on a volatile name delta 0.30 arrives while the strike is still far away -- a fixed threshold would fire constantly on positions that were never at risk. |
| `extrinsic` | Extrinsic remaining | `mark - intrinsic value`. The time value left. Extrinsic decays; intrinsic doesn't. Once extrinsic is nearly gone there's almost nothing left to collect, and rolling stops paying. |
| `cumulative_credit` | Cycle cumulative credit | Every credit collected on this cycle, minus every buyback debit. When a position has been rolled, the current leg's credit is only part of the story -- judge the trade on this number. |
| `wheel_basis` | Wheel-adjusted basis | Assignment strike minus all credits collected. Your covered-call strike floor: selling below it locks in a loss if the shares get called. Not the same as tax basis. |

**Buckets** -- shown when the badge itself is tapped.

| id | Content |
|---|---|
| `bucket_close` | You've captured enough of the credit that what's left isn't worth the remaining risk, or there's almost no time value left. Buy it back and start fresh. |
| `bucket_roll` | Delta says the strike is genuinely threatened. Rolling closes this leg and opens a later one, ideally for a net credit. If the roll costs a net debit, taking assignment is usually the cleaner end. |
| `bucket_assign` | Delta is high enough that assignment is the likely outcome. On the put side that means buying the shares; on the call side, having them called away. If you'd rather keep the shares, buying the call back is the alternative. |
| `bucket_leave` | No rule fired. The profit target isn't hit and delta is below your roll band. Nothing to do -- check again in a week. |
| `bucket_unknown` | No snapshot on file yet, so nothing has been evaluated. Tap Update snapshot and enter the current numbers. |

### C3. First-run explainer

Three swipeable cards on first launch, skippable, reachable again from Settings:

1. **What this does** -- "You type the numbers off your broker screen. The app runs
   your own thresholds against them and tells you which rule fired. It has no market
   data connection and no opinion about any stock."
2. **The loop** -- Screen a trade before you sell it -> track it once you've sold ->
   update the snapshot weekly -> act when a rule fires.
3. **The rules are yours** -- the defaults shipped are a common starting point, not
   doctrine. Everything is editable in Settings, and changing a profile won't
   reclassify trades you've already closed.

### C4. Snapshot sheet improvements

The four snapshot fields are where a novice goes wrong, so this sheet carries the
most help:

- `HelpChip` on all of: Option mark, Stock price, Delta, Convention, IV.
- Inline hint under Delta: *"Enter it exactly as your broker shows it, minus sign
  included."*
- Show the resulting `deltaMagnitude` live as the user types, so the sign handling is
  visible rather than implied.
- Prefill Stock price and IV from the previous snapshot as a starting point, clearly
  marked as carried forward so stale values don't masquerade as fresh ones.

---

## Acceptance checklist

- [ ] `oneSigmaMove` uses stock price; invariance-to-strike test passes
- [ ] SBET fixture updated to ~$1.95 / 0.88 sigma and green
- [ ] Credit > stock price rejected with the per-contract message
- [ ] "Total per contract" toggle works and persists
- [ ] Roll band resolves snapshot IV -> leg IV -> default, and names its source
- [ ] `Bucket.unknown` exists, renders grey with no verb, sorts last
- [ ] No-snapshot leg classifies as `unknown`, not `leave`
- [ ] Expiration is a date picker; DTE derived everywhere; non-Friday warns
- [ ] "Spot" and "Underlying price" both replaced by "Stock price" app-wide
- [ ] Every field and output row in §C2 has a working HelpChip
- [ ] Help sheets are screen-reader navigable
- [ ] First-run explainer shows once and is reachable from Settings

---

## Note on the two spec errors

A1 and A4 were wrong in the brief you were given, not introduced during the build.
If any other formula or rule in that document looks wrong while you're implementing
this, raise it rather than implementing it faithfully.
