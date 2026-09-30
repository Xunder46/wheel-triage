import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/core/purchases/pro_plans.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/models/user_preferences.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/widgets/help_chip.dart';

import 'fake_purchase_gateway.dart';

/// The largest accessibility text size this wave certifies. Declared exactly
/// once, here (D-59) -- `grep -rn "TextScaler.linear(" test/` finds this
/// declaration and nothing else.
const double kMaxTextScale = 3.2;

/// Which book a row is audited against.
enum SurfaceFixture { populated, empty }

/// The book every audited surface is driven from. One book, so a surface that
/// reads another's data cannot pass by accident, and so the leg ids the route
/// tokens resolve to are the same everywhere.
class SurfaceBook {
  SurfaceBook({
    required this.repo,
    this.legId = '',
    this.legTicker = '',
    this.noReadingLegId = '',
    this.closedLegId = '',
    this.pastExpirationLegId = '',
    this.inTheMoneyExpiredLegId = '',
  });

  final InMemoryWheelRepository repo;

  /// An open put leg with a reading (INTC).
  final String legId;

  /// The ticker [legId]'s underlying carries, so a row can address its Today
  /// row among the others.
  final String legTicker;

  /// An open put leg with no snapshot at all (PFE).
  final String noReadingLegId;

  /// A leg on a closed cycle whose close fee is missing (XYZ).
  final String closedLegId;

  /// An open leg past its expiration, out of the money -- covered by "Mark all
  /// expired" (WBD).
  final String pastExpirationLegId;

  /// An open leg past its expiration, in the money -- listed with its own
  /// actions instead (GRPN).
  final String inTheMoneyExpiredLegId;

  /// Resolves a row's route, whose `:legId`-style tokens are the router's own
  /// fragment names so the route-coverage guard reads the same vocabulary.
  String routeFor(String route) => route
      .replaceAll(':closedLegId', closedLegId)
      .replaceAll(':noReadingLegId', noReadingLegId)
      .replaceAll(':pastExpirationLegId', pastExpirationLegId)
      .replaceAll(':inTheMoneyExpiredLegId', inTheMoneyExpiredLegId)
      .replaceAll(':legId', legId);
}

DateTime _day(int offsetDays) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: offsetDays));
}

Future<String> _openLeg(
  InMemoryWheelRepository repo, {
  required String ticker,
  required Decimal strike,
  required Decimal credit,
  required int expirationInDays,
  OptionType optionType = OptionType.put,
  Decimal? mark,
  double? delta,
  double? iv,
  Decimal? spot,
  bool reading = true,
  int readingAgeDays = 0,
  int openedDaysAgo = 30,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: optionType,
      strike: strike,
      expiration: _day(expirationInDays),
      contracts: 2,
      openedAt: _day(-openedDaysAgo),
      openCreditPerShare: credit,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  if (reading) {
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: result.leg.id,
        takenAt: _day(-readingAgeDays),
        optionMark: mark ?? credit,
        underlyingPrice: spot ?? Decimal.fromInt(12),
        deltaAsEntered: delta ?? -0.20,
        deltaConvention: DeltaConvention.position,
        iv: iv ?? 45,
      ),
    );
  }
  return result.leg.id;
}

/// Builds the audited book. `populated` is the reference book the S-015
/// fixture established, reduced to one leg per bucket plus the three special
/// legs the modal rows need; `empty` is a repository with no legs at all, for
/// the six surfaces that have an empty state.
Future<SurfaceBook> buildSurfaceBook(SurfaceFixture fixture) async {
  final repo = InMemoryWheelRepository();
  await repo.updatePreferences(
    UserPreferencesData(wheelCapital: Decimal.parse('30000')),
  );
  if (fixture == SurfaceFixture.empty) return SurfaceBook(repo: repo);

  final close = await _openLeg(
    repo,
    ticker: 'INTC',
    strike: Decimal.parse('20'),
    credit: Decimal.parse('1.00'),
    expirationInDays: 18,
    mark: Decimal.parse('0.45'),
    delta: -0.20,
    spot: Decimal.parse('22'),
    // Older than `kAgingDays`, so Today renders the row's 'Update' action --
    // the only way into the SnapshotSheet from the audit.
    readingAgeDays: 11,
  );
  await _openLeg(
    repo,
    ticker: 'F',
    strike: Decimal.parse('12'),
    credit: Decimal.parse('1.00'),
    expirationInDays: 11,
    mark: Decimal.parse('0.90'),
    delta: -0.78,
  );
  await _openLeg(
    repo,
    ticker: 'SOFI',
    strike: Decimal.parse('14'),
    credit: Decimal.parse('1.00'),
    expirationInDays: 4,
    mark: Decimal.parse('0.90'),
    delta: -0.52,
  );
  await _openLeg(
    repo,
    ticker: 'SBET',
    strike: Decimal.parse('11'),
    credit: Decimal.parse('1.00'),
    expirationInDays: 18,
    optionType: OptionType.call,
    mark: Decimal.parse('0.60'),
    delta: -0.2534,
    iv: 75,
  );
  final noReading = await _openLeg(
    repo,
    ticker: 'PFE',
    strike: Decimal.parse('25'),
    credit: Decimal.parse('0.80'),
    expirationInDays: 25,
    reading: false,
  );
  final pastExpiration = await _openLeg(
    repo,
    ticker: 'WBD',
    strike: Decimal.parse('9'),
    credit: Decimal.parse('0.55'),
    expirationInDays: -3,
    mark: Decimal.parse('0.90'),
    delta: -0.40,
    spot: Decimal.parse('12'),
  );
  // In the money at its last reading, so "Mark all expired" does not cover it
  // and the card lists it with its own two actions -- the single-leg dialog's
  // only door.
  final inTheMoneyExpired = await _openLeg(
    repo,
    ticker: 'GRPN',
    strike: Decimal.parse('10'),
    credit: Decimal.parse('0.50'),
    expirationInDays: -3,
    mark: Decimal.parse('2.00'),
    delta: -0.90,
    spot: Decimal.parse('8'),
  );

  final closedUnderlying = await repo.getOrCreateUnderlying('XYZ');
  final closedCycle = await repo.createCycle(
    underlyingId: closedUnderlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('30'),
      expiration: _day(-10),
      contracts: 1,
      openedAt: _day(-40),
      openCreditPerShare: Decimal.parse('1.20'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.closeLeg(
    legId: closedCycle.leg.id,
    reason: CloseReason.closedEarly,
    closeDebitPerShare: Decimal.parse('0.20'),
    closedAt: _day(0),
  );

  return SurfaceBook(
    repo: repo,
    legId: close,
    legTicker: 'INTC',
    noReadingLegId: noReading,
    closedLegId: closedCycle.leg.id,
    pastExpirationLegId: pastExpiration,
    inTheMoneyExpiredLegId: inTheMoneyExpired,
  );
}

/// One row of the audit's enumeration: a surface, how to reach it, and the
/// numbers it must name. `expectedLabels` pairs the quantity's name with the
/// value string the screen itself renders (D-61).
class AuditedSurface {
  const AuditedSurface({
    required this.name,
    required this.route,
    this.fixture = SurfaceFixture.populated,
    this.open,
    this.expectedLabels = const [],
    this.proActive = true,
    this.offerings,
  });

  final String name;

  /// A router fragment, optionally carrying a `:legId`-style token the
  /// [SurfaceBook] resolves.
  final String route;

  final SurfaceFixture fixture;

  /// Drives the surface into the state being audited -- the sheet, the
  /// dialog, the date picker, the filled form. Takes the book so a row can
  /// address a leg by its fixture id.
  final Future<void> Function(WidgetTester tester, SurfaceBook book)? open;

  final List<(String quantity, String value)> expectedLabels;

  /// Whether the fixture's entitlement is active. The paywall's plan rows --
  /// and their prices -- only render when it is not.
  final bool proActive;

  /// What the store answers, when the row needs plans to render at all.
  final ProOfferings? offerings;
}

/// The three plans the store returns in the audit's paywall fixture (D-60's
/// row 8): monthly, annual with a trial, and lifetime.
final ProOfferings kAuditOfferings = ProOfferings(
  plans: [
    ProPlanOffer(
      productId: kProMonthlyProductId,
      priceString: r'$4.99',
      price: Decimal.parse('4.99'),
      currencyCode: 'USD',
    ),
    ProPlanOffer(
      productId: kProAnnualProductId,
      priceString: r'$29.99',
      price: Decimal.parse('29.99'),
      currencyCode: 'USD',
      trial: const TrialOffer(units: 7, unit: TrialPeriodUnit.day),
    ),
    ProPlanOffer(
      productId: kProLifetimeProductId,
      priceString: r'$79.99',
      price: Decimal.parse('79.99'),
      currencyCode: 'USD',
    ),
  ],
);

/// Taps the first widget rendering [text].
Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Taps the widget carrying [key].
Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// The audit's enumeration (D-60). One row per route and one row per modal
/// surface that renders a number or a bucket reason. A new `GoRoute` in
/// `lib/core/app_router.dart` fails the route-coverage guard until it has a
/// row here.
final List<AuditedSurface> auditedSurfaces = [
  // 1 -- S-315's "the form filled" row: the blank form only ever renders
  // `not available`, which would leave every quantity name unasserted.
  const AuditedSurface(
    name: 'ScreenerScreen',
    route: '/screener',
    open: _fillScreener,
    expectedLabels: [
      // The shipped label speaks the friendlier "3 of 9" while the screen
      // renders "3 / 9" (`screener_screen.dart:354`); the spoken string is
      // what the harness asserts, and A-4 names it as the one exception to
      // "expectedLabels are the rendered labels".
      ('Sorting score', '3 of 9'),
      ('Annualised yield', '30.4%'),
      ('One-sigma move', r'$3.10'),
      ('Strike distance', r'$2.00'),
      ('Strike distance (sigmas)', '0.65'),
    ],
  ),
  // 2 -- with the optional disclosure open and the figures worked out, plus
  // the blank form as its own row below.
  const AuditedSurface(
    name: 'RecordTradeScreen',
    route: '/record',
    open: _fillRecord,
    expectedLabels: [
      // The shipped label spells the unit out for the screen reader
      // (`record_trade_screen.dart:417`), so the assertion is the unit.
      ('Annualised yield', 'percent'),
      ('Capital committed', r'$2,200'),
    ],
  ),
  // 3
  const AuditedSurface(
    name: 'JournalScreen',
    route: '/journal',
    expectedLabels: [
      ('Win rate', '100%'),
      ('Average days in cycle', '40'),
      ('Average premium capture (median)', '83%'),
      ('Total premium collected', r'$100.00'),
      ('Total fees paid', r'$0.00'),
      ('XYZ', r'$100.00'),
      ('Net result', 'not available'),
      ('Return on capital', 'not available'),
    ],
  ),
  // 4
  const AuditedSurface(
    name: 'ShareCardScreen',
    route: '/journal/share',
    expectedLabels: [
      ('Return on capital', '3.3%'),
      ('Cycles closed', '1'),
      ('Closed positive', '1 of 1'),
      ('Average days in cycle', '40'),
      ('Median premium capture', '83%'),
    ],
  ),
  // 5 -- S-304's five, unchanged: the committed total, a concentration row,
  // the net position delta, a bucket count, and an obligation row.
  const AuditedSurface(
    name: 'PortfolioScreen',
    route: '/portfolio',
    expectedLabels: [
      ('Capital committed now', r'$18,000'),
      ('PFE', '17%'),
      ('Net position delta', '−351 shares'),
      ('Assign', '1'),
      ('SOFI', r'$2,800 cash if assigned'),
    ],
  ),
  // 6
  const AuditedSurface(
    name: 'SettingsScreen',
    route: '/settings',
    expectedLabels: [
      ('profit target', '50%'),
      ('assign', '0.7'),
      ('IV rank', '30'),
      ('yield', '20%'),
      ('delta', '0.3'),
      ('tail extrinsic', r'$0.05'),
    ],
  ),
  // 7 -- the explainer carries no figure at all.
  const AuditedSurface(name: 'FirstRunExplainerScreen', route: '/first-run'),
  // 8 -- the store's three plans, with the entitlement inactive so the rows
  // and their prices render.
  AuditedSurface(
    name: 'PaywallScreen',
    route: '/paywall',
    proActive: false,
    offerings: kAuditOfferings,
    expectedLabels: [
      ('Monthly', r'$4.99 a month'),
      ('Lifetime', r'$79.99 once'),
    ],
  ),
  // 9
  const AuditedSurface(
    name: 'TodayScreen',
    route: '/positions',
    expectedLabels: [
      ('Assign', '1'),
      ('Roll', '1'),
      ('Close', '1'),
      ('Leave', '1'),
      ('No data', '1'),
      ('Net premium', r'-$20'),
      ('Year to date', r'$1,270'),
      ('Committed now', r'$18,000'),
      ('Delta', '0.78 at or above 0.70'),
    ],
  ),
  // 10
  const AuditedSurface(
    name: 'PositionDetailSheet',
    route: '/positions/:legId',
    expectedLabels: [
      ('Delta magnitude', '0.2000'),
      ('Captured', '55%'),
      ('Roll band in use', '0.35'),
      ('One-sigma move', r'$2.79'),
      ('Extrinsic remaining', r'$0.45'),
      ('Cycle cumulative credit', r'$1.00'),
      ('Total premium', r'$200.00'),
      ('Total fees', r'$0.00'),
      ('Stock P&L', r'$0.00'),
      ('Net result', r'$200.00'),
      ('Peak capital committed', r'$4000.00'),
      ('Return on capital', '5.0%'),
      ('Annualised return', '60.8%'),
      ('Days held', '30'),
      ('Roll count', '0'),
    ],
  ),
  // 11 -- the planner renders no candidate until one is added, and the
  // candidate card is where its figures live.
  const AuditedSurface(
    name: 'RollPlannerScreen',
    route: '/positions/:legId/roll',
    open: _addRollCandidate,
    expectedLabels: [
      ('New strike', r'$21'),
      ('Strike moves up by', r'$1'),
      ('Annualised yield on extended duration', '24.4%'),
      ('Debit roll', r'$0.05'),
    ],
  ),
  // 12 -- the basis figures are on the second step, behind the first
  // step's confirmation.
  const AuditedSurface(
    name: 'AssignmentFlowScreen',
    route: '/positions/:legId/assign',
    open: _confirmAssignment,
    expectedLabels: [
      ('shares acquired at', '200'),
      ('Wheel-adjusted basis', r'$19'),
      ('Tax basis', r'$19'),
    ],
  ),
  // 13 -- with the preview card showing, so the verdict, its reason and the
  // three figures are all in the audited state.
  const AuditedSurface(
    name: 'SnapshotSheet',
    route: '/positions',
    open: _fillSnapshotPreview,
    expectedLabels: [
      ('Magnitude', '0.2000'),
      ('Captured', '55%'),
      ('Roll band in use', '0.35'),
      ('Extrinsic remaining', r'$0.45'),
    ],
  ),
  // 14
  const AuditedSurface(
    name: 'HelpSheet',
    route: '/screener',
    open: _openHelpSheet,
  ),
  // 15
  const AuditedSurface(
    name: 'FeesSheet',
    route: '/positions/:closedLegId',
    open: _openFeesSheet,
    expectedLabels: [('leg missing fee data', '1')],
  ),
  // 16
  const AuditedSurface(
    name: 'CycleSummaryCard',
    route: '/journal',
    expectedLabels: [
      ('Win rate', '100%'),
      ('Average premium capture (median)', '83%'),
      ('Total fees paid', r'$0.00'),
    ],
  ),
  // 17
  const AuditedSurface(
    name: 'PositionDetailSheet close dialog',
    route: '/positions/:legId',
    open: _openCloseDialog,
  ),
  // 17
  const AuditedSurface(
    name: 'PositionDetailSheet mark-expired dialog',
    route: '/positions/:legId',
    open: _openMarkExpiredDialog,
  ),
  // 18
  const AuditedSurface(
    name: 'PastExpirationCard mark-all dialog',
    route: '/positions',
    open: _openMarkAllDialog,
  ),
  // 18
  const AuditedSurface(
    name: 'PastExpirationCard single dialog',
    route: '/positions',
    open: _openSinglePastExpirationDialog,
  ),
  // 19
  const AuditedSurface(
    name: 'RollPlanner new-candidate dialog',
    route: '/positions/:legId/roll',
    open: _openNewCandidateDialog,
  ),
  // 19
  const AuditedSurface(
    name: 'RollPlanner confirm-roll dialog',
    route: '/positions/:legId/roll',
    open: _openConfirmRollDialog,
  ),
  // 20 -- reachable only through the import flow, which needs a file the
  // harness cannot supply; the Settings row above audits the screen it opens
  // on, and its copy is pinned by the import suite.
  const AuditedSurface(name: 'Settings replace dialog', route: '/settings'),
  // 21 -- the five date pickers, one per call site.
  const AuditedSurface(
    name: 'Date picker (screener)',
    route: '/screener',
    open: _openChange,
  ),
  const AuditedSurface(
    name: 'Date picker (record)',
    route: '/record',
    open: _openOtherDate,
  ),
  const AuditedSurface(
    name: 'Date picker (snapshot sheet)',
    route: '/positions',
    open: _openSnapshotDatePicker,
  ),
  const AuditedSurface(
    name: 'Date picker (roll planner)',
    route: '/positions/:legId/roll',
    open: _openRollDatePicker,
  ),
  const AuditedSurface(
    name: 'Date picker (assignment)',
    route: '/positions/:legId/assign',
    open: _openAssignmentDatePicker,
  ),
  // 22
  const AuditedSurface(
    name: 'ExportReminderBanner',
    route: '/positions',
    expectedLabels: [('days since your last export', '30')],
  ),
];

Future<void> _openChange(WidgetTester tester, SurfaceBook book) =>
    tapText(tester, 'Change');

Future<void> _openOtherDate(WidgetTester tester, SurfaceBook book) =>
    tapText(tester, 'Other date…');

Future<void> _openHelpSheet(WidgetTester tester, SurfaceBook book) async {
  await tester.tap(find.byType(HelpChip).first);
  await tester.pumpAndSettle();
}

Future<void> _openSnapshotSheet(WidgetTester tester, SurfaceBook book) async {
  // PFE shows an 'Update' action too, so the tap has to be scoped to the
  // audited leg's own row.
  final row = find
      .ancestor(of: find.text(book.legTicker), matching: find.byType(InkWell))
      .first;
  await tester.tap(find.descendant(of: row, matching: find.text('Update')));
  await tester.pumpAndSettle();
}

/// The screener with its form filled. The DTE field is typed explicitly so
/// the outputs are the same whichever day the suite runs; the expiration the
/// DTE moves is date-dependent and is not asserted.
Future<void> _fillScreener(WidgetTester tester, SurfaceBook book) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'INTC');
  await tester.enterText(fields.at(1), '22');
  await tester.enterText(fields.at(2), '24');
  await tester.enterText(fields.at(3), '0.55');
  await tester.enterText(fields.at(4), '30');
  await tester.enterText(fields.at(5), '45');
  await tester.enterText(fields.at(6), '48');
  await tester.pumpAndSettle();
}

/// The record form with the fields the preview needs, and the optional
/// disclosure open (D-60's row 2). The annualised yield depends on the days
/// to the default Friday, so only the capital figure is asserted by value.
Future<void> _fillRecord(WidgetTester tester, SurfaceBook book) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'INTC');
  await tester.enterText(fields.at(1), '22');
  await tester.enterText(fields.at(2), '0.55');
  await tapText(tester, 'Add optional fields');
}

/// The snapshot sheet with its three required fields filled, which is what
/// makes the preview card render (S-324's change line lives there).
Future<void> _fillSnapshotPreview(WidgetTester tester, SurfaceBook book) async {
  await _openSnapshotSheet(tester, book);
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '0.45');
  await tester.enterText(fields.at(1), '22');
  await tester.enterText(fields.at(2), '0.20');
  await tester.pumpAndSettle();
}

Future<void> _openSnapshotDatePicker(
  WidgetTester tester,
  SurfaceBook book,
) async {
  await _openSnapshotSheet(tester, book);
  await tapText(tester, 'Change');
}

Future<void> _openFeesSheet(WidgetTester tester, SurfaceBook book) =>
    tapText(tester, 'Add fees');

Future<void> _openCloseDialog(WidgetTester tester, SurfaceBook book) =>
    tapText(tester, 'Close');

Future<void> _openMarkExpiredDialog(WidgetTester tester, SurfaceBook book) =>
    tapText(tester, 'Mark expired');

Future<void> _openMarkAllDialog(WidgetTester tester, SurfaceBook book) =>
    tapKey(tester, 'mark-all-expired');

Future<void> _openSinglePastExpirationDialog(
  WidgetTester tester,
  SurfaceBook book,
) => tapKey(tester, 'mark-expired-${book.inTheMoneyExpiredLegId}');

Future<void> _openNewCandidateDialog(WidgetTester tester, SurfaceBook book) =>
    tapText(tester, 'Add candidate');

Future<void> _openRollDatePicker(WidgetTester tester, SurfaceBook book) async {
  await _openNewCandidateDialog(tester, book);
  await tapText(tester, 'Change');
}

Future<void> _openConfirmRollDialog(
  WidgetTester tester,
  SurfaceBook book,
) async {
  await _addRollCandidate(tester, book);
  await tapText(tester, 'Confirm this roll');
}

/// Adds one candidate to the planner's list, which is what makes the
/// candidate card -- and its figures -- render.
Future<void> _addRollCandidate(WidgetTester tester, SurfaceBook book) async {
  await _openNewCandidateDialog(tester, book);
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '21');
  await tester.enterText(fields.at(1), '0.50');
  await tester.enterText(fields.at(2), '0.45');
  await tapText(tester, 'Add');
}

/// The assignment flow's second step, where the wheel-adjusted basis and the
/// tax basis render.
Future<void> _confirmAssignment(WidgetTester tester, SurfaceBook book) =>
    tapText(tester, 'Confirm assignment');

/// The assignment route's second step -- the call's own form, which carries
/// the date picker -- is only reachable once the assignment is recorded.
Future<void> _openAssignmentDatePicker(
  WidgetTester tester,
  SurfaceBook book,
) async {
  await tapText(tester, 'Confirm assignment');
  await tapText(tester, 'Change');
}

/// The empty variants -- the six surfaces that have an empty state, plus the
/// leg with no reading.
final List<AuditedSurface> auditedEmptySurfaces = [
  const AuditedSurface(
    name: 'ScreenerScreen (empty)',
    route: '/screener',
    fixture: SurfaceFixture.empty,
    expectedLabels: [
      ('Sorting score', 'not available'),
      ('Annualised yield', 'not available'),
      ('One-sigma move', 'not available'),
    ],
  ),
  const AuditedSurface(
    name: 'RecordTradeScreen (empty)',
    route: '/record',
    fixture: SurfaceFixture.empty,
    expectedLabels: [
      ('Annualised yield', 'not available'),
      ('Capital committed', 'not available'),
    ],
  ),
  const AuditedSurface(
    name: 'JournalScreen (empty)',
    route: '/journal',
    fixture: SurfaceFixture.empty,
  ),
  const AuditedSurface(
    name: 'ShareCardScreen (empty)',
    route: '/journal/share',
    fixture: SurfaceFixture.empty,
  ),
  const AuditedSurface(
    name: 'PortfolioScreen (empty)',
    route: '/portfolio',
    fixture: SurfaceFixture.empty,
    expectedLabels: [
      ('Capital committed now', r'$0'),
      ('Net position delta', '0 shares'),
      ('Assign', '0'),
    ],
  ),
  const AuditedSurface(
    name: 'TodayScreen (empty)',
    route: '/positions',
    fixture: SurfaceFixture.empty,
  ),
  const AuditedSurface(
    name: 'PositionDetailSheet (no reading)',
    route: '/positions/:noReadingLegId',
    expectedLabels: [
      ('Captured', 'not available'),
      ('Delta magnitude', 'not available'),
      ('Roll band in use', '0.30'),
      ('Total premium', r'$160.00'),
      ('Days held', '30'),
    ],
  ),
];

/// Every label in the accessibility traversal, in traversal order.
Iterable<String> semanticsLabels(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .map((node) => node.label)
    .where((label) => label.isNotEmpty);

/// Whether any label carries a line matching [pattern]. A `Semantics(label:)`
/// node does not merge its subtree (A-5), so a bare child `Text` keeps its own
/// node and its own label — which is why [pairMatches] needs both halves on one
/// line of one node rather than anywhere in the tree.
bool anyLineMatches(Iterable<String> labels, Pattern pattern) => labels.any(
  (label) => label.split('\n').any((line) => line.contains(pattern)),
);

/// Whether one node's one line carries both halves of a `(quantity, value)`
/// pair.
///
/// Either order satisfies it. D-61 names the form `<Quantity> <value>`
/// (`Close 5`), and D-61 itself points at `today_screen.dart`'s `'$count
/// $label'` (`1 Close`) as the shipped instance of it -- so a fixed order
/// would fail a label the plan calls correct. Requiring both halves **on one
/// line** is what makes the assertion bite: a child `Text('Delta')` alone
/// still fails.
bool pairMatches(
  Iterable<String> labels,
  (String quantity, String value) pair,
) {
  final (quantity, value) = pair;
  final q = RegExp.escape(quantity);
  final v = RegExp.escape(value);
  return anyLineMatches(labels, RegExp('$q.*$v')) ||
      anyLineMatches(labels, RegExp('$v.*$q'));
}

/// Pumps one audited surface at [kMaxTextScale] on a surface tall enough that
/// vertical clipping is not what is measured, runs the row's `open`, and
/// asserts no exception and every expected label.
Future<void> auditSurface(
  WidgetTester tester,
  AuditedSurface surface, {
  required SurfaceBook book,
  DateTime? now,
  List<Override> extraOverrides = const [],
}) async {
  // Tall on purpose: the audit measures wrapping and labelling, so a list
  // long enough to scroll must not be the thing that fails a row (S-313).
  // 6000 logical pixels builds every tile of the Today list at 3.2.
  tester.view.physicalSize = const Size(1000, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final handle = tester.ensureSemantics();
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wheelRepositoryProvider.overrideWithValue(book.repo),
          purchaseGatewayProvider.overrideWithValue(
            FakePurchaseGateway(
              offerings: surface.offerings,
              snapshot: surface.proActive
                  ? const EntitlementSnapshot.active()
                  : const EntitlementSnapshot.inactive(),
            ),
          ),
          ...extraOverrides,
        ],
        child: MaterialApp.router(
          routerConfig: buildAppRouter(
            initialLocation: book.routeFor(surface.route),
            portfolioNow: now,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(kMaxTextScale)),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(entitlementControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    if (surface.open != null) {
      await surface.open!(tester, book);
      await tester.pumpAndSettle();
    }

    expect(
      tester.takeException(),
      isNull,
      reason: '${surface.name} threw at textScaler $kMaxTextScale',
    );

    final labels = semanticsLabels(tester).toList();
    for (final pair in surface.expectedLabels) {
      expect(
        pairMatches(labels, pair),
        isTrue,
        reason:
            '${surface.name}: no accessibility node carries "${pair.$1}" and '
            '"${pair.$2}" on one line at textScaler $kMaxTextScale.\n'
            'labels:\n${labels.join('\n---\n')}',
      );
    }
  } finally {
    // Inline, not `addTearDown`: the framework's own end-of-test check runs
    // before teardowns and fails the test on a live handle.
    handle.dispose();
  }
}

/// The route fragments a surface's row can name, for the coverage guard.
List<String> get auditedSurfaceRoutes => [
  for (final surface in [...auditedSurfaces, ...auditedEmptySurfaces])
    surface.route,
];
