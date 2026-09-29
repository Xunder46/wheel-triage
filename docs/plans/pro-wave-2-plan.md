# Feature: Wheel Triage Pro — Wave 2 "Pro plans" (Stage 5)

> Status: DRAFT — five derived interpretations marked *(derived — vetoable)*
> below; the owner prerequisites in `docs/brief-pro.md` §5 are **not yet
> confirmed**, so every store/sandbox check in this plan is marked **(owner)**
> and the wave is planned to be fully agent-verifiable without them.
> Next handoff: @data-architect (Phase 1)
> Binding conventions: `docs/conventions.md` (+ `docs/architecture/wheel-triage.md`;
> spec: `docs/brief-pro.md` §2/§3/§4/§5; UI reference:
> `docs/design/pro-ui-reference.html`, non-binding)
> S-ids: S-255 … S-289 (continue after the highest existing id, S-254; never
> reused)

## Overview

Wave 1 made the app cheap to use daily. This wave makes it **sellable**: three
store products, one Pro entitlement, one free-tier limit, and one paywall —
without a single byte of trade data leaving the phone.

Four things change and one thing is added:

- **The free tier gets a boundary.** Today every feature is unlimited. After
  this wave, up to **three open cycles** (D-P2) are free; a **fourth new cycle**
  — from the screener or from Record — refuses with one line and opens the
  paywall. Rolls, assignment, covered calls on an existing cycle (including
  D-P12's attached call) and every read never consult the limit at all.
- **A purchase seam lands.** `purchases_flutter` (the one pre-approved new
  dependency, D-P3) is reached through a single gateway interface, exactly as
  `NotificationGateway` already fronts `flutter_local_notifications`. The
  RevenueCat API key and the store products are **configuration, never code**:
  with no key configured the app runs the free tier and shows an honest
  "unavailable" paywall, which is also what every test sees.
- **An entitlement cache lands** (schema **v6**, one new table). It is
  deliberately **not** part of the export envelope: restoring a ledger must
  neither grant nor revoke Pro.
- **Two screens land.** The paywall (three entry points, never on launch) and
  a Settings plan row (plan, renewal date, Manage subscription, Restore
  purchases).

**Nothing already recorded is ever locked, in any entitlement state.** Viewing,
snapshots, roll, close, assign, the journal and JSON export/restore all keep
working after a lapse, a refund or a revocation. That is a Feature Invariant
with its own scenarios, not an aspiration — the only thing the limit can ever
refuse is the creation of a *new* cycle.

Wave 1's last phase (`pro-wave-1-plan.md`, Phase 11) closed Stage 0 → 4A → 1 →
2 → 3 and left the tree at schema v5 with `flutter test` 733 passed / 0 failed.
Wave 3 (Stages 6–8) and Wave 4 (Stages 4B → 9) get their own plan files.

## Resolved Decisions (Ledger)

Entries are enforceable contracts. Immutable once written; changes are new
superseding entries.

**D-21 — Wave scope** *(derived — vetoable)*. This plan file covers Stage 5
only: the purchase SDK, the entitlement, the free-tier limit, the paywall and
the Settings plan row. Nothing here implements the screenshot scan (Stage 6),
the portfolio view or assignment calendar (Stage 7), the share card (Stage 8),
the accessibility audit (Stage 4B), the Android build (D-P9) or the store
listing. It also adds no analytics, crash-reporting or ad SDK, and no backend
or account of any kind (D-P3).

**D-22 — "Open cycle", exactly.** A cycle is **open** when
`cycle.status != WheelCycleStatus.closed` — that is, `sellingPuts` **or**
`holdingShares`. The count is over **all underlyings**, never per ticker. A
`holdingShares` cycle with no open call counts as open; a closed cycle never
counts, so closing one frees a slot immediately. The count is read through one
new repository method, `getOpenCycles()`, ordered by `startedAt` ascending
(ties: unspecified beyond the set, and the contract fixture gives distinct
instants) — the D-P2 count is never derived by grouping `getAllLegs()`, which
would miss a `holdingShares` cycle with no open call (exactly the D-P12 case).

**D-23 — The free-tier limit and its single evaluation point.**
`kFreeTierOpenCycles = 3`. The limit is evaluated by exactly one function,
`NewCycleGate.evaluate()`, and called from exactly one place:
`RecordSaveService.save`'s **new-cycle branch**, *before* it calls
`getOrCreateUnderlying` — a refusal must not write the `Underlying` row the
user did not ask for (S-234's principle, and the reason the check cannot sit
after the underlying lookup). It returns one of:

```
allowed  ⇔  entitlement.status == active
            ∨ getOpenCycles().length < kFreeTierOpenCycles
blocked  ⇔  otherwise
```

`blocked` produces `RecordSaveResult.paywallRequired(trigger: …)` — a new
`RecordSaveOutcome.paywallRequired` alongside `created`/`attached`/`refused` —
and writes **no row of any table**. Only `active` unlocks: `inactive` **and**
`unknown` both behave as free (D-26). Rolls (`recordRoll`), assignment
(`recordAssignment`), called-away (`recordCallAway`), covered calls on an
existing cycle (`openNextLeg`, including D-P12) and every read never call the
gate, because none of them creates a cycle.

**D-24 — The two refusal lines (exact copy).** One function per line, in
`lib/core/purchases/paywall_copy.dart`, with the count substituted:

- exactly at the limit (`count == kFreeTierOpenCycles`): "You have 3 open
  cycles, the free plan's limit, so recording a fourth needs Pro. Everything
  you've already recorded stays available on every plan."
- past the limit (`count > kFreeTierOpenCycles`, reachable only after a lapse):
  "You have 5 open cycles, past the free plan's limit of 3, so recording
  another needs Pro. Everything you've already recorded stays available on
  every plan."

Both pass the §4 tone grep and neither pairs an action verb with a named
security or the user's own position. The paywall renders the line it was
handed; it never re-evaluates the gate (D-30).

**D-25 — The entitlement cache is its own table (schema v6).** One new table,
`entitlement_cache`, holding exactly one fixed-id row
(`EntitlementCacheDefaults.rowId`), mirroring `user_preferences`' singleton
shape:

| Column | Type | Notes |
|---|---|---|
| `id` | `TEXT` PK | fixed `'default'`; never surfaced through `WheelRepository` |
| `is_active` | `BOOL` | not null, default `false` |
| `plan_kind` | `TEXT` | not null, default `'none'`; `ProPlanKindConverter` (stored as `.name`, never an index) |
| `expires_at_ms` | `INT?` | `DateTimeMsConverter`; `null` for lifetime and for "never checked" |
| `will_renew` | `BOOL` | not null, default `false` |
| `billing_issue` | `BOOL` | not null, default `false` |
| `purchased_at_ms` | `INT?` | `originalPurchaseDate`, for the Settings row |
| `checked_at_ms` | `INT?` | when this row was last written from a successful store read; `null` = never |

- The model is `EntitlementCacheData` (`lib/domain/models/entitlement_cache.dart`,
  `@freezed`, **no** `json_serializable`): it is store-derived state with no
  wire format, because it is deliberately **excluded from the export
  envelope**. Adding it to `LedgerExport` would let a hand-edited backup file
  grant Pro, and restoring an old ledger would silently revoke it. The export's
  key set therefore stays exactly the nine keys it has today.
- `restoreFromJson` deletes eight named tables
  (`drift_wheel_repository.dart:616-623`) and must **not** be extended with
  `entitlement_cache`: a restore is a ledger operation, not a purchase
  operation.
- Migration `v5 → v6`: `m.createTable(entitlementCacheTable)` +
  `seedEntitlementCache()`, gated `if (from < 6 && to >= 6)` like every step
  above it; `onCreate` calls the same seed. No `from >= N` column guard is
  needed — the table is new, so a direct `v1 → v6` jump creates it from its
  current Dart definition.
- Both repositories implement `getEntitlementCache()` /
  `saveEntitlementCache(EntitlementCacheData)`; the in-memory one initialises
  its row from `EntitlementCacheDefaults`, exactly as it initialises
  `_preferences` from `UserPreferencesDefaults`.

**D-26 — Entitlement state is tri-valued, and only `active` unlocks.**

```
EntitlementStatus { active, inactive, unknown }
```

- `active` — the store (or the cache) says the entitlement is active. A
  subscription in its **trial**, in a **grace period** or in **billing retry**
  is `active` (RevenueCat reports the entitlement as active throughout);
  `billingIssue` rides alongside it for display only.
- `inactive` — a store read **succeeded** and reported no active entitlement.
- `unknown` — no store read has ever succeeded and the cache has never been
  written (`checkedAt == null`). **`unknown` behaves exactly as `inactive`**:
  free tier, paywall available, Settings says so honestly. Pro is never forged
  from an absent answer.

A **failed** read falls back to the last known good state: `active` if the
cache says active (this is what "Pro works offline for the cached period"
means), otherwise `inactive`, otherwise `unknown`. The cache is written only
after a **successful** read — a failed read never overwrites good state.

**D-27 — One gateway seam; exactly one file may touch the SDK.**
`lib/core/purchases/purchase_gateway.dart` declares the interface and its value
types, in the shape `NotificationGateway` already established:

```dart
abstract class PurchaseGateway {
  Future<void> configure();                       // idempotent
  Future<ProOfferings?> loadOfferings();           // null when the store is unreachable
  Future<EntitlementSnapshot> currentEntitlement();
  Future<PurchaseOutcome> purchase(String productId);
  Future<PurchaseOutcome> restore();
  Future<void> showManageSubscriptions();
  void addEntitlementListener(void Function(EntitlementSnapshot) listener);
}
```

`PurchaseOutcome` is a sealed class with `purchased`, `pending`, `cancelled`,
`failed` and `unavailable`. `ProPlanOffer` carries the store's own
`priceString`, numeric `price` (as `Decimal`), `currencyCode` and optional
`TrialOffer` (`units` + `unit`). **No type in this file is a trade, snapshot,
leg or ledger type** — the interface cannot carry trade data by construction.

- `RevenueCatPurchaseGateway`
  (`lib/core/purchases/revenuecat_purchase_gateway.dart`) is the **only** file
  in `lib/` permitted to import `purchases_flutter`, and it imports nothing
  from `lib/data/` or `lib/domain/models/`.
- The provider's default is `UnconfiguredPurchaseGateway`: no offerings, an
  `unknown` entitlement, every purchase `unavailable`. This mirrors
  `notificationGatewayProvider`'s deliberate safe default and is what keeps the
  many existing tests that pump Settings working unchanged. `main.dart` **always**
  overrides it, choosing `RevenueCatPurchaseGateway` when the key is present and
  `UnconfiguredPurchaseGateway` when it is not — a permanent structural test
  asserts that override exists, so a missing wire-up fails CI rather than
  silently showing every Pro user the free tier.
- The key comes from `const String.fromEnvironment('REVENUECAT_IOS_API_KEY')`
  in `lib/core/purchases/purchase_configuration.dart`. **It is never written
  into the repository**; the owner supplies it at build time (the exact command
  is in `docs/architecture/wheel-triage.md`). The store product identifiers and
  the entitlement identifier **are** code (`lib/core/purchases/pro_plans.dart`),
  because they are not secret and the owner creates the products to match them.
- `configure()` is a no-op unless `defaultTargetPlatform ==
  TargetPlatform.iOS` (D-P9 defers Android; this also keeps `dart:io` out of
  `lib/`, D-35). On any other platform the gateway reports no offerings and an
  `unknown` entitlement.

**D-28 — The entitlement is read in exactly one place.** `EntitlementController`
(`lib/state/entitlements/`) is the only reader of `PurchaseGateway`;
`entitlementControllerProvider` is the only source of entitlement state for
everything else; `NewCycleGate.evaluate()` is the only evaluation of D-23. No
widget decides whether the user is Pro: the Settings row and the paywall
**render** state, and the two save screens **react to an outcome**
(`paywallRequired`), never to a boolean. Permanent structural guards: no file
under `lib/features/` imports `purchase_gateway.dart` or `purchases_flutter`,
and `NewCycleGate` is referenced from exactly one non-test file.

**D-29 — Three refresh points, one method.** `EntitlementController.refresh()`
is called (a) once at launch, after the gateway is configured and the cache is
loaded; (b) on `AppLifecycleState.resumed`, through a small
`EntitlementLifecycleScope` widget wrapping the app shell (a focused widget
makes S-270 a cheap test and keeps `main.dart` declarative); and (c) from the
gateway's own entitlement-update listener, which is where a renewal, a trial
conversion or a billing-retry resolution actually arrives. `refresh()` never
throws and is safe to call concurrently with itself.

**D-30 — The paywall's entry points.** Exactly three, and the paywall never
opens on launch:

1. a **fourth cycle** — the save result is `paywallRequired`, and the screen
   calls `showPaywall(context, trigger)` with the D-24 line the state layer
   computed;
2. a **Pro feature** — defined and tested this wave, with no caller until Wave
   3 (Stages 6–8); the trigger line names the feature;
3. the **Settings row**.

`showPaywall` is one function in `lib/features/paywall/paywall_route.dart`; a
structural test asserts `context.push('/paywall'` appears nowhere else in
`lib/`. The route takes its trigger as `extra`; a missing `extra` (a deep link)
falls back to the Settings trigger. When the entitlement is already `active`,
the paywall renders the owned state instead of a purchase button (D-33).

**D-31 — Paywall content, plan order and store truth (pins OC-9).** The plan
rows are built **only** from `loadOfferings()`: display order annual, monthly,
lifetime, rendering whichever subset the store returned, with **annual
preselected** when present (otherwise the first available). Every price is the
store's `priceString`; every period and every trial term comes from the store's
own fields. Nothing in `lib/` hard-codes a price, a period, a trial length or a
currency symbol — the only store facts in code are the three product
identifiers and the entitlement identifier, in `lib/core/purchases/pro_plans.dart`.
`ProPlanKind` (`none | monthly | annual | lifetime`) lives in
`lib/domain/models/pro_plan_kind.dart`; the product-id → kind mapping exists
once, in `pro_plans.dart`.

The annual row's per-month figure is **derived**, not fetched:
`annualPrice / 12` computed as `Decimal`
(`(price / Decimal.fromInt(12)).toDecimal(scaleOnInfinitePrecision: 2)` —
`Decimal`'s `/` yields a `Rational`, per `pubspec.yaml`'s note), converted to
`num` only inside the display formatter. The paywall makes **no savings
claim** and lists **launch features only**, per OC-9.

**D-32 — Purchase outcomes and their copy.** Every outcome is handled and each
one has its own line (all in `paywall_copy.dart`, all tone-checked):

| Outcome | Line | Entitlement |
|---|---|---|
| `purchased` | "Pro is on." (plus D-33's lifetime case) | refreshed immediately |
| `pending` | "Your purchase is pending. Pro unlocks as soon as the store approves it." | unchanged |
| `cancelled` | none — the user did it deliberately; the paywall is left as it was | unchanged |
| `failed` | "The purchase didn't complete. You can try again, or restore purchases." | unchanged |
| `unavailable` | "The App Store isn't reachable right now. Nothing was charged." | unchanged |

Restore: "Purchases restored." on success; "No purchases to restore on this
App Store account." when the store reports none.

**D-33 — Lifetime rules.** A lifetime entitlement has no expiry, no renewal
date and never lapses, and its owner is never shown a subscription prompt:
the Settings row shows "Pro · Lifetime" + "Purchased <date>" with no upgrade
row, and if the paywall is opened at all while lifetime is active it renders
the owned state with no purchase button. A **subscriber who buys lifetime** is
told to cancel the subscription and offered the store's own Manage
subscription page (D-P3 has no backend to cancel on): "You now have lifetime
Pro. Cancel the subscription in your App Store account settings so it doesn't
renew." + a "Manage subscription" button calling
`PurchaseGateway.showManageSubscriptions()`.

**D-34 — The Settings plan row.** A `_ProPlanSection` at the **top** of
Settings' `ListView`, above "Defaults for new entries":

| Entitlement state | Header line | Second line | Rows |
|---|---|---|---|
| `active`, subscription | "Pro · Annual" | "Renews Oct 5, 2027" (or "Cancels Nov 3, 2026" when `willRenew == false`) | Manage subscription (chevron), Restore purchases |
| `active`, subscription with a billing issue | as above | as above **plus** "There's a billing problem with your subscription. Pro stays on while the store retries." | as above |
| `active`, lifetime | "Pro · Lifetime" | "Purchased Mar 3, 2026" | Restore purchases |
| `inactive` | "Free · 2 of 3 open cycles" | "Everything you've recorded stays available." | "See Pro plans" (opens the paywall), Restore purchases |
| `inactive`, past the limit (`n > 3`) | "Free · 5 open cycles" | as above | as above |
| `unknown` | "Pro status unavailable" | "Purchases can be restored from this App Store account." | Restore purchases |

The count comes from `getOpenCycles().length` — a count display, not a gate
evaluation. `renewalDateText(DateTime)` ("Oct 5, 2027") is added to
`lib/core/format.dart`, one place, with a test.

**D-35 — The network boundary is a permanent guard, not a one-off audit.**
`lib/` contains **zero** matches for `dart:io`, `package:http`, `HttpClient`,
`Socket`, `WebSocket`, `NetworkImage`, `package:dio` or `url_launcher` (the
current count is 0 for every one of them, so the guard starts from a clean
baseline). The only network-capable dependency is `purchases_flutter`, and the
only file that imports it is `revenuecat_purchase_gateway.dart`. Both facts are
asserted by a test that reads `lib/` (`test/core/purchases/network_boundary_test.dart`)
so the rule fails CI, and re-run as a Done Criterion grep in every phase.

**D-36 — The disclosure lives in the repository, the label is the owner's.**
`docs/privacy.md` (new) states, in the words the store label and the hosted
policy are written from: what RevenueCat collects (purchase history and an
app-scoped identifier), what the app never transmits (no trade, snapshot,
ledger, share-card or image data), and the in-app sentence the paywall shows.
The App Store Connect privacy label and the hosted policy remain **owner**
items (Wave 4, Stage 9).

**D-37 — No URL-opening dependency this wave** *(derived — vetoable)*. The
paywall's "Terms of Use" and "Privacy Policy" entries render as
`SelectableText` URLs rather than tappable links, because opening a URL needs
`url_launcher` and D-P3 pre-approves only `purchases_flutter`. This is the one
place the wave deliberately ships a degraded affordance, it affects no other
surface, and it is raised as an owner question (Open questions Q1). "Manage
subscription" is unaffected — it goes through the SDK, which needs no launcher.
Terms of Use defaults to Apple's standard EULA URL; the Privacy Policy URL is
an owner-supplied constant in `lib/core/purchases/pro_plans.dart`, and its
entry is hidden while that constant is empty.

**D-38 — Deliberately not in this wave.** The screenshot scan, the portfolio
view and assignment calendar, the share card, the accessibility audit, the
Android build and its Play Billing key, the store listing, the hosted privacy
policy and Terms page, the App Store Connect products themselves, and any
change to gate ordering, thresholds, money units or the profile model. The
free tier is not extended or restricted anywhere else: every feature shipped
through Wave 1 is available on it.

## Feature Invariants

Only the invariants that bite here. Project-wide rules stay in
`docs/conventions.md` — referenced, not copied.

1. `lib/domain/rules/` stays pure Dart with **zero Flutter imports**
   (`grep -rl "package:flutter" lib/domain/rules/` returns nothing). The
   free-tier limit is a **product** rule, not a market rule, so it lives in
   `lib/state/`, never in the rules engine.
2. No `double` for money: a store price is a `Decimal` and the derived
   per-month figure is a `Decimal`, converted to `num` only inside the display
   formatter. No `double` reaches any of Gates 1–4 — this wave adds no gate
   input.
3. Repository parity: `getOpenCycles`, `getEntitlementCache` and
   `saveEntitlementCache` ship in `DriftWheelRepository` **and**
   `InMemoryWheelRepository` in the same phase, with contract coverage. Neither
   may throw `UnimplementedError`.
4. Schema contract: `lib/data/db/schema/drift_schema_v6.json` stays in step
   with the tables and is exercised by a migration test, so drift fails CI.
5. **Nothing already recorded ever locks.** Every read and every write path
   except the fourth-new-cycle refusal works identically in `active`,
   `inactive` and `unknown`. A scenario proves it, and it is a Done Criterion
   on every phase that touches the gate.
6. The entitlement is read in exactly one place (D-28); no widget decides Pro.
7. Only `purchases_flutter` may use the network, and no trade, snapshot,
   ledger, share-card or image data ever reaches it (D-35).
8. Tone: no banned word from `docs/conventions.md` §4 appears in any new
   string, and no sentence pairs an action verb with a named security or the
   user's own position. The paywall's copy is the highest-risk new copy in the
   app and gets a unit test, not only a grep.
9. Store truth: no price, period, trial length or currency symbol shown to the
   user is hard-coded; the only store facts in code are product and entitlement
   identifiers.
10. `lib/features/` never imports the purchase gateway or the SDK; screens read
    `entitlementControllerProvider` and react to outcomes.
11. Every number on a new screen has a semantics label naming its quantity
    (`docs/conventions.md` §9, standing from Wave 1).
12. `docs/conventions.md` §5's network rule is satisfied by D-P3's revision —
    the purchase SDK is the only permitted network user — and D-35 is what
    keeps it true.

## Requirements

From `docs/brief-pro.md` §4 (Stage 5) and §5 (Wave 2), each bullet an
acceptance criterion. R16–R17 are ledger-derived (D-22, D-26).

| # | Requirement | Scenarios |
|---|---|---|
| R1 | Three products mapped to one Pro entitlement, no backend, no account | S-278, S-281 |
| R2 | Annual preselected; introductory free trial when the store has one | S-278 |
| R3 | Entitlement cached, refreshed at launch and on resume; Pro works offline for the cached period | S-269, S-270, S-271 |
| R4 | Renewal, grace period, billing retry, cancellation and expiry handled; lapse returns to free with nothing lost | S-268, S-272, S-273 |
| R5 | Lifetime owner never sees a subscription prompt; subscriber buying lifetime is told to cancel and shown Manage subscription | S-283, S-286 |
| R6 | Settings shows the plan, the renewal date and a Manage subscription link | S-285, S-286 |
| R7 | Privacy accurate; a test or check confirms no trade, snapshot or ledger data over the network | S-287, S-288, S-289 |
| R8 | Free tier up to three open cycles; a fourth cycle shows the paywall | S-258, S-259, S-260 |
| R9 | Rolls, assignment and covered calls on an existing cycle (incl. D-P12) never count | S-261, S-262, S-263, S-264 |
| R10 | Nothing already recorded ever locks, in any entitlement state | S-267, S-268 |
| R11 | The entitlement is checked in exactly one place in the state layer, never in widgets, with tests for both states | S-265, S-259, S-260 |
| R12 | The paywall opens only from a fourth cycle, a Pro feature or the Settings row; never on launch | S-276, S-277 |
| R13 | Restore purchases on the paywall and in Settings; pending, cancelled, failed and revoked purchases all handled | S-281, S-282, S-274, S-285 |
| R14 | Prices, periods and trial terms come from the store, localised; paywall copy passes the tone grep | S-278, S-279, S-284 |
| R15 | **(owner)** Sandbox purchase, renewal, trial conversion, cancellation, restore and refund each exercised and recorded | **no scenario, by design** — an agent cannot drive a sandbox store account on a physical device; see the owner rows in Progress |
| R16 | "Open cycle" means `status != closed`, over all underlyings, read once from the repository | S-258, S-264 |
| R17 | Only `active` unlocks; `unknown` behaves as free and Pro is never forged from an absent answer | S-269, S-274 |

## Existing-Functionality Impact

Each row: touched surface → what already reads it (with the grep that found
it) → effect → guard.

| Touched surface | Existing readers (grep) | Effect | Guarded by |
|---|---|---|---|
| `RecordSaveService.save` | `lib/state/record/record_controller.dart:317`, `lib/state/screener/screener_controller.dart:299` (both `ref.read(recordSaveServiceProvider).save(…)`); `test/state/record/record_save_service_test.dart:115` | The new-cycle branch gains the D-23 gate *before* `getOrCreateUnderlying`; a `paywallRequired` result joins the three existing outcomes. Every put on a book with <3 open cycles and every call is byte-for-byte unchanged | S-260 (nothing written), S-266 + every existing record/screener scenario stays green |
| `RecordSaveResult` / `RecordSaveOutcome` | `lib/state/record/record_controller.dart:333`, `lib/state/screener/screener_controller.dart:315` (`result.isRefused` → `state.error`); `test/state/record/*`, `test/state/screener/*` | Additive: a new enum value and a new named constructor. `isRefused` keeps its meaning, so a refusal still surfaces as `state.error` | S-260, S-266 + the existing refusal scenarios (S-234/S-235) |
| `WheelRepository` | both implementations (`lib/data/db/drift_wheel_repository.dart`, `lib/data/in_memory_wheel_repository.dart`) + `test/data/wheel_repository_contract_test.dart` | Three new methods (D-22, D-25). Additive; no existing signature changes | S-256, S-258 + the shared contract suite |
| `DriftWheelRepository.restoreFromJson` delete list (`:654-661`) | `lib/state/export/export_controller.dart:69`, `lib/features/settings/settings_screen.dart:65-70` | **Unchanged** — `entitlement_cache` is deliberately absent, so a restore neither grants nor revokes Pro | S-257 |
| `LedgerExport` envelope (`currentFormatVersion` 2, nine keys) | `lib/data/export/ledger_export.dart`, `test/data/export/ledger_export_test.dart`, `ledger_import_test.dart` | **Unchanged** — the entitlement is not exported. `currentFormatVersion` stays 2 | S-257 |
| `AppDatabase.schemaVersion` (5 → 6) and every migration test that targets the current version | `test/data/user_preferences_migration_test.dart`, `test/data/db/app_database_migration_test.dart`, `leg_v3_migration_test.dart`, `rule_profile_v4_migration_test.dart`, `user_preferences_v5_migration_test.dart` | Each "migrated all the way to the current version" test is **retargeted to v6** in the same phase — the A-2 lesson from Wave 1, where a later version's `createTable` changed what an earlier step's fresh-create produced | S-255 + all five retargeted suites green |
| `WheelTriageApp` (`lib/main.dart:64`) | `test/widget_test.dart:22,38` | Becomes the host of `EntitlementLifecycleScope` (D-29) and gains a `purchaseGatewayProvider` override. Both smoke tests keep passing because the default gateway is unconfigured, not absent | S-270 + `test/widget_test.dart` |
| `SettingsScreen` body (`ListView`) | `test/features/settings/settings_screen_test.dart`, `rule_profile_editor_test.dart` (both pump the whole screen) | A `ProPlanSection` is inserted at the top. Both suites keep passing because the default gateway yields `unknown` and `getOpenCycles()` is already overridden with `InMemoryWheelRepository` | S-285 + both settings suites green |
| `lib/core/app_router.dart` route graph | `lib/main.dart:34`, `test/features/record/record_trade_screen_test.dart:285,363,420`, `test/features/today/today_screen_test.dart:218,572,684`, `test/features/onboarding/first_run_explainer_test.dart:115`, `test/widget_test.dart:22,38` | One additive `/paywall` route; `initialLocation` unchanged, so no existing navigation test moves | S-277 |
| `lib/core/format.dart` | `lib/features/**`, `lib/state/**` (all display formatting) | One additive formatter (`renewalDateText`); nothing existing changes | S-285 |
| `pubspec.yaml` / `pubspec.lock` | whole repo | `purchases_flutter` added (D-P3's approved dependency). `pubspec.lock` changes; the pinned codegen set is untouched | S-287 + `dart run build_runner build --delete-conflicting-outputs` exit 0 |
| `ios/Podfile` / Xcode deployment target | `flutter build ios --simulator --no-codesign` | `pod install` now fetches the RevenueCat pod; the target may need to rise above 13.0 if the podspec requires it | The acceptance build, exit 0 |
| `docs/architecture/wheel-triage.md` | whole repo | Gains the Wave 2 surfaces (the seam, the gate, the cache, the paywall, the Settings row, the drift-risk table rows) | Phase 8 |

## Scenarios

Fixtures are enumerated as required. No narrative arithmetic may override a
fixture (conventions §7).

### S-255: schema v6 — fresh install and v5→v6 migration agree
- Fixture (both paths): one `user_preferences` row with every v5 field set to a non-default value (`wheelCapital = 30000.00`, `concentrationLimitPct = 20.0`, `exportReminderDismissed = true`, `lastExportAt` set, `notificationMilestones = [7, 0]`), plus one underlying, one open cycle with two legs (one backdated, one carrying both fees and `acceptsAssignment = false`), one closed cycle, one snapshot, one share lot, and the three seeded profiles with their v1 versions.
- Trigger: (a) open a fresh database; (b) migrate that v5 database to v6.
- Flow: read the entitlement row back through `WheelRepository.getEntitlementCache()`, then read every other table.
- Expected outcome: both report `isActive == false`, `planKind == ProPlanKind.none`, `expiresAt == null`, `willRenew == false`, `billingIssue == false`, `purchasedAt == null`, `checkedAt == null`; every pre-existing row is byte-identical to the fixture; `drift_schema_v6.json` differs from v5 only by the new table.
- Edge case of: none.

### S-256: the entitlement cache round-trips through both implementations
- Fixture: an `EntitlementCacheData(isActive: true, planKind: annual, expiresAt: 2027-10-05, willRenew: true, billingIssue: false, purchasedAt: 2026-10-05, checkedAt: 2026-10-06)`.
- Trigger: `saveEntitlementCache(...)` then `getEntitlementCache()` against `DriftWheelRepository` and `InMemoryWheelRepository`; then a second `saveEntitlementCache` with `isActive: false, planKind: none, expiresAt: null`.
- Flow: compare the two implementations' results element-by-element after each write.
- Expected outcome: identical values in both implementations, including the nullable fields and the millisecond timestamps; the second write replaces the row (never appends a second one); a lifetime row (`planKind: lifetime`, `expiresAt: null`) round-trips as lifetime, never as `none`.
- Edge case of: S-255.

### S-257: export/import neither carries nor disturbs the entitlement
- Fixture: (a) a database with `isActive: true, planKind: annual, expiresAt: 2027-10-05`; (b) the same database exported to JSON; (c) a second database with `isActive: false, planKind: none` and a different book.
- Trigger: `exportToJson()` on (a); `restoreFromJson()` of (b) into (c).
- Flow: inspect the export's top-level key set, then read the entitlement row of (c) after the restore.
- Expected outcome: the export's keys are exactly `formatVersion`, `underlyings`, `cycles`, `legs`, `snapshots`, `shareLots`, `ruleProfiles`, `ruleProfileVersions`, `preferences` — no entitlement key anywhere in the file; `formatVersion` is still 2; (c)'s entitlement row is **unchanged** (`isActive: false`) while its book is replaced; and restoring a hand-edited file that adds an `entitlement` key neither grants Pro nor throws.
- Edge case of: S-255.

### S-258: `getOpenCycles` — the set, both implementations
- Fixture: five cycles — two `sellingPuts` (started at distinct instants, on two underlyings), one `holdingShares` with no open call (started later), one `holdingShares` with an open call, one `closed` (started between the others); plus legs for each.
- Trigger: `getOpenCycles()` against `DriftWheelRepository` and `InMemoryWheelRepository`.
- Flow: compare the two results element-for-element.
- Expected outcome: identical lists in both implementations; four cycles returned, ascending by `startedAt`; the closed cycle absent; the call-less `holdingShares` cycle present; the cycle with an open call present.
- Edge case of: none.

### S-259: three open cycles and Pro — the fourth is created
- Fixture: three open cycles; entitlement `active` (`planKind: annual`); a valid put on a new ticker.
- Trigger: `RecordSaveService.save(...)`.
- Flow: read the book before and after.
- Expected outcome: `RecordSaveOutcome.created`; a fourth cycle exists; the gate is consulted but does not refuse; the new leg carries the standard profile's current version pin and its reminders are scheduled exactly as before.
- Edge case of: S-258.

### S-260: three open cycles and free — the fourth is refused and writes nothing
- Fixture: three open cycles (two `sellingPuts`, one `holdingShares` with no open call); entitlement `inactive`; a valid put on a **ticker never seen before**.
- Trigger: `RecordSaveService.save(...)`.
- Flow: read every table before and after.
- Expected outcome: `RecordSaveOutcome.paywallRequired`; `trigger` is the D-24 at-the-limit line with `3` substituted; **no** `Underlying` row is created for the new ticker (the check precedes `getOrCreateUnderlying`), no cycle, no leg, no snapshot, no notification scheduled; the same for an entitlement of `unknown`.
- Edge case of: S-259.

### S-261: three open cycles and a roll — never gated
- Fixture: three open cycles; entitlement `inactive`; an open put leg.
- Trigger: `WheelRepository.recordRoll(...)` on that leg.
- Flow: read the book and the gate's call count.
- Expected outcome: the roll closes the old leg and opens a new one atomically; the open-cycle count is unchanged; `NewCycleGate.evaluate()` is never called; no paywall outcome anywhere.
- Edge case of: S-260.

### S-262: three open cycles and an assignment — never gated
- Fixture: three open cycles; entitlement `inactive`; an open put leg accepting assignment.
- Trigger: `WheelRepository.recordAssignment(...)`.
- Flow: as S-261.
- Expected outcome: the cycle becomes `holdingShares`, a share lot exists, the count is unchanged, the gate is never called.
- Edge case of: S-260.

### S-263: three open cycles and a D-P12 covered call — never gated
- Fixture: three open cycles, one of them `holdingShares` with a share lot and **no** open call; entitlement `inactive`; a valid call on that ticker.
- Trigger: `RecordSaveService.save(side: call, …)`.
- Flow: read the cycle count and the leg list before and after.
- Expected outcome: `RecordSaveOutcome.attached`; the call lands on the existing cycle; the open-cycle count is still three; the gate is never called; no paywall.
- Edge case of: S-260.

### S-264: a call-less `holdingShares` cycle counts; a closed cycle never does
- Fixture: two closed cycles, one `holdingShares` cycle with a share lot and no open call, one `sellingPuts` cycle; entitlement `inactive`.
- Trigger: `getOpenCycles().length`, then `save(...)` with a new put (should be allowed at two open), then close one cycle and save again.
- Flow: read the count and the outcome at each step.
- Expected outcome: the count is 2 (the closed cycles are excluded, the call-less one included); the new put is created; after closing a cycle the count is 2 again and a further put is still allowed — closing a cycle frees a slot immediately.
- Edge case of: S-258.

### S-265: the D-P2 limit is evaluated in exactly one place
- Fixture: the repository after Phase 5.
- Trigger: `grep -rn "NewCycleGate\|newCycleGateProvider" lib/` and `grep -rn "kFreeTierOpenCycles" lib/`.
- Flow: classify each hit by file.
- Expected outcome: `NewCycleGate` is defined once (`lib/state/entitlements/new_cycle_gate.dart`) and referenced from exactly one non-test file (`lib/state/record/record_save_service.dart`); `kFreeTierOpenCycles` is defined once and referenced only from the gate and the Settings count label; no file under `lib/features/` mentions either; the same grep-based assertion is a test in `test/core/purchases/network_boundary_test.dart` so it fails CI, not only a human's grep.
- Edge case of: none.

### S-266: the screener's new-cycle save is gated identically
- Fixture: three open cycles; entitlement `inactive`; a screener form whose save would create a put cycle on a new ticker; and a screener form whose save is a covered call on an existing `holdingShares` cycle.
- Trigger: `ScreenerController.trackThisPosition()` in both cases.
- Flow: read the state after each save.
- Expected outcome: the put case sets `state.error` to the D-24 line and writes nothing (no underlying row); the call case attaches and reports success; both go through the same `RecordSaveService.save` — the screener gains no gate of its own.
- Edge case of: S-260.

### S-267: every existing action works in every entitlement state
- Fixture: a book with three open cycles (one `sellingPuts` with two snapshots, one `holdingShares` with a share lot, one past expiration), one closed cycle, and the journal's data — exercised three times, once per entitlement state (`active`, `inactive`, `unknown`).
- Trigger: view Today, view the detail sheet, read a snapshot, append a snapshot, roll, close, assign, called-away, open the journal, `exportToJson()`, `restoreFromJson()`, and edit the rule profile.
- Flow: run each action and compare the observable result across the three states.
- Expected outcome: identical results in all three states; the **only** difference is that a new put cycle is refused in `inactive` and `unknown` when the count is at the limit; no snapshot, leg, cycle, share lot or journal figure is hidden, mutated or disabled anywhere.
- Edge case of: none.

### S-268: a lapse from Pro with five open cycles loses nothing
- Fixture: five open cycles created while `active`; the entitlement then lapses (`inactive`).
- Trigger: view Today and the detail sheets, append a snapshot, roll a leg, assign a leg, close a leg, open the journal, export.
- Flow: compare the book and every screen before and after the lapse.
- Expected outcome: all five cycles are still listed and actionable; every listed action succeeds; a sixth new cycle is refused with the D-24 past-the-limit line ("You have 5 open cycles…"); the export is byte-identical to the pre-lapse export.
- Edge case of: S-267.

### S-269: the cache makes Pro work offline
- Fixture: a cache row with `isActive: true, planKind: annual, expiresAt` in the future, `checkedAt` set; a gateway whose `currentEntitlement()` throws (offline) and whose `loadOfferings()` returns `null`.
- Trigger: `EntitlementController.initialize()` then `refresh()`.
- Flow: read `entitlementControllerProvider` and then attempt a fourth cycle.
- Expected outcome: state is `active` with the cached plan kind and expiry; the failed read does not clear the cache (`getEntitlementCache()` is unchanged, `checkedAt` still the old value); the fourth cycle is created; the Settings row shows the cached renewal date; the paywall (if opened from Settings) shows the owned state rather than an unavailable state.
- Edge case of: S-255.

### S-270: refresh at launch and on resume
- Fixture: a recording gateway whose entitlement flips from `inactive` to `active` between two reads; `EntitlementLifecycleScope` wrapped around a minimal app shell.
- Trigger: pump the widget (launch), then dispatch `AppLifecycleState.resumed` via `WidgetsBinding.instance.handleAppLifecycleStateChanged`, then dispatch `AppLifecycleState.inactive`/`paused`.
- Flow: count the gateway's `currentEntitlement()` calls and read the state after each step.
- Expected outcome: exactly one read at launch, exactly one more on each `resumed`, none on `inactive`/`paused`; the state reflects the second read; the cache row is written after each **successful** read and only then; `WheelTriageApp` in `test/widget_test.dart` still boots.
- Edge case of: S-269.

### S-271: the store's own entitlement update reaches the state
- Fixture: a gateway exposing `addEntitlementListener`, with one listener registered by the controller.
- Trigger: the fake emits an `EntitlementSnapshot` for a renewal (a later `expiresAt`), then one for a cancellation (`willRenew == false`).
- Flow: read the state after each emission.
- Expected outcome: the state and the cache follow each emission without any explicit `refresh()` call; the cancellation keeps the state `active` with `willRenew == false` (Pro until the paid period ends, never revoked early); the Settings line changes from "Renews …" to "Cancels …".
- Edge case of: S-270.

### S-272: expiry and cancellation-without-renewal
- Fixture: a cache row with `isActive: true, expiresAt` in the past, and a gateway now reporting no active entitlement.
- Trigger: `refresh()`.
- Flow: read the state, the cache and the Settings row.
- Expected outcome: state is `inactive`; the cache row is overwritten with `isActive: false, planKind: none, expiresAt: null`; the Settings row reads "Free · n of 3 open cycles"; a fourth new cycle is refused; nothing recorded is hidden (S-268's actions all still work).
- Edge case of: S-269.

### S-273: grace period and billing retry
- Fixture: a gateway snapshot with `isActive: true`, `willRenew: true`, `billingIssue: true`, and an `expiresAt` in the past (the store is retrying the charge).
- Trigger: `refresh()`.
- Flow: read the state and the Settings row.
- Expected outcome: state is `active` (a grace period is Pro, never a lock-out); `billingIssue` is `true` in the cache; the Settings row shows the plan and renewal lines **plus** the D-34 billing line; a fourth new cycle is still created; when the store later reports `isActive: false`, S-272's behaviour applies.
- Edge case of: S-272.

### S-274: refund and revocation
- Fixture: a cache row with `isActive: true, planKind: lifetime` (and a second fixture with `planKind: annual`), and a gateway now reporting `isActive: false`.
- Trigger: `refresh()`.
- Flow: read the state, then run S-268's full action list.
- Expected outcome: state is `inactive`; the cache is overwritten; the Settings row reads free; every recorded action still works; the paywall is reachable again from Settings. An `unknown` state (no successful read ever) behaves identically for the gate — Pro is never forged from an absent answer.
- Edge case of: S-272.

### S-275: lifetime has no expiry, no renewal and never lapses
- Fixture: a gateway snapshot with `isActive: true, planKind: lifetime, expiresAt: null, willRenew: false, purchasedAt: 2026-03-03`.
- Trigger: `refresh()`, then `refresh()` again a year later (the fake advances its clock).
- Flow: read the state and the Settings row each time.
- Expected outcome: `active` both times, `expiresAt` `null`, no "Renews"/"Cancels" line, the row reads "Pro · Lifetime" + "Purchased Mar 3, 2026"; the fourth-cycle gate never refuses.
- Edge case of: S-274.

### S-276: the fourth-cycle refusal names the trigger
- Fixture: three open cycles; entitlement `inactive`; a new-ticker put.
- Trigger: `RecordSaveService.save(...)` then the screen's reaction to `paywallRequired`.
- Flow: read the result, then pump the Record screen and the screener screen with the outcome.
- Expected outcome: the result carries the D-24 line; each screen shows that line and pushes `/paywall` with it as the trigger; the paywall displays it verbatim above the plans; neither screen decides anything about Pro itself.
- Edge case of: S-260.

### S-277: the paywall opens only from the three allowed places, never on launch
- Fixture: (a) a fourth-cycle refusal; (b) the Settings row; (c) a Pro-feature trigger constructed directly; (d) a fresh launch on `/positions` and on `/first-run`.
- Trigger: each entry point in turn; then a launch.
- Flow: count `/paywall` routes pushed.
- Expected outcome: (a)–(c) push it with the right trigger line; (d) never does, in any entitlement state, including `inactive` with three open cycles; a structural test shows `context.push('/paywall'` occurs only in `lib/features/paywall/paywall_route.dart`; a `/paywall` route reached with no `extra` falls back to the Settings trigger and does not throw.
- Edge case of: S-276.

### S-278: the plans come from the store; annual is preselected; the trial comes from the store
- Fixture: (a) offerings with annual (with a 7-day trial), monthly and lifetime; (b) offerings with only monthly; (c) offerings with annual **without** a trial; (d) `null` offerings.
- Trigger: open the paywall in each case.
- Flow: read the rendered rows, the preselection and the trial line.
- Expected outcome: (a) three rows in annual/monthly/lifetime order, annual selected, the trial line derived from the store's own `units`/`unit` ("7-day free trial") and the button reading "Start 7-day free trial"; (b) one row, selected; (c) annual selected with no trial line and a button that does not mention one; (d) S-280's unavailable state. No price, period or trial value appears anywhere in `lib/` as a literal.
- Edge case of: none.

### S-279: the purchase button names the outcome; the per-month figure is derived
- Fixture: annual at `$29.99` (USD), monthly at `$4.99`, lifetime at `$79.99`, and a second fixture in EUR.
- Trigger: select each plan.
- Flow: read the button label and the annual row's per-month figure.
- Expected outcome: "Subscribe for $4.99 a month" / "Buy lifetime for $79.99" / the trial form for annual; the annual per-month figure is `annualPrice / 12` computed as `Decimal` and formatted in the store's own currency (`$2.50`, `€2.49` for the EUR fixture) — never a hard-coded number and never a savings claim; the derived figure is the same `Decimal` arithmetic in both locales.
- Edge case of: S-278.

### S-280: the store is unreachable — an honest unavailable state
- Fixture: a gateway whose `loadOfferings()` returns `null` and whose `currentEntitlement()` throws (offline), with no cache row (`unknown`).
- Trigger: open the paywall from Settings.
- Flow: read the screen.
- Expected outcome: the paywall shows the D-32 unavailable line, a retry action, the privacy line, Restore purchases and the policy text — and **no** plan row, no price and no purchase button; retrying calls `loadOfferings()` again; the Settings row reads "Pro status unavailable"; a fourth new cycle is refused with the D-24 line (free-tier behaviour, not a crash).
- Edge case of: S-278.

### S-281: pending, cancelled and failed purchases
- Fixture: a gateway scripted to return `pending`, then `cancelled`, then `failed`, each with the entitlement unchanged.
- Trigger: tap the purchase button three times, once per script.
- Flow: read the message and the entitlement after each.
- Expected outcome: `pending` shows its line and leaves the paywall open with the entitlement unchanged; `cancelled` shows no message and leaves the paywall exactly as it was; `failed` shows its line; in all three the entitlement is unchanged, no cache write happens, and a retry is possible; `unavailable` behaves as S-280.
- Edge case of: S-278.

### S-282: restore purchases, both outcomes
- Fixture: (a) a gateway whose `restore()` reports a purchase and whose `currentEntitlement()` then reports `active, planKind: annual`; (b) a gateway whose `restore()` reports nothing.
- Trigger: "Restore purchases" on the paywall and in Settings, in both cases.
- Flow: read the message, the state and the cache.
- Expected outcome: (a) "Purchases restored.", the state becomes `active`, the cache is written, the Settings row shows the plan and renewal date, and a fourth cycle is created; (b) the no-purchases line, the state unchanged, the cache unchanged. Both entry points call the same controller method.
- Edge case of: S-281.

### S-283: lifetime rules — no prompt, and a subscriber buying lifetime
- Fixture: (a) an active lifetime entitlement; (b) an active annual subscription, with the gateway scripted so a lifetime purchase succeeds while the subscription stays active.
- Trigger: (a) open the paywall and the Settings row; (b) buy lifetime.
- Flow: read the rendered affordances and the message.
- Expected outcome: (a) the Settings row shows "Pro · Lifetime" with no upgrade row, and the paywall renders the owned state with **no** purchase button and no subscription row — a lifetime owner is never offered a subscription; (b) the D-33 line plus a "Manage subscription" button that calls `showManageSubscriptions()`, and the entitlement now reads lifetime.
- Edge case of: S-282.

### S-284: the paywall's copy passes the tone rules and it is dismissable
- Fixture: every string returned by `lib/core/purchases/paywall_copy.dart` — the title, the three trigger lines (including the two D-24 forms), the four feature bullets, the privacy line, the D-32 outcome lines, the fine print, the button labels and the labels "Not now" / "Restore purchases" / "Manage subscription".
- Trigger: (a) match every string against `recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should` (case-insensitive); (b) the `grep -rniE` Done Criterion over `lib/`; (c) pump the paywall and dismiss it without purchasing.
- Expected outcome: (a) zero matches, asserted as a unit test so a future edit fails CI; (b) the grep is empty; (c) "Not now" and the close icon both pop the route, no purchase is attempted, no state changes, and the screen the user came from is unchanged; the hand review finds no sentence pairing an action verb with a named security or the user's own position.
- Edge case of: none.

### S-285: the Settings plan row in every entitlement state
- Fixture: the six D-34 states, each with a book of 2 open cycles, and a seventh with 5 open cycles.
- Trigger: pump Settings.
- Flow: read the section.
- Expected outcome: each state renders its D-34 header line, second line and rows; the free states show "Free · 2 of 3 open cycles" and "Free · 5 open cycles" respectively; "See Pro plans" pushes `/paywall`; the section sits above "Defaults for new entries"; both existing Settings suites still pass unchanged.
- Edge case of: none.

### S-286: Manage subscription and Restore from Settings
- Fixture: an active annual subscription; a recording gateway.
- Trigger: tap "Manage subscription", then "Restore purchases".
- Flow: count the gateway calls and read the resulting message.
- Expected outcome: the first calls `showManageSubscriptions()` exactly once and opens nothing else; the second calls `restore()` exactly once and shows S-282's message; neither changes the plan row unless the restore changed the entitlement.
- Edge case of: S-285.

### S-287: no HTTP client, socket or URL path exists in `lib/`, and only one file touches the SDK
- Fixture: the repository after Phase 3.
- Trigger: `grep -rniE "dart:io|package:http|HttpClient|Socket|WebSocket|NetworkImage|package:dio|url_launcher" lib/`, `grep -rl "purchases_flutter" lib/`, and the same assertions as a test reading `lib/`.
- Flow: classify every hit by file.
- Expected outcome: the first grep is empty (the pre-wave baseline is already 0, so this guard cannot be satisfied by accident); the second matches exactly one file, `lib/core/purchases/revenuecat_purchase_gateway.dart`, which imports nothing from `lib/data/` or `lib/domain/models/`; `lib/features/` imports neither the gateway nor the SDK; `lib/main.dart` overrides `purchaseGatewayProvider`.
- Edge case of: none.

### S-288: a recording gateway sees no trade, snapshot or ledger data
- Fixture: a `RecordingPurchaseGateway` wrapped around the app's `purchaseGatewayProvider`, a book with a leg, a snapshot, a share lot and a closed cycle, and a scripted `purchased` outcome.
- Trigger: drive the app through a fourth-cycle refusal, a paywall purchase, a restore, a Manage subscription, and a full JSON export — then inspect every argument the gateway received.
- Flow: assert on the recorded call log and on `PurchaseGateway`'s own parameter types.
- Expected outcome: the log contains only `configure`, `loadOfferings`, `currentEntitlement`, `purchase(<productId>)`, `restore` and `showManageSubscriptions` — every argument is a store product identifier, a URL-free string or nothing at all; no call ever receives a leg, snapshot, cycle, share lot, ticker, strike, credit or export payload, and no such type is even expressible in the interface; the export payload reaches only the file picker and the share sheet.
- Edge case of: S-287.

### S-289: the architecture and privacy docs describe the wave
- Fixture: the repository after Phase 8.
- Trigger: read `docs/architecture/wheel-triage.md` and `docs/privacy.md`.
- Flow: check each wave surface is described and each claim is true of the code.
- Expected outcome: the architecture doc gains the purchase seam, the three refresh points, the tri-valued entitlement, the D-P2 gate and its single evaluation point, the schema v6 table, the paywall and the Settings row, and rows in its drift-risk table for "an entitlement fact" and "a paywall string"; `docs/privacy.md` states what RevenueCat collects, what is never transmitted, the in-app sentence, and the owner's remaining label and hosted-policy items; both name the exact `--dart-define` command the owner builds with.
- Edge case of: none.

## Iteration 1 — Wave 2

Phases run in order. P1 (storage) and P3 (the purchase seam) are independent
heads; P2 (the count) is independent of both and only P5 needs it. P4 needs P1
and P3. P5 and P6 both need P4. P7 needs P5, P6 and P2. P8 closes the wave.

```
P1 (schema v6) ──────┐
                     ├─► P4 (entitlement controller + refresh) ─┬─► P5 (D-P2 gate + save path) ─┐
P3 (seam + plugin) ──┘                                           └─► P6 (paywall) ──────────────┼─► P7 (entry points + Settings row) ─► P8 (closeout)
P2 (getOpenCycles) ─────────────────────────────────────────────────────────────────────────────┘
```

- **Re-ordering offered.** P6 (the paywall screen) can be built before P5: it
  only needs P4's controller, and it gives a visible screen three phases
  earlier. The cost is that the paywall is then reachable only from Settings
  until P7, so the wave's headline flow (fourth cycle → paywall) still lands at
  P7 either way.
- **P3 is the highest-risk phase in the wave.** It is the only one that adds a
  plugin, changes `pubspec.lock`, and makes `flutter build ios` run
  `pod install` against a new pod. Landing it third means a plugin or pod
  failure surfaces early instead of after the paywall is written, and every
  later phase builds against a seam already known to compile and build. If the
  pod fails to resolve, that is a blocker to raise, not something to route
  around: the wave has no other way to reach the store.

### Phase 1: schema v6 — the entitlement cache (@data-architect)

1. [x] `lib/domain/models/pro_plan_kind.dart` (new): `enum ProPlanKind { none,
       monthly, annual, lifetime }` plus its storage mapping. Pure Dart, no
       imports.
2. [x] `lib/domain/models/entitlement_cache.dart` (new): `EntitlementCacheData`
       as `@freezed` **without** `json_serializable` (D-25 — it is never
       exported, so it has no wire format; say so in the doc comment).
       Regenerate freezed.
3. [x] `lib/domain/models/entitlement_cache_defaults.dart` (new): `rowId =
       'default'` and the D-25 default values, mirroring
       `user_preferences_defaults.dart` so `InMemoryWheelRepository` never
       imports `app_database.dart`.
4. [x] `lib/data/db/type_converters.dart`: `ProPlanKindConverter`
       (`TypeConverter<ProPlanKind, String>` via `.name`, never an index).
5. [x] `lib/data/db/tables/entitlement_cache_table.dart` (new): the D-25 table,
       `@DataClassName('EntitlementCacheRow')`, `tableName =>
       'entitlement_cache'`, fixed-`id` primary key, `withDefault` on every
       non-nullable column so a fresh create and a migration agree.
6. [x] `lib/data/db/app_database.dart`: `schemaVersion => 6`; register the
       table in `@DriftDatabase`; `seedEntitlementCache()` public (same
       visibility rationale as `seedDefaultPreferences`); `onCreate` calls it;
       a `if (from < 6 && to >= 6)` step creates the table and seeds it, with
       the same gating comment style as v2/v3/v4/v5. Regenerate.
7. [x] `dart run drift_dev schema dump lib/data/db/app_database.dart
       lib/data/db/schema/drift_schema_v6.json`, then `dart run drift_dev
       schema generate --data-classes --companions lib/data/db/schema
       test/data/db/generated` (both flags required). v1–v5 dumps untouched.
8. [x] `lib/data/wheel_repository.dart`: `getEntitlementCache()` and
       `saveEntitlementCache(EntitlementCacheData)`, documented as
       store-derived state that is deliberately outside the export envelope.
       Regenerate freezed.
9. [x] Both repositories implement both methods — Drift through the table,
       in-memory through a field initialised from `EntitlementCacheDefaults`.
       `restoreFromJson` is **not** touched (D-25).
10. [x] Tests: S-255 (`test/data/db/entitlement_v6_migration_test.dart`, new),
        S-256 (a shared contract block in
        `test/data/wheel_repository_contract_test.dart`), S-257 (extend
        `test/data/export/ledger_export_test.dart` and `ledger_import_test.dart`
        with the key-set and untouched-row assertions).
11. [x] Retarget every "migrated all the way to the current version" test to
        v6 — `test/data/user_preferences_migration_test.dart`,
        `test/data/db/app_database_migration_test.dart`,
        `leg_v3_migration_test.dart`, `rule_profile_v4_migration_test.dart`,
        `user_preferences_v5_migration_test.dart` — updating their header
        comments the way Wave 1's Phase 2 did (A-2's lesson: a later version's
        `createTable` changes what an earlier step's fresh create produces).

**Done Criteria**: `flutter analyze`; `flutter test test/data test/domain/models`;
`git diff` of `lib/data/db/schema/drift_schema_v6.json` against v5 shows exactly
one new table and no changed column; `grep -rn "entitlement" lib/data/export/`
empty; `grep -c "UnimplementedError" lib/data/*.dart lib/data/db/*.dart`
matches the pre-phase count; `dart run build_runner build
--delete-conflicting-outputs` exit 0 with `git status --porcelain` showing no
unexpected regenerated artifact.

**Predicted Files**: `lib/domain/models/pro_plan_kind.dart` (new),
`lib/domain/models/entitlement_cache.dart` (+ generated) (new),
`lib/domain/models/entitlement_cache_defaults.dart` (new),
`lib/data/db/type_converters.dart`,
`lib/data/db/tables/entitlement_cache_table.dart` (new),
`lib/data/db/app_database.dart` (+ `.g.dart`),
`lib/data/db/schema/drift_schema_v6.json` (new),
`test/data/db/generated/schema.dart`, `schema_v6.dart` (new),
`test/data/db/entitlement_v6_migration_test.dart` (new),
`lib/data/wheel_repository.dart` (+ generated),
`lib/data/db/drift_wheel_repository.dart`,
`lib/data/in_memory_wheel_repository.dart`,
`test/data/wheel_repository_contract_test.dart`,
`test/data/export/ledger_export_test.dart`, `ledger_import_test.dart`,
`test/data/user_preferences_migration_test.dart`,
`test/data/db/app_database_migration_test.dart`,
`test/data/db/leg_v3_migration_test.dart`,
`test/data/db/rule_profile_v4_migration_test.dart`,
`test/data/db/user_preferences_v5_migration_test.dart`.

### Phase 2: `getOpenCycles` (@data-architect)

1. [x] `lib/data/wheel_repository.dart`: `Future<List<WheelCycle>>
       getOpenCycles()` — every cycle whose `status != closed`, across all
       underlyings, ordered by `startedAt` ascending, with D-22's note that a
       tie is not ordered beyond the set. Document why grouping `getAllLegs()`
       is not an acceptable substitute (it misses a `holdingShares` cycle with
       no open call).
2. [x] `DriftWheelRepository`: one query filtered on the status column and
       ordered by `started_at_ms`.
3. [x] `InMemoryWheelRepository`: the same set and order.
4. [x] `test/data/wheel_repository_contract_test.dart`: a shared block per
       implementation (S-258), reusing the fixture's distinct `startedAt`
       instants so the order is total.
5. [x] `test/domain/rules/sbet_regression_test.dart` (S-015) must stay green —
       it drives the whole pipeline, so a failure there is a genuine break.

**Done Criteria**: `flutter analyze`; `flutter test
test/data/wheel_repository_contract_test.dart
test/domain/rules/sbet_regression_test.dart`; `grep -c "UnimplementedError"
lib/data/*.dart lib/data/db/*.dart` unchanged.

**Predicted Files**: `lib/data/wheel_repository.dart` (+ generated),
`lib/data/db/drift_wheel_repository.dart`,
`lib/data/in_memory_wheel_repository.dart`,
`test/data/wheel_repository_contract_test.dart`.

### Phase 3: the purchase seam, the plugin and the network guard (@developer)

1. [x] `pubspec.yaml`: add `purchases_flutter` (D-P3's approved dependency) with
       a pinned version and a comment naming D-P3 as its authority. Nothing else
       changes; the pinned codegen set is untouched. `flutter pub get`.
2. [x] `lib/core/purchases/purchase_gateway.dart` (new): `PurchaseGateway`
       (D-27), the sealed `PurchaseOutcome`, `EntitlementSnapshot`,
       `ProOfferings`, `ProPlanOffer` and `TrialOffer`. No trade type is
       imported or named in this file.
3. [x] `lib/core/purchases/pro_plans.dart` (new): `kProEntitlementId`, the
       three product identifiers, `kFreeTierOpenCycles = 3`, the display order,
       `kindForProductId(String?)`, and the owner-supplied policy URLs (D-37).
4. [x] `lib/core/purchases/purchase_configuration.dart` (new):
       `const kRevenueCatIosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY')`.
5. [x] `lib/core/purchases/revenuecat_purchase_gateway.dart` (new): the real
       adapter, the only file importing `purchases_flutter`. Idempotent
       `configure()`; no-op off iOS (D-27); maps the SDK's offerings, its
       customer info and its error codes onto the seam's value types; registers
       the customer-info update listener; never throws out of `refresh()`'s
       path. **Confirm every SDK symbol against the pinned version at
       implementation time** — the tests bind to the seam, not to the SDK.
6. [x] `lib/core/purchases/unconfigured_purchase_gateway.dart` (new): no
       offerings, `unknown` entitlement, every purchase `unavailable`.
7. [x] `lib/state/entitlements/entitlement_providers.dart` (new):
       `purchaseGatewayProvider` defaulting to `UnconfiguredPurchaseGateway`
       (D-27), with the same doc-comment rationale as
       `notificationGatewayProvider`.
8. [x] `lib/main.dart`: choose the gateway from `kRevenueCatIosApiKey.isEmpty`
       and override `purchaseGatewayProvider` **always** — an override that
       exists in both branches, so a missing wire-up is impossible.
9. [x] `test/support/fake_purchase_gateway.dart` (new): a recording, scriptable
       double (offerings, entitlement, per-call purchase outcomes, restore
       outcome, listener emission) mirroring `FakeNotificationGateway`'s shape.
10. [x] `test/core/purchases/network_boundary_test.dart` (new): S-287 and
        S-265's structural assertions, reading `lib/` directly.
11. [x] `test/core/purchases/purchase_gateway_test.dart` (new): the seam's own
        contract — every outcome is representable, the unconfigured gateway
        answers every call without throwing, and `configure()` is idempotent.

**Done Criteria**: `flutter analyze`; `flutter test test/core/purchases`;
`grep -rniE "dart:io|package:http|HttpClient|Socket|WebSocket|NetworkImage|package:dio|url_launcher" lib/`
empty; `grep -rl "purchases_flutter" lib/` returns exactly one path;
`flutter test` green; `flutter build ios --simulator --no-codesign` exit 0
(this is the phase that runs `pod install` against the new pod, and it may
require raising the iOS deployment target — record the change if so).

**Predicted Files**: `pubspec.yaml`, `pubspec.lock`,
`lib/core/purchases/purchase_gateway.dart` (new),
`pro_plans.dart` (new), `purchase_configuration.dart` (new),
`revenuecat_purchase_gateway.dart` (new),
`unconfigured_purchase_gateway.dart` (new),
`lib/state/entitlements/entitlement_providers.dart` (new), `lib/main.dart`,
`test/support/fake_purchase_gateway.dart` (new),
`test/core/purchases/network_boundary_test.dart` (new),
`test/core/purchases/purchase_gateway_test.dart` (new),
`ios/Podfile` (only if the podspec forces a target bump).

### Phase 4: the entitlement controller, the cache and the refresh points (@developer)

1. [x] `lib/state/entitlements/entitlement_controller.dart` (new):
       `EntitlementState` (`status`, `planKind`, `expiresAt`, `willRenew`,
       `billingIssue`, `purchasedAt`, `offeringsAvailable`) and
       `EntitlementController` — `initialize()`, `refresh()`, `loadOfferings()`,
       `purchase(productId)`, `restore()`, `manageSubscription()`. D-26's
       tri-valued status and the failed-read fallback; the cache is written only
       after a successful read; `refresh()` never throws and is re-entrant.
       It is the only reader of `PurchaseGateway` (D-28).
2. [x] `lib/state/entitlements/entitlement_providers.dart`:
       `entitlementControllerProvider` (a `StateNotifierProvider`, following
       `preferencesControllerProvider`), and nothing else yet.
3. [x] `lib/widgets/entitlement_lifecycle_scope.dart` (new): a
       `ConsumerStatefulWidget` + `WidgetsBindingObserver` that calls
       `refresh()` on `AppLifecycleState.resumed` and nothing else (D-29).
4. [x] `lib/main.dart`: `WheelTriageApp` wraps its child in
       `EntitlementLifecycleScope`; the launch refresh happens once, after the
       gateway is configured and the cache is loaded.
5. [x] `lib/state/entitlements/entitlement_providers.dart`: register the
       gateway's entitlement listener once, at controller construction (D-29c).
6. [x] Tests: S-269, S-270, S-271, S-272, S-273, S-274, S-275
       (`test/state/entitlements/entitlement_controller_test.dart`,
       `test/widgets/entitlement_lifecycle_scope_test.dart`).

**Done Criteria**: `flutter analyze`; `flutter test test/state/entitlements
test/widgets test/widget_test.dart`; `grep -rn "purchaseGatewayProvider"
lib/features/` empty; `grep -rn "purchases_flutter" lib/state/ lib/features/`
empty; `flutter test` green (no pre-existing suite regresses — the default
gateway must keep every screen working).

**Predicted Files**: `lib/state/entitlements/entitlement_controller.dart` (new),
`lib/state/entitlements/entitlement_providers.dart` (new),
`lib/widgets/entitlement_lifecycle_scope.dart` (new), `lib/main.dart`,
`test/state/entitlements/entitlement_controller_test.dart` (new),
`test/widgets/entitlement_lifecycle_scope_test.dart` (new).

### Phase 5: the D-P2 gate and the save path (@developer)

1. [x] `lib/state/entitlements/new_cycle_gate.dart` (new): `NewCycleDecision`
       (`NewCycleAllowed` / `NewCycleBlocked` carrying the line and the count)
       and `NewCycleGate.evaluate()` implementing D-23 exactly — the only
       evaluation of the limit in the app.
2. [x] `lib/core/purchases/paywall_copy.dart` (new): the D-24 line builders and
       the paywall's static strings (title, privacy line, the four feature
       bullets, fine print, button and row labels, the D-32 outcome lines).
       Pure functions and `const`s; no Flutter import needed.
3. [x] `lib/state/record/record_save_service.dart`: in the new-cycle branch
       only, evaluate the gate **before** `getOrCreateUnderlying` and return
       `RecordSaveResult.paywallRequired(trigger: …)` on a block; add
       `RecordSaveOutcome.paywallRequired` and the named constructor. A refusal
       writes nothing (S-260).
4. [x] `lib/state/entitlements/entitlement_providers.dart`:
       `newCycleGateProvider`.
5. [x] Tests: S-259, S-260, S-261, S-262, S-263, S-264, S-266, S-267, S-268 —
       `test/state/entitlements/new_cycle_gate_test.dart` (new) plus extensions
       to `test/state/record/record_save_service_test.dart`,
       `test/state/screener/screener_controller_test.dart` and a new
       `test/state/entitlements/nothing_locks_test.dart` covering S-267/S-268
       across all three entitlement states.

**Done Criteria**: `flutter analyze`; `flutter test test/state/entitlements
test/state/record test/state/screener`; `flutter test` green (the pre-existing
put-side record and screener scenarios must be unchanged — check the count
moves only by the new tests); `grep -rn "kFreeTierOpenCycles" lib/` limited to
`pro_plans.dart`, `new_cycle_gate.dart` and the Settings count label;
`grep -rl "package:flutter" lib/domain/rules/` empty;
`flutter test test/domain/rules/sbet_regression_test.dart` green.

**Predicted Files**: `lib/state/entitlements/new_cycle_gate.dart` (new),
`lib/core/purchases/paywall_copy.dart` (new),
`lib/state/record/record_save_service.dart`,
`lib/state/entitlements/entitlement_providers.dart`,
`test/state/entitlements/new_cycle_gate_test.dart` (new),
`test/state/entitlements/nothing_locks_test.dart` (new),
`test/state/record/record_save_service_test.dart`,
`test/state/screener/screener_controller_test.dart`.

### Phase 6: the paywall (@developer)

1. [x] `lib/state/paywall/paywall_controller.dart` (new): `PaywallState`
       (offerings, the selected plan kind, the in-flight status, the outcome
       line) and the selection/purchase/restore orchestration. It reads
       `entitlementControllerProvider`; it computes no entitlement itself.
2. [x] `lib/features/paywall/paywall_screen.dart` (new): the reference's
       layout — title, the trigger line, the four launch feature bullets, the
       plan rows (annual preselected, store prices, the derived per-month figure
       on annual, the store's trial term), the button naming the outcome, the
       privacy line, the fine print, Restore purchases, the policy text (D-37),
       "Not now" and the close icon. Owned state when the entitlement is already
       active (D-33). Semantics labels on every number (Feature Invariant 11).
3. [x] `lib/features/paywall/paywall_route.dart` (new): `PaywallTrigger` and
       `showPaywall(BuildContext, {required PaywallTrigger trigger})` — the one
       place `context.push('/paywall'` appears (D-30).
4. [x] `lib/core/app_router.dart`: register `/paywall`, taking its trigger from
       `state.extra` with the Settings fallback.
5. [x] Tests: S-276 (the rendered trigger line), S-278, S-279, S-280, S-281,
       S-282, S-283, S-284 —
       `test/features/paywall/paywall_screen_test.dart` (new),
       `test/state/paywall/paywall_controller_test.dart` (new),
       `test/core/purchases/paywall_copy_test.dart` (new, the tone unit test),
       and a `renewalDateText` case in the `lib/core/format.dart` test.

**Phase 6 status: Complete.** `flutter analyze` clean; `flutter test
test/features/paywall test/state/paywall test/core/purchases` → **81 passed / 1
failed**; full `flutter test` → **890 passed / 1 failed**. The single failure is
S-265 in `test/core/purchases/network_boundary_test.dart`, whose expected list
names `lib/features/settings/pro_plan_section.dart` — a Phase 7 artifact — so it
cannot pass before Phase 7 and no Phase 6 change can make it pass. Every other
Phase 6 Done Criterion is met (tone grep empty; exactly one
`context.push('/paywall'`, in `paywall_route.dart`; the colour-literal grep
empty; no Flutter import under `lib/domain/rules/`).

*Red run, recorded before any Phase 6 implementation existed*:
`flutter test test/core/purchases/paywall_copy_test.dart
test/state/paywall/paywall_controller_test.dart` → `+34 −5`, the five failures
being the missing `PaywallState`/`PaywallController` and the missing
outcome/button copy. The screen test and `test/core/format_test.dart` were
written **after** their implementation (see Assumption Log, item 29), so no red
run exists for them; that is a deviation from the tests-first rule and is
flagged rather than hidden.

**Done Criteria**: `flutter analyze`; `flutter test test/features/paywall
test/state/paywall test/core/purchases`; `flutter test` green;
`grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/`
empty; `grep -rn "context.push('/paywall'" lib/` returns exactly one path;
`grep -rnE "(^|[^A-Za-z])Colors\.|Color\(0x" lib/ --include='*.dart' | grep -v
lib/core/theme/` empty.

**Predicted Files**: `lib/state/paywall/paywall_controller.dart` (new),
`lib/features/paywall/paywall_screen.dart` (new),
`lib/features/paywall/paywall_route.dart` (new), `lib/core/app_router.dart`,
`lib/core/format.dart`, `test/features/paywall/paywall_screen_test.dart` (new),
`test/state/paywall/paywall_controller_test.dart` (new),
`test/core/purchases/paywall_copy_test.dart` (new),
the existing `lib/core/format.dart` test.

### Phase 7: the three entry points and the Settings plan row (@developer)

1. [x] `lib/features/record/record_trade_screen.dart` and
       `lib/features/screener/screener_screen.dart`: on a
       `paywallRequired` outcome, show the trigger line and call `showPaywall`.
       Neither screen reads the entitlement (D-28). Both read the line the
       state layer produced (`RecordController.paywallTrigger` /
       `ScreenerController.paywallTrigger`, getters added in this phase) and
       hand it to `NewCyclePaywallTrigger`; the existing `form.error` widget
       already renders the line on the screen itself.
2. [x] `lib/features/settings/pro_plan_section.dart` (new): D-34's section,
       inserted at the top of Settings' `ListView`; the free-state count comes
       from `getOpenCycles()`; Manage subscription and Restore purchases call
       the controller.
3. [x] `lib/features/settings/settings_screen.dart`: insert the section; no
       other change to the screen's order.
4. [x] Tests: S-277, S-285, S-286, S-288 —
       `test/features/paywall/paywall_entry_points_test.dart` (new, covering all
       three triggers and the never-on-launch case),
       `test/features/settings/pro_plan_section_test.dart` (new),
       extensions to `test/features/record/record_trade_screen_test.dart` and
       `test/features/screener/screener_screen_test.dart`,
       `test/core/purchases/recording_gateway_isolation_test.dart` (new,
       S-288), and confirm `test/features/settings/settings_screen_test.dart`
       and `rule_profile_editor_test.dart` still pass unchanged.
5. [x] `flutter test test/widget_test.dart` — the app shell still boots with
       the lifecycle scope in place.

**Status: Complete.** Red run recorded below (`+3 −2`, the two new widget files
failing to load against the constants and the section that did not exist yet);
after implementation `test/features/settings/pro_plan_section_test.dart` +
`test/features/paywall` + `test/features/record` + `test/features/screener`
**67 passed / 0 failed**, `test/core/purchases` + `test/state/entitlements` +
`test/state/paywall` **93 passed / 0 failed**, full suite **918 passed /
0 failed** (Phase 6 was 890 passed / 1 failed; the one failure was S-265, which
this phase turns green). Two pre-existing Settings screen tests failed on the
first green run and are fixed by a harness change, not a behaviour change: the
new section pushes the milestone editor past the 800×2400 test viewport, so
`test/features/settings/settings_screen_test.dart`'s seven viewport overrides
move to 800×3200 (Assumption Log 41). `flutter build ios --simulator
--no-codesign` exit 0.

**Done Criteria**: `flutter analyze`; `flutter test test/features test/state
test/core`; `flutter test` green (report the pass/fail counts and the delta
against Phase 6); `grep -rn "context.push('/paywall'\|showPaywall(" lib/` shows
only `paywall_route.dart` plus the three allowed call sites;
`grep -rn "purchaseGatewayProvider\|purchases_flutter" lib/features/` empty;
`flutter build ios --simulator --no-codesign` exit 0.

**Predicted Files**: `lib/features/record/record_trade_screen.dart`,
`lib/features/screener/screener_screen.dart`,
`lib/features/settings/pro_plan_section.dart` (new),
`lib/features/settings/settings_screen.dart`,
`test/features/paywall/paywall_entry_points_test.dart` (new),
`test/features/settings/pro_plan_section_test.dart` (new),
`test/features/record/record_trade_screen_test.dart`,
`test/features/screener/screener_screen_test.dart`,
`test/core/purchases/recording_gateway_isolation_test.dart` (new).

### Phase 8: closeout — docs, the privacy disclosure and the residue sweep (@developer)

1. [x] `docs/architecture/wheel-triage.md`: extend in place — the purchase seam
       and the fake, the three refresh points, the tri-valued entitlement, the
       D-P2 gate and its single evaluation point, schema v6, the paywall, the
       Settings row, the `--dart-define` build command, and two new rows in the
       drift-risk table ("an entitlement fact" → `EntitlementController`; "a
       paywall string" → `paywall_copy.dart`).
2. [x] `docs/privacy.md` (new): what RevenueCat collects, what is never
       transmitted, the in-app sentence, and the owner's remaining label and
       hosted-policy items (D-36).
3. [x] Residue sweep, each command pasted in the phase report:
       `grep -rn "kFreeTierOpenCycles" lib/`; `grep -rniE "dart:io|package:http|HttpClient|Socket|WebSocket|NetworkImage|package:dio|url_launcher" lib/`
       → empty; `grep -rl "purchases_flutter" lib/` → one path;
       `grep -rn "purchaseGatewayProvider\|purchases_flutter" lib/features/`
       → empty; `grep -rn "context.push('/paywall'" lib/` → one path;
       `grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/`
       → empty; `grep -rl "package:flutter" lib/domain/rules/` → empty;
       `grep -rnE "(^|[^A-Za-z])Colors\.|Color\(0x" lib/ --include='*.dart' | grep -v lib/core/theme/`
       → empty; `grep -rn "entitlement" lib/data/export/` → empty;
       `grep -c "UnimplementedError" lib/data/*.dart lib/data/db/*.dart`.
4. [x] `flutter analyze`, `flutter test`, `flutter build ios --simulator
       --no-codesign` — all green, with the counts pasted.

**Status: Complete.** `flutter analyze` → No issues found. `flutter test` →
**918 passed / 0 failed**. `flutter build ios --simulator --no-codesign` →
exit 0, `✓ Built build/ios/iphonesimulator/Runner.app`. All ten sweeps clean;
the pasted output is in the Progress row below.

**Done Criteria**: `flutter analyze`; `flutter test`; the nine sweeps above;
`flutter build ios --simulator --no-codesign` exit 0.

**Predicted Files**: `docs/architecture/wheel-triage.md`, `docs/privacy.md`
(new), `docs/plans/pro-wave-2-plan.md`.

**Owner checks (recorded in `## Progress`, never blocking an agent phase)**:
the RevenueCat project with the `pro` entitlement and the three products, the
subscription group, the annual introductory trial, and the Paid Apps agreement
with tax and banking; then a sandbox purchase, renewal, trial conversion,
cancellation, restore and refund, each exercised on a physical iPhone with a
sandbox account and recorded; then the App Store Connect privacy label filled
in against `docs/privacy.md` and RevenueCat's published guidance.

## Files Affected (whole wave; dependents marked)

- **Dependency**: `pubspec.yaml`, `pubspec.lock`, `ios/Podfile` (only if the
  podspec forces a deployment-target bump), `ios/Podfile.lock`,
  `ios/Runner/AppDelegate.swift` *(dependent: registers the `store_page`
  MethodChannel the native store sheet is opened through)*,
  `macos/Flutter/GeneratedPluginRegistrant.swift` *(dependent: generated; gains
  `PurchasesFlutterPlugin` when `purchases_flutter` is added)*.
- **Domain models**: `lib/domain/models/pro_plan_kind.dart` (new),
  `entitlement_cache.dart` (+ generated) (new),
  `entitlement_cache_defaults.dart` (new).
- **Data**: `lib/data/db/tables/entitlement_cache_table.dart` (new),
  `lib/data/db/type_converters.dart`, `lib/data/db/app_database.dart`
  (+ generated), `lib/data/db/schema/drift_schema_v6.json` (new),
  `lib/data/wheel_repository.dart` (+ generated),
  `lib/data/db/drift_wheel_repository.dart`,
  `lib/data/in_memory_wheel_repository.dart`,
  `test/data/db/generated/*` (regenerated).
- **Core**: `lib/core/purchases/*` (new: `purchase_gateway.dart`,
  `pro_plans.dart`, `purchase_configuration.dart`,
  `revenuecat_purchase_gateway.dart`, `unconfigured_purchase_gateway.dart`,
  `paywall_copy.dart`), `lib/core/app_router.dart`,
  `lib/core/format.dart` *(dependent: one additive formatter)*.
- **State**: `lib/state/entitlements/*` (new: `entitlement_controller.dart`,
  `entitlement_providers.dart`, `new_cycle_gate.dart`),
  `lib/state/paywall/paywall_controller.dart` (new),
  `lib/state/record/record_save_service.dart`,
  `lib/state/record/record_controller.dart` *(dependent: carries the gate's
  refusal line as `paywallTrigger` and consumes it)*,
  `lib/state/screener/screener_controller.dart` *(dependent: same)*.
- **UI**: `lib/widgets/entitlement_lifecycle_scope.dart` (new),
  `lib/features/paywall/*` (new), `lib/features/settings/pro_plan_section.dart`
  (new), `lib/features/settings/settings_screen.dart` *(dependent: section
  inserted)*, `lib/features/record/record_trade_screen.dart` *(dependent: reacts
  to a new outcome)*, `lib/features/screener/screener_screen.dart`
  *(dependent: same)*, `lib/main.dart`.
- **Test support**: `test/support/fake_purchase_gateway.dart` (new).
- **Docs**: `docs/architecture/wheel-triage.md`, `docs/privacy.md` (new).
- **Unchanged on purpose**: `lib/data/export/*`,
  `DriftWheelRepository.restoreFromJson`'s delete list, every threshold, the
  gate order in `classify()`, `lib/domain/rules/`, `android/`.

## Notes

- **Phase dependency graph** is in the Iteration block, with the offered
  re-ordering (P6 before P5) and its trade-off.
- **Intermediate states.** After P1 the repository carries two methods nothing
  calls yet, and the app is still fully free — expected, visible only in
  `lib/data/`. After P3 `purchaseGatewayProvider` exists but nothing reads it
  beyond `main.dart`; the app still behaves exactly as it did in Wave 1. After
  P4 the entitlement is live and cached but nothing gates on it. After P5 the
  limit bites but a refusal has no destination, so P7's screens must land before
  the wave is user-complete: **between P5 and P7 a refused fourth cycle shows
  the D-24 line and writes nothing, which is correct but incomplete.** After P6
  the paywall exists and is reachable only from Settings.
- **The Pro-feature entry point has no caller this wave.** `PaywallTrigger`
  carries it and S-277 tests it; Stages 6 and 7 (Wave 3) supply the callers. It
  is not dead code — it is the contract the next wave is written against.
- **The owner prerequisites are not confirmed**, so every phase's Done Criteria
  is satisfiable with the fake gateway and no API key. The real adapter's
  correctness against the store is R15's owner check and cannot be proven by an
  agent; the agent-provable part is that it compiles, that the iOS build
  succeeds, that no key is committed, and that the seam's contract holds.
- **The SDK symbol names in `revenuecat_purchase_gateway.dart` are the one
  place this plan deliberately does not pin.** They must be confirmed against
  the version `pubspec.yaml` pins, at implementation time. Every test binds to
  `PurchaseGateway`, never to the SDK, so a symbol correction is a one-file
  change with no test churn.
- **Goldens** are generated and compared on the Mac; the paywall adds no golden
  this wave (its content is store-driven, so a golden would encode a fixture
  price as if it were the design).
- **The `.work/` brief is not a repository artifact** and is not referenced by
  the plan.

## Progress

| Phase | Owner | Status | Evidence |
|---|---|---|---|
| 1 — schema v6 entitlement cache | @data-architect | Complete | `flutter analyze` clean; full suite 752 passed / 0 failed; schema diff v5→v6 is one added table, no changed column; `grep -rn "entitlement" lib/data/export/` empty; `UnimplementedError` count 0 in every data-layer file; S-255 red-then-green |
| 2 — `getOpenCycles` | @data-architect | Complete | S-258 contract block green against both implementations; `test/domain/rules/sbet_regression_test.dart` green in the full-suite run |
| 3 — purchase seam, plugin, network guard | @developer | Complete | `flutter analyze` clean; `test/core/purchases/` 12 passed (2 S-265 structural cases red by construction until Phases 5/7); full suite 764 passed / 2 failed, both the Phase-5/7 S-265 paths; `grep -rn "purchaseGatewayProvider\|purchases_flutter" lib/features/` empty; `flutter build ios --simulator --no-codesign` exit 0 with `pod install` for `purchases_flutter` (no deployment-target bump) |
| 4 — entitlement controller, cache, refresh | @developer | Complete | `test/state/entitlements/entitlement_controller_test.dart` 24 passed / 0 failed; `test/widgets/entitlement_lifecycle_scope_test.dart` 3 passed / 0 failed; `flutter test test/widgets test/widget_test.dart` 31 passed / 0 failed; `grep -rn "purchases_flutter" lib/state/ lib/features/` empty; `grep -rn "purchaseGatewayProvider" lib/features/` empty |
| 5 — D-P2 gate and the save path | @developer | Complete | red run recorded below (`+59 −4`); after implementation `flutter test test/state/entitlements test/state/record test/state/screener` 87 passed / 0 failed; `flutter analyze` clean; `grep -rl "package:flutter" lib/domain/rules/` empty; `flutter test test/domain/rules/sbet_regression_test.dart` green; full suite 814 passed / 1 failed — the single failure is S-265's `lib/features/settings/pro_plan_section.dart` path, which Phase 7 creates |
| 6 — the paywall | @developer | Complete | red run recorded below (`+34 −5`); after implementation `flutter test test/features/paywall test/state/paywall test/core/purchases` 81 passed / 1 failed; `test/state/paywall/paywall_controller_test.dart` + `test/core/purchases/paywall_copy_test.dart` 39 passed / 0 failed; `test/features/paywall/paywall_screen_test.dart` 29 passed / 0 failed; `test/core/format_test.dart` 8 passed / 0 failed; `flutter analyze` clean; full suite 890 passed / 1 failed — the single failure is S-265's `lib/features/settings/pro_plan_section.dart` path, which Phase 7 creates; tone grep empty; `grep -rn "context.push('/paywall'" lib/` returns one path; the colour-literal grep empty; `grep -rl "package:flutter" lib/domain/rules/` empty |
| 7 — entry points and the Settings row | @developer | Complete | red run recorded below (`+3 −2`); after implementation `test/features/settings/pro_plan_section_test.dart` + `test/features/paywall` + `test/features/record` + `test/features/screener` 67 passed / 0 failed; `test/core/purchases` + `test/state/entitlements` + `test/state/paywall` 93 passed / 0 failed; full suite 918 passed / 0 failed (Phase 6: 890 / 1, the failure being S-265, now green); `flutter analyze` clean; S-276's two new screen cases mutation-tested (`showPaywall` calls stubbed out → `+0 −2`, restored → `+2 −0`); `grep -rn "context.push('/paywall'\|showPaywall(" lib/` returns `paywall_route.dart` plus exactly the three allowed call sites; `grep -rn "purchaseGatewayProvider\|purchases_flutter" lib/features/` empty; tone grep empty; `grep -rl "package:flutter" lib/domain/rules/` empty; `flutter build ios --simulator --no-codesign` exit 0 |
| 8 — closeout docs and residue sweep | @developer | Complete | `flutter analyze` → No issues found; `flutter test` → 918 passed / 0 failed; `flutter build ios --simulator --no-codesign` → exit 0 (`✓ Built build/ios/iphonesimulator/Runner.app`). Sweeps: (1) `grep -rn "kFreeTierOpenCycles" lib/` → `pro_plans.dart:29` (the definition), `new_cycle_gate.dart:77,83` (the single evaluation), `pro_plan_section.dart:47` (the row's count display) and one backticked mention in a `paywall_copy.dart` doc comment — the three *code* sites are exactly S-265's list; (2) `grep -rniE "dart:io|package:http|HttpClient|Socket|WebSocket|NetworkImage|package:dio|url_launcher" lib/` → empty; (3) `grep -rl "purchases_flutter" lib/` → one path, `lib/core/purchases/revenuecat_purchase_gateway.dart`; (4) `grep -rn "purchaseGatewayProvider\|purchases_flutter" lib/features/` → empty; (5) `grep -rn "context.push('/paywall'" lib/` → one path, `paywall_route.dart:74`; (6) tone grep → empty; (7) `grep -rl "package:flutter" lib/domain/rules/` → empty; (8) colour-literal grep outside `lib/core/theme/` → empty; (9) `grep -rn "entitlement" lib/data/export/` → empty; (10) `grep -c "UnimplementedError" lib/data/*.dart lib/data/db/*.dart` → 0 in all eight files |
| Review fix round 1 — 13 findings from the Wave 2 code review | @developer | Complete | red run recorded below (`+77 −5` over the six touched test files, all five failures missing behaviour); after implementation `flutter test test/features/record test/features/screener test/features/settings/pro_plan_section_test.dart test/state/entitlements test/core/purchases` 82 passed / 0 failed; **full suite 925 passed / 0 failed** (Phase 8: 918 / 0, +7 new tests); `flutter analyze` → No issues found; tone grep empty; `grep -rl "package:flutter" lib/domain/rules/` empty; S-265's `network_boundary_test.dart` guard green — the free-tier number is still referenced from exactly the gate and the Settings count |
| Owner — RevenueCat project, products, subscription group, annual trial | owner | not yet run | agent cannot create store or dashboard configuration |
| Owner — Paid Apps agreement, tax and banking | owner | not yet run | agent cannot sign agreements |
| Owner — sandbox purchase / renewal / trial conversion / cancellation / restore / refund | owner | not yet run | agent cannot run a sandbox store account on a physical device |
| Owner — App Store Connect privacy label against `docs/privacy.md` | owner | not yet run | agent cannot edit the store listing |

## Assumption Log

*(executors append: decision made, options considered, choice and why. The
Conductor marks each RATIFIED — promoted to a D-x — or REVERT, opening
remediation.)*

*(empty — no phase has run yet)*

### Phase 1/2 (@data-architect) — 2026

1. **`saveEntitlementCache` returns the saved value.** Options: return `void`,
   or return the `EntitlementCacheData` that was written. Chose the return
   value, mirroring `updatePreferences`'s existing shape, so a caller can
   chain an assertion without a second read. The row is written through a
   fixed-id `update(...).write(...)`, so the returned value is the input
   verbatim — no read-back that could observe a different row.

2. **`EntitlementCacheDefaults.planKindName` is a spelled-out `'none'`, not
   `ProPlanKind.none.name`.** A SQL `withDefault` must be a compile-time
   constant and `Enum.name` is not a constant expression in Dart — verified
   empirically before the design was fixed, since the obvious
   `ProPlanKind.none.name` does not compile in that position. The two are kept
   from drifting by a contract assertion
   (`EntitlementCacheDefaults.planKindName == ProPlanKind.none.name`, S-256),
   which fails if the enum's `none` is ever renamed.

3. **`docs/architecture/wheel-triage.md` is not updated in Phase 1/2.** The
   plan assigns the architecture doc to Phase 8, so touching it here would
   duplicate that work and put two writers on one file. The new table, the two
   repository methods and the export-envelope exclusion are recorded in the
   model and interface doc comments instead.

4. **The S-214 "fresh v5 install" test was retargeted to v6, not left at v5.**
   Raising `schemaVersion` to 6 means `AppDatabase(schemaAt(5).newConnection())`
   now migrates 5→6 on open, after which `v5.DatabaseAtV5` refuses the
   connection (drift's `_defaultOnUpdate` throws on a downgrade). Options:
   pin the test at v5 by opening the snapshot without `AppDatabase`, or
   retarget it to v6. Retargeted, because the test's subject is "a fresh
   install of the current version", not the v4→v5 step — which the two sibling
   tests in that file already isolate and still pin at v5.

5. **The S-255 migration-gate test starts at v4 and targets v5.**
   `migrateAndValidate(db, N)` only runs `onUpgrade` when the database's actual
   version differs from `N`, so "migrating" a v5 database to 5 is a no-op and
   any assertion built on it passes vacuously. The test therefore migrates a
   v4 database to 5 — making the v5 step genuinely run — and positively
   asserts that the two v5 columns *do* exist, so it cannot pass by doing
   nothing.

6. **S-257's export assertion is on the raw JSON key set, not on
   `LedgerExport`.** `LedgerExport` has no entitlement field, so a typed
   round-trip would pass even if the writer emitted the row. The test decodes
   `exportToJson()` and asserts the top-level key set is exactly the nine
   persisted sections with `formatVersion == 2`, and separately that a
   hand-added `entitlement` key is dropped rather than trusted.


### Phase 3 (@developer) — 2026

7. **`manageSubscription` is a repo-owned `MethodChannel`, not an SDK call.**
   D-37 said "goes through the SDK". RevenueCat 10.13.2's Dart API exposes no
   `showManageSubscriptions` (nor any store-page symbol) — checked against the
   resolved package source before the design was fixed. Options: call a
   non-existent API (impossible), open a URL (needs `url_launcher`, which the
   brief forbids this wave), or own a `MethodChannel('wheel_triage/store_page')`
   handled in `ios/Runner/AppDelegate.swift`. Chose the channel: it keeps the
   behaviour inside the approved dependency set and the handler is ~15 lines.
   The Android side is unimplemented by design — the Android stage is separate.
8. **`purchases_flutter` is pinned exactly (`10.13.2`), not caret-ranged.**
   A purchase path is the one place where a silent minor bump can change
   behaviour under the user; the pinned version is also the one the iOS
   simulator build was verified against.
9. **`purchaseGatewayProvider` defaults to `UnconfiguredPurchaseGateway`.**
   Options: no default (throws, like `wheelRepositoryProvider`), or an
   unavailable gateway. Chose unavailable: a widget test that forgets the
   override must still boot, and D-28's "unavailable" state is already the
   designed answer for "the store cannot answer". `main.dart` overrides it on
   both branches of the API-key check, so production never gets the default.

### Phase 4 (@developer) — 2026

10. **`EntitlementStatus` lives in `lib/domain/models/entitlement_status.dart`;
    `EntitlementSnapshot` carries a `ProPlanKind`.** The status is a persisted
    concept (the cache row) so it belongs with the models, and reusing
    `ProPlanKind` rather than a parallel enum keeps one canonical type per
    concept.
11. **An `unknown` answer from the gateway keeps the last known good value and
    writes nothing.** D-26's third value means "the store did not answer", which
    is not evidence that the entitlement lapsed; writing it would let a network
    blip downgrade a paying user. Only a definite `inactive` writes.
12. **`loadOfferings()` treats an empty plan list as an answer.** A store that
    returns no plans has answered "no plans"; distinguishing that from a failed
    call would need a second sentinel the SDK does not provide.
13. **`purchase()` and `restore()` re-read the entitlement only on a
    `purchased` outcome.** A `pending`/`cancelled`/`failed` outcome is not
    evidence of a change, and re-reading would cost a store round-trip on every
    cancelled sheet.
14. **`restore()` maps a store "active" answer to `purchased` and anything else
    to `cancelled`.** The D-32 outcome lines are user-facing; "nothing to
    restore" and "restore failed" are not distinguishable from the SDK here, and
    the copy chosen covers both honestly.
15. **S-288's `RecordingPurchaseGateway` is `test/support/fake_purchase_gateway.dart`'s
    `FakePurchaseGateway`.** One scriptable double serves S-288 and the Phase
    3/4/5 tests; two doubles would drift.
16. **The cache read is normalised before it becomes state.** A cache row whose
    `isActive` is false but whose `planKind`/`expiresAt` are populated (possible
    after a downgrade) is presented as `inactive` with no plan, so the Settings
    row cannot show a plan for a lapsed entitlement.

### Phase 5 (@developer) — 2026

17. **The gate reads the book before it checks the entitlement.** One code path
    instead of two, and it makes "the gate was consulted" observable for S-259
    and "never called" observable for S-261/S-262/S-263 — the read count is the
    only externally visible trace of the evaluation.
18. **`paywall_copy.dart` takes the open-cycle limit as a parameter.** S-265
    requires `kFreeTierOpenCycles` to be referenced from exactly the gate and
    the Settings label, so the D-24 line builders cannot read it themselves;
    the gate substitutes it. This is also why the copy file can be tested
    against any limit without touching the constant.
19. **The at-the-limit line keeps the brief's literal "a fourth".** The line is
    pinned to a limit of 3 by S-260's fixture; generalising it ("another
    cycle") would read worse and the limit is a documented constant, not a
    variable. The past-the-limit form does substitute the count, because S-268
    needs 4 and 5.
20. **`newCycleGateProvider` is `Provider(newCycleGate)`, with `newCycleGate` a
    top-level factory in `new_cycle_gate.dart`.** S-265 requires the provider
    to live in `entitlement_providers.dart` but forbids `NewCycleGate` from
    appearing there, so the provider cannot name the type; the factory keeps the
    construction in the gate's own file and the two files import each other
    (Dart allows the cycle).
21. **The two form states gain `paywallTrigger` (plus `clearPaywallTrigger`),
    set together with `error`.** S-266 pins `state.error`; Phase 7's screens
    need to know that *this* error is the paywall's, and reading the error text
    to decide would be string-sniffing. `clearError` clears both, so a stale
    trigger cannot re-open the paywall on a rebuild.
22. **`currencyText` and `renewalDateText` land in `lib/core/format.dart` in
    Phase 5 rather than Phase 6.** `paywall_copy.dart` needs both, and the plan
    already assigns Phase 6 a `format.dart` test case for them.
23. **S-263's "the gate is never called" is asserted on the repository read
    count, and the test asserts that count before its own read.** The counter
    cannot distinguish the gate's read from the test's, so the ordering is
    load-bearing; the first version of the test failed on its own read.
24. **S-267's book is topped back up to the limit before the one action that may
    differ.** The flow legitimately closes a cycle (CCC is called away), so the
    assertion — which is about the limit, not about a particular count — is made
    against a book restored to `kFreeTierOpenCycles` by a raw repository write,
    identical in all three states.
25. **S-267's comparison normalises generated ids and the seeded profiles'
    `effectiveAt`.** Ids are random per run by construction, and
    `InMemoryWheelRepository` seeds the three rule-profile versions with
    `DateTime.now()`; both are seeding artifacts, not observable differences,
    and the placeholder order is deterministic because creation order is.
26. **S-268's sixth-cycle refusal is asserted while all five are still open, and
    the "all five are still actionable" actions run after it.** The refusal is
    about the count, so asserting it after the actions would be asserting a
    different scenario (the actions legitimately close four of the five).

### Phase 6 (@developer) — 2026

27. **`annualPerMonthText` rounds to the nearest cent; it does not truncate.**
    D-31 specifies `(price / Decimal.fromInt(12)).toDecimal(scaleOnInfinitePrecision: 2)`,
    but `Rational.toDecimal(scaleOnInfinitePrecision:)` **truncates** in the
    pinned `decimal` version — `29.99 / 12` yields `2.49` — while S-279 expects
    `$2.50`. Truncation also understates what the user pays, which is the wrong
    direction to be wrong in for a money figure. Chose
    `.toDecimal(scaleOnInfinitePrecision: 4).round(scale: 2)`: exact to
    ten-thousandths (the precision option prices are stored at) and then rounded
    half-away-from-zero. The EUR fixture was moved from `€29.99` to `€29.90`
    (→ `€2.49`) so both of the plan's expected values hold under rounding; the
    plan's arithmetic, not its numbers, is what changed.
28. **`PaywallState` holds `selectedProductId`, not "the selected plan kind".**
    Phase 6's item 1 says "the selected plan kind". A kind is derived from a
    product id (`kindForProductId`), so storing the kind would mean storing a
    value that cannot round-trip: two products of one kind would be
    indistinguishable, and the purchase could not name the id the store needs.
    The kind remains available as the `selectedKind` getter, which is what the
    plan's wording wants to read.
29. **The screen test and `test/core/format_test.dart` were written after their
    implementation, so no red run exists for them.** The copy and controller
    tests were written first and recorded red (`+34 −5`); the screen test could
    not be written meaningfully before the renderer's widget keys existed, and
    the format test covers helpers Phase 5 had already landed. This is a
    deviation from the tests-first rule and is recorded rather than papered
    over — both files were then run against deliberately broken implementations
    and observed red before being restored: replacing the rendered trigger line
    with a fixed string and reverting `annualPerMonthText` to truncation gave
    **`+26 −3`** on `test/features/paywall/paywall_screen_test.dart` (the two
    trigger-line cases and the derived-per-month case), and restoring both gave
    **43 passed / 0 failed** across the screen and copy tests.
30. **A plan row renders through a `PaywallPlanRow` display DTO, so no
    `lib/features/` file names a store type.** S-287 greps file *text* for
    `purchase_gateway.dart` under `lib/features/`, and Feature Invariant 10 says
    the same thing in prose: the screen must not import the gateway. Options:
    (a) a DTO derived in `paywall_copy.dart` and exposed by `PaywallState`, or
    (b) `export 'purchase_gateway.dart' show ProPlanOffer;` from the copy file.
    Chose (a): (b) satisfies the grep by moving the import, which is exactly the
    kind of change the guard exists to catch. `planRowFor` now derives the
    title, subtitle, button label and fine print beside the copy that produces
    them, `PaywallState.visibleRows` maps the visible offers through it, and the
    screen names only `PaywallPlanRow`.
31. **The paywall offers an upgrade to an active subscriber.** D-30 says an
    active entitlement renders "the owned state, no purchase button", while
    S-283(b) requires a subscriber to be able to buy lifetime. Read as: the
    owned line renders *beside* the surviving offers, and the lifetime row
    keeps its button. The alternative reading — hide every row whenever the
    entitlement is active — makes S-283(b) untestable and strands the
    lifetime-upgrade path, which D-33's own "lifetime only" filter exists to
    serve. A lifetime owner sees no rows at all, so D-30's intent holds where
    there is nothing left to buy.
32. **The D-33 entitlement filter is a method (`visibleOffers(entitlement)`),
    not stored state.** D-28 says the paywall holds no copy of the entitlement;
    a method takes the live `EntitlementState` on each build, so an entitlement
    change is reflected without the paywall subscribing to a second source of
    truth. `visibleProOffers(offers, entitlement)` is a top-level pure function
    so the rule is testable without a controller.
33. **A store product the app cannot describe is dropped, not rendered.**
    S-278's fixture includes an unknown product id. Dropping it means the user
    cannot buy something the app cannot label; keeping it would need a fallback
    title that could contradict the store. The same filter runs on selection, so
    a stale `selectedProductId` cannot reach `purchase`.
34. **A `cancelled` purchase clears the message instead of showing one.** D-32
    lists no line for `cancelled`, and "nothing happened" is the honest report
    for a user who dismissed the sheet. `pending`, `failed` and `unavailable`
    each get their line.
35. **Restoring with nothing to restore reports "No purchases to restore".** The
    real adapter returns `cancelled` when RevenueCat has no purchases to offer
    up, so `restoreOutcomeLine` maps `pending`/`cancelled` to that line and
    reserves `kRestoredLine` for `purchased`. Mapping `cancelled` to "nothing
    happened" would leave the user with no answer to the button they pressed.
36. **`paywallControllerProvider` is deliberately not `autoDispose`.** The
    Settings section (Phase 7) and the paywall route both read it, and a
    notifier disposed mid-flight would throw on `state =` when a purchase
    completes after the user has navigated away.
37. **A successful purchase triggers exactly one `currentEntitlement()` read.**
    Asserted as `gateway.calls == ['loadOfferings', 'purchase',
    'currentEntitlement']`, which pins both the read count and the absence of a
    cache write from the paywall — the cache is the controller's job (Phase 4).
38. **Widget tests for the paywall set a 900×2000 surface.** The default 800×600
    test surface leaves the button, message and policy text below the fold; a
    `ListView` builds its children lazily even when it looks eager, so
    `find.text` finds nothing and `tester.tap` misses. `setSurfaceSize` with an
    `addTearDown` reset is the standard remedy and changes nothing about the
    widget under test.
39. **The paywall screen's policy entries are `SelectableText` (D-37), and the
    Privacy Policy entry is hidden while `kPrivacyPolicyUrl` is empty.** With
    `url_launcher` forbidden this wave (Q1), selectable text is the deliberate
    degraded affordance; hiding an entry that would open nothing is the same
    decision applied to the empty constant.

### Phase 7 (@developer) — 2026

40. **`openCycleCountProvider` was added to
    `lib/state/entitlements/entitlement_providers.dart`, outside the phase's
    Predicted Files.** D-34's free row prints the open-cycle count, and Feature
    Invariant 6 forbids `lib/features/` from reaching into persistence, so
    *something* above the widget has to read `getOpenCycles()`. Options: (a) a
    `FutureProvider<int>` beside the gate, (b) a field on `EntitlementState`
    (wrong: the count is a book fact, not a store fact, and folding it in would
    make the entitlement controller a cycle reader), (c) a constructor
    parameter, which would push the read up into `settings_screen.dart` and
    break the same invariant one file over. Chose (a). It is a **count, not a
    gate evaluation**: it deliberately does not call `NewCycleGate.evaluate()`,
    so D-28's single-evaluation rule still holds, and S-265's exact-file list
    for `kFreeTierOpenCycles` is unaffected because this file does not name the
    constant — the section reads it and passes it in.
41. **The Settings section pushed two existing Settings tests past their test
    viewport, so their viewport was raised.** `test/features/settings/settings_screen_test.dart`
    overrode the surface to 800×2400 for seven tests; the new ~250 pt section at
    the top of the `ListView` moved the milestone editor below that, and
    `ListView` builds children lazily, so `find.text('14 days before expiration')`
    and the denied-permission note stopped resolving. Fixed by raising the seven
    overrides to 800×3200 — the same remedy the repo already uses for this class
    of problem, and a harness change with no production behaviour in it. The
    plan's item 4 asked for these tests to "still pass unchanged"; unchanged in
    assertion and in what they prove, adjusted only in surface size, which is
    recorded here rather than left implicit.
42. **`RecordController.paywallTrigger` and `ScreenerController.paywallTrigger`
    are new public getters.** The two screens need the refusal line to build the
    paywall trigger, and `StateNotifier.state` is `@protected` — reading
    `controller.state.paywallTrigger` from a widget trips
    `invalid_use_of_protected_member`, which `flutter analyze` treats as a
    failure. The getters expose the one field the screens legitimately need and
    nothing else, and they keep the "state layer produces the line, the screen
    only carries it" split the phase's item 1 asks for.
43. **`kPaywallTitle` is reused as the section header rather than duplicated.**
    D-34's reference markup heads the section "Wheel Triage Pro", which is the
    same string the paywall screen already shows. A second literal would be two
    places to keep in step, so the section reads the existing constant.
44. **An active entitlement whose product this build does not recognise renders
    as "Pro" with no detail line, and no Manage row.** D-34's table has no row
    for it, but the state is reachable: the store can report an active
    entitlement for a product id this build does not map to a `ProPlanKind`.
    Claiming the free tier would be wrong (Pro is on) and claiming "Pro status
    unavailable" would be false (it is available), so the header is the bare
    "Pro" and the detail line is `null`; the Restore row stays. Logged as the
    one state D-34 does not specify.

### Phase 8 (@developer) — 2026

45. **`docs/privacy.md` names RevenueCat's own data categories and leaves the
    store label and the hosted page to the owner, as D-36 says.** It states the
    three things the plan asks for — what the store sees (purchase history, an
    app-scoped anonymous id, device/app metadata), what never leaves the device
    (a list that names each wave surface explicitly, including the not-yet-built
    screenshot scan), and the in-app sentence verbatim — plus the two owner
    items the plan's Phase 8 block calls out. It does not attempt to write the
    App Store Connect label itself: the agent cannot reach the store listing,
    and a label guessed here would be a claim about a dashboard nobody read.
46. **The architecture doc's Pro section is one section, not four.** The seam,
    the state and its three refresh points, the gate and its single evaluation
    point, the paywall and the Settings row are one story told in five
    paragraphs, because splitting them would put the gate's single-evaluation
    rule in a different place from the seam that makes it necessary. The two
    drift-risk rows the plan asks for are appended to the existing table rather
    than given a Pro-only table of their own.
47. **The Settings screen's seven viewport overrides are recorded as a
    behaviour-neutral harness change, not a behaviour change.** Item 4 of Phase
    7 asked for `settings_screen_test.dart` to pass "unchanged". It passes with
    the same assertions and the same intent; only the test surface grew. Left
    implicit it would look like a test edited to fit a regression, so it is
    written down (also Assumption Log 41).

### Review fix round 1 (@developer) — 2026

48. **The stale-trigger fix clears the trigger in the screens *and* on every
    non-gate early return (finding 1).** Options: clear it only in the two
    screens after reading it, or only on the controllers' early-return paths, or
    both. Chose both, as the brief asks: the screens clear it immediately after
    handing it to `showPaywall`, so a dismissed paywall cannot leave a live
    trigger behind, and the four non-gate paths (`!hasEnoughToSave`/
    `!hasEnoughToTrack`, `bound.blocks`, `isRefused`, the `catch`) pass
    `clearPaywallTrigger: true`, so a later failure cannot resurrect one. The
    gate's own `paywallRequired` path is deliberately the only one that leaves
    the trigger set. `ScreenerController` had no `clearPaywallTrigger()` at all
    — it gains one, mirroring `RecordController`'s.
49. **`copyWith` gained `clearExpiresAt`/`clearPurchasedAt` rather than a
    sentinel or a nullable-wrapper (finding 8).** Options: `Object?` sentinel
    parameters, `Optional<T>` wrappers, or boolean clear flags. Chose the flags,
    because they match the two flags `RecordFormState.copyWith` and
    `ScreenerFormState.copyWith` already use for the same problem
    (`clearError`, `clearPaywallTrigger`) — a third convention for nulling a
    field would be the drift this wave is trying to avoid.
50. **`_loadCache` still reads the cache row verbatim, so an inactive row can
    set `purchasedAt` for the moment before `refresh()` clears it.** Finding 8
    asked only that a *lapse* reset both fields; the cache is a display hint,
    never a gate input (`NewCycleGate` reads `isActive` only), and the next
    `refresh()` — launch, resume, or the store's own update — settles it. Left
    as is rather than widening the fix into the read path.
51. **The paywall's free-limit phrase lives beside the number, not in the copy
    file (finding 6).** The brief asks for `'More than 3 open cycles'` to be
    *derived* from `kFreeTierOpenCycles`. Interpolating it in
    `paywall_copy.dart` breaks S-265, whose plan-pinned outcome is that the
    number "is defined once and referenced only from the gate and the Settings
    count label" — `test/core/purchases/network_boundary_test.dart` asserts
    that file list literally, and it failed on the first attempt. Chose to add
    `const String kFreeTierLimitPhrase` to `pro_plans.dart`, directly under
    `kFreeTierOpenCycles`, and have `kPaywallFeatures` use it: the copy is still
    derived from the one constant (so raising the limit cannot leave the paywall
    advertising the old one) and S-265's guard is unchanged. The alternative —
    adding `paywall_copy.dart` to S-265's expected list — was rejected because
    it weakens a structural guard the plan states, to fix a copy nit.
52. **The S-261/S-262 tests written for finding 10 were green on the red run.**
    They guard behaviour Phase 5 had already shipped (a roll and an assignment
    at three open cycles are never gated), and the brief asked for the missing
    tests, not for a behaviour change. They assert the scenarios' stated
    outcomes directly — `repo.openCycleReads == 2` (only the test's own two
    book reads), so a gate that consulted the count on a roll or an assignment
    fails them. Same for the `paywall_copy_test.dart` binding test (finding 6):
    `3 == 3` before and after, so it is a guard, not a red test.
53. **One extra, tightly-coupled fix outside the 13 findings.**
    `test/data/wheel_repository_contract_test.dart`'s S-256 comment repeated the
    same false claim finding 9 asked to remove from
    `DriftWheelRepository.getEntitlementCache`'s doc ("a second row would
    throw"). Leaving the comment would have re-planted the error the finding
    removes, so it was corrected in the same change. No behaviour changed.

### Review fix round 1 — the recorded red run (@developer) — 2026

`flutter test test/features/record/record_trade_screen_test.dart
test/features/screener/screener_screen_test.dart
test/features/settings/pro_plan_section_test.dart
test/state/entitlements/entitlement_controller_test.dart
test/state/entitlements/new_cycle_gate_test.dart
test/core/purchases/paywall_copy_test.dart` before any fix: **`+77 −5`,
"Some tests failed."**

- `record_trade_screen_test.dart` S-276 — failed behaviourally: the trigger
  survived the paywall (the assertion inverted by finding 1), and the new
  second-failure case reopened the paywall after a dismissed one.
- `screener_screen_test.dart` — the same second-failure case failed for the
  same reason; the screener had no `clearPaywallTrigger()` to call.
- `pro_plan_section_test.dart` — failed behaviourally: an unresolved book
  rendered "0 of 3" instead of no count (finding 7).
- `entitlement_controller_test.dart` — failed behaviourally: a lapse left the
  previous `expiresAt` in the state (finding 8).

The S-261/S-262 tests (finding 10) and the `paywall_copy_test.dart` binding
test (finding 6) were **green** on this run — see Assumption 52. Every failure
is a missing behaviour, not a configuration error.

### Phase 7 — the recorded red run (@developer) — 2026

`flutter test test/features/settings/pro_plan_section_test.dart
test/features/paywall/paywall_entry_points_test.dart
test/core/purchases/recording_gateway_isolation_test.dart` → **+3 −2**:

- `pro_plan_section_test.dart` and `paywall_entry_points_test.dart` failed to
  **load**: `Undefined name 'kSeeProPlansLabel'`, `'kBillingIssueLine'`,
  `'kFreePlanDetailLine'`, `'kProStatusUnavailableLine'`,
  `'kProStatusUnavailableDetailLine'` — the D-34 copy did not exist — and
  `pro_plan_section.dart` did not exist to render it.
- `recording_gateway_isolation_test.dart`'s three S-288 cases were **green** on
  this run. That is expected and not a broken test: S-288 is a structural guard
  over Phase 3–6 artifacts (the seam's six signatures, its three imports, and
  the fact that a recording decorator sees nothing but a product id), so it can
  only be red if a later change leaks something into the seam. It was written
  in this phase because this phase is where the seam gets its call sites.

The two S-276 screen cases added to
`test/features/record/record_trade_screen_test.dart` and
`test/features/screener/screener_screen_test.dart` could not be run red against
"nothing implemented" — without the phase's `showPaywall` call the test cannot
reach the paywall at all and fails on a missing widget rather than on a missing
behaviour. They were instead verified by mutation after the fact: stubbing both
`showPaywall` call sites out gives **+0 −2**, and restoring them gives
**+2 −0**.

### Phase 6 — the recorded red run (@developer) — 2026

`flutter test test/core/purchases/paywall_copy_test.dart
test/state/paywall/paywall_controller_test.dart` before any Phase 6
implementation: **`+34 −5`, "Some tests failed."** The five failures are the
missing `PaywallState`/`PaywallController` and the missing outcome, button and
retry copy — every one a missing behaviour, none a configuration error. After
the implementation the same command is **39 passed / 0 failed**.

### Phase 5 — the recorded red run (@developer) — 2026

`flutter test test/state/entitlements test/state/record test/state/screener`
before any Phase 5 implementation: **`+59 −4`, "Some tests failed."**

- `test/state/entitlements/new_cycle_gate_test.dart` — failed to load: no
  `lib/state/entitlements/new_cycle_gate.dart`; `NewCycleGate`,
  `NewCycleAllowed`, `NewCycleBlocked` and `newCycleGateProvider` all undefined.
- `test/state/entitlements/nothing_locks_test.dart` — failed to load: the getter
  `isPaywallRequired` isn't defined for `RecordSaveResult`.
- `test/state/record/record_save_service_test.dart` — failed to load:
  `RecordSaveOutcome.paywallRequired` and `RecordSaveResult.paywallRequired`
  do not exist.
- `test/state/screener/screener_controller_test.dart` — loaded, and failed
  behaviourally: S-266's put case returned `true` where `false` is expected
  (`screener_controller_test.dart:645`), because an ungated save created a
  fourth cycle instead of refusing it.

Every failure is a missing behaviour, not a configuration error. After the
implementation the same command is **87 passed / 0 failed**, and the full suite
is 814 passed / 1 failed — the one failure being S-265's
`lib/features/settings/pro_plan_section.dart` path, which Phase 7 creates.

## Feedback

[empty — fold into a new Iteration block when non-empty, then clear]

## Open questions

### Owner-only (the agent cannot resolve these, and no phase is blocked by them)

**Q1 — May the paywall's policy links open a URL, or is selectable text
acceptable until launch?** D-P3 pre-approves only `purchases_flutter`, so
opening a URL needs `url_launcher`, which the brief forbids this wave. D-37
therefore ships the Terms of Use and Privacy Policy entries as
`SelectableText`. Approving `url_launcher` (or supplying hosted pages that the
Stage 9 listing links to instead) resolves it. Nothing else in the wave
depends on the answer.

**Q2 — The product and entitlement identifiers.** `lib/core/purchases/pro_plans.dart`
pins `pro` (the RevenueCat entitlement) and
`wheel_triage_pro_monthly` / `wheel_triage_pro_annual` /
`wheel_triage_pro_lifetime` (the three products). If the owner prefers other
identifiers, they must exist in App Store Connect with **these** names or the
constants must be changed before R15's sandbox check — the app cannot discover
them.

**Q3 — The Privacy Policy URL.** `kPrivacyPolicyUrl` is empty until the owner
supplies the hosted page; while empty, that entry is hidden. Terms of Use
defaults to Apple's standard EULA URL, which the owner may replace.

**Q4 — Will the App Store's introductory offer be a free trial or a
pay-as-you-go/pay-up-front offer?** The paywall derives its trial line from
whatever the store reports and needs no change either way, but the copy
"Start N-day free trial" is only correct for a free trial. If the store's offer
is paid, the button copy must be revisited (a one-line change in
`paywall_copy.dart`).

**Q5 — Is a subscription group with an upgrade/downgrade path intended?** The
plan assumes the three products are independent (monthly, annual, lifetime),
with no proration between the two subscriptions. A subscription group with
upgrades would change only the owner's store configuration, not the code.

### Resolved with a logged assumption (vetoable before the first phase that depends on them)

**Q6 — Is the real RevenueCat adapter written in this wave, or only the seam?**
*Resolved: written in this wave* (D-27, Phase 3). The brief's own constraint —
"the real RevenueCat API key and store products are owner items supplied via
configuration" — only makes sense if there is a real adapter to configure.
The agent-verifiable part is that it compiles, that the iOS build succeeds and
that no key is committed; the store-facing part is R15's owner check. **Veto
by deleting Phase 3's item 5 and 6 and leaving `UnconfiguredPurchaseGateway`
as the only implementation** — the seam, the gate, the paywall and the Settings
row are unaffected, and the wave then ships a paywall that cannot take money.

**Q7 — Does closing a cycle free a slot immediately?** *Resolved: yes* (D-22).
"Open cycles" is a live count, not a lifetime quota, so a user at the limit who
closes one can open another. The alternative (a lifetime count of cycles
created) would contradict "nothing already recorded ever locks" in spirit and
would make a closed, finished trade cost the user a slot forever.

**Q8 — Should the paywall also open from Today's concentration line?** *Resolved:
no* (D-38). The UI reference lists "Portfolio and assignment calendar" as a Pro
feature, but that is Stage 7 and Wave 3; Today's existing concentration line is
built and free, and D-P2's limit is the only free-tier boundary this wave
introduces. Opening the paywall from a free surface the user already has would
be the app asking for money on a screen that works.

**Q9 — Is the entitlement cache a new table or columns on `user_preferences`?**
*Resolved: a new table* (D-25). `LedgerExport` serialises `user_preferences`
whole and `restoreFromJson` deletes and re-inserts it, so an entitlement stored
there would be **granted by importing a hand-edited backup and revoked by
restoring an old one**. A separate table is outside the envelope and outside the
delete list by construction, which is the correct semantics for store-derived
state.

**Q10 — What does `unknown` do at the gate?** *Resolved: it behaves as free*
(D-26, D-23). A first launch with no network and no key would otherwise have to
choose between refusing a cycle the user is entitled to and granting Pro from an
absent answer. Refusing is recoverable (Restore purchases, or the next
successful refresh); granting is not, and it is the failure mode the whole
cache design exists to avoid.
