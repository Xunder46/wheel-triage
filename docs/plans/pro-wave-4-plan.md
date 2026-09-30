# Feature: Pro Wave 4a — Accessibility and polish (Stage 4B)

> Status: **DRAFT — active**. Phase 1 is ready to hand off; the owner-only checks in
> `## Open questions` are unresolved and do not block Phases 1–6.
> Next handoff: `@developer` (Phase 1 — the three shared mechanisms)
> Binding conventions: `docs/conventions.md` (especially §4 tone, §7 testing, §9 accessibility)
> (+ `docs/architecture/wheel-triage.md`, `docs/brief-pro.md` §2/§4/§5/§8)
> Supersedes: nothing. Wave 3 (`docs/plans/pro-wave-3-plan.md`) is closed at D-57 / S-312; this
> plan continues both registers from D-58 and S-313.

## Overview

`docs/brief-pro.md` §4 Stage 4B is four bullet points, and this wave is exactly those four
points plus the polish the brief's own wording implies ("it works for everyone, on every screen
that exists at launch"):

1. Dynamic type up to the largest accessibility size, with numbers and bucket reasons wrapping
   rather than truncating, **on every screen**.
2. Every number's VoiceOver label names its quantity, audited against the standing rule in
   `docs/conventions.md` §9 that Wave 1 introduced.
3. Haptic feedback when a snapshot changes a bucket.
4. A contrast audit at 4.5:1, in both themes, on every screen.

Stage 4B's stated reason for running now — "Runs once, after Stages 5–8, so no screen is
audited twice" — is satisfied: Waves 1–3 shipped Stages 0–3, 7 and 8, and the Pro screens that
exist at launch are all in the tree. Stage 5 (Pro plans) is RevenueCat configuration and
store-side work, Stage 9 is store delivery, and Stage 10 is post-launch; none of them adds a
screen. **Stage 4B is therefore the last wave that can audit a complete screen set**, which is
why it is worth doing properly rather than as a spot check.

### The wave's shape: three mechanisms, then the audit

The brief asks for one shared, testable mechanism per requirement rather than per-screen
patches, and the reason is the next wave. Stage 6 (screenshot scan) does not exist yet, and
whatever it adds will be a screen with numbers on it. A per-screen fix leaves nothing behind
for Stage 6 to inherit; a mechanism does. So this wave builds, in this order:

| Mechanism | What it replaces | Why it is the one |
|---|---|---|
| `test/support/screen_a11y_harness.dart` — one table of audited surfaces, one pump at the largest text scale, one traversal assertion | `test/features/portfolio/portfolio_screen_test.dart`'s S-304 test (the only screen currently checked at a raised text scale) | Adding a screen becomes adding a table row, and a **structural test** makes a route without a row fail (D-60, D-72) |
| `lib/widgets/label_value_row.dart` — one label/value row that stacks instead of truncating | **four** near-identical copies: `screener_screen._OutputRow:348`, `journal_screen._stat:163`, `position_detail_sheet._Row:284`, `cycle_summary_card._row:120` | It is where all eight `TextOverflow.ellipsis` sites that can carry a number or a reason actually live (D-64) |
| `lib/core/haptics/haptics.dart` — one injectable seam over Flutter's built-in `HapticFeedback` | nothing (there is no haptic today) | Same shape as `NotificationGateway` (`lib/core/notifications/notification_scheduler.dart:101`) and `ShareSheet` (`lib/state/export/export_controller.dart:91`): a test can assert *that* it fired, which a real vibration cannot be asserted about (D-65) |

The contrast audit is the fourth requirement and needs no mechanism beyond the one that already
exists: `test/core/theme/app_theme_contrast_test.dart` (S-219) is the permanent guard, and this
wave widens it from "the pairs the design table documents" to "every pair a screen actually
paints" plus a **structural** check that a new `scheme.<role>` read cannot arrive unaudited
(D-70). The audit found one real failure and it is recorded in D-69.

### What this wave deliberately does not do

- **No new token, no restyling, no layout redesign.** The only colour value that changes is the
  one that fails its bar (D-69). The only layout change is the one a failed truncation audit
  forces: a row that stacks instead of clipping (D-64).
- **No new dependency.** `HapticFeedback` is Flutter's own (`package:flutter/services.dart`);
  the wave adds no line to `pubspec.yaml`.
- **No schema change.** `AppDatabase.schemaVersion` stays 6 and no `drift_schema_v7.json`
  appears; `dart run build_runner build` is not needed by this wave (D-74).
- **Nothing is built for Stage 6.** D-72 writes the forward contract down (a harness row plus a
  checklist entry is what a Stage 6 screen owes) without creating a Stage 6 surface, a route, a
  placeholder or an abstraction "ready for" one. `docs/conventions.md` §9 is already standing
  policy from Wave 1; this wave adds the path to the mechanism, not a new policy.
- **The drift table's "percentage string" observation stays an observation.** Four sites
  (`journal_row.dart:47`, `cycle_summary_card.dart:136`, `screener_screen.dart:395`,
  `roll_planner_screen.dart:103`) each format a percentage by hand. This wave touches three of
  those four files for semantics labels, so folding them into `format.percentText` is tempting —
  but they do not all use the same precision, so "folding them in" is a display change, not a
  consolidation. Left out of scope; raised in `## Open questions` (D-74).

### Ground truth at planning time

| Fact | Value | How it was established |
|---|---|---|
| `flutter analyze` | clean | run in this checkout |
| `flutter test` | **1076 passed, 0 failed** | run in this checkout (Wave 3's closeout was 1076) |
| `AppDatabase.schemaVersion` | 6 | `lib/data/db/app_database.dart:41`; `lib/data/db/schema/` holds v1–v6 |
| Rules purity | clean | `grep -rl "package:flutter" lib/domain/rules/` → nothing |
| Colour literals | clean | `grep -rnE "(^|[^A-Za-z])Colors\.\|Color\(0x" lib/ --include='*.dart' \| grep -v lib/core/theme/` → nothing |
| Tone | clean | the §4 banned-word grep over `lib/` → nothing |
| `TextOverflow.ellipsis` in `lib/` | **8 sites** | `journal_screen.dart:168`, `screener_screen.dart:366`, `today_screen.dart:263`, `:436`, `:443`, `position_detail_sheet.dart:333`, `portfolio_screen.dart:565`, `cycle_summary_card.dart:126` |
| `Semantics(` in `lib/` | 13 sites | `portfolio_screen.dart` ×5, `paywall_screen.dart` ×4, `record_trade_screen.dart` ×2, `today_screen.dart` ×1, plus `bucket_badge.dart`, `help_chip.dart`, `app_bottom_nav.dart` |
| Routes | 12 | `lib/core/app_router.dart` (see D-60's table) |
| Modal surfaces | 17 | 4 `showModalBottomSheet`, 7 `showDialog`, 6 `showDatePicker`, 4 `showSnackBar` (D-60) |

## Resolved Decisions (Ledger)

Entries are immutable once written. A change is a new superseding entry ("D-70 supersedes
D-63"), never an edit.

### D-58 — Wave scope *(derived from the brief — vetoable)*

This wave is **Stage 4B only**: dynamic type, semantics labels, the bucket-change haptic, and
the contrast audit. It includes the shared mechanisms those four need (D-60, D-64, D-65) and
the documentation closeout that keeps `docs/conventions.md` §9 and
`docs/architecture/wheel-triage.md` true.

It excludes, permanently or until a later wave:

- Stage 6 (screenshot scan) — not planned, not scaffolded, no placeholder (D-72).
- Stage 5 (Pro plans / RevenueCat configuration), Stage 9 (store delivery), Stage 10
  (post-launch import) — none adds a screen, none is Stage 4B.
- Stage 4B's own owner checks, which are listed as `(owner)` items and recorded, not performed
  by an agent (D-73).
- Any new colour token, any restyling beyond what a failed audit requires, any layout redesign
  beyond the truncation fix, any new dependency, any schema change (D-69, D-64, D-74).
- The four hand-rolled percentage formatters (D-74).

### D-59 — The largest accessibility text size is one pinned constant

**`kMaxTextScale = 3.2`**, declared exactly once, in `test/support/screen_a11y_harness.dart`,
and read by every text-scale assertion in the suite.

- **Why 3.2.** iOS's largest accessibility size (AX5) scales body text from 17pt to about 53pt —
  a ratio of ≈3.12. 3.2 is that ceiling with margin, so a screen that passes 3.2 passes the
  device's own maximum. It is deliberately **not** 2.0: the existing S-304 test pumps at 2.0,
  which is below AX5, and the brief asks for "the largest accessibility size".
- **Why one constant.** Two numbers in two files is how a test starts passing for the wrong
  reason. `grep -rn "TextScaler.linear(" test/` must show exactly one literal, and it is inside
  the harness's `kMaxTextScale`.
- **The `MediaQuery` shape.** `TextScaler.linear` (a flat multiplier), applied through
  `MaterialApp.router`'s `builder`, exactly as S-304 does at 2.0. Not `MediaQuery.withClampedTextScaling`,
  which would silently cap the scale and make the assertion vacuous.
- **The owner check is still required** (S-333): 3.2 is a proxy for AX5, and only a device shows
  what the OS actually does to a `TextTheme` at AX5.

### D-60 — One harness, one table, and a structural test that keeps the table complete

**New file `test/support/screen_a11y_harness.dart`.** It exports:

```dart
/// D-59. The largest accessibility text size the app must survive.
const double kMaxTextScale = 3.2;

/// One audited surface: how to reach it, what to open on top of it, and the
/// numbers its screen must label. `route` is a full path
/// ('/positions/:legId/roll'); `open` runs after the route settles and is how
/// a sheet or a dialog is audited; `expectedLabels` are `(quantity, value)`
/// pairs asserted on **one line** of one accessibility node (D-61);
/// `fixture` selects the populated or the empty data population.
class AuditedSurface {
  const AuditedSurface({
    required this.name,
    required this.route,
    this.open,
    this.expectedLabels = const [],
    this.fixture = SurfaceFixture.populated,
  });
  final String name;
  final String route;
  final Future<void> Function(WidgetTester tester)? open;
  final List<(String quantity, String value)> expectedLabels;
  final SurfaceFixture fixture;
}

enum SurfaceFixture { populated, empty }

/// Pump [surface] at [kMaxTextScale] on a surface tall enough that vertical
/// overflow is not what is being measured, then assert (a) no layout
/// exception was thrown and (b) every expected label is reachable.
Future<void> auditSurface(
  WidgetTester tester,
  AuditedSurface surface, {
  required InMemoryWheelRepository repo,
  List<Override> extraOverrides = const [],
});

/// Every accessibility label in the tree, flattened, as assistive technology
/// would traverse it -- not one widget's isolated node.
Iterable<String> semanticsLabels(WidgetTester tester);

/// Whether any label carries a line matching [pattern]. A `Semantics(label:)`
/// node does **not** merge its subtree (A-5), so a bare child `Text` keeps its
/// own node and its own label -- which is why the pair assertion below needs
/// both halves on one line of one node rather than anywhere in the tree.
bool anyLineMatches(Iterable<String> labels, Pattern pattern);

/// The audited surfaces. Adding a screen means adding a row here (D-72).
const List<AuditedSurface> auditedSurfaces = [ /* the table below */ ];
```

**The table is the audit's enumeration, and it is complete.** One row per route and one row per
modal surface that renders a number or a bucket reason:

| # | Surface | Route / how reached | Fixture |
|---|---|---|---|
| 1 | `ScreenerScreen` | `/screener` | populated (form filled), empty (blank form) |
| 2 | `RecordTradeScreen` | `/record` | populated (optional disclosure open), empty |
| 3 | `JournalScreen` | `/journal` | populated (closed cycles), empty |
| 4 | `ShareCardScreen` | `/journal/share` | populated (a month with closed cycles), empty (no card) |
| 5 | `PortfolioScreen` | `/portfolio` | populated (S-304's book), empty |
| 6 | `SettingsScreen` | `/settings` | populated |
| 7 | `FirstRunExplainerScreen` | `/first-run` | populated |
| 8 | `PaywallScreen` | `/paywall` | populated (store returns three plans) |
| 9 | `TodayScreen` | `/positions` | populated (S-015's book), empty |
| 10 | `PositionDetailSheet` | `/positions/:legId` | populated (a reading), no-reading (a leg with no snapshot) |
| 11 | `RollPlannerScreen` | `/positions/:legId/roll` | populated |
| 12 | `AssignmentFlowScreen` | `/positions/:legId/assign` | populated |
| 13 | `SnapshotSheet` | Today row → Update snapshot | populated (a leg with a reading) |
| 14 | The help sheet | any `HelpChip` → tap | populated (`captured`) |
| 15 | The fees sheet | `PositionDetailSheet` → the fees row | populated |
| 16 | The cycle summary sheet | `JournalScreen` → a closed cycle | populated |
| 17 | `PositionDetailSheet`'s two dialogs | → the close / mark-expired confirm | populated |
| 18 | `PastExpirationCard`'s two dialogs | Today → the past-expiration action | populated |
| 19 | The roll planner's two dialogs | `/roll` → new candidate / confirm roll | populated |
| 20 | `SettingsScreen`'s reset dialog | Settings → Replace everything? | populated |
| 21 | The date pickers (6 call sites) | Screener, Record, Snapshot, Roll, Assign | one row each, populated |
| 22 | `ExportReminderBanner` | Today, with the banner visible | populated |

**Structural guard (S-330).** A test reads `lib/core/app_router.dart`, extracts every
`GoRoute(path: '<literal>')` fragment (`'/screener'`, `'/record'`, `'/journal'`, `'share'`,
`'/portfolio'`, `'/settings'`, `'/first-run'`, `'/paywall'`, `'/positions'`, `':legId'`,
`'roll'`, `'assign'`), and asserts each fragment appears in `auditedSurfaces`' route list. A new
route without a harness row fails by name. **This is the mechanism Stage 6 inherits** (D-72).

**SnackBars are exempt** from the number-label audit: a SnackBar is a sentence announced as it
appears, not a screen a user navigates, and its `Text` wraps by default. Recorded here so the
exemption is bounded and not an oversight. A SnackBar that gained a truncation would still fail
the truncation ban (D-63).

### D-61 — What "names the quantity" means, exactly

A number is *labelled* when the accessibility tree contains a node whose label carries **the
quantity's name and the number's value on the same line**.

- **Form.** `<Quantity name> <the same value string the screen renders>`. The quantity name is
  the wording the visible label already uses (`Delta`, `Captured`, `Roll band`, `Extrinsic
  remaining`, `Annualised yield`), so a sighted and a VoiceOver user read the same words.
- **The value keeps the app's own formatting, symbols included.** `wholeDollars` returns
  `$4,500` and `percentText` returns `62.0%`; the label carries that same string. VoiceOver reads
  both correctly in en-US, and this is what the two shipped label styles already do
  (`record_trade_screen.dart:417` `'Annualised yield 62 percent'`,
  `portfolio_screen.dart:253` `'INTC $4,500 committed, 12.0% of wheel capital'`). **No existing
  label is reworded** — S-304's five assertions are the pattern this wave generalises, and they
  must stay green unchanged.
- **A missing value is spoken as `not available`**, never `--` and never `0`. A `--` on screen is
  an absence; read aloud it is two dashes, which is the same failure as a bare number.
  `record_trade_screen.dart:417` is the precedent.
- **Dimensionless quantities carry no unit** (`Delta 0.25`, `Sorting score 6`); a quantity with a
  unit carries it, spelled or symbolised, as the screen renders it.
- **A bucket's label is `<Bucket> <count>`** (`Close 5`), matching
  `today_screen.dart:234`'s `'$count $label'` and `portfolio_screen.dart:550`'s
  `'${bucketLabel(entry.bucket)} ${entry.count}'`. A bucket **reason** is already a sentence and
  needs no label of its own; what it needs is to not be truncated (D-63).
- **The assertion is same-line.** `anyLineMatches(labels, RegExp(r'Delta\s+0\.25'))` — not
  "the quantity name appears somewhere in the node", which a child `Text('Delta')` would satisfy
  on its own and which would make the whole audit vacuous. S-304 already asserts this way
  (`l.contains('INTC') && l.contains('$') && l.contains('%')`); the harness makes it uniform.

### D-62 — Where the label sits

- The `Semantics(label: ...)` wraps **the smallest widget that contains both the quantity's
  visible label and its value** — one node per number, so the traversal reads one item per
  quantity rather than one per `Text`.
- The shipped shape is used as-is: `Semantics(label: ..., child: ...)`, no `container: false`,
  no `MergeSemantics`, no `ExcludeSemantics`. It is what `portfolio_screen.dart` and
  `record_trade_screen.dart` already do, and it is what S-304 traverses.
- **A `HelpChip` inside a labelled row stays its own node.** A chip is a button; merging it into
  the number's label would make the number's node announce "Help: Captured" and cost the user
  the tap target. `help_coverage_test.dart` (S-082) finds chips by type and is unaffected.
- A label is added **only where a number is rendered**. Adding one to a node that has no number
  is noise, and the harness's table lists the numbers per surface precisely so this stays
  bounded.

### D-63 — The truncation ban, and why it needs its own guard

**No `Text` that can carry a number or a bucket reason may set `overflow: TextOverflow.ellipsis`
or `maxLines` below the lines it needs.**

- **`takeException()` does not catch this.** An ellipsised `Text` lays out inside its box and
  throws nothing; that is the whole point of the ellipsis. A horizontal `RenderFlex` overflow
  *does* throw, so the harness's max-scale assertion catches unbounded rows — but it is silent
  about a clipped one. Hence a second, structural guard:
- **Structural guard (S-317).** A test scans `lib/` for `TextOverflow.ellipsis` and
  `overflow: TextOverflow.clip`, and asserts every occurrence is in a file/line on a pinned
  allow-list of sites that **cannot** carry a number or a reason (today: none — all eight sites
  are cleared by this wave, so the allow-list starts empty and the assertion is that the grep
  finds nothing at all in `lib/features/` or `lib/widgets/`). Adding a site means editing the
  pinned list, which is the guard doing its job.
- **The remedy is wrap or stack, never shrink.** Not a smaller `fontSize`, not a `FittedBox`, not
  `maxLines: 3` with an ellipsis: a number a user cannot finish reading is the defect. A
  `Row(spaceBetween, [Flexible(label), Text(value)])` becomes a `Column` at large scales (D-64).
- The bucket badge's reason already wraps (`bucket_badge.dart` sets no `maxLines`); the ban
  protects it from a future edit, which is why the guard is structural rather than a one-off fix.

### D-64 — One label/value row, and the four copies it replaces

**New file `lib/widgets/label_value_row.dart`.** It replaces four near-identical private
implementations:

| Site | Today |
|---|---|
| `lib/features/screener/screener_screen.dart:348` | `class _OutputRow` — `Row(spaceBetween, [Flexible(Row[Flexible(Text(label, ellipsis)), HelpChip]), Text(value)])` |
| `lib/features/journal/journal_screen.dart:163` | `Widget _stat` — `Row(spaceBetween, [Flexible(Text(label, ellipsis)), Text(value)])` |
| `lib/features/positions/position_detail_sheet.dart:284` | `class _Row` — as the screener's, plus an optional `valueText` widget |
| `lib/widgets/cycle_summary_card.dart:120` | `Widget _row` — as the journal's, plus `emphasize` |

**Its contract:**

```dart
/// One label and one value, which **stacks** when the label and the value
/// cannot share a line at the active text scale -- so neither is truncated at
/// any accessibility size (D-63). The row owns no formatting: [value] is the
/// string the caller already renders, and [label] is the quantity's name.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.helpTopicId,
    this.emphasize = false,
    this.trailing,
  });
  final String label;
  final String value;
  final String? helpTopicId;   // the HelpChip stays its own node (D-62)
  final bool emphasize;        // cycle_summary_card's bold variant
  final Widget? trailing;      // position_detail_sheet's `valueText`
}
```

- **When it stacks.** At `textScaler` at or above 2.0 it lays the label above the value; below
  that it keeps the one-line `spaceBetween` shape, so the shipped layout is byte-identical for
  every user who is not using a large text size. **This threshold is a decision, not a
  mechanic**: a row that stacks at every scale changes the default look, which is restyling this
  wave is not for. 2.0 is chosen because it is where a `Flexible` label starts to ellipsise in
  practice and because S-304 already uses it as the "large" probe.
- **No formatting, no domain logic.** It takes strings. It never calls `percentText`, never
  reads a `Bucket`, never touches a `Decimal`.
- **The four call sites are rewritten to use it in the same phase** — a shared widget beside
  four live copies is drift, not consolidation. Their rendered output below 2.0 is asserted
  identical by the existing suites (`screener_screen_test.dart`, `journal_row_test.dart`,
  `cycle_summary_card_test.dart`, `position_detail_sheet_test.dart`), which is the guard.

### D-65 — Haptics: Flutter's built-in, through one seam, with no dependency

**New file `lib/core/haptics/haptics.dart`:**

```dart
/// The injectable seam between the snapshot save (which decides *whether* a
/// bucket changed, D-66) and Flutter's own `HapticFeedback`. Built into the
/// framework, so this wave adds no dependency -- but it is still a seam, for
/// the same reason `NotificationGateway` and `ShareSheet` are: a test can
/// assert *that* the feedback fired, and a widget test cannot observe a real
/// vibration.
abstract class Haptics {
  /// A save that changed the bucket. Deliberately `mediumImpact`: noticeable
  /// confirmation, not `heavyImpact` (which reads as an alarm) and not
  /// `selectionClick` (which reads as a scroll tick).
  Future<void> bucketChanged();
}

class SystemHaptics implements Haptics {
  const SystemHaptics();
  @override
  Future<void> bucketChanged() => HapticFeedback.mediumImpact();
}

final hapticsProvider = Provider<Haptics>((ref) => const SystemHaptics());
```

- **`package:flutter/services.dart` is imported in exactly one file** — `haptics.dart`. A
  structural test asserts `HapticFeedback` appears in no other file under `lib/`, so no screen
  can quietly vibrate on its own (the same shape as Wave 3's pinned `showPaywall(` call sites).
- **The provider has a default**, unlike `wheelRepositoryProvider`. A haptic is presentation, and
  a missing override should mean "vibrate normally", not a crash. The test fake is a
  `ProviderScope` override, exactly as `FakePurchaseGateway` is.
- **`test/support/recording_haptics.dart`** (new) holds `RecordingHaptics implements Haptics`
  with a `List<String> calls` — it lives in `test/support/` because two suites need it: the
  sheet's (S-322…S-326) and Today's cross-screen liveness (S-331).
- **The real call is tested once**, in `test/core/haptics/haptics_test.dart`: `SystemHaptics().bucketChanged()`
  is asserted to send `HapticFeedback.mediumImpact` on `SystemChannels.platform`, so the seam's
  one concrete implementation is not the untested part.

### D-66 — The before/after comparison lives in the state layer

`PositionDetailController.updateSnapshot` (`lib/state/positions/position_detail_controller.dart:326`)
already has both halves: `state.bucket` before the append, and `state.bucket` after `await load()`
recomputes it. It gains:

```dart
/// True when the save that just completed changed this leg's bucket, and there
/// was a previous verdict to change from (D-67). Null means "no save has
/// happened in this controller's life, or the last one did not qualify" -- a
/// nullable field, not a bool, so "never" and "no change" cannot be confused.
final bool? lastSnapshotChangedBucket;
```

- **Set** at the end of `updateSnapshot`, in the same `copyWith` that sets `snapshotWarning`.
- **Cleared to `null` by `load()`**, exactly as `load()` clears `snapshotWarning` through
  `clearSnapshotWarning`. Without that, a rebuild after any `load()` could replay a stale `true`.
- **`updateSnapshot` keeps returning `bool`.** The sheet already reads `snapshotWarning` back
  through the provider after `ok` (`snapshot_sheet.dart:398`); reading the new flag the same way
  is the established pattern, and changing the return type would touch every caller and every
  test for no gain.
- **The comparison is `runtimeType` inequality**, the same rule `SnapshotPreview.changesBucket`
  already uses (`lib/domain/rules/snapshot_preview.dart:63`) — so the sheet's sentence and the
  haptic can never disagree about what "changed" means.
- **No widget computes it.** The sheet reads a state fact; it does not classify anything. The
  rules engine keeps its one caller discipline, and `lib/features/` gains no `classify()` call.

### D-67 — The firing rules, exhaustively

The haptic fires **exactly when all four hold**, and never otherwise:

1. the save succeeded (`updateSnapshot` returned `true`);
2. there **was a previous reading** (`state.snapshots` was non-empty before the append);
3. the bucket's `runtimeType` after the save differs from before it; and
4. the firing site is the save handler itself — once, immediately after the sheet's own
   `navigator.pop(true)`, never from a `build`, a `listen`, a `ref.watch` or a post-frame
   callback.

Consequences, each of which is a scenario:

| Case | Haptic? | Why |
|---|---|---|
| A save that moves a leg from `Leave` to `Close` | **yes** | The whole point; the sheet's own sentence ("This changes the bucket") promised it |
| A save whose numbers leave the bucket unchanged | no | Nothing changed; a buzz would be a lie |
| A save that updates only the captured % inside the same bucket | no | `runtimeType` is unchanged, by D-66's rule |
| **The first reading on a leg** (`No data` → `Close`) | **no** | `SnapshotPreview.changeLine` is deliberately suppressed when there is no previous reading (`snapshot_preview.dart:71`) — the sheet says nothing, so a buzz would be unexplained. This is a decision, not an oversight; see `## Open questions` |
| Loading a position, opening the sheet, the live preview changing as fields are typed | no | The preview *says* it would change; it does not save. Firing here would buzz on every keystroke |
| A save blocked by the credit bound (`record_trade_screen`'s hard reject path, `credit_bound.dart`) | no | `updateSnapshot` returns `false` before appending |
| A save rejected by the backdating range check | no | Same early return |
| A save that throws | no | The `catch` sets `snapshotError` and returns `false` |
| Record's first save for a brand-new leg | no | Record does not go through `updateSnapshot`, and there is no previous verdict anyway |
| A second save with the same numbers | no | Rule 3: `runtimeType` unchanged |
| A second save that changes the bucket again | **yes** | Each genuine change is its own feedback; this is not debounced |

**One firing site.** `lib/features/positions/snapshot_sheet.dart` is the only caller of
`hapticsProvider.bucketChanged()` in `lib/`, asserted by a structural test. Today's row and the
position detail sheet both open the *same* sheet through `showSnapshotSheet`, so the single site
covers all three entry points without a second one.

### D-68 — The contrast audit's scope and its two bars

- **Text: 4.5:1**, in both themes, for every foreground/background pair a screen actually paints.
  This is the brief's bar and `docs/conventions.md` §9's.
- **A non-text UI component that conveys state: 3:1** (WCAG 1.4.11), in both themes. Exactly one
  component in the app qualifies: the paywall's unselected plan indicator
  (`paywall_screen.dart:315`, `Icons.radio_button_unchecked` painted `scheme.outline` on
  `scheme.surface`). It is the only non-text element whose colour carries information that no
  other element repeats — the selected indicator is `scheme.primary`, and the *selected* card's
  own border is `scheme.primary` too.
- **Dividers and decorative card borders are exempt, deliberately.** `scheme.outlineVariant` is
  the divider token (`t.divider`: `#243030` dark, `#DCE5E5` light) and is used as
  `share_card.dart:63`, `:246`, `past_expiration_card.dart:107`, `portfolio_screen.dart:460`,
  `:594`, `paywall_screen.dart:304` and `app_bottom_nav.dart:38`. A divider is not "required to
  identify a component or state" — the card's own background already separates it, and the
  selected card is marked by `scheme.primary` on two surfaces. Requiring 3:1 of the divider
  token would force a hairline that reads as a rule, which is restyling. **This exemption is
  pinned so the audit is bounded and so a later reviewer can challenge it by name.**
- **The audit's method is the pair table, not an eye.** Every pair is computed from the theme's
  own tokens in a pure-Dart test (D-70), so the audit is reproducible on any machine and the
  result is a number, not an opinion. `docs/design/pro-ui-reference.html` is non-binding intent
  and was not used as a source of ratios.
- **What the audit found.** Twelve of the fourteen text pairings in play already clear 4.5:1 in
  both themes; the existing S-219 table covers nine of them. The one genuine failure is D-69.
  Two pairs that look like failures are not pairs any screen paints and are recorded here so a
  later reader does not re-litigate them: `accent` on `accentContainer` in the light theme
  (3.91:1) and `error` on `errorContainer` in the light theme (4.11:1) — the containers' own ink
  roles are `onAccentContainer` (5.29:1) and `onErrorContainer` (5.69:1), and those are what
  every screen paints.

### D-69 — The one colour value that changes

**`AppTokens.dark.outline` and `AppTokens.light.outline` must clear 3:1 against both `surface`
and `raised` in their own theme.** They do not today:

| Pair | Today | Bar |
|---|---|---|
| `outline` on `surface`, dark | `#404E4E` on `#171F1F` = **1.93:1** | 3:1 |
| `outline` on `surface`, light | `#A3B4B4` on `#FFFFFF` = **2.15:1** | 3:1 |

- **What it breaks.** The paywall's unselected radio indicator is invisible to a user with low
  vision; the checked one is not. That is a state a user cannot read.
- **The value is the implementer's; the requirement is not.** Any value that clears 3:1 against
  both `surface` and `raised` in both themes, while still reading as a hairline rather than as
  text, is correct. The new value is guarded by S-321, which fails on a later palette edit.
- **No other token changes**, and `scheme.outline` has exactly **one** reader in
  `lib/features/` (`paywall_screen.dart:315`) plus M3's own defaults for `OutlinedButton` and
  `InputDecorator` — which only improve. `grep -rn "scheme\.outline\b" lib/` is the Impact
  Check's proof and returns that one line.
- **No golden changes.** `scheme.outline` appears in neither golden's surface: the bucket badge
  golden paints `BucketPalette` fills and `pillEdge`, and the share card golden paints
  `outlineVariant` and the token text roles. If a golden *does* move, that is a finding for the
  reviewer, not a baseline to regenerate (D-71).

### D-70 — The S-219 guard grows in two directions

`test/core/theme/app_theme_contrast_test.dart` (S-219) stays the permanent guard and gains:

1. **The screen-pairing table.** Its 15 pairs are "the pairs the design table documents a ratio
   for"; the wave adds every pair a screen actually paints that the table does not already
   cover — `accent on card`, `accent on raised`, `accent on background` (already), `caution on
   raised`, `error on raised`, `muted on raised` (already), and the paywall's `outline on
   surface` / `outline on raised` at the 3:1 bar. The pair list stays one list, in one file, so
   a later palette edit fails there rather than in review.
2. **A structural role guard.** A test reads every `scheme.<role>` occurrence in `lib/` and
   asserts each role is in an `_auditedRoles` allow-list that names the pair(s) it is audited
   in. A new role read in a screen therefore **fails the test until it is added to the table** —
   which is the only way this guard keeps working once Stage 6 lands. Today the list is the 14
   roles in the ground-truth table above; `_auditedRoles` is the mechanism, the current 14 are
   its first content.

**The guard is pure Dart and deterministic** — no widget, no golden, no font. It computes WCAG
relative luminance and the ratio from `Color` values, exactly as the existing `_luminance`,
`_contrast` and `_lStar` helpers do, and asserts the L\* ordering of the four bucket fills
(88/75/61/45) is preserved. Nothing about S-219's existing assertions is relaxed.

### D-71 — Goldens: none added, and a moved golden is a finding

- **No new golden.** Everything this wave asserts is assertable: a label is a string, a ratio is
  a number, an overflow is an exception, a haptic is a recorded call. A golden would add a
  Mac-only baseline and prove nothing those four do not.
- **The two existing goldens must be unchanged**: `test/features/goldens/bucket_badge_golden_test.dart`
  and `test/features/goldens/share_card_golden_test.dart`. Neither surface paints
  `scheme.outline` (D-69), and neither is touched by the semantics work (a `Semantics` node
  paints nothing).
- **If one moves, it is a finding.** The reviewer compares it to the Predicted Files list; a
  golden that changed without a corresponding `lib/` change in the diff is a baseline edit, and
  the fix is to revert it and find what painted differently.

### D-72 — Stage 6's forward contract: a written obligation, not a scaffold

Stage 6 (screenshot scan) is not planned and nothing is built for it. What this wave leaves
behind is the obligation, written in two places that a Stage 6 planner already reads:

1. **`docs/architecture/wheel-triage.md` gains an accessibility section** naming the harness,
   `kMaxTextScale`, `LabelValueRow`, `Haptics`, the S-219/S-321 pair table and the structural
   guards, with the sentence: *a new screen is audited by adding a row to
   `auditedSurfaces`; the route-coverage test fails until it has one.*
2. **`docs/conventions.md` §9 gains the paths** — the harness file, `kMaxTextScale`, and the
   truncation ban's structural guard. §9's substance does not change; it is already standing
   policy from Wave 1, and this wave adds the mechanism it was always describing.

The harness's route-coverage test (D-60) is the enforcement, and it is the reason a Stage 6
screen cannot ship unaudited: a new `GoRoute` in `lib/core/app_router.dart` fails the test until
it has an `AuditedSurface` row, and a row with no `expectedLabels` is visible in the diff.
**No Stage 6 route, screen, placeholder, feature flag or "ready for" abstraction is created.**

### D-73 — Owner checks block the wave, not a phase

The brief's §8 says the checks marked **(owner)** are recorded in the wave's plan. This wave has
three, all in Phase 6 and repeated in `## Open questions`:

- VoiceOver on a physical iPhone, every screen, at the largest accessibility text size (S-333).
- The bucket-change haptic on a physical iPhone (S-333).
- Both themes on a physical device, at the largest text size (S-333).

They are `(owner)` items: **a phase reports complete without them, and the wave's Status stays
`DRAFT — active` until they are recorded.** They cannot be run by an agent — a simulator's
VoiceOver and a Mac's vibration are not the device's — and pretending otherwise is how an
accessibility wave passes its own tests while failing its user.

### D-74 — Pinned exclusions

- **No new dependency.** `pubspec.yaml` is untouched. `HapticFeedback` is Flutter's own.
- **No schema change.** `AppDatabase.schemaVersion` stays 6; no `drift_schema_v7.json`; no
  migration test; `dart run build_runner build` is not needed.
- **No new colour token, and no colour literal anywhere new.** The
  `grep -rnE "(^|[^A-Za-z])Colors\.|Color\(0x" lib/ --include='*.dart' | grep -v lib/core/theme/`
  guard stays empty; `lib/widgets/label_value_row.dart` paints nothing.
- **No restyling.** The only layout change is `LabelValueRow`'s stack at ≥2.0 (D-64), and the
  only token change is D-69's.
- **The four hand-rolled percentage sites stay.** `journal_row.dart:47` (inline),
  `cycle_summary_card.dart:136` (`_pct`), `screener_screen.dart:395` (`_pctText`),
  `roll_planner_screen.dart:103` (inline). Three of those files are edited by this wave for
  labels, which makes the consolidation tempting — but they do not all use the same precision, so
  it is a display change, not a consolidation. The architecture doc's existing "observation, not
  a work item" row stays as written.
- **SnackBars are exempt** from the number-label audit (D-60), and remain subject to the
  truncation ban.
- **`lib/domain/rules/` is not touched by this wave at all.** No gate, no threshold, no
  formatter, no `classify()`, no `SnapshotPreview` change — the preview's `changesBucket` is read
  as it is. `grep -rl "package:flutter" lib/domain/rules/` returning nothing is therefore a
  formality here, and it is still run on every phase.

## Feature Invariants

Only the invariants that *bite* in this wave. Project-wide rules live in `docs/conventions.md`
and are referenced, not copied.

1. **The rules engine is untouched.** `lib/domain/rules/` gains no file, no function and no
   change. Its purity check (`grep -rl "package:flutter" lib/domain/rules/` → nothing) is run on
   every phase anyway, because a wave about widgets is exactly when the boundary gets crossed by
   accident.
2. **No `double` reaches a gate, and this wave adds no arithmetic at all.** The one new
   computation is a `runtimeType` comparison (D-66). No money, no percentage, no threshold is
   computed in a widget or a test helper.
3. **A bucket verdict is never rendered without its reason.** The wave touches every screen that
   shows a bucket; none of them may gain a path where the badge or the count appears alone. The
   `Bucket` sealed class makes it a compile error, and S-317's truncation ban protects the
   reason's readability at large text.
4. **`lib/core/theme/app_theme.dart` stays the only place a colour value is written.** The
   colour-literal grep stays empty, including in the new widget and the new test support file.
5. **A container role is derived from the table's tokens, never invented.** D-69 changes an
   existing token's *value*; it adds no role, and no screen gains a role the design table does
   not define.
6. **Every number's label names its quantity, and the audit is table-driven.** A screen with a
   number and no label fails `screen_a11y_test.dart` by name, not by review.
7. **Nothing is truncated at any text scale.** `TextOverflow.ellipsis` is banned wherever a
   number or a bucket reason can appear (D-63), and the ban is a test, not a convention.
8. **The comparison that decides the haptic is in the state layer.** `lib/features/` never calls
   `classify()` and never compares two `Bucket`s; it reads `lastSnapshotChangedBucket`.
9. **`HapticFeedback` is called in exactly one file.** `lib/core/haptics/haptics.dart`. A
   structural test pins it, so no screen can vibrate on its own.
10. **The haptic fires on a genuine change only** (D-67). Never on load, never on a build, never
    on the preview, never on a failed or blocked save, never on the first reading, never on an
    unchanged save.
11. **Tone is enforced, not reviewed.** The wave adds essentially no user-facing copy — but it
    adds *labels*, which are user-facing strings read aloud. Every new label passes the §4
    banned-word grep, and no label pairs an action verb with a named security or with the user's
    own position.
12. **Repository parity is structural.** This wave adds **no** `WheelRepository` method, so
    parity is preserved trivially. `InMemoryWheelRepository` gains no method and no behaviour.
13. **No schema change, no new dependency, no network.** `schemaVersion` stays 6; `pubspec.yaml`
    is untouched; no surface this wave touches has a network user.
14. **Nothing already recorded changes.** The audit is presentation-only: no persisted value, no
    stored label, no notification text, no exported field is touched. The full migration suite
    and the export/import suites are green at closeout as the proof (S-332).

## Requirements

Each requirement maps to at least one scenario. "§4" refers to `docs/brief-pro.md` §4.

| # | Requirement | Source | Scenarios |
|---|---|---|---|
| R1 | Every screen renders at the largest accessibility text size without a layout exception | §4 Stage 4B | S-313, S-314 |
| R2 | Every number and bucket reason **wraps**, and is never truncated or ellipsised | §4 Stage 4B, conventions §9 | S-317, S-318 |
| R3 | Every number's VoiceOver label names the quantity | §4 Stage 4B, conventions §9 | S-315, S-316 |
| R4 | A missing value is spoken as "not available", never as a dash or a zero | conventions §9 (D-61) | S-316 |
| R5 | The audit is one table-driven mechanism, and a new route cannot ship without a row | D-60, D-72 | S-313, S-330 |
| R6 | The largest text size is one pinned constant | D-59 | S-314 |
| R7 | A save that changes the bucket plays a haptic, exactly once | §4 Stage 4B | S-322, S-331 |
| R8 | A save that does not change the bucket plays nothing | D-67 | S-323, S-335 |
| R9 | Loading, rebuilding, opening the sheet or typing in the preview plays nothing | D-67 | S-324 |
| R10 | The first reading on a leg plays nothing | D-67 | S-325 |
| R11 | A blocked, rejected or failed save plays nothing | D-67 | S-326 |
| R12 | The before/after comparison lives in the state layer and is asserted without a widget | D-66 | S-327 |
| R13 | The haptic is Flutter's built-in, through one seam, with no dependency | D-65 | S-328 |
| R14 | Every text pair a screen paints clears 4.5:1 in both themes | §4 Stage 4B, conventions §9 | S-319 |
| R15 | A new `scheme.<role>` read cannot arrive unaudited | D-70 | S-320 |
| R16 | A state-conveying non-text component clears 3:1 in both themes | D-68 | S-321 |
| R17 | The two existing goldens are unchanged, and no golden is added | D-71 | S-329 |
| R18 | The four label/value row copies collapse into one widget with identical output below 2.0 | D-64 | S-318 |
| R19 | A new screen's accessibility obligation is written down for Stage 6 | D-72 | S-330 |
| R20 | The owner checks are recorded as `(owner)` items and block wave closure, not a phase | §8, D-73 | S-333 |
| R21 | Tone holds: no banned word in any new label, and no label pairs an action with a position | conventions §4 | S-334 |
| R22 | No schema change, no new dependency, no network, and nothing already recorded changes | D-74 | S-332, P6 residue sweep |

## Existing-Functionality Impact

Every row carries the grep that found its readers. A row may not read "unaffected" without one.
Line numbers are from the tree at the time of writing (baseline `flutter test` 1076 passed).

| Touched surface | What already reads it (grep) | Effect of this change | Guarded by |
|---|---|---|---|
| `lib/features/today/today_screen.dart` | `test/features/today/today_screen_test.dart` (pumps it), `test/state/entitlements/nothing_locks_test.dart`, `test/features/paywall/paywall_entry_points_test.dart`, `lib/core/app_router.dart:57` (the `/positions` route), `lib/features/export/export_reminder_banner.dart` (hosted at `:119`) | Three ellipsis sites go (`:263` the count chip's label, `:436` `_LedgerTile`'s label, `:443` **`_LedgerTile`'s money value**); the ledger tiles, the count chips and the row's reading line gain labels (D-61); the "Committed now" tile keeps its `onTap`; `_Row:515` is the position row and is **not** a `LabelValueRow` (it is a ticker, a contract, a badge and a reason) | S-313, S-315, S-317, S-331 + the existing suite green |
| `lib/features/portfolio/portfolio_screen.dart` | `test/features/portfolio/portfolio_screen_test.dart` (S-304 group at `:623`, its 2.0 probe at `:625`), `lib/features/today/today_screen.dart` (`context.push('/portfolio')`), `test/features/paywall/paywall_entry_points_test.dart` | `:565`'s bucket label stops ellipsising; the five existing `Semantics(` nodes are **unchanged**; the committed total, the bars, the delta, the count tiles and the obligation rows keep their current wording. **S-304's five assertions are the pre-existing pattern this wave generalises and must stay green without an edit** — if S-304 needs changing, the wave has reworded a label it should not have | S-315, S-317 + S-304 green unchanged |
| `lib/features/journal/journal_screen.dart` | `test/features/journal/*`, `lib/widgets/app_bottom_nav.dart` (the `/journal` path), `lib/features/journal/share_card_screen.dart` (pushed from `:98`) | `_stat:163` collapses into `LabelValueRow`; `:168`'s ellipsis goes; the aggregate figures gain labels; the cycle summary sheet's figures gain labels | S-315, S-318 + `test/features/journal/*` green |
| `lib/widgets/journal_row.dart` | `lib/features/journal/journal_screen.dart`, `test/widgets/journal_row_test.dart` | Two figures gain labels. **`_pct`/`_pctText`-style formatting is not touched** (D-74); the row's own strings are unchanged | S-315 + `journal_row_test.dart` green |
| `lib/widgets/cycle_summary_card.dart` | `lib/features/positions/position_detail_sheet.dart`, `lib/features/journal/journal_screen.dart`, `test/widgets/cycle_summary_card_test.dart` | `_row:120` collapses into `LabelValueRow` (the `emphasize` variant); `:126`'s ellipsis goes; the two figures gain labels | S-315, S-318 + `cycle_summary_card_test.dart` green |
| `lib/features/positions/position_detail_sheet.dart` | `test/features/positions/position_detail_sheet_test.dart`, `test/features/help_coverage_test.dart` (two chip groups at `:69`, `:101`), `lib/core/app_router.dart:64`, `lib/features/today/today_screen.dart` (`context.push('/positions/${leg.id}')`) | `_Row:284` collapses into `LabelValueRow` (the `trailing` variant); `:333`'s ellipsis goes; the eight figures gain labels; the fees sheet and the two confirm dialogs join the harness table. The five `HelpChip`s stay their own nodes (D-62) | S-313, S-315, S-318 + `help_coverage_test.dart` green |
| `lib/features/positions/snapshot_sheet.dart` | `test/features/positions/snapshot_sheet_test.dart`, `lib/features/today/today_screen.dart:575`, `lib/features/positions/position_detail_sheet.dart:42` | The save handler gains the **only** `hapticsProvider.bucketChanged()` call in `lib/`, guarded by the flag read back through the provider exactly as `snapshotWarning` is at `:398`; the preview's figures gain labels; the sheet joins the harness table. `showSnapshotSheet` still completes `true` only on a real save | S-315, S-322, S-331 + the existing suite green |
| `lib/state/positions/position_detail_controller.dart` | `test/state/positions/position_detail_controller_test.dart`, `test/state/positions/position_detail_close_test.dart`, `test/state/entitlements/nothing_locks_test.dart`, `test/features/positions/*` | **Additive**: `PositionDetailState.lastSnapshotChangedBucket` (a nullable `bool`), set in `updateSnapshot`'s final `copyWith` and cleared by `load()`. `updateSnapshot` still returns `bool`; no existing field, warning, error or loading flag changes; `closeDirect`, `assign` and `roll` are untouched | S-327, S-323, S-324, S-335 + `test/state/positions/*` green |
| `lib/core/theme/app_theme.dart` | every screen (`Theme.of`), `test/core/theme/app_theme_contrast_test.dart` (S-219), `test/features/goldens/bucket_badge_golden_test.dart`, `test/features/goldens/share_card_golden_test.dart` | **Unchanged (A-1 supersedes D-69):** no token value changes, `outline` included. `grep -rn "scheme\.outline\b" lib/` returns **0** readers — the paywall's indicator repaints instead — and `outline` stays in `_auditedRoles` as "no longer painted anywhere" so a later reader cannot drop the record silently. The L\* ordering 88/75/61/45 is untouched | S-319, S-321, S-329 |
| `test/core/theme/app_theme_contrast_test.dart` | itself, and `docs/conventions.md` §9 cites S-219 as the permanent guard | The pair table gains the screen pairs; the structural `_auditedRoles` check is added. **No existing assertion is relaxed or removed** — the 15 pairs and the bucket checks stay exactly as written | S-319, S-320 |
| `lib/features/paywall/paywall_screen.dart` | `test/features/paywall/paywall_screen_test.dart`, `test/features/paywall/paywall_entry_points_test.dart`, `test/core/purchases/paywall_copy_test.dart`, `lib/features/settings/pro_plan_section.dart` | **A-1 supersedes D-69:** the unselected radio indicator's 3:1 bar is met by a one-line edit here (`scheme.onSurfaceVariant`, 7.32:1 dark / 6.24:1 light), not by a token change; the four existing `Semantics(` nodes are unchanged; the screen joins the harness table. `kPaywallFeatures` and every copy string are untouched | S-321, S-313, S-315 + the paywall suites green |
| `lib/features/screener/screener_screen.dart` | `test/features/screener/screener_screen_test.dart`, `test/features/help_coverage_test.dart` (14 topics at `:39`), `test/state/screener/*` | `_OutputRow:348` collapses into `LabelValueRow`; `:366`'s ellipsis goes; the eight figures gain labels. `_GateChip:378` and its `primaryContainer`/`errorContainer`/`raised` backgrounds are **unchanged** (all three pairings already clear 4.5:1 — D-68) | S-315, S-317, S-318 + the screener suites green |
| `lib/features/record/record_trade_screen.dart` | `test/features/record/record_trade_screen_test.dart`, `test/features/help_coverage_test.dart` (10 topics at `:173`), `test/state/record/*` | The two existing labels at `:417` and `:424` are **the style the rest adopts and are not reworded**; the remaining figures gain labels. The `creditBound` message line's colour roles (`error`/`tertiary` on `surface`) are unchanged and already clear 4.5:1 | S-315 + the record suites green |
| `lib/features/roll/roll_planner_screen.dart` | `test/features/roll/roll_planner_screen_test.dart`, `test/state/roll/*` | **No labels were added and the file is untouched** (A-16): its five figures already arrive as single rendered strings that name their quantity, so a wrapper would add a duplicate node and break D-62. The two dialogs and the date picker join the harness table. The debit-roll line at `:108` keeps its wording, its `isDebit` branch and its `error`/`primary` roles (both clear 4.5:1 on `surface`); `_pct`-style formatting is untouched (D-74) | S-315, S-313 + the roll suites green |
| `lib/features/assignment/assignment_flow_screen.dart` | `test/features/assignment/assignment_flow_screen_test.dart`, `test/features/help_coverage_test.dart` (the `wheel_basis` chip group at `:141`) | **No labels were added** (A-16): the shipped strings already name their quantity. The date picker joins the harness table; the `wheelBasis` chip stays its own node | S-315, S-313 + the existing suite green |
| `lib/features/settings/settings_screen.dart`, `rule_profile_section.dart`, `pro_plan_section.dart` | `test/features/settings/*` (`settings_screen_test.dart`, `rule_profile_editor_test.dart`, `pro_plan_section_test.dart`) | **No labels were added and the three files are untouched** (A-16): the shipped copy already names every figure. The "Replace everything?" dialog joins the harness table. The two `SnackBar`s (`settings_screen.dart:90`, `rule_profile_section.dart:118`) are exempt (D-60) and their copy is unchanged; the `kAppDisclaimer` block at `:248` is untouched | S-315, S-313 + the settings suites green |
| `lib/features/journal/share_card.dart`, `share_card_screen.dart` | `test/features/journal/share_card_screen_test.dart`, `test/domain/rules/share_card_test.dart`, `test/features/goldens/share_card_golden_test.dart`, `test/support/share_card_fixtures.dart` | Two figures gain labels; the screen joins the harness table. `share_card.dart:63`'s `outlineVariant` border is a decorative card border and is exempt (D-68). The golden must not move (D-71) | S-315, S-329 + the share-card suites green |
| `lib/features/onboarding/first_run_explainer.dart` | `test/features/onboarding/first_run_explainer_test.dart`, `test/core/disclaimer_test.dart`, `lib/core/app_router.dart:56`, `lib/main.dart` (the fresh-install `initialLocation`) | **Copy only, no number.** The screen joins the harness table for the no-overflow assertion alone. `kAppDisclaimer` is untouched and still verbatim | S-313, S-332 + the onboarding suite green |
| `lib/features/export/export_reminder_banner.dart` | `lib/features/today/today_screen.dart:119`, `lib/widgets/app_bottom_nav.dart:8` (a doc mention), `test/features/export/export_reminder_banner_test.dart` | **Unchanged.** The banner is a sentence with no number; it is audited through Today's row | S-313 |
| `lib/widgets/bucket_badge.dart` | `lib/features/today/today_screen.dart`, `lib/features/portfolio/portfolio_screen.dart`, `lib/features/positions/*`, `test/widgets/bucket_badge_test.dart`, `test/features/goldens/bucket_badge_golden_test.dart` | **Unchanged.** The badge's `Semantics(label:)` at `:74` stays; its reason already wraps (no `maxLines`). It is the widget the truncation ban protects, and it is the reason the ban is structural rather than a one-off fix | S-317, S-329 + both badge suites green |
| `lib/widgets/help_chip.dart` | `lib/features/*` (every screen with a chip), `test/features/help_coverage_test.dart`, `test/widgets/help_chip_test.dart` | **Unchanged.** The chip's `Semantics(label: 'Help: ...', button: true)` at `:23` stays its own node (D-62); the help sheet it opens joins the harness table | S-313 + both chip suites green |
| `lib/core/app_router.dart` | `lib/main.dart:34`, `test/widget_test.dart`, 8 feature suites that pump a route | **Unchanged.** The harness's route-coverage test *reads* it, which is what makes a new route owe a table row (D-60) | S-330 |
| `lib/state/export/export_controller.dart` (`ShareSheet`) | `lib/features/settings/settings_screen.dart`, `lib/features/journal/share_card_screen.dart`, `test/features/settings/settings_screen_test.dart` | **Unchanged.** `Haptics` is a second seam of the same shape, not a change to this one | S-328 |
| `lib/data/db/app_database.dart:41` (`schemaVersion`) | every migration test, `test/data/db/*` | **Unchanged at 6.** No table, column or seed change; no `drift_schema_v7.json`; `build_runner` is not needed by this wave | S-332 + P6 residue sweep |
| `docs/conventions.md` §9 | every agent, by path | Gains the harness path, `kMaxTextScale` and the truncation guard's location. **No rule is relaxed**; §9's substance is unchanged | Phase 6 |
| `docs/architecture/wheel-triage.md` | the whole repo (the architecture index) | Gains an accessibility section and two drift-risk rows: the label/value row's five old copies, and the harness table's route coverage | Phase 6 |

**A-1 supersedes D-69's wording:** the two rows above describe the governor's override — the `outline` token did not change and the paywall's indicator repaints instead.

## Scenarios

IDs continue from **S-313** (Wave 3 ends at S-312) and are stable and never reused. Fixtures are
enumerated, not described: if a fixture cannot be listed, the scenario is underspecified and is
fixed here rather than left to an implementer.

**A note on the reference.** `docs/design/pro-ui-reference.html` is non-binding intent. Its one
accessibility statement — line 756, "Says when saving would change the bucket. A save that
changes it plays a haptic. Stage 4B" — is adopted. Its theme panel (`:485`–`560`) documents no
contrast ratio the theme does not already carry, and its radio indicator's colour is not a
specification of a ratio, so D-68's two bars are **authored here** rather than read out of the
reference. No expected value in this plan comes from the reference.

### S-313: Every audited surface survives the largest accessibility text size

- **Fixture**: for each of the 22 rows in D-60's table, a populated `InMemoryWheelRepository`
  built from the fixtures the existing suite for that surface already uses (Today's book from
  `today_screen_test.dart`, Portfolio's from `portfolio_screen_test.dart`'s `_bookFull()`, the
  screener's from `screener_screen_test.dart`, and so on), **plus** the empty variant for the six
  surfaces that have an empty state (Screener's blank form, Record's blank form, Journal with no
  cycles, Portfolio with no legs, Today with no legs, a leg with no reading). A `ProviderScope`
  overriding `wheelRepositoryProvider` and `purchaseGatewayProvider`; a
  `MaterialApp.router` built from `buildAppRouter(initialLocation: <the row's route>)`; a
  `builder` applying `TextScaler.linear(kMaxTextScale)`; `tester.view.physicalSize = Size(1000,
  4000)` so vertical clipping is not what is measured.
- **Trigger**: `auditSurface(tester, row, repo: repo)` for every row, in one `testWidgets` per
  row.
- **Flow**: the route settles; `row.open` runs where the row has one (the sheet, the dialog, the
  date picker); then the assertions run.
- **Expected outcome**: `tester.takeException()` is `null` for every row and every fixture — no
  `RenderFlex` overflow, no assertion. And for every row with `expectedLabels`, every
  `(quantity, value)` pair matches **one line** of one accessibility node.
- **Edge case of**: none — this is the wave's spine.

### S-314: The largest text size is one constant, and the suite has one of them

- **Fixture**: the `test/` tree.
- **Trigger**: a source scan for `TextScaler.linear(` and for `TextScaler` literals in `test/`.
- **Flow**: every occurrence is compared against the harness's own declaration.
- **Expected outcome**: exactly one `TextScaler.linear(` literal exists in `test/`, inside
  `screen_a11y_harness.dart`, and its argument is `kMaxTextScale`; `kMaxTextScale == 3.2`. The
  one pre-existing site, `portfolio_screen_test.dart:625`'s S-304 probe at 2.0, is either folded
  into the harness or left as a second, deliberately-lower probe — if left, the scan's
  allow-list names it and says why (2.0 is the "large but not maximal" probe, 3.2 is the ceiling).
- **Edge case of**: S-313.

### S-315: Every number's label names its quantity, on every surface

- **Fixture**: S-313's fixtures, one row at a time; the per-row `expectedLabels` from D-60's
  table, each pair authored from that surface's own rendered strings. Worked examples of the
  enumeration, one per number-heavy surface:
  - **Today** (`/positions`, the S-015 book): `('Capital committed now', '$2,400')`,
    `('Close', '1')`, `('Roll', '2')`, `('Assign', '0')`, `('Leave', '1')`,
    `('No data', '1')`, `('Delta', '0.25')`, `('Captured', '62.0%')`.
  - **Position detail** (`/positions/:legId`): `('Captured', '62.0%')`, `('Roll band', '0.35')`,
    `('One-sigma move', '$3.40')`, `('Extrinsic remaining', '$1.10')`,
    `('Cycle credit', '$240.00')`, `('Delta', '0.25')`, `('Strike', '$11.00')`,
    `('DTE', '45')`.
  - **Screener** (`/screener`, the form filled): `('Sorting score', '6')`,
    `('Annualised yield', '31.0%')`, `('One-sigma move', '$4.20')`,
    `('Strike distance', '12.5%')`, `('IV rank', '48.0%')`, `('Capital committed', '$4,500')`.
  - **Roll planner** (`/positions/:legId/roll`): `('Net credit', '$0.45')`,
    `('Annualised yield on extended duration', '28.4%')`, `('New strike', '$12.00')`,
    `('New expiration', 'Nov 20')`, `('Shares', '100')`.
  - **Portfolio** (`/portfolio`): S-304's five, unchanged — the committed total, a concentration
    bar, the net position delta, a bucket count, and an obligation row.
- **Trigger**: `auditSurface` per row, then a same-line match per expected pair (D-61).
- **Flow**: each pair is searched for on a single line of a single node, as
  `anyLineMatches(labels, RegExp('<quantity>.*<value>'))`.
- **Expected outcome**: every pair matches on one line. A quantity name present only as a
  separate child line does **not** satisfy the assertion — that is the case a naive
  `labels.any((l) => l.contains('Delta'))` would pass and this one fails.
- **Edge case of**: S-313.

### S-316: A missing value is spoken as "not available"

- **Fixture**: three readings-free states in one book: a leg with no snapshot (so captured %,
  delta, IV, extrinsic and one-sigma are all absent), the screener with its form blank, and
  Record with only a ticker typed.
- **Trigger**: `auditSurface` on those three rows.
- **Flow**: the traversal is searched for a label line containing `--`.
- **Expected outcome**: no node's label contains `--`; the corresponding labels read
  `... not available` (the `record_trade_screen.dart:417` form). A label containing `0` where the
  screen renders `--` also fails: an absent value is absent, not zero.
- **Edge case of**: S-315.

### S-317: Nothing that can carry a number or a reason is truncated

- **Fixture**: the `lib/` tree, and S-313's fixtures for the runtime half.
- **Trigger**: (a) a source scan of `lib/` for `TextOverflow.ellipsis` and
  `TextOverflow.clip`; (b) `auditSurface` on the four surfaces whose ellipsis sites this wave
  clears.
- **Flow**: the scan's hits are compared against a pinned allow-list that names a file, a line
  and the reason the site cannot carry a number or a reason; the runtime half asserts no
  exception at 3.2.
- **Expected outcome**: the scan finds **nothing** in `lib/features/` or `lib/widgets/` — all
  eight sites are cleared and the allow-list is empty. Every bucket reason on Today, Portfolio,
  the detail sheet and the badge renders in full at 3.2 (asserted by the absence of an
  `ellipsis`, and by the reason's full text being findable as a widget: `find.text(reason)`
  succeeds, which an ellipsised `Text` also satisfies — so the scan is the real guard and the
  runtime assertion is the corroboration).
- **Edge case of**: S-313.

### S-318: The one label/value row, and its four old copies

- **Fixture**: one `LabelValueRow` per call shape — a plain one (`Journal`'s `_stat`), one with a
  `helpTopicId` (the screener's `_OutputRow`), one with `trailing` (the detail sheet's `_Row`),
  one with `emphasize` (`cycle_summary_card`'s `_row`) — plus the four screens that host them.
  A long label and a long money value together (`Extrinsic remaining` / `$1,234.56`).
- **Trigger**: pump each at `TextScaler.linear(1.0)`, `1.5`, `2.0`, `2.5`, `kMaxTextScale`.
- **Flow**: measure the row's laid-out height and its children's positions at each scale.
- **Expected outcome**: below 2.0 the label and the value share a line and the row's output is
  identical to the shipped shape (the four existing suites are the proof, plus a golden-free
  position assertion); at and above 2.0 the value sits **below** the label, both render in full,
  and no exception is thrown. No `TextOverflow.ellipsis` exists anywhere in
  `label_value_row.dart`.
- **Edge case of**: S-317.

### S-319: Every text pair a screen paints clears 4.5:1 in both themes

- **Fixture**: `darkTheme` and `lightTheme` from `lib/core/theme/app_theme.dart`, and the pair
  list D-70 defines: the 15 existing pairs plus `accent on card`, `accent on raised`,
  `caution on raised`, `error on raised`, and the `tertiary`-on-`surface` variant the cycle
  summary card paints at `:72`.
- **Trigger**: `_contrast(foreground, background)` per pair per theme, as the existing test does.
- **Flow**: WCAG relative luminance, then `(L1 + 0.05) / (L2 + 0.05)`.
- **Expected outcome**: every pair ≥ 4.5 in both themes, with the ratio in the failure message.
  The four bucket fills' L\* ordering (88/75/61/45) is asserted unchanged, and the bucket
  ink/fill pairs are asserted as they are today.
- **Edge case of**: S-219 (extends it; relaxes nothing).

### S-320: A new role read cannot arrive unaudited

- **Fixture**: the `lib/` tree, and `_auditedRoles` in the contrast test.
- **Trigger**: a source scan extracting every `scheme.<role>` occurrence under `lib/`.
- **Flow**: each extracted role is looked up in `_auditedRoles`, which maps a role to the pair(s)
  it is audited in.
- **Expected outcome**: no role is missing. Adding `scheme.someNewRole` to any file under `lib/`
  fails the test until the role is added to `_auditedRoles` **and** to the pair list. The current
  14 roles (`onSurfaceVariant`, `onSurface`, `surface`, `outlineVariant`, `primaryContainer`,
  `primary`, `onPrimaryContainer`, `error`, `tertiary`, `surfaceContainerHighest`, `outline`,
  `onPrimary`, `errorContainer`, `onErrorContainer`) are the first content, and `outlineVariant`
  carries the D-68 exemption as its audit note rather than being silently absent.
- **Edge case of**: S-319.

### S-321: The unselected plan indicator is visible in both themes

- **Fixture**: `darkTheme`, `lightTheme`, and the paywall's plan cards on `scheme.surface`.
- **Trigger**: `_contrast(scheme.outline, scheme.surface)` and
  `_contrast(scheme.outline, scheme.surfaceContainerHighest)` in both themes.
- **Flow**: the same ratio computation as S-319, at the 3:1 bar.
- **Expected outcome**: ≥ 3.0 in all four combinations, where today the two `surface` pairs are
  1.93 (dark) and 2.15 (light). The failure message names the pair and the ratio, so a later
  palette edit fails here rather than in review. **No other token's value changes** — asserted by
  the rest of S-219's suite being green without an edit.
- **Edge case of**: S-319.

### S-322: A save that changes the bucket plays the haptic, exactly once

- **Fixture**: a leg with one reading whose numbers put it in `Leave`; a second reading's numbers
  that put it in `Close` (per `classify()`, not by assertion — the fixture names the entered
  mark, spot and delta, and the scenario asserts the resulting `runtimeType`s). A
  `ProviderScope` overriding `wheelRepositoryProvider` and `hapticsProvider` with
  `RecordingHaptics`.
- **Trigger**: open the snapshot sheet from Today's row, enter the second reading, press **Save
  snapshot**.
- **Flow**: `updateSnapshot` appends, `load()` reclassifies, the sheet reads
  `lastSnapshotChangedBucket`, the sheet pops `true`, and the haptic is played.
- **Expected outcome**: `RecordingHaptics.calls.length == 1`; the sheet closed; Today's row shows
  the new bucket; `lastSnapshotChangedBucket == true`.
- **Edge case of**: none.

### S-323: A save that does not change the bucket plays nothing

- **Fixture**: as S-322, but the second reading's numbers move the captured % inside `Close`
  without leaving it — e.g. mark `0.10` then `0.12` with the same spot and delta.
- **Trigger**: the same save.
- **Flow**: the same path.
- **Expected outcome**: `RecordingHaptics.calls` is empty; `lastSnapshotChangedBucket == false`;
  the saved snapshot is present and its captured % is the new one (the absence of a haptic is not
  a failed save).
- **Edge case of**: S-322.

### S-324: Loading, opening the sheet, and typing in the preview play nothing

- **Fixture**: as S-322.
- **Trigger**: (a) pump Today and settle; (b) open the snapshot sheet and settle; (c) type the
  changing numbers into the sheet's fields, one keystroke at a time, without saving; (d) dismiss
  the sheet; (e) call `controller.load()` directly.
- **Flow**: each step is pumped and settled before the counter is read.
- **Expected outcome**: `RecordingHaptics.calls` is empty after every step. The sheet's preview
  **does** show the "This changes the bucket" line during (c) — the sentence and the haptic are
  deliberately different events, and the scenario asserts both: the line is present, the counter
  is zero.
- **Edge case of**: S-322.

### S-325: The first reading on a leg plays nothing

- **Fixture**: a leg created through `createCycle` with **no** snapshot; its entered reading
  produces `Close`. `RecordingHaptics` overridden.
- **Trigger**: open the sheet from the leg's detail, enter the reading, save.
- **Flow**: as S-322.
- **Expected outcome**: `RecordingHaptics.calls` is empty; `lastSnapshotChangedBucket == false`
  even though the leg moved from `No data` to `Close`; the snapshot was saved and Today shows
  `Close`. The sheet's `changeLine` is `null` for the same save, which is the consistency this
  decision exists to hold (`snapshot_preview.dart:71`).
- **Edge case of**: S-322.

### S-326: A blocked, rejected or failed save plays nothing

- **Fixture**: three legs. (a) One whose entered mark trips the credit bound's hard reject
  (`checkCreditBound`); (b) one whose `takenAt` is before its open date; (c) one whose repository
  append throws (an `InMemoryWheelRepository` subclass or a throwing `appendSnapshot` override).
  `RecordingHaptics` overridden.
- **Trigger**: the save for each.
- **Flow**: `updateSnapshot` returns `false` before or during the append.
- **Expected outcome**: `RecordingHaptics.calls` is empty in all three; `snapshotError` is set and
  rendered; `lastSnapshotChangedBucket` is `null` or `false`, never `true`; no snapshot was
  appended.
- **Edge case of**: S-322.

### S-327: The comparison is a state fact, asserted with no widget

- **Fixture**: an `InMemoryWheelRepository` with a leg and one reading, driven through
  `ProviderContainer` — **no `pumpWidget` anywhere in this scenario**.
- **Trigger**: `container.read(positionDetailControllerProvider(legId).notifier).updateSnapshot(...)`
  with (a) numbers that change the bucket, (b) numbers that do not, (c) numbers for a leg with no
  prior reading.
- **Flow**: read `state.lastSnapshotChangedBucket` after each call; then call `load()` and read it
  again.
- **Expected outcome**: (a) `true`; (b) `false`; (c) `false`; and after `load()` it is `null` in
  all three cases. A grep-based structural assertion also holds: no file under `lib/features/`
  contains a `Bucket` `runtimeType` comparison or a `classify(` call — the widget layer reads the
  flag, it does not compute it.
- **Edge case of**: S-322.

### S-328: One seam, one file, no dependency

- **Fixture**: the `lib/` tree, `pubspec.yaml`, and `test/core/haptics/haptics_test.dart`.
- **Trigger**: (a) a source scan for `HapticFeedback` under `lib/`; (b) a scan for
  `hapticsProvider.bucketChanged` under `lib/`; (c) `pubspec.yaml`'s dependency diff; (d) a call
  to `SystemHaptics().bucketChanged()` with the platform channel mocked.
- **Flow**: (a) and (b) count files; (d) records the `SystemChannels.platform` invocation.
- **Expected outcome**: `HapticFeedback` appears in exactly one file, `lib/core/haptics/haptics.dart`;
  `hapticsProvider.bucketChanged()` is called in exactly one file,
  `lib/features/positions/snapshot_sheet.dart`; `pubspec.yaml` is unchanged from the baseline
  (no line added, none removed, no version moved); and (d) sends exactly one `mediumImpact`
  invocation on the platform channel.
- **Edge case of**: S-322.

### S-329: No golden is added, and neither existing golden moves

- **Fixture**: `test/features/goldens/bucket_badge_golden_test.dart` and
  `test/features/goldens/share_card_golden_test.dart` as they are.
- **Trigger**: the golden suite, run on the Mac.
- **Flow**: comparison against the committed PNGs.
- **Expected outcome**: both suites pass with **no baseline file changed in the diff**. A
  `*.png` in the Predicted Files list is a finding (D-71). The `test/features/goldens/`
  directory gains no new file.
- **Edge case of**: S-321.

### S-330: A new route cannot ship unaudited

- **Fixture**: `lib/core/app_router.dart`, and `auditedSurfaces` in the harness.
- **Trigger**: a source scan extracting every `GoRoute(path: '<literal>')` fragment from the
  router.
- **Flow**: each fragment is searched for in `auditedSurfaces`' route strings.
- **Expected outcome**: every fragment is covered — today `'/screener'`, `'/record'`, `'/journal'`,
  `'share'`, `'/portfolio'`, `'/settings'`, `'/first-run'`, `'/paywall'`, `'/positions'`,
  `':legId'`, `'roll'`, `'assign'`. The failure message names the uncovered fragment. A
  **negative** fixture proves the guard bites: a temporary router file with an extra
  `GoRoute(path: '/stage-6')` fails the test (asserted by scanning a string fixture, not by
  editing the real router).
- **Edge case of**: none — this is the Stage 6 forward contract (D-72).

### S-331: Cross-screen liveness, and the haptic still fires once

- **Fixture**: a book with two open legs on the same underlying, a `RecordingHaptics`, and a
  repository shared by all three surfaces.
- **Trigger**: save a bucket-changing reading through the sheet opened from Today's row.
- **Flow**: pop back to Today, then push Portfolio and the position detail sheet.
- **Expected outcome**: all three show the new bucket and its reason (one classification, three
  views — nothing is cached); the count tiles on Today and Portfolio both move by one between the
  two buckets; `RecordingHaptics.calls.length == 1` across the whole flow — navigating, rebuilding
  and re-reading do not add calls.
- **Edge case of**: S-322.

### S-332: Nothing already recorded changes

- **Fixture**: the full `test/data/` tree — `wheel_repository_contract_test.dart`, every
  `test/data/db/*_migration_test.dart`, `test/data/export/*`, `test/domain/models/*`.
- **Trigger**: the full suite at closeout.
- **Flow**: nothing.
- **Expected outcome**: every migration, contract, export/import and model suite is green with no
  test edited by this wave; `AppDatabase.schemaVersion == 6`; `lib/data/db/schema/` holds v1–v6
  and no `drift_schema_v7.json`; the persistence-boundary converters
  (`lib/data/db/type_converters.dart`) are untouched.
- **Edge case of**: none.

### S-333: The owner's device checks **(owner)**

- **Fixture**: a physical iPhone with the app installed from a real build; the owner's own book or
  the app's empty state; both themes; the OS's largest accessibility text size; VoiceOver on.
- **Trigger**: manual.
- **Flow**: (a) walk every screen and every sheet at the largest text size with VoiceOver on and
  read each number aloud; (b) set the largest text size with VoiceOver off and look for a clipped
  or overlapping figure; (c) save a bucket-changing reading and feel the haptic; (d) repeat (b) in
  the other theme.
- **Expected outcome**: recorded in `## Progress` as `(owner)` rows, each with what was observed.
  A screen that reads a bare number aloud, a figure that is clipped, or a missing haptic opens a
  remediation phase — the harness's proxy (3.2, a simulated traversal) is not the device.
- **Edge case of**: S-313, S-315, S-322.

### S-334: Tone holds in every new label

- **Fixture**: the diff's added strings.
- **Trigger**: `grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/`.
- **Flow**: the grep, plus a hand-read of every added label.
- **Expected outcome**: the grep returns nothing. The hand-read finds no label pairing an action
  verb with a named security or with the user's own position: a label is
  `<Quantity name> <value>` and nothing else, so a label like `Roll your SBET call` is not
  reachable by construction. The wave adds no sentence, no SnackBar, no dialog copy and no help
  topic.
- **Edge case of**: none.

### S-335: The flag cannot be replayed

- **Fixture**: a leg and one reading; a `ProviderContainer`.
- **Trigger**: `updateSnapshot` with a bucket-changing reading, then (a) `load()`, then (b)
  `load()` again, then (c) `updateSnapshot` with the **same** numbers as the first save.
- **Flow**: read the flag after each.
- **Expected outcome**: `true` after the first save; `null` after (a); `null` after (b); and
  **`false`** after (c) — the second identical save does not re-fire, because nothing changed.
  The widget half is asserted in S-331's flow: a `pumpAndSettle` after the save, and a rebuild of
  Today, add no calls.
- **Edge case of**: S-322, S-327.

## Iteration 1

### Dependency graph

```
Phase 1 (three shared mechanisms) ──┬──► Phase 2 (contrast audit + the one token)  ──┐
                                    │                                                │
                                    ├──► Phase 3 (the read screens) ──┐               │
                                    │                                 ├──► Phase 6 ◄─┤
                                    ├──► Phase 4 (the write screens) ─┤   (closeout)  │
                                    │                                 │               │
                                    └──► Phase 5 (haptics end to end) ┘               │
```

- **Phase 1 must land first.** Phases 3–5 all import its harness, its `LabelValueRow` or its
  `Haptics` seam. Landing any of them first means writing the mechanism twice.
- **Phase 2 is independent of 3–5.** It touches `lib/core/theme/`, `lib/core/haptics/`'s sibling
  directory and the contrast test — no screen file, no harness row. It can run before, after or
  interleaved with 3–5.
- **Phases 3 and 4 are one job split by file count, not by dependency.** Both are "add the
  labels, clear the ellipsis, use the shared row". They are separated because the audit is 22
  surfaces and a single handoff that rewrites fifteen files is not reviewable; 3 covers the five
  read surfaces the wave's assertions lean on (Today, Portfolio, Journal, Position detail, Share
  card) and 4 covers the rest. They can be worked in either order.
- **Phase 5 depends on Phase 1 only** (the `Haptics` seam). It does not depend on 3 or 4 — the
  sheet's save handler is edited in Phase 5, and Phase 4 does not touch
  `snapshot_sheet.dart`'s save handler (it only adds labels to the preview above it). If Phase 4
  runs first it must not edit that handler.
- **Phase 6 needs all of 2, 3, 4 and 5.**

**Re-ordering offered.** The recommended order puts the mechanism first because every later
phase's Done Criteria depend on it. The alternative — audit the screens first, extract the
mechanism second — buys an earlier visible improvement at the cost of writing fifteen screens'
worth of one-off fixes and then rewriting them, which is the failure this wave exists to avoid.
Phase 2 could run first of all (it has no dependency and its result — one token value — is the
smallest possible change to review), at the cost of the harness landing later. Both orders end at
the same Phase 6.

### Phase 1: The three shared mechanisms (@developer)

1. [x] Add `test/support/screen_a11y_harness.dart` with `kMaxTextScale = 3.2`, `AuditedSurface`,
       `SurfaceFixture`, `auditSurface`, `semanticsLabels`, `anyLineMatches` and the 22-row
       `auditedSurfaces` table, per D-59 and D-60. Reuse `portfolio_screen_test.dart`'s
       `_semanticsLabels`/`_anyLineMatches` shapes and `help_coverage_test.dart`'s
       `_tallSurface`; do not re-derive them.
2. [x] Add `lib/widgets/label_value_row.dart` per D-64: one-line `spaceBetween` below
       `textScaler` 2.0, stacked at and above it, `helpTopicId` → a `HelpChip` as its own node,
       `emphasize`, `trailing`. No formatting, no `Decimal`, no `Bucket`.
3. [x] Add `lib/core/haptics/haptics.dart` per D-65: `abstract class Haptics`,
       `SystemHaptics` calling `HapticFeedback.mediumImpact()`, and `hapticsProvider` with a
       default. `package:flutter/services.dart` is imported here and nowhere else under `lib/`.
4. [x] Add `test/support/recording_haptics.dart`: `RecordingHaptics implements Haptics` with a
       `List<String> calls`.
5. [x] Add `test/features/a11y/screen_a11y_test.dart`: one `testWidgets` per `auditedSurfaces`
       row, asserting no exception and every expected label (S-313, S-315, S-316). Populate each
       fixture from the existing suite for that surface; do not invent a book.
6. [x] Add `test/features/a11y/a11y_structure_test.dart` with the structural guards that belong
       to no single screen: S-314 (one `TextScaler.linear(`), S-317 (the ellipsis scan), S-320
       (the `_auditedRoles` scan), S-328 (`HapticFeedback` in one file,
       `hapticsProvider.bucketChanged` in one file, `pubspec.yaml` unchanged), S-330 (route
       coverage).
7. [x] Add `test/widgets/label_value_row_test.dart` per S-318: the four call shapes at
       `1.0`, `1.5`, `2.0`, `2.5`, `3.2`, the long label/long value pair, and the assertion that
       the file contains no `TextOverflow.ellipsis`.
8. [x] Add `test/core/haptics/haptics_test.dart`: `SystemHaptics().bucketChanged()` sends exactly
       one `mediumImpact` on `SystemChannels.platform` (S-328(d)).
9. [x] **Do not touch any screen, sheet, dialog or state file in this phase.** The harness's table
       will fail loudly for the surfaces whose labels do not exist yet — that is the red state
       Phases 3–5 turn green, and it is the phase's own evidence that the assertions bite. Record
       the observed failure count in the Assumption Log; a table that passes before the screens
       are fixed is a table that asserts nothing.

**Done Criteria** (run until green): `flutter analyze`; `flutter test test/widgets/label_value_row_test.dart test/core/haptics/haptics_test.dart test/features/a11y/a11y_structure_test.dart`
— and `flutter test test/features/a11y/screen_a11y_test.dart` **is expected to fail** at this
phase, with the failing rows named in the Progress evidence; the ellipsis, `_auditedRoles`,
`HapticFeedback`-in-one-file, route-coverage and `pubspec.yaml` scans all behave as specified;
`grep -rl "package:flutter" lib/domain/rules/` returns nothing;
`grep -rnE "(^|[^A-Za-z])Colors\.|Color\(0x" lib/ --include='*.dart' | grep -v lib/core/theme/`
returns nothing.

**Predicted Files**: `test/support/screen_a11y_harness.dart` (new),
`test/support/recording_haptics.dart` (new), `lib/widgets/label_value_row.dart` (new),
`lib/core/haptics/haptics.dart` (new), `test/features/a11y/screen_a11y_test.dart` (new),
`test/features/a11y/a11y_structure_test.dart` (new), `test/widgets/label_value_row_test.dart`
(new), `test/core/haptics/haptics_test.dart` (new). Nothing under `lib/features/`, `lib/state/`,
`lib/data/` or `lib/domain/`.

### Phase 2: The contrast audit and the one colour value (@data-architect)

1. [x] In `lib/core/theme/app_theme.dart`, change `AppTokens.dark.outline` and
       `AppTokens.light.outline` so each clears 3:1 against both `surface` and `raised` in its own
       theme, per D-69. Today they are `#404E4E` (1.93:1) and `#A3B4B4` (2.15:1) on `surface`.
       Keep each reading as a hairline rather than as text. **Change no other token.**
2. [x] In `test/core/theme/app_theme_contrast_test.dart`, add the screen-pairing rows D-70 names
       (`accent on card`, `accent on raised`, `caution on raised`, `error on raised`, and the
       cycle summary card's `tertiary on surface` variant) at the 4.5:1 bar, per S-319. **Do not
       relax or remove any of the 15 existing pairs or the bucket checks.**
3. [x] Add the `_auditedRoles` map and its scan test to the same file, per S-320: every
       `scheme.<role>` read under `lib/` must appear in the map, and `outlineVariant`'s entry
       carries the D-68 decorative-border exemption as its audit note.
4. [x] Add the 3:1 assertions for `scheme.outline` against `scheme.surface` and
       `scheme.surfaceContainerHighest` in both themes, per S-321.
5. [x] Add the failure messages that name the pair, the ratio and the bar — the existing test's
       `reason:` pattern. A ratio that fails must be diagnosable from the test output alone.
6. [x] Confirm the two goldens are unchanged (S-329) and record the observation; do not regenerate
       either.

**Done Criteria** (run until green): `flutter analyze`;
`flutter test test/core/theme/app_theme_contrast_test.dart test/features/goldens`;
the colour-literal grep returns nothing;
`grep -rn "scheme\.outline\b" lib/` returns exactly one line
(`lib/features/paywall/paywall_screen.dart:315`);
`grep -c "outline" lib/core/theme/app_theme.dart` shows the two changed values and no other token
touched; `git diff --stat` shows no `*.png`.

**Predicted Files**: `lib/core/theme/app_theme.dart`, `test/core/theme/app_theme_contrast_test.dart`.

### Phase 3: The five read screens (@developer)

1. [x] `lib/features/today/today_screen.dart`: clear the three ellipsis sites (`:263`, `:436`,
       `:443`) so the count chip's label, the ledger tile's label and the ledger tile's **money
       value** all wrap; add the labels D-60's Today row lists; keep the "Committed now" tile's
       `onTap` and the two inert tiles inert.
2. [x] `lib/features/portfolio/portfolio_screen.dart`: clear `:565`'s ellipsis; add the labels
       D-60's Portfolio row lists. **Do not reword the five existing `Semantics(` labels** — S-304
       asserts them and must stay green without an edit.
3. [x] `lib/features/journal/journal_screen.dart`: replace `_stat:163` with `LabelValueRow`
       (clearing `:168`); add the aggregate labels; add the cycle summary sheet's labels.
4. [x] `lib/widgets/journal_row.dart`: add the two labels. Do not touch its formatting (D-74).
5. [x] `lib/widgets/cycle_summary_card.dart`: replace `_row:120` with `LabelValueRow`'s
       `emphasize` variant (clearing `:126`); add the two labels.
6. [x] `lib/features/positions/position_detail_sheet.dart`: replace `_Row:284` with
       `LabelValueRow`'s `trailing` variant (clearing `:333`); add the eight labels; the five
       `HelpChip`s stay their own nodes. Do not edit the save handler — that is Phase 5's.
7. [x] `lib/features/journal/share_card.dart`, `share_card_screen.dart`: add the labels. Leave
       `share_card.dart:63`'s `outlineVariant` border alone (D-68).
8. [x] Extend the existing suites for any behaviour the rewrite could have moved: a
       `LabelValueRow` below 2.0 must render what the private copy rendered.

**Done Criteria** (run until green): `flutter analyze`;
`flutter test test/features/a11y/screen_a11y_test.dart test/features/today test/features/portfolio test/features/journal test/features/positions test/widgets`;
`grep -rn "TextOverflow.ellipsis" lib/features lib/widgets` returns nothing;
`grep -rn "class _Row\|Widget _stat\|Widget _row\|class _OutputRow" lib/` returns nothing;
`grep -rniE "recommend|we suggest|our analysis|buy signal|sell signal|opportunity|guaranteed|you should" lib/`
returns nothing; the colour-literal grep returns nothing.

**Predicted Files**: `lib/features/today/today_screen.dart`,
`lib/features/portfolio/portfolio_screen.dart`, `lib/features/journal/journal_screen.dart`,
`lib/features/journal/share_card.dart`, `lib/features/journal/share_card_screen.dart`,
`lib/features/positions/position_detail_sheet.dart`, `lib/widgets/journal_row.dart`,
`lib/widgets/cycle_summary_card.dart`, plus the suites those files already have
(`test/features/today/today_screen_test.dart`, `test/features/portfolio/portfolio_screen_test.dart`,
`test/features/journal/share_card_screen_test.dart`,
`test/features/positions/position_detail_sheet_test.dart`,
`test/widgets/journal_row_test.dart`, `test/widgets/cycle_summary_card_test.dart`).

### Phase 4: The remaining screens and surfaces (@developer)

1. [x] `lib/features/screener/screener_screen.dart`: replace `_OutputRow:348` with
       `LabelValueRow` (clearing `:366`); add the eight labels. Leave `_GateChip:385` alone.
2. [x] `lib/features/record/record_trade_screen.dart`: add the remaining labels; **do not reword
       `:417` or `:424`** — they are the style the rest adopted.
3. [x] `lib/features/roll/roll_planner_screen.dart`: add the five labels; leave the debit-roll
       line's wording and roles alone.
4. [x] `lib/features/assignment/assignment_flow_screen.dart`: add the two labels.
5. [x] `lib/features/settings/settings_screen.dart`, `rule_profile_section.dart`,
       `pro_plan_section.dart`: add the three labels; leave the `kAppDisclaimer` block and both
       `SnackBar`s alone.
6. [x] `lib/features/paywall/paywall_screen.dart`: add any label the harness row names; leave the
       four existing `Semantics(` nodes, the copy and `kPaywallFeatures` alone.
7. [x] `lib/features/onboarding/first_run_explainer.dart`: no label (no number); confirm it passes
       the no-overflow assertion unchanged.
8. [x] Wire the remaining harness rows' `open` callbacks: the help sheet, the fees sheet, the
       cycle summary sheet, the six date pickers, the five dialogs, and Today's banner.
9. [x] Extend the existing suites where the row rewrite could have moved output.

**Done Criteria** (run until green): `flutter analyze`;
`flutter test test/features/a11y test/features/screener test/features/record test/features/roll test/features/assignment test/features/settings test/features/paywall test/features/onboarding test/features/export test/features/help_coverage_test.dart`;
`grep -rn "TextOverflow.ellipsis" lib/features lib/widgets` returns nothing; the tone grep
returns nothing; the colour-literal grep returns nothing.

**Predicted Files**: `lib/features/screener/screener_screen.dart`,
`lib/features/record/record_trade_screen.dart`, `lib/features/roll/roll_planner_screen.dart`,
`lib/features/assignment/assignment_flow_screen.dart`,
`lib/features/settings/settings_screen.dart`, `lib/features/settings/rule_profile_section.dart`,
`lib/features/paywall/paywall_screen.dart`, `test/features/a11y/screen_a11y_test.dart`, plus the
suites those files already have.

### Phase 5: Haptics, end to end (@developer)

1. [x] `lib/state/positions/position_detail_controller.dart`: add
       `PositionDetailState.lastSnapshotChangedBucket` (a nullable `bool`); capture
       `state.bucket?.runtimeType` and `state.snapshots.isNotEmpty` before the append; set the flag
       in `updateSnapshot`'s final `copyWith` after `await load()`; clear it to `null` in `load()`
       alongside `clearSnapshotWarning`. `updateSnapshot` still returns `bool`. Per D-66.
2. [x] `lib/features/positions/snapshot_sheet.dart`: in the save handler, after `navigator.pop(true)`
       and after reading the warning, read `lastSnapshotChangedBucket` through the provider (the
       same read as `:398`'s warning) and, when it is `true`, call
       `ref.read(hapticsProvider).bucketChanged()` — **once**. Per D-67.
3. [x] Add S-322…S-326 and S-335 to `test/features/positions/snapshot_sheet_test.dart`, each with a
       `RecordingHaptics` override; assert the counter, the saved state, and (for S-324) that the
       preview's "This changes the bucket" line is present while the counter is zero.
4. [x] Add S-327 to `test/state/positions/position_detail_controller_test.dart` with a
       `ProviderContainer` and **no widget**, asserting `true` / `false` / `false` and `null` after
       `load()`; plus the structural assertion that no file under `lib/features/` compares a
       `Bucket`'s `runtimeType` or calls `classify(`.
5. [x] Add S-331 to `test/features/today/today_screen_test.dart`: the save through the sheet, then
       Today, Portfolio and the detail sheet all showing the new bucket, with exactly one recorded
       call across the whole flow.
6. [x] Confirm `grep -rn "hapticsProvider" lib/` returns exactly one call site.

**Done Criteria** (run until green): `flutter analyze`;
`flutter test test/features/positions test/state/positions test/features/today test/features/a11y`;
`grep -rn "HapticFeedback" lib/` returns exactly one file;
`grep -rn "hapticsProvider" lib/` returns exactly one call site plus the declaration;
`grep -rn "classify(\|runtimeType" lib/features/` returns nothing; the tone grep returns nothing.

**Predicted Files**: `lib/state/positions/position_detail_controller.dart`,
`lib/features/positions/snapshot_sheet.dart`,
`test/features/positions/snapshot_sheet_test.dart`,
`test/state/positions/position_detail_controller_test.dart`,
`test/features/today/today_screen_test.dart`.

### Phase 6: Closeout — docs, the Stage 6 contract, and the residue sweep (@developer)

1. [x] Add an accessibility section to `docs/architecture/wheel-triage.md`, naming the harness and
       `kMaxTextScale` (D-59), `LabelValueRow` (D-64), `Haptics` (D-65), the S-219/S-321 pair
       table and the structural guards, with the sentence D-72 pins: *a new screen is audited by
       adding a row to `auditedSurfaces`; the route-coverage test fails until it has one.*
2. [x] Add two rows to the doc's Drift-risk areas table: **the label/value row** (the one owner is
       `lib/widgets/label_value_row.dart`; what would drift is a screen re-implementing the
       stack-at-large-scales behaviour) and **the accessibility audit's enumeration** (the one
       owner is `auditedSurfaces`; what would drift is a route shipping unaudited).
3. [x] Add the harness path, `kMaxTextScale` and the truncation guard's location to
       `docs/conventions.md` §9. **Change no rule in §9** — the paths are new, the policy is not.
4. [x] Run the residue sweep and record every command's actual output in `## Progress`:
       - `grep -rn "TextOverflow.ellipsis" lib/` → nothing
       - `grep -rn "HapticFeedback" lib/` → one file
       - `grep -rn "hapticsProvider" lib/` → the declaration plus one call site
       - `grep -rn "classify(\|runtimeType" lib/features/` → nothing
       - `grep -rn "TextScaler.linear(" test/` → one, in the harness
       - `grep -rl "package:flutter" lib/domain/rules/` → nothing
       - the colour-literal grep → nothing
       - the tone grep → nothing
       - `grep -rn "scheme\.outline\b" lib/` → one line
       - `grep -c "schemaVersion" lib/data/db/app_database.dart` and `ls lib/data/db/schema/` → 6, v1–v6
       - `git diff --stat` → no `*.png`, no `pubspec.yaml`
5. [x] Run the full suite and `flutter analyze`; record the pass/fail counts beside the 1076
       baseline.
6. [x] Run `flutter build ios --simulator --no-codesign` and record the exit code — the
       acceptance build is a Done Criterion for the wave even though no build-affecting file
       changed.
7. [x] Fill in `## Progress`'s three `(owner)` rows as **pending**, and leave the Status as
       `DRAFT — active` until S-333 is recorded (D-73).

**Done Criteria** (run until green): `flutter analyze`;
`flutter test` (full suite); `flutter build ios --simulator --no-codesign` exit 0; every residue
command above returning its expected result; the two docs edited and no other file.

**Predicted Files**: `docs/architecture/wheel-triage.md`, `docs/conventions.md`.

## Files Affected

Whole-feature list. `(new)` marks a file this wave creates; `(docs)` marks documentation;
everything else exists and is edited.

**New source**

- `lib/widgets/label_value_row.dart` (new)
- `lib/core/haptics/haptics.dart` (new)

**New tests**

- `test/support/screen_a11y_harness.dart` (new)
- `test/support/recording_haptics.dart` (new)
- `test/features/a11y/screen_a11y_test.dart` (new)
- `test/features/a11y/a11y_structure_test.dart` (new)
- `test/widgets/label_value_row_test.dart` (new)
- `test/core/haptics/haptics_test.dart` (new)

**Edited source**

- `lib/core/theme/app_theme.dart` — **not edited** (D-69 is overridden by A-1: no `outline` value changed)
- `lib/state/positions/position_detail_controller.dart` (the flag, D-66)
- `lib/features/positions/snapshot_sheet.dart` (the one haptic call site, D-67; the preview's labels)
- `lib/features/positions/position_detail_sheet.dart` (`_Row` → `LabelValueRow`; labels)
- `lib/features/today/today_screen.dart` (three ellipsis sites; labels)
- `lib/features/portfolio/portfolio_screen.dart` (one ellipsis site; labels)
- `lib/features/journal/journal_screen.dart` (`_stat` → `LabelValueRow`; labels)
- `lib/features/journal/share_card.dart` (labels)
- `lib/features/journal/share_card_screen.dart` — **not edited** (A-16)
- `lib/features/screener/screener_screen.dart` (`_OutputRow` → `LabelValueRow`; labels)
- `lib/features/record/record_trade_screen.dart` (labels)
- `lib/features/roll/roll_planner_screen.dart` — **not edited** (A-16)
- `lib/features/assignment/assignment_flow_screen.dart` — **not edited** (A-16)
- `lib/features/settings/settings_screen.dart` — **not edited** (A-16)
- `lib/features/settings/rule_profile_section.dart` — **not edited** (A-16)
- `lib/features/paywall/paywall_screen.dart` (the unselected plan indicator's colour, D-68/A-1 — no labels added)
- `lib/widgets/journal_row.dart` (labels)
- `lib/widgets/cycle_summary_card.dart` (`_row` → `LabelValueRow`; labels)

**Edited tests** (each already exists; each is extended, never replaced)

- `test/core/theme/app_theme_contrast_test.dart` (S-219 grows; nothing relaxed)
- `test/features/positions/snapshot_sheet_test.dart` (S-322…S-326, S-335)
- `test/state/positions/position_detail_controller_test.dart` (S-327)
- `test/features/today/today_screen_test.dart` (S-331)
- `test/features/portfolio/portfolio_screen_test.dart` (only if S-304 needs a fixture tweak; **not** a label reword)
- `test/features/screener/screener_screen_test.dart`,
  `test/features/record/record_trade_screen_test.dart`,
  `test/features/roll/roll_planner_screen_test.dart`,
  `test/features/assignment/assignment_flow_screen_test.dart`,
  `test/features/settings/settings_screen_test.dart`,
  `test/features/journal/share_card_screen_test.dart`,
  `test/features/positions/position_detail_sheet_test.dart`,
  `test/widgets/journal_row_test.dart`, `test/widgets/cycle_summary_card_test.dart`
  (only where the `LabelValueRow` rewrite could have moved output)

**Documentation**

- `docs/architecture/wheel-triage.md` (docs) — the accessibility section, two drift rows
- `docs/conventions.md` (docs) — §9 gains the paths

**Explicitly untouched**

- `lib/domain/rules/**` — every file, including `snapshot_preview.dart` (its `changesBucket` is read, not changed)
- `lib/data/**` — including `lib/data/db/app_database.dart` (v6) and `lib/data/db/type_converters.dart`
- `lib/core/format.dart`, `lib/core/money/**`, `lib/core/disclaimer.dart`, `lib/core/app_router.dart`
- `lib/widgets/bucket_badge.dart`, `lib/widgets/help_chip.dart`, `lib/widgets/labeled_number_field.dart`,
  `lib/widgets/delta_sparkline.dart`, `lib/widgets/app_bottom_nav.dart`,
  `lib/widgets/entitlement_lifecycle_scope.dart`
- `pubspec.yaml`, `pubspec.lock`, `.claude/**`, `.github/**`
- every `*.png` under `test/features/goldens/`

## Notes

**Phase dependency graph.** Phase 1 → {2, 3, 4, 5} → 6. 2 is independent of 3/4/5; 3 and 4 are
independent of each other and of 5; 5 needs only 1. The one ordering constraint that is not a
dependency: **Phase 4 must not edit `snapshot_sheet.dart`'s save handler** (it edits only the
preview above it), because Phase 5 owns that handler. If the two are worked out of order, the
handler's edit is still Phase 5's.

**Predicted intermediate states.**

- **After Phase 1**: `screen_a11y_test.dart` **fails**, naming every surface whose labels do not
  exist yet. That is the intended state — it is the red evidence that the harness asserts
  something. `a11y_structure_test.dart` also fails on the ellipsis scan (eight sites) and the
  `_auditedRoles` scan (before Phase 2 fills the map). `label_value_row_test.dart`,
  `haptics_test.dart` and `flutter analyze` pass. The full suite is red at this point; that is
  expected and is not a defect.
- **After Phase 2**: the contrast suite passes; the goldens are unchanged; the
  `a11y_structure_test.dart`'s `_auditedRoles` half passes. `screen_a11y_test.dart` is still red.
- **After Phase 3**: the five read surfaces' harness rows pass; the remaining rows are still red.
  The ellipsis scan is down to `screener_screen.dart:366` and nothing else in `lib/features/`.
- **After Phase 4**: `screen_a11y_test.dart` is fully green; the ellipsis scan is empty.
- **After Phase 5**: the haptics scenarios pass; the full suite is green.
- **After Phase 6**: the full suite is green at a new count above 1076, `flutter analyze` clean,
  the iOS simulator build exit 0, and three `(owner)` rows pending.

**Legacy handling.** Nothing in this wave migrates anything. The audit reads what the app
already renders; no stored value, label, notification or export field changes (S-332). The two
legacy profile rows (`Conservative`, `Aggressive`) are untouched and stay unlisted.

**A note on why the harness's `expectedLabels` are authored by hand.** The wave could have
generated them from the rendered strings, which would make the table self-fulfilling: whatever a
screen prints becomes the expected label, and a screen that prints a bare number would pass. The
pairs in D-60's table are therefore written from the *quantity*, not from the output, and
`S-315`'s worked examples name the quantity first. That is the whole difference between an audit
and a snapshot.

**A note on the haptic's one honest gap.** A widget test proves the seam was called exactly once
under exactly the right conditions; it cannot prove the phone vibrated. That is why S-333(c) is
an `(owner)` item and why D-73 makes it block the wave rather than a phase — the same shape as
Wave 3's image-capture golden, which the owner also had to confirm on a device.

## Progress

| Phase | Owner | Status | Evidence |
|---|---|---|---|
| 1 — The three shared mechanisms | @developer | Complete | 8 new files: `test/support/screen_a11y_harness.dart`, `test/support/recording_haptics.dart`, `lib/widgets/label_value_row.dart`, `lib/core/haptics/haptics.dart`, `test/features/a11y/screen_a11y_test.dart`, `test/features/a11y/a11y_structure_test.dart`, `test/widgets/label_value_row_test.dart`, `test/core/haptics/haptics_test.dart`. Confirmed red first: `screen_a11y_test.dart` failed for every audited surface whose labels did not exist yet, and three of the five structural guards were red because their subjects are later phases' (A-12 records which phase turned each green). Final: `flutter test test/features/a11y` 48 passed, 0 failed; `label_value_row_test` 6; `haptics_test` 2. `flutter analyze` clean |
| 2 — The contrast audit and the one colour value | @data-architect | Complete | **Deviation, by the brief's governor decision:** `AppTokens.{dark,light}.outline` is **not** changed (D-69 overridden); the paywall's unselected plan indicator now paints `scheme.onSurfaceVariant` (`lib/features/paywall/paywall_screen.dart:315`). `test/core/theme/app_theme_contrast_test.dart` grew to `_auditedRoles` (14 roles) + 4 screen-pairing rows + the role-audit-completeness guard; S-319/S-321 green. `grep -rn "scheme\.outline\b" lib/` → **0 lines**, not the plan's 1 (see the Assumption Log). The `tertiary` on `surfaceContainerHighest` pair (light 4.20:1) is recorded as not-painted rather than asserted. Both `test/features/goldens/` goldens unchanged |
| 3 — The five read screens | @developer | Complete | `LabelValueRow` replaces the private row copies in the screener (`_OutputRow`), the journal (`_stat`), the cycle summary (`_row`) and the detail sheet (`_Row`); `Sorting score` is wrapped in `Semantics`; the eight labels added. Overflow sweep at `kMaxTextScale` (S-313) fixed seven sites: screener gate chips `Row`→`Wrap` + two `Flexible` section headers, journal `JournalRowTile` `ListTile`→`InkWell`+`Row`, portfolio key line `Text`→`Flexible`, assignment wheel basis `Text`→`Flexible`. `screen_a11y_test.dart` green over the harness's rows (`auditedSurfaces` + `auditedEmptySurfaces`, `test/support/screen_a11y_harness.dart`); the four `test/widgets/goldens/journal_row_*.png` moved and were regenerated (see the Assumption Log) |
| 4 — The remaining screens and surfaces | @developer | Complete | Record DTE `Text`→`Flexible`; Today's `_LedgerTile` labelled and its ellipsis removed; Portfolio `_CountsRow` ellipsis removed; `snapshot_sheet._PreviewRow`→three `LabelValueRow`s + the convention `Row`→`Wrap`; `share_card.dart` laid out at `TextScaler.noScaling` with `_Figure` labelled (a fixed 360×450 export surface). Settings, `rule_profile_section`, `pro_plan_section`, the paywall copy, `kAppDisclaimer` and both SnackBars are untouched — the shipped copy already names every figure. Final audit: 36 rows (29 populated + 7 empty-state), **zero exceptions**, every expected label present |
| 5 — Haptics, end to end | @developer | Complete | `PositionDetailState.lastSnapshotChangedBucket` (nullable `bool`, cleared by `load()`); the one firing site is `snapshot_sheet.dart:396` after `navigator.pop(true)`. `flutter test test/features/positions test/state/positions test/features/today test/features/a11y` → **147 passed, 0 failed**; S-322…S-326 and S-335 in `snapshot_sheet_test.dart` (22 tests), S-327/S-335 in `position_detail_controller_test.dart` (25 tests), S-331 in `today_screen_test.dart` (32 tests). `grep -rln "HapticFeedback" lib/` → `lib/core/haptics/haptics.dart` only; `grep -rn "hapticsProvider" lib/` → the declaration plus one call site |
| 6 — Closeout | @developer | Complete | `docs/architecture/wheel-triage.md` gained the accessibility section and two Drift-risk rows; `docs/conventions.md` §9 gained the four mechanism paths and no rule changed. Residue sweep and the full suite below. `flutter analyze` clean; `flutter test` **1156 passed, 0 failed** (baseline 1076); `flutter build ios --simulator --no-codesign` exit 0 |
| Owner check — VoiceOver on a device at the largest text size **(owner)** | owner | pending | Blocks wave closure (D-73); not yet run |
| Owner check — the bucket-change haptic on a device **(owner)** | owner | pending | Blocks wave closure (D-73); not yet run |
| Owner check — both themes on a device at the largest text size **(owner)** | owner | pending | Blocks wave closure (D-73); not yet run |

### Phase 6 residue sweep — actual output

| Command | Actual result |
|---|---|
| `grep -rn "TextOverflow.ellipsis" lib/` | 0 lines |
| `grep -rln "HapticFeedback" lib/` | 1 file: `lib/core/haptics/haptics.dart` |
| `grep -rn "hapticsProvider" lib/` | 2 lines: `lib/core/haptics/haptics.dart:26` (the declaration) and `lib/features/positions/snapshot_sheet.dart:396` (the one call site) |
| `grep -rn "classify(\|runtimeType" lib/features/` | 4 lines, all pre-existing and none a comparison: `today_screen.dart:207`, `:208` (a bucket `runtimeType` **type token**), `position_detail_sheet.dart:64` (a comment), `paywall_route.dart:66` (`GoRoute.hashCode`). No `classify(` anywhere; the guard pins the allow-list |
| `grep -rn "TextScaler.linear(" test/` | 6 lines: 3 code sites (`screen_a11y_harness.dart:820` = the ceiling, `portfolio_screen_test.dart:645` = the 2.0 probe, `label_value_row_test.dart:31` = a scaled parameter) and 3 comment/`reason:` strings. S-314 asserts the ceiling is the only one outside the allow-list |
| `grep -rl "package:flutter" lib/domain/rules/` | 0 files |
| colour-literal grep (`grep -rnE "(^\|[^A-Za-z])Colors\.\|Color\(0x" lib/ --include='*.dart' \| grep -v lib/core/theme/`) | empty — exit 1, no matches, and no added line in `git diff` matches |
| tone grep | 0 lines |
| `grep -rn "scheme\.outline\b" lib/` | **0 lines** (the plan predicted 1 — see the Assumption Log) |
| `grep -c "schemaVersion" lib/data/db/app_database.dart` / `ls lib/data/db/schema/` | `1` (the `int get schemaVersion => 6;` getter — the plan's `6` was the version, not the match count); `drift_schema_v1.json` … `drift_schema_v6.json` |
| `git diff --stat` | no `*.png` under `test/features/goldens/`, no `pubspec.yaml`; the four `test/widgets/goldens/journal_row_*.png` did move (Assumption Log) |

**Baseline at planning time:** `flutter analyze` clean; `flutter test` **1076 passed, 0 failed**;
`AppDatabase.schemaVersion == 6`; `lib/data/db/schema/` holds v1–v6; `TextOverflow.ellipsis` at 8
sites in `lib/`; `Semantics(` at 13 sites in `lib/`; 12 routes and 17 modal surfaces; the tone,
rules-purity and colour-literal greps all empty.

**After this wave:** `flutter analyze` clean; `flutter test` **1156 passed, 0 failed** (+80);
`AppDatabase.schemaVersion` still 6 and `lib/data/db/schema/` still v1–v6; `TextOverflow.ellipsis`
0 sites in `lib/`; the tone, rules-purity and colour-literal greps still empty; `pubspec.yaml`
unchanged — pinned by content and length (S-328), not by comparison against `HEAD`.

**The one gap in the coverage guard.** S-330 derives the router's paths from
`lib/core/app_router.dart` and fails on a new `GoRoute` with no row, but the 18 rows whose surface
needs an `open:` helper (7 screens and sheets, 6 dialogs, 5 date pickers) are hand-listed: a new
modal can ship unaudited while the guard stays green. Every route is derived; no modal is.

## Assumption Log

Executors append here and never stop on ambiguity: pick the option most consistent with the
Ledger and the Feature Invariants, record the decision, the options considered and the
rationale, and continue. The Conductor then marks each entry **RATIFIED** (promoted to a D-x) or
**REVERT** (remediation opened). An empty log after a complex phase is itself suspicious.

_(No entries yet. Phase 1 is the first handoff.)_

### A-1 — The governor's override of D-69 (Phase 2)

**Decision.** `AppTokens.{dark,light}.outline` is **not** changed. The paywall's unselected plan
indicator paints `scheme.onSurfaceVariant` instead — a one-line screen change
(`lib/features/paywall/paywall_screen.dart:315`) — and the contrast audit proves it (7.32:1 dark,
6.24:1 light against `surface`, both above D-68's 3:1 non-text bar).

**Options.** (a) D-69 as written — change the token in both themes; (b) the brief's override —
leave the palette and repaint the one component.

**Why.** The brief's governor decision is binding and takes precedence over D-69. Consequence: the
plan's Phase 2 Done Criterion "`grep -rn "scheme\.outline\b" lib/` → one line" is now **0 lines**,
and `outline` is no longer painted by any screen. The contrast suite records that in
`_auditedRoles` (`'outline': 'the unselected plan indicator's old colour; no longer painted
anywhere'`) and the role-audit-completeness guard still requires an entry for it, so a later
reader cannot remove the record silently. The two `test/features/goldens/` goldens are unchanged
(S-329 holds), as D-69's own note predicted they would be either way.

### A-2 — One candidate pair is recorded, not asserted

**Decision.** `tertiary` on `surfaceContainerHighest` (light theme, 4.20:1) is listed in
`_auditedRoles` and in the screen-pairing table as **not painted** rather than asserted at 4.5:1.

**Options.** (a) Assert it and change a palette value to clear the bar; (b) record it as a pair the
design documents but nothing paints.

**Why.** D-68 says a documented-but-unpainted pair is recorded rather than asserted, and D-74
forbids a new colour token or literal. Changing a palette value to satisfy a pair no screen paints
would be exactly the "a violated rule that still renders acceptably" spread D-74 exists to stop.
If a later wave paints caution text on the raised container, the entry is already there and the
assertion is a one-line addition.

### A-3 — The harness's parameter names differ from D-60's prose

**Decision.** `auditSurface` takes `book:` (a `SurfaceBook`), not D-60's `repo:`, and its `open`
callback takes `(WidgetTester, SurfaceBook)`.

**Options.** (a) D-60's literal names; (b) names that describe what is passed.

**Why.** The audited surfaces do not all take a repository: a surface needs the leg, the book and
the profile version to be seeded before it renders, and several need a specific leg *id* rather
than a repository handle. `SurfaceBook` is the seeded fixture bundle the harness already builds;
naming the parameter `repo:` would have been a lie the first time a surface needed the ticker
instead. The `expectedLabels` pairs, the route-coverage guard and the exemption list are exactly
as D-60 specifies.

### A-4 — `expectedLabels` are the shipped strings, and the plan's worked examples are not

**Decision.** Every `expectedLabels` pair was authored from the **rendered** labels of the shipped
screens, and D-61's label form (`<Quantity name> <value>`) is what the screens now emit. Where the
plan's prose and the shipped copy disagree, the shipped copy wins and the test asserts the shipped
copy.

**One named exception.** The screener's `('Sorting score', '3 of 9')` asserts the **spoken** string,
not the rendered one: the screen renders `'3 / 9'` (`screener_screen.dart:356`) and its own
`Semantics(label:)` hand-rolls `'3 of 9'` (`:354`). The spoken form is the friendlier one — "three
of nine" reads better than "three slash nine" — so it is kept and named here rather than making the
"rendered labels" claim false by silence. It is the only pair where the two differ.

**Options.** (a) Reword the screens to match the plan's examples; (b) assert what the screens say.

**Why.** D-61 says "no existing label reworded", and D-74 forbids restyling copy; the plan's
examples were written before the copy was final. The differences: the paywall's plan rows are
labelled `<Plan kind>, <subtitle>` (`'Monthly, $4.99 a month'`), not `'Pro plan, …'`; the screener
and journal figures carry their shipped names (`'Sorting score'`, `'Net result not available'`);
Today renders `<count> <Bucket>` where Portfolio renders `<Bucket> <count>`. The pair matcher is
therefore **either-order on the same line** rather than a fixed order, which is the narrower
change than rewording one of the two screens. S-315's "quantity first" requirement is met by the
harness's own pair form, not by the screen's word order.

### A-5 — S-316's literal assertion is unsatisfiable as written

**Decision.** S-316 ("an absent value is spoken as `not available`, never as `--`") is implemented
as three assertions: the *label* is `<quantity> not available`; no label contains `--`; and the
value cell that renders `--` is a sibling node the wrapper's own label does not include.

**Options.** (a) The literal "no node's label contains `--`"; (b) the three-part form.

**Why.** The value cell still renders `--` on screen — that is shipped behaviour and D-74 forbids
changing it — and a `Semantics(label:)` wrapper does not merge its children, so the child `Text`
remains its own node whose label is `--`. The literal reading would fail on correct code. The
three-part form is strictly stronger than the plan's intent (it proves the spoken label carries the
quantity *and* says the value is unavailable) and it fails if a wrapper ever starts speaking the
raw `--`.

### A-6 — S-327's structural guard needs a pinned allow-list

**Decision.** The "no `classify(` or `runtimeType` under `lib/features/`" guard is implemented as:
(i) `classify(` → nothing, comment lines skipped; (ii) a pinned allow-list naming the two files
that legitimately contain `runtimeType` — `today_screen.dart` (a bucket **type token** passed as a
filter value) and `paywall_route.dart` (`GoRoute.hashCode`).

**Options.** (a) The literal grep; (b) the guard plus an allow-list.

**Why.** Four pre-existing hits are not comparisons: `today_screen.dart:207`/`:208` pass
`count.bucket.runtimeType` as a `Type` token (the Today filter's value, not a classification),
`position_detail_sheet.dart:64` is a **comment**, and `paywall_route.dart:66` is a routing hash.
The comparison the scenario exists to prevent — a screen re-deriving a bucket — is what the guard
now forbids, and the allow-list is asserted to be exactly those two files, so a third site fails
the test. A grep-only guard would have been red from the first run and would have been deleted or
`skip`ped by the next agent.

### A-7 — The four `test/widgets/goldens/journal_row_*.png` goldens moved

**Decision.** `JournalRowTile` no longer uses a `ListTile`; it is an `InkWell` over an
intrinsic-height `Row`, with `ListTile`'s M3 metrics (`contentPadding` start 16 / end 24, a
`bodyLarge` title). Its four goldens were regenerated.

**Options.** (a) Keep `ListTile` and find another remedy; (b) replace it and regenerate.

**Why.** At `kMaxTextScale` `ListTile`'s `trailing` slot is given a fixed height and the two
figures overflow it by 59px (S-313) — the row cannot grow, and D-63's remedy is wrap-or-stack,
never shrink. Moving the figures into the `subtitle` slot would have been a larger visual change
than removing the tile. Matching the tile's typography, padding and title/subtitle gap reduced the
golden delta from 2.11% to 0.42%. **The residual is a hairline, measured from the decoded PNGs:**
the title is identical, the subtitle moves 1px, and the two trailing figures move 2px in *opposite*
directions — the cause is the 4px gap that replaced `ListTile`'s centred trailing alignment, not a
baseline difference. (An earlier draft of this entry attributed it to `ListTile`'s baseline-based
title/subtitle positioning and cited a `height: 1.0` experiment as the evidence; the measurement
does not support that reading, so it is corrected here rather than kept.) **This is the one moved
golden, and it has a corresponding `lib/` change in the diff** (`lib/widgets/journal_row.dart`),
which is the condition D-71 sets for a legitimate move. The two goldens D-71 pins
(`test/features/goldens/bucket_badge_golden_test.dart`, `share_card_golden_test.dart`) did not
move, and no golden was added.

### A-8 — The ShareCard is laid out at `TextScaler.noScaling`

**Decision.** `lib/features/journal/share_card.dart`'s fixed 360 × 450 export surface is wrapped
in `MediaQuery(textScaler: TextScaler.noScaling)`; the screen around it still scales.

**Options.** (a) Let the card scale and reflow; (b) pin the export surface's scale.

**Why.** The card is an image exported to the platform share sheet (D-P7), not a screen: its
geometry is the export contract and a scaled card would change what every recipient sees rather
than what the user reads. The audit therefore asserts the card's labels (which are what a
screen-reader user hears) but not its wrapping — it is the one surface in `auditedSurfaces`
exempted from S-313's reflow, and the exemption is named in the harness.

### A-9 — The audit viewport is 1000 × 6000, and the harness's `open` helpers are real

**Decision.** `auditSurface` pumps on a 1000 × 6000 viewport and the harness's `open` callbacks
drive the real UI (fill the screener form, add a roll candidate, confirm the assignment, fill the
snapshot preview) rather than rendering a pre-built widget.

**Options.** (a) The default 800 × 600; (b) a tall viewport; and (a) pump the surface's own widget;
(b) drive the route.

**Why.** At 4000px the Today list's third and later tiles were never built, so an overflow in them
would not have been caught — the tall viewport is what makes S-313's "every surface" claim true.
Driving the route is what makes the audit a *screen* audit: a pre-built widget would not have
caught the `position_detail_controller` autoDispose interaction that S-331 depends on.

### A-10 — Five of the plan's enumerations are one or more off, and the code follows the code

**Decision.** Where the plan's count of existing sites disagrees with the repository, the tests
assert the repository: there are **5** date pickers, not 6; `snapshot_sheet._PreviewRow` was a
**fifth** copy of the label/value row, not four; `TextScaler.linear(` appears **6** times in
`test/` (3 code sites, 3 in comments), and S-314 pins the 3; the Settings replace dialog is
reachable only through the import flow, so it has no `open` and is audited as the import surface
that reaches it; there is no cycle-summary *sheet* — `CycleSummaryCard` is inline in `/journal`.
The table itself grew the same way: D-60 enumerates 22 rows, and the harness ships **36** (29
populated + 7 empty-state), because splitting a surface's empty fixture out of its populated row
is cheaper than making one row assert both.

**Options.** (a) Add a sixth date picker or a cycle-summary sheet to match the plan; (b) audit what
exists.

**Why.** Adding UI to satisfy an enumeration would be building a surface the brief does not ask
for. Each of these is recorded here so the count in the plan is not silently treated as a
requirement by the next wave.

### A-11 — `LabelValueRow` gained `spokenValue`, and `trailing` has no live caller

**Decision.** `LabelValueRow` takes `spokenValue` (the label the reader hears when it must differ
from the rendered value — `wholeDollars` returns `'$2,200'`, so Record's label reads
`Capital committed $2,200 dollars` without it) and `stacked` (forced stacking below
`stackAtScale`). Its `trailing` parameter has **no live caller** in `lib/`.

**Options.** (a) D-64's exact constructor; (b) the two additions; (c) drop `trailing`.

**Why.** `spokenValue` is what makes the spoken label grammatical in the one case where the
formatter already emits a currency symbol, and `stacked` is what lets the screener force the
stacked shape the plan's S-144 roll-band row needs at 1.0. `trailing` was in D-64 and is kept
because the detail sheet's row shape is the one the plan describes it for; a parameter with no
caller is a smaller smell than deleting a shape the plan asked for and re-adding it later.

### A-12 — The structural guards went green as their subjects landed

**Decision.** Phase 1's own Done Criteria assume `a11y_structure_test.dart` passes at the end of
Phase 1 while `screen_a11y_test.dart` is red. In practice the red set at the end of Phase 1 was
wider, because four of the five structural guards assert properties the later phases create. Each
was left red rather than weakened, and the phase that made it green is recorded here:

| Guard | Green from | Why it was red earlier |
|---|---|---|
| S-314 — one `TextScaler.linear(` outside the allow-list | Phase 1 | The allow-list names the pre-existing 2.0 probe and Phase 1's own scaled-parameter test |
| S-317 — no `TextOverflow.ellipsis`/`clip` under `lib/features` or `lib/widgets` | Phases 3–4 | The eight shipped sites (`today_screen`, `portfolio_screen` and the others) were still there; the scan is what found them |
| S-320 — every `scheme.<role>` read under `lib/` has an `_auditedRoles` entry | Phase 2 | `_auditedRoles` had not yet grown to the 14 roles the screens read |
| S-328 — `HapticFeedback` in one file, `hapticsProvider.bucketChanged` in one file, `pubspec.yaml` unchanged | Phase 5 | The one call site is Phase 5's; the `pubspec.yaml` and `HapticFeedback` halves were green from Phase 1 |
| S-330 — every `GoRoute` fragment has an audited row | Phase 1 | The 22-row table covers all 12 routes from the start; its second test feeds the guard a router with an extra route, so the guard is shown to bite rather than assumed to |

**Options.** (a) Weaken each guard so the phase's Done Criteria hold on day one; (b) leave them red
and record which phase turned each green.

**Why.** A guard weakened to pass before its subject exists asserts nothing, and the plan says so
in Phase 1's task 9. The red runs are the evidence that the guards bite: S-317 named all eight
sites, S-320 named the unmeasured roles, and S-328 named the missing call site.

### A-13 — The plan's S-324 preview line is the shipped one

**Decision.** S-324's prose calls the preview line "This changes the bucket"; the shipped copy is
`'Was Close on the <date> reading'` (`lib/domain/rules/snapshot_preview.dart:72`), pinned by
S-241. The test asserts the shipped wording.

**Options.** (a) Change the copy; (b) assert the shipped copy.

**Why.** D-74 leaves `lib/domain/rules/` untouched and the copy is pinned by an existing
scenario. The scenario's subject — that the save was accepted and the sheet reported it — is
unchanged.

### A-14 — `positionDetailControllerProvider` is `autoDispose`, so the Phase 5 tests hold a listener

**Decision.** Every Phase 5 test that reads `PositionDetailState` after the sheet pops holds a
`container.listen(...)` subscription, and every Phase 5 fixture is wall-clock relative
(`wallNow ± n days`) with `takenAt` inside `[leg.openedAt, leg.expiration]`.

**Options.** (a) Read the provider after the pop; (b) hold a listener.

**Why.** The sheet's own pop disposes the autoDispose provider, so a read after the pop sees a
fresh, empty state — that is what made `bucket == null` and `lastSnapshotChangedBucket == null`
after a *successful* save, and it is a property of the shipped design, not of the test.
`updateSnapshot` reclassifies through `load()` with the real `DateTime.now()` (S-140), so a fixed
calendar date would have been a fixture that expired; the wall-clock fixture is what makes S-335
("two identical saves in the same second") reproducible.

### A-15 — S-331 asserts the sheet's badge, scoped, and refreshes the entitlement

**Decision.** S-331's Today→Portfolio→sheet path refreshes `entitlementControllerProvider` before
asserting, and scopes its bucket assertions to `PositionDetailSheet`/`BucketBadge`.

**Options.** (a) Assert on the screen's whole tree; (b) scope them.

**Why.** Today's own count chips render the same bucket words as the sheet behind it, so an
unscoped `find.text('Roll')` finds two; and the Pro gate reads `entitlementControllerProvider`,
not the gateway (S-277), so a fixture that answers "active" at the gateway still shows the
non-Pro path until the controller refreshes. Both are properties of the shipped design.

### A-16 — The Settings, `rule_profile_section`, `pro_plan_section`, roll-planner, assignment and
share-card-screen files needed no new wrapper

**Decision.** The "three labels" Phase 4 asks Settings' surfaces for are the three the shipped
copy already names (`profit target 50% · assign 0.7 · bands 0.3/0.35/0.4` and its siblings), and
the roll planner's and assignment flow's figures likewise. `kAppDisclaimer` and both SnackBars are
untouched, as D-74 requires.

**Options.** (a) Wrap every figure in a redundant `Semantics`; (b) add a wrapper only where a
figure would otherwise be spoken bare.

**Why.** D-61 labels a number when one node's label carries the quantity name **and** the value;
where the shipped string already does that (`'Delta 0.52 at or above the 0.35 band'`), a wrapper
adds a second node saying the same thing and breaks the "smallest widget containing both" rule of
D-62. The harness's rows for these surfaces assert the shipped labels, so a later edit that strips
a quantity name fails the audit.

**The same holds for `lib/features/journal/share_card_screen.dart`**, which the Files Affected
table names but which is also untouched: the screen hosts the card and pushes nothing that needs a
label of its own, so no wrapper was added there either.

### A-17 — Review fix round 1: the 14 findings, and what each one changed

**Decision.** The code review of 30 September returned **CHANGES_REQUESTED** with 14 findings (1
blocker, 2 major, 11 minor). All 14 are addressed in one bounded round, each in the place the
finding named. The round adds no dependency, changes no threshold, and touches no `lib/` file the
wave had not already touched except `lib/widgets/journal_row.dart`'s semantics wrapper.

| # | Severity | What changed |
|---|---|---|
| 1 | blocker | `journal_row.dart` wraps its `InkWell` in `Semantics(button: onTap != null, …)`. `ListTile` set that flag for free from `onTap != null`; `InkWell` sets only the tap *action*, so the rewrite had silently dropped the role. The wrapper merges into one node (`button: true`, one tap action, no duplicate announcement) — verified against the semantics tree before and after |
| 2 | major | The two Existing-Functionality Impact rows (`app_theme.dart`, `paywall_screen.dart`) now describe A-1's outcome, and Open questions 4 and 17 are annotated with the override they predicted. The "Edited source" list and the roll-planner, assignment and Settings rows in Files Affected are corrected the same way — they were the same falsity in a second table |
| 3 | major | `journal_row_test.dart` gains three behavioural tests: the tap fires `onTap`, the node is a button with a tap action, and the target is ≥48 dp. **Confirmed red first**: the semantics assertion failed on the pre-fix code (tap and size passed), then green |
| 4 | minor | The spoken `3 of 9` is kept — the reviewer's own lean — and the divergence is now commented at the harness row and named as A-4's one exception, so the "every pair is a rendered label" claim is no longer false |
| 5 | minor | A-7 and the code comment now attribute the golden delta to the newly added 4 px gap (title identical, subtitle 1 px, trailing figures ±2 px) rather than to `ListTile`'s baseline positioning. The gap is kept: it is what replaced the dropped centred alignment |
| 6 | minor | S-317's colour-literal guard added, with a **real-file** negative fixture (`lib/core/theme`) rather than a hand-written string. S-317's own negative fixture was upgraded the same way, which is the looseness finding 12 named |
| 7 | minor | `paywall_screen_test.dart` asserts the selected and unselected `Icon.color` (`scheme.primary` / `scheme.onSurfaceVariant`, and explicitly not `scheme.outline`), so reverting `paywall_screen.dart:320` fails a test |
| 8 | minor | S-320 matches `auditedRoles`' **map keys** (the map is now public) instead of the contrast test's file text, and `_scan` no longer truncates at `//` or skips `reason:` lines — a new `_codeOnly` strips comments and blanks string contents, so prose cannot satisfy a guard and a `//` inside a string cannot hide code |
| 9 | minor | S-328 pins `pubspec.yaml` by content (`_fingerprint`, 6061 bytes) instead of comparing against `HEAD`, which degenerates once the wave is committed; S-330 matches **full** route paths, computed by joining nested `path:` segments, so `/share` can no longer satisfy `/journal/share` |
| 10 | minor | A-16 now names `lib/features/journal/share_card_screen.dart` as untouched too |
| 11 | minor | Four Progress/Files-Affected counts corrected: 36 rows (29 + 7), `label_value_row_test` 6, `grep -c "schemaVersion"` 1, and the roll-planner row no longer claims labels were added |
| 12 | minor | `docs/architecture/wheel-triage.md`: scope line widened to Wave 4a, "five" private copies, the guards sentence softened, and the colour-literal guard added to the enumeration |
| 13 | minor | The residue section records the one gap in the coverage guard: the 18 rows whose surface needs an `open:` helper are hand-listed; only routes are derived |
| 14 | minor | The "a `Semantics` node merges its subtree" claim is corrected in the plan's harness snippet and the harness's own doc comment — A-5 says the opposite. The double announcement it describes is **not** changed: D-62 forbids both remedies, so it is the owner-only Open question 7 |

**Options.** For finding 1: (a) the `Semantics` wrapper; (b) go back to `ListTile` with a taller
trailing slot. For finding 4: (a) assert the rendered `3 / 9`; (b) keep the spoken string and name
the exception. For finding 14: (a) leave the comment; (b) correct it and escalate the underlying
behaviour.

**Why.** (1a) is the smaller change and keeps the row's layout, which is what moved the goldens;
the wrapper is asserted by finding 3's test, so a future rewrite that drops the flag fails.
(4b) is the reviewer's lean and the friendlier reading; the audit still bites because the value
half is asserted. (14b) is the only honest option — A-5 already records the opposite — and the
behaviour is a product call the wave cannot take alone.

**Nothing in this round is a silent fix.** The one `lib/` behaviour change is the button flag;
every other change is a test, a comment or a plan/doc correction. The three `(owner)` device
checks still block closure (D-73).

**Resume verification.** The round was interrupted by a stray `dart format lib/ test/` and
finished in a second run; no finished finding was redone. The formatter left three
`curly_braces_in_flow_control_structures` infos (`snapshot_sheet.dart:368`,
`a11y_structure_test.dart:348`, `position_detail_controller_test.dart:1261`); each was braced by
hand, in place, with no reformatting. Final state: `flutter analyze` **No issues found**;
`flutter test` **1163 passed, 0 failed** (baseline 1076); the tone, rules-purity and
colour-literal greps empty. Finding 1's semantics tree, dumped from the row with a tap attached:
one node, `flags: isButton, isFocusable`, `actions: focus, tap` — the role and exactly one tap
action, with no second button node.

**Formatter churn against `HEAD`.** The same stray run means the 19 shipped code and test files now
carry formatter-only churn against `HEAD`, so a reader of `git diff main` will meet wrapping hunks
that no Stage 4B item explains. The two governor process edits to `.claude/commands/feature.md` (the
diff-size check and the never-format-the-tree rule) were landed as their own commit, `b6e43cd`, not
inside this wave.

## Feedback

[empty — fold into a new Iteration block when non-empty, then clear]

## Open questions

Split into questions only the owner can answer, and questions this plan resolved with a logged
assumption that the owner may veto before the phase that depends on it.

### Owner-only

1. **Does the bucket-change haptic fire on a leg's *first* reading?** This plan says **no** (D-67):
   `SnapshotPreview.changeLine` is deliberately suppressed when there is no previous reading
   (`snapshot_preview.dart:71`), so the sheet says nothing and a buzz would be unexplained. The
   other reading — "the user just learned the verdict for the first time, so confirm it" — is
   defensible and would make S-325 assert the opposite. Changing it is one condition in
   `updateSnapshot` plus one scenario's expectation.
2. **Is 3.2 the right ceiling for `kMaxTextScale`?** This plan pins 3.2 because iOS AX5 scales body
   text by about 3.12×, so 3.2 is that ceiling with margin (D-59). If the owner's device at AX5
   clips something the harness passed at 3.2, the constant moves and S-314 records the new value;
   if 3.2 is judged stricter than the product needs, it moves down and S-314 records that too.
   Either way the number lives in one place.
3. **Should the harness cover every dialog and date picker, or only the screens?** This plan
   includes all 22 rows (D-60), because a dialog is where a money figure appears with no room and
   the brief says "on every screen". The cheaper alternative — routes only — would leave the five
   dialogs and six date pickers unaudited until someone notices. The cost is roughly a dozen extra
   harness rows.
4. **Does the unselected plan indicator's 3:1 bar warrant a token change, or a different
   affordance?** This plan proposed changing `AppTokens.{dark,light}.outline` (D-69). **Resolved
   the other way:** A-1's governor override left both token values alone and painted the unselected
   indicator with `scheme.onSurfaceVariant` (7.32:1 dark, 6.24:1 light) — the second, more
   conservative option named here — and S-321 now asserts that colour, so a revert is not silent.
5. **Should the four hand-rolled percentage formatters be folded into `format.percentText`?** This
   plan leaves them (D-74), because they do not all use the same precision, so folding them in is
   a display change rather than a consolidation. The architecture doc already carries it as an
   "observation, not a work item". Say if the wave should close it while it is in three of the
   four files.
6. **The three `(owner)` device checks.** They are listed, they are `(owner)` items, and D-73
   makes them block wave closure rather than any phase. Confirm that is the right gate — the
   alternative is to let the wave close and carry them into Stage 9's pre-launch list, which is
   where the brief's §6 launch gate would catch them anyway.

7. **Is each labelled figure's double announcement acceptable?** The traversal yields each
   labelled number twice: once inside the wrapper's own label, which names the quantity, and once
   as the bare child `Text` that is still its own node, because a `Semantics(label:)` wrapper does
   not merge its subtree (A-5) and D-62 forbids `MergeSemantics`/`ExcludeSemantics`. VoiceOver
   therefore reads "Delta 0.52" and then "0.52". The remedies are all decisions this plan cannot
   take alone: `MergeSemantics` on the row (what D-62 bans), `ExcludeSemantics` on the child `Text`
   (also banned, and it would drop the value from the tree if the wrapper's label ever drifted from
   what the screen renders), or dropping the wrapper and rewording the rendered string. The audit
   passes either way — it asserts that the labelled node exists, not that the tree is free of
   duplicates — so this is a product call, not a defect against this wave's criteria.

### Resolved with a logged assumption — vetoable

8. **`kMaxTextScale` is 3.2, a flat `TextScaler.linear`.** Assumed iOS's largest accessibility
   size (AX5, ≈3.12×) is the ceiling the brief means by "the largest accessibility size", and that
   a flat multiplier is the right probe rather than a non-linear system scaler. (D-59)
9. **The audit is one table with 22 rows, including sheets, dialogs and date pickers.** Assumed
   "every screen" in the brief includes every surface a user can read a number on, not only the 12
   routes. (D-60)
10. **A label must match on one line, not merely appear somewhere in the node.** Assumed the
   assertion is worthless otherwise: a bare child `Text('Delta')` is its own node with its own
   label (A-5), so a looser "the two strings appear somewhere in the tree" check would pass on a
   node that names the quantity and a different node that carries the value. (D-61)
11. **`--` is spoken as "not available", and a `$`/`%` symbol is kept in the label.** Assumed the
    app's own formatting is what should be read aloud, matching the two shipped label styles, and
    that VoiceOver's en-US reading of both symbols is correct. (D-61)
12. **No existing label is reworded, including S-304's five.** Assumed the brief's "audits every
    screen against it" means the screens that already comply are left alone, and that S-304 is the
    proof rather than a thing to update. (D-61)
13. **`LabelValueRow` stacks at ≥2.0 and keeps the shipped one-line shape below it.** Assumed a row
    that stacks at every scale is restyling, which the brief excludes, and that 2.0 is where a
    `Flexible` label starts to ellipsise in practice. (D-64)
14. **A `HelpChip` inside a labelled row stays its own node.** Assumed the chip's tap target is
    worth more than the label's brevity, and that merging it would make the number's node announce
    the chip's topic. (D-62)
15. **The truncation ban is a source scan, because `takeException()` cannot see an ellipsis.**
    Assumed an ellipsised `Text` throws nothing — which is the point of an ellipsis — so the ban
    needs its own guard rather than a runtime assertion. (D-63)
16. **The ellipsis allow-list starts empty.** Assumed all eight current sites can and should be
    cleared, so the guard's strongest form is "the grep finds nothing" rather than a list of
    exceptions. (D-63)
17. **The `outline` token changes rather than the paywall's icon colour.** Assumed the token is the
    single owner of the colour and that its one screen reader plus M3's defaults make the change
    bounded. **Overridden:** A-1 shipped the alternative — the icon colour, no token change — and
    the alternative is what Q4 above now records. (D-69, overridden by A-1)
18. **Dividers and decorative card borders are exempt from 3:1.** Assumed `outlineVariant` is not
    "required to identify a component or state", since the card's background already separates it
    and the selected state is marked twice by `scheme.primary`. Pinned so a reviewer can challenge
    it by name. (D-68)
19. **`accent on accentContainer` (3.91:1 light) and `error on errorContainer` (4.11:1 light) are
    not audited pairs.** Assumed no screen paints them — the containers' own ink roles are what
    every screen paints — so requiring 4.5:1 of them would force two token changes for a pairing
    that does not exist. (D-68)
20. **The haptic is `mediumImpact`.** Assumed a bucket change is a confirmation, not an alarm
    (`heavyImpact`) and not a scroll tick (`selectionClick`). (D-65)
21. **The haptic seam has a default implementation, unlike `wheelRepositoryProvider`.** Assumed a
    missing override should mean "vibrate normally" rather than a crash, because a haptic is
    presentation and not a choice anyone must make on purpose. (D-65)
22. **The flag is a nullable `bool`, not a `bool`.** Assumed "no save has happened" and "the last
    save changed nothing" must not be the same value, because the first is what a fresh controller
    is in. (D-66)
23. **`updateSnapshot` keeps returning `bool`.** Assumed the existing pattern — read the extra
    facts back through the provider, as `snapshot_warning` already is at
    `snapshot_sheet.dart:398` — is worth more than a typed result, which would touch every caller
    and every test. (D-66)
24. **The flag is cleared by `load()`, not by the sheet.** Assumed a state fact should not outlive
    the load that invalidates it, and that the sheet's single firing site cannot re-fire in any
    case. (D-66)
25. **SnackBars are exempt from the number-label audit.** Assumed a SnackBar is a sentence
    announced as it appears rather than a screen a user navigates, and that its default wrapping
    makes the truncation ban unnecessary there. (D-60)
26. **No new golden, and a moved golden is a finding.** Assumed everything this wave asserts is
    assertable without one, and that a baseline regenerated for no `lib/` reason is how a golden
    stops being evidence. (D-71)
27. **The Stage 6 contract is a doc section plus the route-coverage test.** Assumed the brief's
    "how future Stage 6 screens will be held to the same standards" is satisfied by a mechanism
    that already bites plus a written obligation, with no Stage 6 surface, route or abstraction
    created. (D-72)
28. **Owner checks block the wave, not a phase.** Assumed the brief's §8 "run the checks marked
    (owner) and record them in the wave's plan" means the wave is not closed without them, and
    that a phase should not stall on a device check an agent cannot run. (D-73)
29. **The harness's `expectedLabels` are authored from the quantity, not generated from the
    output.** Assumed a generated table would be self-fulfilling and would pass on a screen that
    prints a bare number. (Notes)
30. **Phase 4 does not edit `snapshot_sheet.dart`'s save handler.** Assumed one owner per change
    surface is worth splitting the audit into two handoffs, and that the preview's labels above
    the handler are a different surface from the handler itself. (Notes)
31. **`flutter build ios --simulator --no-codesign` is a Phase 6 Done Criterion** even though no
    build-affecting file changes. Assumed the wave should still prove the acceptance build, since
    it is a Done Criterion on every phase of the project. (Phase 6)
