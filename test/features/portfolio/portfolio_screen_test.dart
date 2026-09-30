import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/core/money/whole_dollars.dart';
import 'package:wheel_triage/core/purchases/paywall_copy.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/capital_committed.dart';
import 'package:wheel_triage/features/paywall/paywall_screen.dart';
import 'package:wheel_triage/features/portfolio/portfolio_screen.dart';
import 'package:wheel_triage/features/today/today_screen.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';

import '../../support/fake_purchase_gateway.dart';

/// Pro Wave 3 Phase 5: the Portfolio screen, its entry point on Today, and the
/// route. Every scenario here is a *rendering* assertion over the shipped
/// rules — the arithmetic itself is pinned by the rules' own tests.
///
/// Today is fixed at Mon Sep 28 2026 for every fixture, so the calendar's
/// month, the aging line and the "as of" sub-line are all deterministic.
final _now = DateTime(2026, 9, 28);

/// A tall surface: the whole screen is built, not just its first viewport.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// One open leg, with an optional reading. `expiration` is absolute so a
/// fixture can place a leg past expiration on purpose, and `versionId` is
/// explicit so a fixture can pin a leg to a version the profile has since
/// moved past.
Future<Leg> _put(
  InMemoryWheelRepository repo, {
  required String ticker,
  required String strike,
  required int contracts,
  required DateTime expiration,
  String credit = '1.00',
  String? mark,
  double? delta,
  DeltaConvention convention = DeltaConvention.option,
  DateTime? readingAt,
  OptionType optionType = OptionType.put,
  String versionId = RuleProfileVersionIds.standardV1,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final created = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: optionType,
      strike: Decimal.parse(strike),
      expiration: expiration,
      contracts: contracts,
      openedAt: _now.subtract(const Duration(days: 10)),
      openCreditPerShare: Decimal.parse(credit),
      ruleProfileVersionId: versionId,
    ),
  );
  if (mark != null) {
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: created.leg.id,
        takenAt: readingAt ?? _now,
        optionMark: Decimal.parse(mark),
        underlyingPrice: Decimal.parse(strike),
        deltaAsEntered: delta ?? 0,
        deltaConvention: convention,
        iv: 45,
      ),
    );
  }
  return created.leg;
}

/// S-293's `bookFull`: eight underlyings, two of them past expiration, two
/// `holdingShares` cycles with share lots, wheel capital `$30,000` and the
/// default 25% limit.
///
/// Committed: INTC 8,000 + SOFI 4,200 + F 2,400 + PFE 2,500 + AAL 1,200 +
/// T 2,700 + SBET 3,000 + WBD 900 = 24,900.
Future<InMemoryWheelRepository> _bookFull({String? wheelCapital = '30000'}) async {
  final repo = InMemoryWheelRepository();
  if (wheelCapital != null) {
    await repo.updatePreferences(
      (await repo.getPreferences()).copyWith(wheelCapital: Decimal.parse(wheelCapital)),
    );
  }

  await _put(repo, ticker: 'INTC', strike: '20', contracts: 4, expiration: DateTime(2026, 10, 16), mark: '0.90', delta: -0.19);
  await _put(repo, ticker: 'SOFI', strike: '14', contracts: 3, expiration: DateTime(2026, 10, 2), mark: '0.90', delta: -0.19);
  await _put(repo, ticker: 'F', strike: '12', contracts: 2, expiration: DateTime(2026, 10, 9), mark: '0.90', delta: -0.19);
  await _put(repo, ticker: 'PFE', strike: '25', contracts: 1, expiration: DateTime(2026, 10, 23), mark: '0.90', delta: -0.19);
  // Past expiration, not recorded: still counted in committed capital.
  await _put(repo, ticker: 'AAL', strike: '15', contracts: 2, expiration: DateTime(2026, 9, 18), mark: '0.90', delta: -0.19);
  await _put(repo, ticker: 'WBD', strike: '9', contracts: 1, expiration: DateTime(2026, 9, 18), mark: '0.90', delta: -0.19);

  // T: assigned at $28, wheel basis $27 -> 2,700.
  final tUnderlying = await repo.getOrCreateUnderlying('T');
  final tCycle = await repo.createCycle(
    underlyingId: tUnderlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('28'),
      expiration: DateTime(2026, 9, 18),
      contracts: 1,
      openedAt: _now.subtract(const Duration(days: 40)),
      openCreditPerShare: Decimal.parse('1.00'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.recordAssignment(
    legId: tCycle.leg.id,
    shareLot: NewShareLotInput(
      assignedAt: _now.subtract(const Duration(days: 20)),
      assignmentStrike: Decimal.parse('28'),
      contracts: 1,
    ),
  );

  // SBET: assigned at $13, wheel basis $12 -> 3,000, plus an open covered call.
  final sbetUnderlying = await repo.getOrCreateUnderlying('SBET');
  final sbetCycle = await repo.createCycle(
    underlyingId: sbetUnderlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('13'),
      expiration: DateTime(2026, 9, 18),
      contracts: 1,
      openedAt: _now.subtract(const Duration(days: 40)),
      openCreditPerShare: Decimal.parse('1.00'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.recordAssignment(
    legId: sbetCycle.leg.id,
    shareLot: NewShareLotInput(
      assignedAt: _now.subtract(const Duration(days: 20)),
      assignmentStrike: Decimal.parse('13'),
      contracts: 1,
    ),
  );
  final sbetCall = await repo.openNextLeg(
    cycleId: sbetCycle.cycle.id,
    leg: NewLegInput(
      optionType: OptionType.call,
      strike: Decimal.parse('11'),
      expiration: DateTime(2026, 10, 16),
      contracts: 1,
      openedAt: _now.subtract(const Duration(days: 10)),
      openCreditPerShare: Decimal.parse('0.40'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.appendSnapshot(
    NewSnapshotInput(
      legId: sbetCall.id,
      takenAt: _now,
      optionMark: Decimal.parse('0.30'),
      underlyingPrice: Decimal.parse('12'),
      deltaAsEntered: 0.25,
      deltaConvention: DeltaConvention.option,
      iv: 45,
    ),
  );

  return repo;
}

/// Pumps the app's own router on [location] over [repo], with the store
/// answering [entitlement].
Future<ProviderContainer> _pump(
  WidgetTester tester,
  InMemoryWheelRepository repo, {
  String location = '/portfolio',
  EntitlementSnapshot entitlement = const EntitlementSnapshot.active(),
  DateTime? now,
}) async {
  // Every fixture is dated against `_now`, so the screen's clock is pinned to
  // it too -- otherwise the controller reads the real clock and the aging and
  // calendar assertions drift with the day the suite runs.
  final clock = now ?? _now;
  _tallSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        purchaseGatewayProvider.overrideWithValue(FakePurchaseGateway(snapshot: entitlement)),
      ],
      child: MaterialApp.router(
        routerConfig: buildAppRouter(
          initialLocation: location,
          portfolioNow: clock,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  await container.read(entitlementControllerProvider.notifier).refresh();
  await tester.pumpAndSettle();
  return container;
}

/// Every string the screen is currently rendering, in tree order.
List<String> _renderedText(WidgetTester tester) => [
  for (final widget in tester.widgetList<Text>(find.byType(Text)))
    if (widget.data != null) widget.data!,
];

/// How many cells the calendar grid pads before the 1st, read off the first
/// row: the pad cells carry the previous month's day numbers, so the count is
/// the index of the cell whose text is `1`.
int _leadingPadCount(WidgetTester tester) {
  final row = find.byKey(const ValueKey('portfolio-calendar-row-0'));
  final cells = tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((text) => text.data)
      .toList();
  return cells.indexOf('1');
}

/// The screen is a lazy `ListView`, so anything below the fold is not built
/// until it is scrolled into view. Drags to the bottom and returns every
/// string the screen then renders.
Future<List<String>> _renderedTextScrolled(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 12; i++) {
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  return _renderedText(tester);
}

/// The decoration on the day cell in calendar [row] whose text is [day].
///
/// Found by radius rather than by position, so the assertion cannot pass by
/// accidentally reading the card shell's own border one level up.
BoxDecoration _cellDecoration(
  WidgetTester tester, {
  required int row,
  required String day,
}) {
  final containers = tester.widgetList<Container>(
    find.ancestor(
      of: find.descendant(
        of: find.byKey(ValueKey('portfolio-calendar-row-$row')),
        matching: find.text(day),
      ),
      matching: find.byType(Container),
    ),
  );
  return containers
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((decoration) => decoration.borderRadius == BorderRadius.circular(8));
}

/// Portfolio's five count labels (`Assign 1`), in tree order. Scrolls first:
/// the counts row is the last card, and an unbuilt card has no labels.
Future<List<String>> _portfolioCountLabels(WidgetTester tester) async {
  await _renderedTextScrolled(tester);
  return [
    for (final widget in tester.widgetList<Semantics>(find.byType(Semantics)))
      ?widget.properties.label,
  ].where((label) => RegExp(r'^(Assign|Roll|Close|Leave|No data) \d+$').hasMatch(label)).toList();
}

/// Today's five count labels (`1 Assign`), in tree order.
List<String> _todayCountLabels(WidgetTester tester) => [
  for (final widget in tester.widgetList<Semantics>(find.byType(Semantics)))
    ?widget.properties.label,
].where((label) => RegExp(r'^\d+ (Assign|Roll|Close|Leave|No data)$').hasMatch(label)).toList();

void main() {
  group('S-291: Portfolio is Pro, and the gate is the only door', () {
    testWidgets('an active entitlement opens the screen from Today', (tester) async {
      final repo = await _bookFull();
      await _pump(tester, repo, location: '/positions');

      await tester.tap(find.text('Committed now'));
      await tester.pumpAndSettle();

      expect(find.byType(PortfolioScreen), findsOneWidget);
      expect(find.byType(PaywallScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an inactive entitlement opens the paywall with the D-40 line, '
        'and never the screen', (tester) async {
      final repo = await _bookFull();
      await _pump(
        tester,
        repo,
        location: '/positions',
        entitlement: const EntitlementSnapshot.inactive(),
      );

      await tester.tap(find.text('Committed now'));
      await tester.pumpAndSettle();

      expect(find.byType(PortfolioScreen), findsNothing);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(find.text(proFeatureLine(kPortfolioFeatureName)), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown entitlement locks too — Pro is never forged', (tester) async {
      final repo = await _bookFull();
      await _pump(
        tester,
        repo,
        location: '/positions',
        entitlement: const EntitlementSnapshot.unknown(),
      );

      await tester.tap(find.text('Committed now'));
      await tester.pumpAndSettle();

      expect(find.byType(PortfolioScreen), findsNothing);
      expect(find.byType(PaywallScreen), findsOneWidget);
    });

    test('the route is pushed, never gone to, and the gate is the only reader', () {
      final screen = File('lib/features/portfolio/portfolio_screen.dart').readAsStringSync();
      expect(screen.contains("context.push('/portfolio')"), isFalse);
      expect(
        File('lib/features/today/today_screen.dart').readAsStringSync(),
        contains("context.push('/portfolio')"),
      );
      // D-40: the screen reads the gate's verdict and nothing else.
      expect(screen.contains('entitlementControllerProvider'), isFalse);
      expect(screen.contains('purchaseGatewayProvider'), isFalse);
      expect(screen.contains('.isActive'), isFalse);
    });
  });

  group('S-293: Portfolio\'s figures equal Today\'s for the same book', () {
    testWidgets('the committed total, the sub-line and the flag line match', (tester) async {
      final repo = await _bookFull();
      await _pump(tester, repo);

      final text = _renderedText(tester);
      expect(text, contains(wholeDollars(Decimal.parse('24900'))));
      expect(text, contains('committed now · 83% of \$30,000 wheel capital'));
      expect(text, contains('INTC 27% of wheel capital · limit 25%'));
      expect(
        text,
        contains(
          '${committedNowDefinition(committedNow: Decimal.parse('24900'), wheelCapital: Decimal.parse('30000'))} '
          'Includes AAL and WBD, past expiration and not yet recorded.',
        ),
      );
    });

    testWidgets('Today renders the same total for the same book', (tester) async {
      final repo = await _bookFull();
      await _pump(tester, repo, location: '/positions');

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(_renderedText(tester), contains(wholeDollars(Decimal.parse('24900'))));
    });
  });

  group('S-294: the bars\' order, fills and limit mark', () {
    testWidgets('bars descend by percent, ties by ticker, and the key line '
        'names the track', (tester) async {
      final repo = await _bookFull();
      await _pump(tester, repo);

      final text = _renderedText(tester);
      expect(text, contains('Limit 25% · bars run to 30%'));

      final tickers = [
        for (final key in tester
            .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
            .map((w) => w.key)
            .whereType<ValueKey<String>>()
            .map((k) => k.value)
            .where((v) => v.startsWith('portfolio-bar-')))
          key.substring('portfolio-bar-'.length),
      ];
      expect(tickers, ['INTC', 'SOFI', 'AAL', 'T', 'F', 'PFE', 'SBET', 'WBD']);
    });

    testWidgets('a book with no wheel capital shows dollars, no bars and the '
        'invite line', (tester) async {
      final repo = await _bookFull(wheelCapital: null);
      await _pump(tester, repo);

      final text = _renderedText(tester);
      expect(text, contains(wholeDollars(Decimal.parse('24900'))));
      expect(text, contains(kConcentrationInviteLine));
      expect(text.any((line) => line.contains('%')), isFalse);
      expect(text.any((line) => line.contains('NaN')), isFalse);
      expect(text.any((line) => line.contains('--%')), isFalse);
    });
  });

  group('S-296/S-297: the delta card', () {
    testWidgets('the total is signed shares and the exclusions are named once '
        'each', (tester) async {
      final repo = InMemoryWheelRepository();
      await _put(repo, ticker: 'INTC', strike: '20', contracts: 4, expiration: DateTime(2026, 10, 16), mark: '0.90', delta: 0.19, convention: DeltaConvention.position);
      await _put(repo, ticker: 'PFE', strike: '25', contracts: 1, expiration: DateTime(2026, 10, 23));
      await _put(repo, ticker: 'AAL', strike: '15', contracts: 2, expiration: DateTime(2026, 9, 18), mark: '0.90', delta: 0.19);
      await _put(repo, ticker: 'WBD', strike: '9', contracts: 1, expiration: DateTime(2026, 9, 18));

      await _pump(tester, repo);
      final text = _renderedText(tester);

      expect(text, contains('+76 shares'));
      // A-Z within a clause, which is what `leftOutLine`'s own doc pins; the
      // plan's S-297 example string transposes the two tickers.
      expect(text, contains('Left out: PFE (no reading); AAL, WBD (past expiration)'));
    });

    testWidgets('the aging note is Today\'s own string', (tester) async {
      final repo = InMemoryWheelRepository();
      await _put(repo, ticker: 'SOFI', strike: '14', contracts: 3, expiration: DateTime(2026, 10, 2), mark: '0.90', delta: 0.19, readingAt: DateTime(2026, 9, 20));
      await _put(repo, ticker: 'T', strike: '28', contracts: 1, expiration: DateTime(2026, 10, 2), mark: '0.90', delta: 0.19, readingAt: DateTime(2026, 9, 21));
      await _put(repo, ticker: 'INTC', strike: '20', contracts: 4, expiration: DateTime(2026, 10, 16), mark: '0.90', delta: 0.19, readingAt: DateTime(2026, 9, 27));

      await _pump(tester, repo);
      expect(
        _renderedText(tester),
        contains('1 reading older than 7 days · SOFI, from Sep 20'),
      );
    });
  });

  group('S-299/S-300/S-301/S-303: the calendar', () {
    testWidgets('it opens on the next expiration\'s month and lists the '
        'obligations ascending', (tester) async {
      final repo = InMemoryWheelRepository();
      await _put(repo, ticker: 'SOFI', strike: '14', contracts: 3, expiration: DateTime(2026, 10, 2), mark: '0.90', delta: 0.19);
      await _put(repo, ticker: 'T', strike: '28', contracts: 1, expiration: DateTime(2026, 10, 2), mark: '0.90', delta: 0.19, optionType: OptionType.call);
      await _put(repo, ticker: 'F', strike: '12', contracts: 2, expiration: DateTime(2026, 10, 9), mark: '0.90', delta: 0.19);
      await _put(repo, ticker: 'INTC', strike: '20', contracts: 4, expiration: DateTime(2026, 10, 16), mark: '0.90', delta: 0.19);
      await _put(repo, ticker: 'SBET', strike: '11', contracts: 1, expiration: DateTime(2026, 10, 16), mark: '0.90', delta: 0.19, optionType: OptionType.call);
      await _put(repo, ticker: 'PFE', strike: '25', contracts: 1, expiration: DateTime(2026, 10, 23), mark: '0.90', delta: 0.19);
      await _put(repo, ticker: 'AAL', strike: '15', contracts: 2, expiration: DateTime(2026, 9, 18), mark: '0.90', delta: 0.19);
      await _put(repo, ticker: 'WBD', strike: '9', contracts: 1, expiration: DateTime(2026, 9, 18), mark: '0.90', delta: 0.19);

      await _pump(tester, repo);
      final text = await _renderedTextScrolled(tester);

      expect(text, contains('October 2026'));
      expect(text, contains('Fri Oct 2'));
      expect(text, contains('SOFI \$14 put ×3 · \$4,200 cash if assigned'));
      expect(text, contains('T \$28 call ×1 · 100 shares delivered at \$28 if assigned'));
      expect(text, contains('Fri Oct 9'));
      expect(text, contains('F \$12 put ×2 · \$2,400 cash if assigned'));
      expect(text, contains('Fri Oct 16'));
      expect(text, contains('INTC \$20 put ×4 · \$8,000 cash if assigned'));
      expect(text, contains('SBET \$11 call ×1 · 100 shares delivered at \$11 if assigned'));
      expect(text, contains('Fri Oct 23'));
      expect(text, contains('PFE \$25 put ×1 · \$2,500 cash if assigned'));
      // The past-expiration legs are Today's card's job, never the calendar's.
      // The committed-now definition line names them on purpose, so the
      // assertion is scoped to the calendar card's own rows.
      final calendarRows = text.where((line) => line.contains('cash if assigned') ||
          line.contains('shares delivered'));
      expect(calendarRows.any((line) => line.contains('AAL')), isFalse);
      expect(calendarRows.any((line) => line.contains('WBD')), isFalse);
    });

    testWidgets('with no future expiration it falls back to today\'s month and '
        'still renders the grid', (tester) async {
      final repo = InMemoryWheelRepository();
      await _put(repo, ticker: 'AAL', strike: '15', contracts: 2, expiration: DateTime(2026, 9, 18), mark: '0.90', delta: 0.19);
      await _put(repo, ticker: 'WBD', strike: '9', contracts: 1, expiration: DateTime(2026, 9, 18), mark: '0.90', delta: 0.19);

      await _pump(tester, repo);
      final text = await _renderedTextScrolled(tester);

      expect(text, contains('September 2026'));
      expect(text, contains('28'));
      expect(text.any((line) => line.contains('cash if assigned')), isFalse);
    });

    testWidgets('a month starting on a Saturday pads six leading cells; one '
        'starting on a Sunday pads none', (tester) async {
      // August 2026 starts on a Saturday, and the 1st is a leading pad of six.
      final august = InMemoryWheelRepository();
      await _put(august, ticker: 'T', strike: '28', contracts: 1, expiration: DateTime(2026, 8, 21), mark: '0.90', delta: 0.19);
      await _pump(tester, august, now: DateTime(2026, 8, 3));
      final augustText = await _renderedTextScrolled(tester);
      expect(augustText, contains('August 2026'));
      expect(_leadingPadCount(tester), 6);

      // November 2026 starts on a Sunday, so there is no leading pad at all.
      final november = InMemoryWheelRepository();
      await _put(november, ticker: 'T', strike: '28', contracts: 1, expiration: DateTime(2026, 11, 20), mark: '0.90', delta: 0.19);
      await _pump(tester, november, now: DateTime(2026, 11, 2));
      final novemberText = await _renderedTextScrolled(tester);
      expect(novemberText, contains('November 2026'));
      expect(_leadingPadCount(tester), 0);
    });

    testWidgets('today is outlined even as a leading cell of the shown month '
        '(D-45)', (tester) async {
      final repo = InMemoryWheelRepository();
      await _put(repo, ticker: 'INTC', strike: '20', contracts: 4, expiration: DateTime(2026, 10, 16), mark: '0.90', delta: 0.19);

      await _pump(tester, repo);

      // October 2026 starts on a Thursday, so its grid is padded by four
      // leading cells and today (Mon Sep 28) lands in the first row.
      expect(await _renderedTextScrolled(tester), contains('October 2026'));
      expect(
        _cellDecoration(tester, row: 0, day: '28').border,
        isNotNull,
        reason: 'Sep 28 is today and is outlined in the leading pad',
      );
      expect(_cellDecoration(tester, row: 0, day: '27').border, isNull);
      expect(
        _cellDecoration(tester, row: 2, day: '16').color,
        isNotNull,
        reason: 'Oct 16 carries an expiration and is filled',
      );
    });

    testWidgets('a reload reads the screen\'s own clock, not the wall clock',
        (tester) async {
      final repo = InMemoryWheelRepository();
      await _put(repo, ticker: 'T', strike: '28', contracts: 1, expiration: DateTime(2026, 8, 21), mark: '0.90', delta: 0.19);

      // Pinned to Aug 3, when the Aug 21 expiration is still ahead: the
      // calendar opens on August 2026. Reloading against the wall clock would
      // put that expiration in the past and open the calendar on the current
      // month instead.
      await _pump(tester, repo, now: DateTime(2026, 8, 3));
      final before = await _renderedTextScrolled(tester);
      expect(before, contains('August 2026'));

      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();

      expect(await _renderedTextScrolled(tester), before);
    });
  });

  group('S-302: the bucket summary cannot drift from Today\'s', () {
    testWidgets('both screens show the same five counts in the same order, '
        'before and after a profile edit', (tester) async {
      final repo = InMemoryWheelRepository();
      // Six counted legs: 1 Assign, 1 Roll, 1 Close, 2 Leave, 1 No data.
      await _put(repo, ticker: 'A', strike: '20', contracts: 1, expiration: DateTime(2026, 10, 16), credit: '0.50', mark: '0.50', delta: 0.85);
      await _put(repo, ticker: 'B', strike: '20', contracts: 1, expiration: DateTime(2026, 10, 16), credit: '0.50', mark: '0.50', delta: 0.35);
      await _put(repo, ticker: 'C', strike: '20', contracts: 1, expiration: DateTime(2026, 10, 16), credit: '0.50', mark: '0.20', delta: 0.10);
      await _put(repo, ticker: 'D', strike: '20', contracts: 1, expiration: DateTime(2026, 10, 16), credit: '0.50', mark: '0.50', delta: 0.15);
      await _put(repo, ticker: 'E', strike: '20', contracts: 1, expiration: DateTime(2026, 10, 16), credit: '0.50', mark: '0.50', delta: 0.12);
      await _put(repo, ticker: 'F', strike: '20', contracts: 1, expiration: DateTime(2026, 10, 16), credit: '0.50');
      // The seventh leg is past expiration, so neither screen counts it.
      await _put(repo, ticker: 'G', strike: '20', contracts: 1, expiration: DateTime(2026, 9, 18), credit: '0.50', mark: '0.50', delta: 0.85);

      await _pump(tester, repo);
      final portfolioBefore = await _portfolioCountLabels(tester);
      await _pump(tester, repo, location: '/positions');
      final todayBefore = _todayCountLabels(tester);

      expect(portfolioBefore, ['Assign 1', 'Roll 1', 'Close 1', 'Leave 2', 'No data 1']);
      expect(todayBefore, ['1 Assign', '1 Roll', '1 Close', '2 Leave', '1 No data']);

      // `Standard` moves on. Leg A is pinned to v1, where 0.85 assigns; under
      // v2 it would roll. The pin is what keeps the counts still.
      await repo.appendRuleProfileVersion(
        profileId: RuleProfileIds.standard,
        effectiveAt: _now,
        values: NewRuleProfileVersionInput(
          profitTargetPct: 50,
          assignThreshold: 0.95,
          baseRollBand: 0.30,
          midIvRollBand: 0.35,
          highIvRollBand: 0.40,
          midIvCutoff: 40,
          highIvCutoff: 70,
          tailDteDays: 7,
          tailExtrinsicThreshold: Decimal.parse('0.05'),
          minIvRank: 0,
          minAnnualisedYield: 0,
          targetDteMin: 30,
          targetDteMax: 45,
          targetDelta: 0.30,
        ),
      );

      await _pump(tester, repo);
      expect(await _portfolioCountLabels(tester), portfolioBefore);
      await _pump(tester, repo, location: '/positions');
      expect(_todayCountLabels(tester), todayBefore);
    });

    test('no bucket-order list exists outside lib/domain/rules/bucket.dart', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path == 'lib/domain/rules/bucket.dart') continue;
        final source = entity.readAsStringSync();
        if (RegExp(r'BucketAssign\(reason:').hasMatch(source) &&
            RegExp(r'BucketRoll\(reason:').hasMatch(source)) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('S-304: every number on Portfolio is labelled', () {
    testWidgets('the figures carry semantics labels and nothing overflows at '
        'textScaler 2.0', (tester) async {
      final repo = await _bookFull();
      _tallSurface(tester);
      // Enabled before the first pump: the semantics owner only exists once
      // the binding has been asked for a tree.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(repo),
            purchaseGatewayProvider.overrideWithValue(
              FakePurchaseGateway(snapshot: const EntitlementSnapshot.active()),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: buildAppRouter(
              initialLocation: '/portfolio',
              portfolioNow: _now,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final labels = _semanticsLabels(tester).toList();
      handle.dispose();

      // The big committed figure.
      expect(labels.any((l) => l.contains('committed') && l.contains('\$')), isTrue);
      // A concentration bar: ticker, dollars committed, share of wheel capital.
      expect(
        labels.any((l) => l.contains('INTC') && l.contains('\$') && l.contains('%')),
        isTrue,
      );
      // The net position delta.
      expect(labels.any((l) => l.contains('shares')), isTrue);
      // The five count tiles.
      expect(_anyLineMatches(labels, RegExp(r'^Assign \d+$')), isTrue);
      // An obligation row: the ticker and what assignment would cost.
      expect(
        labels.any((l) => l.contains('SOFI') && l.contains('cash if assigned')),
        isTrue,
      );
    });
  });
}

/// Every semantics label currently in the tree, flattened. A real traversal
/// of the visible tree, as assistive technology would perform it, rather than
/// a lookup of one widget's own isolated node.
Iterable<String> _semanticsLabels(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .map((node) => node.label)
    .where((label) => label.isNotEmpty);

/// Whether any semantics label carries a line matching [pattern]. A
/// `Semantics` node merges its subtree, so a tile's own label arrives as one
/// line among its children's rather than as a label of its own.
bool _anyLineMatches(Iterable<String> labels, Pattern pattern) => labels.any(
  (label) => label.split('\n').any((line) => line.contains(pattern)),
);
