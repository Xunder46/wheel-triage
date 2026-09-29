# Fourth brief: Wheel Triage — the Pro release

> Audience: the planner agent (`conductor-v2`). This document states **goals
> and acceptance criteria only**. Technical design, phasing, S-ids, predicted
> files and tests belong in the plans written from it.
>
> **Plan one wave per plan file** (§5), not the whole roadmap at once — for
> example `docs/plans/pro-wave-1-plan.md`. S-ids continue after the highest
> existing id (S-210 when this was written) and are never reused.
>
> Binding sources, in order: `CLAUDE.md`, `docs/conventions.md`,
> `docs/brief.md`, `docs/brief-followup.md`, `docs/brief-ledger.md`, then this
> document. Where this document disagrees with an earlier one, **the
> decisions in §2 win and nothing else does**. Every other rule (precision,
> tone grep, rules-engine purity, repository parity, gate ordering, versioned
> rule profile, no market-data dependency) stands exactly as written.
>
> UI reference: `docs/design/pro-ui-reference.html`. It shows intent and
> layout, not pixel specs. Its sample numbers are computed with the app's own
> formulas and gate order so they can be checked, but they are sample data,
> not fixtures. The earlier "Pro release UI reference" design canvas is
> **superseded and not binding**.
>
> §2 was ratified by the owner on 2026-09-28. The appendix lists what changed
> from the first draft.

---

## 1. Why this iteration exists

The ledger release made the app correct. This release makes it **worth
paying for** and **cheap to use daily**. Two problems stand between the
current build and a paying user:

1. **Friction.** Tracking a trade already placed goes through the screener's
   eleven fields. Updating a snapshot takes a trip into the detail sheet.
   Nothing on the start screen says what needs attention or how the month
   went.
2. **No reason to pay.** There is no purchase path, and the features that
   would justify one (screenshot capture, portfolio view, broker import)
   were parked as post-release.

Pricing is a hybrid (D-P1): subscriptions fund the ongoing work the product
needs, such as new broker screenshot layouts, imports and exports, while a
lifetime option keeps buyers who refuse subscriptions.

Success means: a new user records their first trade in under 20 seconds,
updates a snapshot in three taps, and hits a clear, honest reason to unlock
Pro once their book outgrows the free tier.

---

## 2. Decisions (ratified 2026-09-28)

| ID | Decision | Supersedes |
|---|---|---|
| D-P1 | **Free download + "Wheel Triage Pro" in three forms:** monthly subscription, annual subscription (default, with a free trial) and a one-time lifetime unlock. All three grant the same single Pro entitlement. Accounts, backend and sync stay permanently out. | `brief-ledger.md` §2: "Backend, accounts, sync, subscriptions" (subscriptions are now allowed; the rest stays out) and "Do not build subscription plumbing, entitlement checks, or tiering". |
| D-P2 | **Free tier limit: 3 open cycles.** Nothing already recorded ever locks. | — |
| D-P3 | Purchases go through **RevenueCat** (StoreKit on iOS, Play Billing on Android); `purchases_flutter` is an approved dependency. **The only SDKs that may use the network are RevenueCat and, on Android only, ML Kit text recognition (D-P4).** No analytics, crash-reporting or ad SDKs. The privacy label discloses what RevenueCat collects (purchase history and an app-scoped identifier) and must stay accurate. The product promise changes from "Data Not Collected" to **"your trades never leave your phone"**: no trade, snapshot, ledger or image data is ever transmitted, to RevenueCat or anyone else. | `brief.md` §10 "Data Not Collected"; `docs/conventions.md` §5 "No HTTP client dependency". |
| D-P4 | **Screenshot scan is a launch Pro feature.** Recognition runs on-device. **iOS:** Apple's Vision framework, through a platform channel written in this repo (Swift). No OCR package, because the common Flutter OCR plugins run Google ML Kit on iOS too. **Android (Stage 13):** ML Kit on-device text recognition, its diagnostics disclosed in Play's Data safety section. Screenshots are picked with **`image_picker`** (the Flutter team's own plugin; on iOS it uses the system photo picker, which needs no photo-library permission), an approved dependency. Images and recognised text never leave the device, and the picker's temporary copy is deleted when the flow ends. | `brief-ledger.md` §10 "next after this release" ordering. |
| D-P5 | **Portfolio view and assignment calendar (M6) are promoted.** A slim summary lives on the free Today screen; the full view is Pro. | `brief-ledger.md` §10 "M6 deferred, low priority". |
| D-P6 | Two new user preferences: **wheel capital** (the money the user sets aside for the wheel; optional) and a **concentration limit per underlying** (default 25%). Concentration = an underlying's current capital committed (D-P14) ÷ wheel capital. **No wheel capital set → no concentration flag anywhere.** | New threshold default, signed off 2026-09-28. |
| D-P7 | **Share card allowed.** It is an image exported through the share sheet: no feeds, accounts, leaderboards or streaks, so it is not a social feature under `brief.md` §7. | — |
| D-P8 | **Visual refresh**: dark theme default (light supported, follows system), teal accent (continuity with the current seed colour), bucket colours distinguishable by lightness as well as hue. The theme lands first (Stage 4A) so new screens are built once, on the final look. | — |
| D-P9 | **Android ships after the iOS launch**, not before. | — |
| D-P10 | Broker CSV import is a **post-launch** Pro feature for **one broker**: the owner's own, the same one as Stage 6's first screenshot layout. The owner names it before Wave 3 is planned. | — |
| D-P11 | **Readings older than 7 days** are counted separately and **overlapping**: on Today and Portfolio those positions stay in their bucket's count, and a separate count says how many readings are older than 7 days. 7 days is one named constant this release, not a setting. The detail sheet's freshness indicator (fresh / recent / old / stale) is unchanged. "No data" stays its own, exclusive count (Feature Invariant 19). | New default, signed off 2026-09-28. |
| D-P12 | **Calls on Record a trade.** A call on a ticker that has a `holdingShares` cycle with no open call is recorded as that cycle's covered call: no new cycle, never counted toward D-P2. Otherwise Record accepts puts only and says why in one line. The screener's "Track this position" follows the same rule, so the two save paths cannot diverge. Cycles opened with a call before this change keep loading; the planner decides how their figures are labelled. "Start from shares I already own" is Stage 14. | The screener's save path. `brief-ledger.md` §2 keeps the screener "as built"; this fixes its save path and does not extend it. |
| D-P13 | **Expiry records the expiration date.** Batch expiry and the single-leg "Mark expired" record `closedAt` as the leg's expiration date whenever the action happens on or after that date, not the moment of the tap. Legs whose latest reading was in the money, and legs with no reading, are never part of "Mark all expired"; each needs its own action. | Current "Mark expired" behaviour, which records the tap time. |
| D-P14 | **Current capital committed** (Today, Portfolio, concentration) is a separate, separately named figure from the Journal's **peak capital committed**, and its definition is stated on screen. The planner pins its formula; `brief.md` §5.5's put-side and covered-call-side definitions are the starting point. | — |
| D-P15 | **The app presents itself as a journal and calculator, never as anything more.** The persistent disclaimer, in Settings and in the first-run explainer, reads exactly: *"Wheel Triage is a journal and calculator for your own options trades. It keeps a record of what you enter and checks those numbers against the thresholds you set. It is not investment advice. It has no market data connection and no view on any security."* It says what the app is and isn't, and tells the user nothing to do. The share-card footer and the store listing use the same "journal and calculator" wording. | `brief.md` §10's suggested disclaimer text ("something like…"). |

### Why the decisions added on 2026-09-28 read the way they do

- **D-P6.** Measured against capital committed, the largest underlying is
  always at least 1/n of the book. With 1–3 underlyings, the whole free
  tier, that is 100%, 50%+ or 33%+, so a 25% flag would never turn off.
  Wheel capital is one new persisted preference, which means a schema change
  and an export-format change; the planner owns both.
- **D-P11.** In code, "stale" means a reading from before yesterday
  (`lib/domain/rules/snapshot_freshness.dart`). On the weekly habit this
  release designs for, positions would be stale five days out of seven, and
  taking them out of the bucket counts would empty the summary most days.
- **D-P12.** `createCycle` always opens a `sellingPuts` cycle. A call there
  has no ShareLot, so peak capital is 0, return on capital shows 0% (the
  zero-denominator guard in `lib/domain/rules/cycle_pnl.dart`), stock P&L is
  0 when the call is assigned, and Stage 7 would count the short call without
  its shares: the "hedged book looks directional" error `CLAUDE.md` warns
  about. The screener has this gap today; Record would make it common.
- **D-P13.** "Mark expired" records the tap time today
  (`PositionDetailController.closeDirect`). A Friday expiry marked on Monday
  inflates days held and can land in the next month, which skews Today's
  "this month" figure and the share card. An assigned put recorded as
  expired worthless corrupts the cycle and skips the assignment flow, which
  is why in-the-money and unread legs need their own action.
- **D-P15.** The app is a tool and journal; it never asks or tells the user
  to do anything with a trade. `brief.md` §10's suggested text carried two
  lines that imply otherwise: "Options trading involves substantial risk of
  loss…" reads like a broker's disclosure, as if the app were where trading
  happens, and "You are responsible for your own decisions" implies the app
  takes part in them. Both are dropped. The fourth sentence reuses the
  first-run explainer's existing wording.

---

## 3. Constraints that do NOT change

These are strengths for pricing, privacy and App Review. Do not relax them.

- No market-data feed, quote API, broker API or scraping. Manual entry and
  on-device reading of a screenshot the user picks, nothing else.
- Calculator, not advisor. The banned-vocabulary grep and the hand review of
  "action verb + named security" apply to every new string, including the
  paywall, share card, store listing and notifications.
- No backend, accounts, sync, or AI trade selection.
- Trade, snapshot, ledger and image data never leave the device. The only
  network traffic allowed is inside the purchase SDK (D-P3) and, on Android,
  ML Kit's diagnostics (D-P4).
- One editable Standard profile, versioned. No profile picker.
- Wash-sale detection, tax-lot matching, spreads: still out.
- `lib/domain/rules/` stays pure Dart; money stays `Decimal`.

---

## 4. Stages

Each stage is independently shippable and ends with `flutter analyze`
clean, the full test suite green, the iOS simulator build succeeding, and
both greps (tone, rules purity) clean. Those four are implied in every stage
below and not repeated. They run on the Mac; a checkout without the Flutter
SDK can plan but cannot verify.

Checks marked **(owner)** are run by the owner, not an agent, and recorded
in the wave's plan. An owner check closes its own stage and gates launch
(§6); it never blocks the next agent phase.

Stages keep their original numbers. Stage 4 is split into 4A and 4B, and §5
sets the order they run in.

### Stage 0 — Foundation hygiene

**Goal:** a base the next stages can build on without codegen or launch
surprises.

- [ ] A full, unfiltered `build_runner` run succeeds. The crash is logged in
      `docs/plans/rule-versioning-plan.md` (Phase 24 Assumption #3:
      `Missing implementation of visitDotShorthandInvocation` inside
      `riverpod_generator`); D-16 in the Iteration 4 closeout records that
      `flutter pub upgrade` did not fix it. The approved route is to remove
      the unused Riverpod code-gen stack: `riverpod_annotation` (zero
      imports), `riverpod_generator`, `riverpod_lint` and `custom_lint`,
      plus the `custom_lint` plugin entry in `analysis_options.yaml`.
- [ ] The exported `drift_schema_v1`–`v4` JSON files and every migration
      test are unchanged by the regeneration.
- [ ] `fl_chart` is removed (zero imports in `lib/` and `test/`).
- [ ] **(owner)** The full wheel loop walked end to end **on a physical
      iPhone** (simulator launch is already verified): first run → screen →
      track → snapshot → roll → assign → covered call → called away →
      journal → export → restore. Notification permission and the file
      picker used by restore are exercised on the device. Result recorded in
      the plan. (The photo picker arrives with Stage 6 and gets its own
      device check there.)

`CLAUDE.md` and `docs/conventions.md` were updated for §2 together with this
brief, so they are not a Stage 0 item.

### Stage 4A — Theme foundation (moved forward from Stage 4)

**Goal:** Record, the snapshot sheet and Today are built once, on the final
look.

- [ ] Dark theme by default, light supported, following the system setting
      (D-P8).
- [ ] Theme tokens in one place: colour scheme, bucket colours, type scale,
      spacing. No colour literals outside it.
- [ ] Bucket colours differ in lightness as well as hue, and Assign no longer
      borrows the error colour (assignment is part of the strategy, not a
      failure). "No data" stays visually distinct from Leave (Feature
      Invariant 19). Text contrast is at least 4.5:1 in both themes.
- [ ] Golden tests for the bucket badge in all five states, in both themes,
      generated on the Mac (goldens rendered on another OS differ).
- [ ] Existing screens pick up the theme without layout changes. The UI
      reference's token panel is the starting palette.

### Stage 1 — Record a trade in under 20 seconds

**Goal:** log a trade already placed at the broker without touching the
screener.

- [ ] "Record a trade" is reachable in one tap from the start screen.
- [ ] Required inputs are only: ticker, put/call, strike, expiration,
      credit, contracts. Stock price, IV, IV rank and open fee are optional.
- [ ] Recently used tickers appear as one-tap chips.
- [ ] Expiration offers one-tap chips for the next four Fridays plus an
      "Other date" picker; the non-Friday warning and derived DTE behave as
      today.
- [ ] The total-per-contract preference and the credit-bound rules (hard
      reject / soft warn) apply. The missing-stock-price case is already
      decided by Feature Invariant 20: a put's bound is its strike, so it
      needs no stock price; a call with no stock price skips the check
      rather than using a guessed value.
- [ ] Calls follow D-P12. Choosing "Call" says in one line whether the call
      will attach to an existing share-holding cycle or why it can't be
      recorded here.
- [ ] "Happy to be assigned on this one?" defaults on; a missing fee stays
      null, never zero.
- [ ] Annualised yield (screener formula) and capital committed are shown
      before saving.
- [ ] Saving creates the same rows and notifications "Track this position"
      creates; optional fields left blank are stored as null. Existing
      screener scenarios are unchanged except where D-P12 changes the call
      path.
- [ ] The screener stays as built and is linked from this screen.
- [ ] **(owner)** Manual timing check: median under 20 seconds for a repeat
      ticker, recorded in the plan.

### Stage 2 — Snapshot in three taps, with a preview

**Goal:** make the weekly snapshot habit fast and self-explanatory.

- [ ] From the start screen, any position reaches the snapshot sheet in at
      most two taps and is saved at three. A position that needs a reading
      (No data, or a reading older than 7 days, D-P11) opens the sheet
      straight from its row. The existing detail-sheet route still works.
- [ ] Before saving, the sheet shows the bucket the numbers would produce,
      with its reason and the captured %, roll band (with source) and
      extrinsic figures. It is computed by the existing rules engine against
      real `now` and the leg's pinned rule version, with no rule logic in
      widgets.
- [ ] Carried-forward values stay visibly marked; all help chips, sign
      handling and backdating behaviour are preserved.
- [ ] After saving, the user returns where they came from with the badge
      updated.

Batch expiry, first drafted here, moved to Stage 3: there is no Today screen
to put it on before then, and it belongs next to "Expiring this week".

### Stage 3 — Today screen

**Goal:** opening the app answers "what needs me?" and "how is the month
going?" at a glance.

- [ ] Today replaces Positions as the start screen; the positions list, with
      its existing sort options and badge-plus-reason rows, lives inside it.
- [ ] Bucket summary counts for Close, Roll, Assign and Leave. "No data" is
      counted separately (Feature Invariant 19). Readings older than 7 days
      get their own overlapping count (D-P11). Each count filters the list
      when tapped.
- [ ] Ledger strip: premium collected this month and year to date, and
      current capital committed (D-P14). The premium definition is stated on
      screen; the planner pins it (the UI reference shows one candidate).
- [ ] Concentration flag per D-P6, worded neutrally ("INTC 27% of wheel
      capital · limit 25%"). With no wheel capital set there is no flag, and
      a one-line invitation to set it.
- [ ] Settings gains wheel capital and the concentration limit (D-P6).
- [ ] "Expiring this week" card listing legs with the obligation at each
      date: cash needed if puts are assigned, shares delivered if calls are.
- [ ] **Batch expiry** (moved from Stage 2): once an expiration date has
      passed, legs still open appear together on one card with "Mark all
      expired" and a per-leg review. The batch action records each leg
      exactly as "Mark expired" does, with `closedAt` set to the expiration
      date (D-P13); fees stay null; nothing is ever marked without the
      user's action; legs whose latest reading was in the money, or that
      have no reading, are left out of "Mark all" (D-P13). Legs past their
      expiration date appear only on this card, not in the bucket counts.
- [ ] Bottom navigation: Today, Journal, Record (+), Screener, Settings.
- [ ] The export reminder banner and first-run explainer are retained; the
      empty state invites the first trade.
- [ ] The persistent disclaimer appears in Settings and in the first-run
      explainer, in D-P15's exact words (a test pins the string). It is
      missing today: no string in `lib/` says the app is not investment
      advice.

### Stage 4B — Accessibility and polish (the rest of M8)

**Goal:** it works for everyone, on every screen that exists at launch.
Runs once, after Stages 5–8, so no screen is audited twice.

- [ ] Dynamic type up to the largest accessibility size without truncating
      numbers or bucket reasons, on every screen.
- [ ] Every number's VoiceOver label names the quantity ("Delta 0.25", not
      "0.25"). This is a standing convention from Wave 1 on
      (`docs/conventions.md`); this stage audits every screen against it.
- [ ] Haptic feedback when a snapshot changes a bucket.
- [ ] Contrast audit: text contrast at least 4.5:1 on every screen, in both
      themes.

### Stage 5 — Pro plans

**Goal:** one-tap purchase of any of the three plans, with no trade data
ever leaving the device.

- [ ] Three products (monthly, annual, lifetime) mapped to one Pro
      entitlement through RevenueCat (D-P3). No backend of our own; no
      account or sign-in.
- [ ] The annual plan is preselected and supports an introductory free
      trial when one is configured in the store.
- [ ] The entitlement is cached locally, refreshed at launch and on resume,
      and Pro works offline for the cached period.
- [ ] Renewal, grace period, billing retry, cancellation and expiry are all
      handled. A lapsed subscription returns the user to the free tier with
      nothing lost.
- [ ] A lifetime owner never sees a subscription prompt. A subscriber who
      buys lifetime is told to cancel the subscription and shown the store's
      "Manage subscription" page.
- [ ] Settings shows the current plan, renewal date and a "Manage
      subscription" link.
- [ ] The privacy label and privacy policy accurately describe what the
      purchase SDK collects, checked against RevenueCat's published privacy
      guidance when the label is filled in, and a test or check confirms no
      trade, snapshot or ledger data is sent over the network.
- [ ] Free tier: every existing feature plus Stages 1–3 and the share card,
      up to three open cycles. Opening a fourth cycle (from the screener or
      Record) shows the paywall. Rolls, assignment and covered calls on an
      existing cycle, including a call recorded under D-P12, never count as
      a new cycle.
- [ ] **Nothing already recorded ever locks.** Viewing, snapshots, roll,
      close, assign, journal and JSON export/restore work in every
      entitlement state, including after a lapse, refund or revocation.
- [ ] The entitlement is checked in exactly one place in the state layer
      (never in widgets), with tests for both states.
- [ ] The paywall opens only from: a fourth cycle, tapping a Pro feature, or
      the Settings row. It never opens on launch.
- [ ] "Restore purchases" is available on the paywall and in Settings.
      Pending, cancelled, failed and revoked purchases are all handled.
- [ ] Prices, periods and trial terms shown come from the store (localised),
      not hard-coded. Paywall copy passes the tone grep.
- [ ] **(owner)** Sandbox purchase, renewal, trial conversion, cancellation,
      restore and refund are each exercised and recorded.

### Stage 6 — Screenshot scan (Pro)

**Goal:** replace typing with a screenshot.

- [ ] Available from the snapshot sheet and from Record a trade: pick a
      screenshot (D-P4), text is read on-device, then a confirm-and-correct
      view shows every parsed field beside the text it came from. Nothing
      fills in without the user's confirmation.
- [ ] Snapshot fields: option mark, stock price, delta (sign exactly as
      shown), IV. Trade fields: ticker, put/call, strike, expiration, fill
      price, quantity. A call read from a screenshot still follows D-P12.
- [ ] First supported layout: the owner's broker's option detail screen
      (D-P10), light and dark mode.
- [ ] The image and recognised text never leave the device, and the image,
      including the picker's temporary copy, is gone after the flow ends.
- [ ] The parsing logic is pure Dart and tested against recorded text
      fixtures; the text-recognition call sits behind an interface, and the
      iOS implementation is the Vision platform channel (D-P4).
- [ ] **(owner)** At least 20 real screenshots supplied. Fixtures are
      recorded from Vision's output on iOS; ML Kit's output differs and gets
      its own fixtures in Stage 13.
- [ ] Accuracy on those 20+ screenshots: at least 95% of fields correct, and
      **zero wrong values presented as confident**. An uncertain field is
      flagged, never guessed.
- [ ] An unreadable image falls back to manual entry with the fields
      untouched.
- [ ] **(owner)** The photo picker and scan flow exercised on a physical
      iPhone.

### Stage 7 — Portfolio and assignment calendar (Pro)

**Goal:** see exposure across the whole book (completes `brief.md` §5.6).

- [ ] Current capital committed (D-P14) in total and per underlying, with
      concentration against wheel capital and the D-P6 limit. It reuses the
      calculations built for Stage 3; there is one implementation.
- [ ] Net position delta in share equivalents, using signed position delta
      from each snapshot's stored convention, plus shares held. All four
      sign quadrants are tested. Figures that use a reading older than 7
      days (D-P11) are labelled with its date. Positions with no reading are
      left out of the total and counted beside it.
- [ ] Month calendar of expirations with the obligation at each date.
- [ ] Bucket summary, with "No data" reported separately.

### Stage 8 — Share card (free)

**Goal:** every user can post their month, and each post shows the app.

- [ ] A monthly summary image built from closed cycles: return on capital,
      cycles closed, cycles closed positive, average days in cycle, and
      **median** premium capture (Feature Invariant 29: the Journal's own
      figure, never a mean).
- [ ] Return on capital states its definition on the card. If any cycle in
      the month is missing fee data, the card says "before fees"
      (`brief-ledger.md` §4.3).
- [ ] The planner pins how the month's return on capital is aggregated and
      which date places a cycle in a month.
- [ ] Dollar amounts are **hidden by default**; toggles for dollar amounts
      and tickers.
- [ ] Shared as an image through the existing share sheet, at a fixed size
      suitable for social posts, correct in both themes.
- [ ] Descriptive statistics only: no streaks, badges or praise. The footer
      names the app and says it is a journal and calculator, not advice
      (D-P15).

### Stage 9 — Beta and App Store launch

**Goal:** shipped, approved and priced.

- [ ] **(owner)** TestFlight beta with at least 20 external wheel traders for
      at least two weeks; crash-free sessions of at least 99.5%, measured
      from Apple's own TestFlight and Xcode Organizer crash data (no crash
      SDK, D-P3); feedback collected and triaged into the plan.
- [ ] Store listing, screenshots and keywords position the app as a
      journal and calculator (D-P15), with no advice or signal wording and
      no broker or other brand names in the keywords.
- [ ] Privacy policy and support URLs are live; the privacy label matches
      D-P3 exactly; the listing says trades never leave the phone; age
      rating answered as a tracking tool; review notes explain manual entry,
      on-device screenshot reading and the disclaimer.
- [ ] Subscription and lifetime metadata, the subscription group, and the
      review screenshot are submitted with the build. The paywall shows
      price, period, trial terms and auto-renewal terms, and links to terms
      of use and the privacy policy, as App Review requires for
      subscriptions.
- [ ] Launch-gate checklist in §6 fully green.

---

## 5. Delivery waves

Each wave gets its own plan file. A wave is planned when the one before it
is done and its owner prerequisites are in place.

| Wave | Stages, in order | Owner prerequisites before planning |
|---|---|---|
| 1 — Daily use | 0 → 4A → 1 → 2 → 3 | none |
| 2 — Pro plans | 5 | RevenueCat project; products, subscription group and annual trial in App Store Connect; Paid Apps agreement, tax and banking forms |
| 3 — Pro features and share card | 6, 7, 8 | broker named (D-P10); at least 20 real screenshots, light and dark |
| 4 — Launch | 4B → 9 | privacy policy, support page, beta testers recruited |

- Running Stage 4A before Stages 1–3 delays Record by one phase in exchange
  for building three screens once.
- Stage 7 reuses Stage 3's capital and concentration calculations. Plan
  Stage 3 knowing Stage 7 will need per-underlying figures.
- Stage 8 has no Pro dependency and may move earlier if the beta wants it;
  it must still come before Stage 9.
- Owner items with long lead times (the Paid Apps agreement, tax and
  banking, screenshot collection, beta recruiting) start now, in parallel
  with Wave 1.

---

## 6. Launch gate

Stages 0–9, including 4A and 4B, complete, with every owner check recorded.
Stages 10–14 are not required to launch.

---

## 7. Post-launch (Stages 10–13 in order; Stage 14's place is open)

### Stage 10 — Broker CSV import (Pro)

**Goal:** bring in history instead of retyping it (D-P10, one broker).

- [ ] Preview before import, showing which cycles, legs, rolls, assignments
      and fees will be created.
- [ ] All or nothing: a file that fails validation changes nothing.
- [ ] Re-importing the same file creates no duplicates.
- [ ] Rows that can't be matched confidently are listed for the user, not
      guessed.

### Stage 11 — Tax-year export and account labels (Pro)

**Goal:** answer "what did I realise this year, per account?"

- [ ] Optional account label per cycle (e.g. "IRA", "Taxable"), filterable
      on Today, Journal and exports.
- [ ] CSV of realised results per calendar year, with both basis figures
      labelled and the `brief.md` §3.6 tax note included verbatim.
- [ ] No wash-sale computation; the note says it isn't computed.

### Stage 12 — Home-screen widget (Pro)

**Goal:** see what needs attention without opening the app.

- [ ] Shows bucket counts, the count of readings older than 7 days (D-P11)
      and the next expiration, read from local data only.

### Stage 13 — Android

**Goal:** double the addressable market.

- [ ] Play Store release with the same three plans through Play Billing
      (RevenueCat). Purchases don't transfer between stores.
- [ ] Screenshot scan works with ML Kit on-device recognition behind the
      Stage 6 interface, with its own recorded fixtures, and the Data safety
      section discloses its diagnostics (D-P4).
- [ ] `allowBackup` and data extraction rules configured (`brief.md` §9).
- [ ] Notification permission and exact-alarm behaviour verified; the app
      stays fully usable when permission is denied.
- [ ] **(owner)** A full wheel-loop walk-through on a physical Android
      device, including the photo picker.

### Stage 14 — Start from shares I already own

**Goal:** record covered calls on shares bought outside the app, with
correct figures (D-P12). Tier and position in the order are decided when it
is planned.

- [ ] The user enters shares already held: ticker, number of shares (a
      multiple of 100), cost per share and acquisition date. This opens a
      share-holding cycle that the next covered call attaches to under
      D-P12, and counts toward D-P2 like any new cycle.
- [ ] Both basis figures are shown and labelled, with the `brief.md` §3.6
      tax note verbatim.
- [ ] Capital committed, stock P&L when the call is assigned, and net delta
      come out the same as for a cycle that began with a put assigned at
      that cost.

---

## 8. Owner items (outside the agents' scope)

- §2 is ratified. Still open: name the broker for Stage 6 and D-P10 before
  Wave 3 is planned.
- Create the RevenueCat project and configure the products, the
  subscription group and the annual trial in App Store Connect (before
  Wave 2).
- Apple Developer Program membership, Paid Apps agreement, tax and banking
  forms. Start now; they take calendar time.
- Host the privacy policy, support page and a landing page with a waitlist
  (before Stage 9).
- Provide 20+ real broker screenshots, light and dark, as Stage 6 fixtures
  (before Wave 3).
- Recruit beta testers from wheel-trading communities (before Stage 9).
- Set prices in App Store Connect. The UI reference shows $4.99/month,
  $29.99/year with a 7-day trial, and $79.99 lifetime as sample prices
  only; the app shows whatever the store returns.
- Run the checks marked **(owner)** and record them in the wave's plan.
- Keep shipping post-launch stages on a steady cadence: subscribers are
  paying for ongoing updates, and App Review expects ongoing value.
- Track the funnel with App Store Connect analytics (page views, downloads)
  and RevenueCat (trials, conversions, churn); no other SDK is needed.

---

## Appendix: changes from the first draft (2026-09-28)

The first draft was checked against the code and the binding docs before
planning. Changes:

- **D-P6** measures concentration against user-set wheel capital instead of
  capital committed, which would have flagged every free-tier book
  permanently.
- **D-P11–D-P14 added**: readings older than 7 days (overlapping count),
  calls on Record, expiry recording the expiration date, and current versus
  peak capital committed.
- **D-P15 added**: the disclaimer's exact wording, which presents the app as
  a journal and calculator and tells the user nothing to do. It replaces
  `brief.md` §10's suggested text, and the share card and store listing use
  the same wording.
- **D-P3** now says "the only SDKs that may use the network", because the
  first draft's "the only third-party SDK allowed" contradicted D-P4's ML
  Kit. `docs/conventions.md` §5 added to what it supersedes.
- **D-P4** names the approach: Vision through an in-repo platform channel,
  and `image_picker` for the picker, both approved.
- **Stage 0**: the removal set is four packages plus an
  `analysis_options.yaml` entry, not two; the crash's log location is
  corrected; the device check exercises the restore file picker, since no
  photo picker exists yet; the `CLAUDE.md` update was done with this brief.
- **Stage 1**: the credit-bound fallback was already decided by Feature
  Invariant 20; calls follow D-P12.
- **Stage 2**: "two taps" made concrete; batch expiry moved to Stage 3.
- **Stage 3**: the first draft attributed stale-snapshot counting to Feature
  Invariant 19, which covers only "No data" (now D-P11); capital committed
  is the current figure (D-P14); the missing disclaimer added, in D-P15's
  words.
- **Stage 4** split into 4A (theme, before Stages 1–3) and 4B
  (accessibility, once every screen exists).
- **Stage 8**: premium capture is the median (Feature Invariant 29), not an
  average; fee-incomplete months say "before fees".
- **§5 Delivery waves** added; owner checks marked; Stage 14 added.
- **UI reference** replaced with `docs/design/pro-ui-reference.html`.
