import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wheel_triage/core/app_router.dart';
import 'package:wheel_triage/core/haptics/haptics.dart';
import 'package:wheel_triage/core/purchases/purchase_gateway.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/capital_committed.dart';
import 'package:wheel_triage/domain/rules/premium_collected.dart';
import 'package:wheel_triage/features/positions/position_detail_sheet.dart';
import 'package:wheel_triage/features/positions/snapshot_sheet.dart';
import 'package:wheel_triage/features/record/record_trade_screen.dart';
import 'package:wheel_triage/features/screener/screener_screen.dart';
import 'package:wheel_triage/features/today/today_screen.dart';
import 'package:wheel_triage/features/portfolio/portfolio_screen.dart';
import 'package:wheel_triage/state/entitlements/entitlement_providers.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/state/today/today_controller.dart';
import 'package:wheel_triage/widgets/app_bottom_nav.dart';
import 'package:wheel_triage/widgets/bucket_badge.dart';

import '../../support/fake_purchase_gateway.dart';
import '../../support/recording_haptics.dart';

/// The reference's own book: 1 Assign, 1 Roll, 1 Close, 2 Leave (one of them
/// aging), 1 No data, plus one leg past expiration that appears in neither
/// the counts nor the list (S-242/S-243).
final _fixtureNow = DateTime.now();

Future<String> _addLeg(
  InMemoryWheelRepository repo, {
  required String ticker,
  required String strike,
  required int contracts,
  required int dteDays,
  required String credit,
  String? mark,
  double delta = 0,
  double? ivAtOpen,
  OptionType optionType = OptionType.put,
  DateTime? readingAt,
  DateTime? openedAt,
  String spot = '12',
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: optionType,
      strike: Decimal.parse(strike),
      expiration: _fixtureNow.add(Duration(days: dteDays)),
      contracts: contracts,
      openedAt: openedAt ?? _fixtureNow,
      openCreditPerShare: Decimal.parse(credit),
      ivAtOpen: ivAtOpen,
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  if (mark != null) {
    await repo.appendSnapshot(
      NewSnapshotInput(
        legId: result.leg.id,
        takenAt: readingAt ?? _fixtureNow,
        optionMark: Decimal.parse(mark),
        underlyingPrice: Decimal.parse(spot),
        deltaAsEntered: delta,
        deltaConvention: DeltaConvention.position,
      ),
    );
  }
  return result.leg.id;
}

Future<InMemoryWheelRepository> _sampleBook({int tReadingAgeDays = 11}) async {
  final repo = InMemoryWheelRepository();
  await _addLeg(
    repo,
    ticker: 'F',
    strike: '12',
    contracts: 2,
    dteDays: 11,
    credit: '1.00',
    mark: '0.90',
    delta: -0.78,
  ); // Assign
  await _addLeg(
    repo,
    ticker: 'SOFI',
    strike: '14',
    contracts: 3,
    dteDays: 4,
    credit: '1.00',
    mark: '0.90',
    delta: -0.52,
    ivAtOpen: 45,
  ); // Roll, band 0.35
  await _addLeg(
    repo,
    ticker: 'INTC',
    strike: '20',
    contracts: 4,
    dteDays: 18,
    credit: '1.00',
    mark: '0.45',
    delta: -0.20,
  ); // Close, 55% captured
  await _addLeg(
    repo,
    ticker: 'SBET',
    optionType: OptionType.call,
    strike: '11',
    contracts: 1,
    dteDays: 18,
    credit: '1.00',
    mark: '0.60',
    delta: -0.2534,
    ivAtOpen: 75,
  ); // Leave, band 0.40
  await _addLeg(
    repo,
    ticker: 'T',
    optionType: OptionType.call,
    strike: '28',
    contracts: 1,
    dteDays: 4,
    credit: '1.00',
    mark: '0.70',
    delta: -0.28,
    readingAt: _fixtureNow.subtract(Duration(days: tReadingAgeDays)),
  ); // Leave, aging
  await _addLeg(
    repo,
    ticker: 'PFE',
    strike: '25',
    contracts: 1,
    dteDays: 25,
    credit: '1.00',
  ); // No data
  await _addLeg(
    repo,
    ticker: 'WBD',
    strike: '11',
    contracts: 1,
    dteDays: -3,
    credit: '1.00',
    mark: '0.90',
    delta: -0.20,
  ); // past expiration
  return repo;
}

/// S-251/S-254's book: three legs past their expiration — WBD, whose last
/// reading was out of the money; AAL, whose last reading was in it; and XYZ,
/// with no reading at all — plus one live leg, so the counts and the list
/// have something in them and the past-expiration legs can be shown to be in
/// neither.
///
/// [wbdReadingAgeDays] dates WBD's reading: the default keeps it recent
/// (S-251's own fixture), while S-254 passes an old one to prove the aging
/// line does not pick up a leg that belongs to the card.
Future<InMemoryWheelRepository> _expiryBook({int wbdReadingAgeDays = 1}) async {
  final repo = InMemoryWheelRepository();
  await _addLeg(
    repo,
    ticker: 'WBD',
    strike: '11',
    contracts: 1,
    dteDays: -3,
    credit: '0.60',
    mark: '0.90',
    delta: -0.20,
    spot: '12.10',
    readingAt: _fixtureNow.subtract(Duration(days: wbdReadingAgeDays)),
  );
  await _addLeg(
    repo,
    ticker: 'AAL',
    strike: '13',
    contracts: 2,
    dteDays: -3,
    credit: '1.00',
    mark: '0.50',
    delta: -0.70,
    spot: '12.60',
    readingAt: _fixtureNow.subtract(const Duration(days: 2)),
  );
  await _addLeg(
    repo,
    ticker: 'XYZ',
    strike: '20',
    contracts: 1,
    dteDays: -5,
    credit: '0.80',
  );
  await _addLeg(
    repo,
    ticker: 'SOFI',
    strike: '14',
    contracts: 3,
    dteDays: 4,
    credit: '1.00',
    mark: '0.90',
    delta: -0.52,
    ivAtOpen: 45,
  );
  return repo;
}

Future<void> _pumpToday(
  WidgetTester tester,
  InMemoryWheelRepository repo, {
  GoRouter? router,
  List<Override> extraOverrides = const [],
}) async {
  // The counts row, the aging line and six rows do not fit the default
  // 800x600 test surface.
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        ...extraOverrides,
      ],
      child: MaterialApp.router(
        routerConfig: router ?? buildAppRouter(initialLocation: '/positions'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _navItem(String label) =>
    find.descendant(of: find.byType(AppBottomNav), matching: find.text(label));

void _expectCount(WidgetTester tester, String label, int count) {
  expect(
    find.descendant(
      of: find.byKey(ValueKey('today-count-$label')),
      matching: find.text('$count'),
    ),
    findsOneWidget,
    reason: 'the $label count should read $count',
  );
}

/// Portfolio's five count labels (`Roll 1`), in tree order. Scrolls first:
/// the counts row is the last card in the list, and an unbuilt card has no
/// labels.
Future<List<String>> _portfolioCountLabels(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.text('No data'),
    find.byType(ListView),
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
  return [
        for (final widget in tester.widgetList<Semantics>(
          find.byType(Semantics),
        ))
          ?widget.properties.label,
      ]
      .where(
        (label) =>
            RegExp(r'^(Assign|Roll|Close|Leave|No data) \d+$').hasMatch(label),
      )
      .toList();
}

void main() {
  group('S-242: Today replaces Positions', () {
    testWidgets(
      'the screen is Today (date + title) with the five-item bottom navigation',
      (tester) async {
        final repo = await _sampleBook();
        await _pumpToday(tester, repo);

        expect(find.byType(TodayScreen), findsOneWidget);
        expect(
          find.text(
            '${_weekdayText(_fixtureNow)}, ${_monthText(_fixtureNow)} ${_fixtureNow.day}',
          ),
          findsOneWidget,
        );
        expect(find.text('Today'), findsWidgets);
        for (final label in [
          'Today',
          'Journal',
          'Record',
          'Screener',
          'Settings',
        ]) {
          expect(
            _navItem(label),
            findsOneWidget,
            reason: 'bottom nav is missing $label',
          );
        }
        // The app bar no longer carries Screener/Journal/Settings/sort icons.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(IconButton),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(PopupMenuButton<TodaySort>),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'the list carries every open leg with a badge and its reason, sorted by bucket',
      (tester) async {
        final repo = await _sampleBook();
        await _pumpToday(tester, repo);

        expect(find.text('Open positions · 6'), findsOneWidget);
        expect(find.text('By bucket'), findsOneWidget);
        expect(find.byType(BucketBadge), findsNWidgets(6));

        // The past-expiration leg is in neither the list nor the counts.
        expect(find.text('WBD'), findsNothing);
        _expectCount(tester, 'Assign', 1);
        _expectCount(tester, 'No data', 1);

        // Every row pairs its badge with the reason that fired it.
        expect(find.text('Delta 0.78 at or above 0.70'), findsOneWidget);
        expect(find.text('55% of credit captured'), findsOneWidget);
        expect(find.text('No snapshot yet'), findsOneWidget);

        // The reference's own row shape: ticker, then strike/type/contracts,
        // expiry and DTE.
        expect(find.text('F'), findsOneWidget);
        final expiry = _fixtureNow.add(const Duration(days: 11));
        expect(
          find.text(
            '\$12 put ×2 · ${_monthText(expiry)} ${expiry.day} · 11 DTE',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the sort control switches between By bucket, By DTE and By ticker',
      (tester) async {
        final repo = await _sampleBook();
        await _pumpToday(tester, repo);

        // By bucket: Assign (F) sorts before Leave (T).
        expect(
          tester.getTopLeft(find.text('F')).dy <
              tester.getTopLeft(find.text('T')).dy,
          isTrue,
        );

        await tester.tap(find.byKey(const ValueKey('today-sort')));
        await tester.pumpAndSettle();
        expect(find.text('By DTE'), findsOneWidget);
        expect(find.text('By ticker'), findsOneWidget);
        await tester.tap(find.text('By DTE'));
        await tester.pumpAndSettle();

        expect(find.text('By DTE'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('SOFI')).dy <
              tester.getTopLeft(find.text('F')).dy,
          isTrue,
          reason: '4 DTE sorts before 11 DTE',
        );

        await tester.tap(find.byKey(const ValueKey('today-sort')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('By ticker'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('F')).dy <
              tester.getTopLeft(find.text('SBET')).dy,
          isTrue,
        );
      },
    );

    testWidgets('tapping a row still resolves the /positions/:legId flow', (
      tester,
    ) async {
      final repo = await _sampleBook();
      await _pumpToday(tester, repo);

      await tester.tap(find.text('SBET'));
      await tester.pumpAndSettle();

      expect(find.byType(PositionDetailSheet), findsOneWidget);
    });

    testWidgets('the empty variant invites the first trade with both buttons', (
      tester,
    ) async {
      await _pumpToday(tester, InMemoryWheelRepository());

      expect(find.text('Nothing recorded yet'), findsOneWidget);
      expect(
        find.text(
          'Trades you record appear here, grouped by which of your rules applies.',
        ),
        findsOneWidget,
      );
      expect(find.text('Record a trade'), findsOneWidget);
      expect(find.text('Open screener'), findsOneWidget);

      await tester.tap(find.text('Record a trade'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordTradeScreen), findsOneWidget);
    });

    testWidgets('the empty variant\'s second button opens the screener', (
      tester,
    ) async {
      await _pumpToday(tester, InMemoryWheelRepository());

      await tester.tap(find.text('Open screener'));
      await tester.pumpAndSettle();
      expect(find.byType(ScreenerScreen), findsOneWidget);
    });

    testWidgets(
      'S-205: returning to /positions reloads Today, no manual reload needed',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final router = GoRouter(
          initialLocation: '/positions',
          routes: [
            GoRoute(
              path: '/positions',
              builder: (context, state) => const TodayScreen(),
            ),
            GoRoute(
              path: '/screener',
              builder: (context, state) => _TrackingScreenerStub(repo: repo),
            ),
          ],
        );
        await _pumpToday(tester, repo, router: router);
        expect(find.text('Nothing recorded yet'), findsOneWidget);

        // Leave via the bottom navigation, the way the app does, so Today
        // stays alive underneath rather than being rebuilt from scratch.
        await tester.tap(_navItem('Screener'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Track this position'));
        await tester.pumpAndSettle();

        expect(find.text('Nothing recorded yet'), findsNothing);
        expect(find.text('NEWT'), findsOneWidget);
      },
    );
  });

  group('S-243: bucket counts and filters', () {
    testWidgets(
      'the counts render in sort order and each tap filters the list',
      (tester) async {
        final repo = await _sampleBook();
        await _pumpToday(tester, repo);

        for (final entry in {
          'Assign': 1,
          'Roll': 1,
          'Close': 1,
          'Leave': 2,
          'No data': 1,
        }.entries) {
          _expectCount(tester, entry.key, entry.value);
        }

        await tester.tap(find.byKey(const ValueKey('today-count-Assign')));
        await tester.pumpAndSettle();
        expect(find.byType(BucketBadge), findsOneWidget);
        expect(find.text('F'), findsOneWidget);

        // A second tap on the same count clears the filter.
        await tester.tap(find.byKey(const ValueKey('today-count-Assign')));
        await tester.pumpAndSettle();
        expect(find.byType(BucketBadge), findsNWidgets(6));

        await tester.tap(find.byKey(const ValueKey('today-count-Leave')));
        await tester.pumpAndSettle();
        expect(find.byType(BucketBadge), findsNWidgets(2));
        expect(find.text('T'), findsOneWidget);
        expect(find.text('SBET'), findsOneWidget);
      },
    );
  });

  group('S-331: cross-screen liveness, and the haptic still fires once', () {
    testWidgets(
      'one save moves Today, Portfolio and the detail sheet, with exactly one call',
      (tester) async {
        final repo = InMemoryWheelRepository();
        await _addLeg(
          repo,
          ticker: 'SOFI',
          strike: '14',
          contracts: 3,
          dteDays: 4,
          credit: '1.00',
          mark: '0.45',
          delta: -0.20,
          ivAtOpen: 45,
          openedAt: _fixtureNow.subtract(const Duration(days: 11)),
          readingAt: _fixtureNow.subtract(const Duration(days: 11)),
        ); // Close, 55% captured, aging
        await _addLeg(
          repo,
          ticker: 'SOFI',
          strike: '15',
          contracts: 1,
          dteDays: 25,
          credit: '1.00',
          mark: '0.70',
          delta: -0.28,
          ivAtOpen: 75,
        ); // Leave, band 0.40 -- the second open leg on the same underlying

        final haptics = RecordingHaptics();
        await _pumpToday(
          tester,
          repo,
          extraOverrides: [
            hapticsProvider.overrideWithValue(haptics),
            purchaseGatewayProvider.overrideWithValue(
              FakePurchaseGateway(snapshot: const EntitlementSnapshot.active()),
            ),
          ],
        );

        // The store is answering with an active entitlement, but the gate
        // reads the controller, not the gateway (S-277): refresh it.
        await ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        ).read(entitlementControllerProvider.notifier).refresh();
        await tester.pumpAndSettle();

        _expectCount(tester, 'Close', 1);
        _expectCount(tester, 'Roll', 0);
        _expectCount(tester, 'Leave', 1);

        // Save a bucket-changing reading through the sheet opened from
        // Today's own row.
        await tester.tap(find.byKey(const ValueKey('today-aging-line')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();
        expect(find.byType(SnapshotSheet), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, r'Option mark ($)'),
          '0.90',
        );
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Delta, as shown on your broker screen',
          ),
          '-0.52',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save snapshot'));
        await tester.tap(find.text('Save snapshot'));
        await tester.pumpAndSettle();

        expect(haptics.calls, ['bucketChanged']);
        expect(find.byType(SnapshotSheet), findsNothing);
        _expectCount(tester, 'Close', 0);
        _expectCount(tester, 'Roll', 1);
        _expectCount(tester, 'Leave', 1);
        expect(
          find.text('Delta 0.52 at or above the 0.35 band'),
          findsOneWidget,
        );

        // Portfolio reads the same repository through its own controller:
        // same bucket, one count moved between the two.
        await tester.tap(find.text('Committed now'));
        await tester.pumpAndSettle();
        expect(find.byType(PortfolioScreen), findsOneWidget);
        expect(
          await _portfolioCountLabels(tester),
          containsAll(<String>['Roll 1', 'Close 0', 'Leave 1']),
        );

        // Back to Today, then into the position's own detail sheet.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delta 0.52 at or above the 0.35 band'));
        await tester.pumpAndSettle();
        expect(find.byType(PositionDetailSheet), findsOneWidget);
        // Scoped to the sheet: Today's own 'Roll' count chip is still mounted
        // behind the pushed route.
        expect(
          find.descendant(
            of: find.descendant(
              of: find.byType(PositionDetailSheet),
              matching: find.byType(BucketBadge),
            ),
            matching: find.text('Roll'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(PositionDetailSheet),
            matching: find.text('Delta 0.52 at or above the 0.35 band'),
          ),
          findsOneWidget,
        );

        expect(
          haptics.calls,
          hasLength(1),
          reason: 'navigating and re-reading add no calls',
        );
      },
    );
  });

  group('S-244: the aging count and the inline Update', () {
    testWidgets(
      'the aging line names the leg and its date, and T stays counted under Leave',
      (tester) async {
        final repo = await _sampleBook();
        await _pumpToday(tester, repo);

        expect(
          find.textContaining('1 reading older than 7 days · T, from'),
          findsOneWidget,
        );
        _expectCount(tester, 'Leave', 2);
        _expectCount(tester, 'No data', 1);

        // The reading line names its date; only the aging one counts its days.
        expect(find.textContaining('11 days old'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the aging line filters to T and clears on the second tap',
      (tester) async {
        final repo = await _sampleBook();
        await _pumpToday(tester, repo);

        await tester.tap(find.byKey(const ValueKey('today-aging-line')));
        await tester.pumpAndSettle();
        expect(find.byType(BucketBadge), findsOneWidget);
        expect(find.text('T'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('today-aging-line')));
        await tester.pumpAndSettle();
        expect(find.byType(BucketBadge), findsNWidgets(6));
      },
    );

    testWidgets(
      'the inline Update opens the sheet in one tap and saves in two',
      (tester) async {
        final repo = await _sampleBook();
        await _pumpToday(tester, repo);

        // Filter to T so the Update button under test is unambiguous.
        await tester.tap(find.byKey(const ValueKey('today-aging-line')));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextButton, 'Update'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();
        expect(find.byType(SnapshotSheet), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Option mark (\$)'),
          '0.90',
        );
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Delta, as shown on your broker screen',
          ),
          '-0.35',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save snapshot'));
        await tester.tap(find.text('Save snapshot'));
        await tester.pumpAndSettle();

        // Back on Today: T's badge and reason are updated, the counts are
        // recomputed and the reading is no longer aging.
        expect(find.byType(SnapshotSheet), findsNothing);
        expect(
          find.text('Delta 0.35 at or above the 0.30 band'),
          findsOneWidget,
        );
        expect(find.text('Delta 0.28 below the 0.30 band'), findsNothing);
        expect(find.textContaining('reading older than 7 days'), findsNothing);
        _expectCount(tester, 'Roll', 2);
        _expectCount(tester, 'Leave', 1);
        expect(find.byType(BucketBadge), findsNWidgets(6));
      },
    );

    testWidgets(
      'a reading exactly 7 days old is not aging and gets no inline Update',
      (tester) async {
        final repo = await _sampleBook(tReadingAgeDays: 7);
        await _pumpToday(tester, repo);

        expect(find.textContaining('reading older than 7 days'), findsNothing);
        expect(
          find.widgetWithText(TextButton, 'Update'),
          findsNWidgets(1),
        ); // PFE only
        expect(find.text('T'), findsOneWidget);
      },
    );
  });

  group('S-245: kept behaviour on Today', () {
    Widget app(InMemoryWheelRepository repo) => ProviderScope(
      overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        routerConfig: buildAppRouter(initialLocation: '/positions'),
      ),
    );

    testWidgets(
      'the export reminder banner sits above the counts and dismisses permanently',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final underlying = await repo.getOrCreateUnderlying('OLD');
        await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45'),
            expiration: DateTime.now().add(const Duration(days: 20)),
            contracts: 1,
            openedAt: DateTime.now().subtract(const Duration(days: 40)),
            openCreditPerShare: Decimal.parse('0.60'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );

        tester.view.physicalSize = const Size(900, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(repo));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialBanner), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(MaterialBanner)).dy <
              tester
                  .getTopLeft(find.byKey(const ValueKey('today-count-Assign')))
                  .dy,
          isTrue,
        );

        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialBanner), findsNothing);
        final prefs = await repo.getPreferences();
        expect(prefs.exportReminderDismissed, isTrue);
      },
    );

    testWidgets(
      'a 31+ day-old position with a recent export never shows the banner',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final underlying = await repo.getOrCreateUnderlying('OLD');
        await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45'),
            expiration: DateTime.now().add(const Duration(days: 20)),
            contracts: 1,
            openedAt: DateTime.now().subtract(const Duration(days: 5)),
            openCreditPerShare: Decimal.parse('0.60'),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
          ),
        );

        await tester.pumpWidget(app(repo));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialBanner), findsNothing);
      },
    );

    testWidgets(
      'dismissing is permanent -- rebuilding Today never shows it again',
      (tester) async {
        final repo = InMemoryWheelRepository();
        final underlying = await repo.getOrCreateUnderlying('OLD');
        await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('45'),
            expiration: DateTime.now().add(const Duration(days: 20)),
            contracts: 1,
            openedAt: DateTime.now().subtract(const Duration(days: 400)),
            ruleProfileVersionId: RuleProfileVersionIds.standardV1,
            openCreditPerShare: Decimal.parse('0.60'),
          ),
        );
        final prefs = await repo.getPreferences();
        await repo.updatePreferences(
          prefs.copyWith(exportReminderDismissed: true),
        );

        await tester.pumpWidget(app(repo));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialBanner), findsNothing);
      },
    );

    testWidgets('a fresh install still opens the first-run explainer', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wheelRepositoryProvider.overrideWithValue(
              InMemoryWheelRepository(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: buildAppRouter(initialLocation: '/first-run'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What this does'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-246: the ledger strip', () {
    testWidgets(
      'net premium for the month, year to date and committed now, over one '
      'definition paragraph',
      (tester) async {
        final now = DateTime.now();
        final repo = await _ledgerBook(now: now, wheelCapital: '30000');
        await _pumpToday(tester, repo);

        expect(find.text('Net premium · ${_monthText(now)}'), findsOneWidget);
        expect(find.text('Year to date'), findsOneWidget);
        expect(find.text('Committed now'), findsOneWidget);

        // Credits 445 this month, less the 40 buyback on the leg closed
        // today; year to date adds the 140 credited in the earlier month.
        expect(find.text('\$405'), findsOneWidget);
        expect(find.text('\$545'), findsOneWidget);
        // The two open puts at strike -- INTC 20x400 + SOFI 14x300. The F
        // leg's put is closed, so it commits nothing.
        expect(find.text('\$12,200'), findsOneWidget);

        expect(
          find.text(
            '$kPremiumDefinitionLine Committed now: open puts at strike, '
            'shares at wheel-adjusted basis; 41% of your \$30,000 wheel capital.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the definition line names no percentage when no capital is set',
      (tester) async {
        final repo = await _ledgerBook(now: DateTime.now());
        await _pumpToday(tester, repo);

        expect(
          find.text(
            '$kPremiumDefinitionLine Committed now: open puts at strike, '
            'shares at wheel-adjusted basis.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('S-247: concentration per underlying', () {
    const flagLine = 'INTC 27% of wheel capital · limit 25%';

    testWidgets(
      'flags the one underlying over the limit, as a neutral fact with no link',
      (tester) async {
        final repo = await _ledgerBook(
          now: DateTime.now(),
          wheelCapital: '30000',
        );
        await _pumpToday(tester, repo);

        expect(find.text(flagLine), findsOneWidget);
        expect(find.text(kConcentrationInviteLine), findsNothing);
        // SOFI is at 14%: named nowhere near the flag.
        expect(find.textContaining('SOFI 14%'), findsNothing);
        // A fact in the neutral surface colour -- no warning colour, no link
        // to a portfolio view that does not exist yet (D-10).
        final scheme = Theme.of(
          tester.element(find.text(flagLine)),
        ).colorScheme;
        expect(
          tester.widget<Text>(find.text(flagLine)).style?.color,
          scheme.onSurfaceVariant,
        );
        expect(
          find.ancestor(
            of: find.text(flagLine),
            matching: find.byType(InkWell),
          ),
          findsNothing,
        );
        expect(find.byIcon(Icons.warning_amber), findsNothing);
        expect(find.byIcon(Icons.warning), findsNothing);
      },
    );

    testWidgets('shows the invite line instead when wheel capital is not set', (
      tester,
    ) async {
      final repo = await _ledgerBook(now: DateTime.now());
      await _pumpToday(tester, repo);

      expect(find.text(kConcentrationInviteLine), findsOneWidget);
      expect(find.textContaining('of wheel capital · limit'), findsNothing);
    });

    testWidgets('with two underlyings over the limit, largest share first', (
      tester,
    ) async {
      final repo = await _ledgerBook(
        now: DateTime.now(),
        wheelCapital: '30000',
        secondConcentration: true,
      );
      await _pumpToday(tester, repo);

      final intc = find.text(flagLine);
      final aapl = find.text('AAPL 26% of wheel capital · limit 25%');
      expect(intc, findsOneWidget);
      expect(aapl, findsOneWidget);
      expect(tester.getTopLeft(intc).dy, lessThan(tester.getTopLeft(aapl).dy));
      expect(find.text('\$20,000'), findsOneWidget);
    });

    testWidgets('no flag when the limit is raised above every share', (
      tester,
    ) async {
      final repo = await _ledgerBook(
        now: DateTime.now(),
        wheelCapital: '30000',
      );
      await repo.updatePreferences(
        (await repo.getPreferences()).copyWith(concentrationLimitPct: 30.0),
      );
      await _pumpToday(tester, repo);

      expect(find.textContaining('of wheel capital · limit'), findsNothing);
      // Wheel capital *is* set, so the invite line stays away too.
      expect(find.text(kConcentrationInviteLine), findsNothing);
    });
  });

  group('S-248: a Settings edit reaches Today on arrival', () {
    testWidgets('lowering the concentration limit rewrites the flag line', (
      tester,
    ) async {
      final repo = await _ledgerBook(
        now: DateTime.now(),
        wheelCapital: '30000',
      );
      await _pumpToday(tester, repo);
      expect(
        find.text('INTC 27% of wheel capital · limit 25%'),
        findsOneWidget,
      );

      await tester.tap(_navItem('Settings'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('concentration-limit')),
        '20',
      );
      await tester.pumpAndSettle();

      await tester.tap(_navItem('Today'));
      await tester.pumpAndSettle();
      expect(find.text('INTC 27% of wheel capital · limit 25%'), findsNothing);
      expect(
        find.text('INTC 27% of wheel capital · limit 20%'),
        findsOneWidget,
      );

      // Raising it back above the share takes the line away entirely
      // (S-247's limit-raised case), and wheel capital is still set, so the
      // invitation line stays away too.
      await tester.tap(_navItem('Settings'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('concentration-limit')),
        '30',
      );
      await tester.pumpAndSettle();

      await tester.tap(_navItem('Today'));
      await tester.pumpAndSettle();
      expect(find.textContaining('of wheel capital · limit'), findsNothing);
      expect(find.text(kConcentrationInviteLine), findsNothing);
    });
  });

  group('S-250: the "Expiring this week" card', () {
    testWidgets('lists the legs inside seven days with what each obliges', (
      tester,
    ) async {
      final repo = await _sampleBook();
      await _pumpToday(tester, repo);

      expect(find.text('Expiring this week'), findsOneWidget);
      expect(find.text('SOFI \$14 put ×3'), findsOneWidget);
      expect(find.text('\$4,200 cash if assigned'), findsOneWidget);
      expect(find.text('T \$28 call ×1'), findsOneWidget);
      expect(
        find.text('100 shares delivered at \$28 if assigned'),
        findsOneWidget,
      );

      // The card's caption is the latest date it covers.
      final last = _fixtureNow.add(const Duration(days: 4));
      expect(find.text(_weekdayShortText(last)), findsOneWidget);

      // An 11-DTE leg is in the list, not here; a past-expiration leg is on
      // the other card, not here.
      final card = find.byKey(const ValueKey('expiring-this-week-card'));
      expect(find.text('F \$12 put ×2'), findsNothing);
      expect(
        find.descendant(of: card, matching: find.text('WBD \$11 put ×1')),
        findsNothing,
      );
      expect(find.text('WBD \$11 put ×1'), findsOneWidget);
    });

    testWidgets(
      'two expiration dates are labelled on their own groups, earliest first',
      (tester) async {
        final repo = InMemoryWheelRepository();
        await _addLeg(
          repo,
          ticker: 'LATE',
          strike: '10',
          contracts: 1,
          dteDays: 6,
          credit: '0.50',
        );
        await _addLeg(
          repo,
          ticker: 'SOON',
          strike: '20',
          contracts: 1,
          dteDays: 2,
          credit: '0.50',
        );
        await _pumpToday(tester, repo);

        final soon = _fixtureNow.add(const Duration(days: 2));
        final late = _fixtureNow.add(const Duration(days: 6));
        // The caption carries the latest date; each group carries its own, so
        // the latest date appears twice and the earlier one once.
        expect(find.text(_weekdayShortText(late)), findsNWidgets(2));
        expect(find.text(_weekdayShortText(soon)), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('SOON \$20 put ×1')).dy <
              tester.getTopLeft(find.text('LATE \$10 put ×1')).dy,
          isTrue,
        );
      },
    );

    testWidgets(
      'there is no card at all when nothing expires inside the window',
      (tester) async {
        final repo = InMemoryWheelRepository();
        await _addLeg(
          repo,
          ticker: 'FAR',
          strike: '20',
          contracts: 1,
          dteDays: 30,
          credit: '0.50',
        );
        await _pumpToday(tester, repo);

        expect(find.text('Expiring this week'), findsNothing);
      },
    );
  });

  group('S-251: the "Past expiration, still open" card', () {
    testWidgets('shows every past-expiration leg with its last reading', (
      tester,
    ) async {
      final repo = await _expiryBook();
      await _pumpToday(tester, repo);

      expect(find.text('Past expiration, still open'), findsOneWidget);
      expect(find.text('WBD \$11 put ×1'), findsOneWidget);
      expect(
        find.text(
          'Last reading ${_readingDateText(_fixtureNow.subtract(const Duration(days: 1)))}: '
          'stock \$12.10, above the strike',
        ),
        findsOneWidget,
      );
      expect(find.text('AAL \$13 put ×2'), findsOneWidget);
      expect(
        find.text(
          'Last reading ${_readingDateText(_fixtureNow.subtract(const Duration(days: 2)))}: '
          'stock \$12.60, below the strike',
        ),
        findsOneWidget,
      );
      expect(find.text('XYZ \$20 put ×1'), findsOneWidget);
      expect(find.text('No reading recorded'), findsOneWidget);
    });

    testWidgets('only the out-of-the-money reading is in "Mark all expired"', (
      tester,
    ) async {
      final repo = await _expiryBook();
      await _pumpToday(tester, repo);

      expect(find.text('Mark all expired (1)'), findsOneWidget);
      expect(
        find.text('Not in Mark all: last reading in the money'),
        findsOneWidget,
      );
      expect(find.text('Not in Mark all: no reading'), findsOneWidget);

      // The two legs left out carry their own two actions.
      expect(
        find.widgetWithText(OutlinedButton, 'Mark assigned'),
        findsNWidgets(2),
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Mark expired'),
        findsNWidgets(2),
      );
    });

    testWidgets('the batch states that the close fee stays blank', (
      tester,
    ) async {
      final repo = await _expiryBook();
      await _pumpToday(tester, repo);

      expect(find.textContaining('The close fee stays blank.'), findsOneWidget);
    });
  });

  group('S-252: "Mark all expired"', () {
    testWidgets(
      'confirms, then records the eligible leg on its expiration date',
      (tester) async {
        final repo = await _expiryBook();
        await _pumpToday(tester, repo);

        await tester.tap(find.byKey(const ValueKey('mark-all-expired')));
        await tester.pumpAndSettle();
        expect(find.text('Mark all expired?'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('confirm-mark-all-expired')),
        );
        await tester.pumpAndSettle();

        // The one eligible leg is gone; the two left out are untouched.
        expect(find.text('WBD \$11 put ×1'), findsNothing);
        expect(find.text('Mark all expired (1)'), findsNothing);
        expect(find.text('AAL \$13 put ×2'), findsOneWidget);
        expect(find.text('XYZ \$20 put ×1'), findsOneWidget);

        final wbd = (await repo.getAllLegs()).firstWhere(
          (leg) => leg.closedAt != null,
        );
        expect(wbd.closeReason, CloseReason.expiredWorthless);
        expect(wbd.closedAt, wbd.expiration);
        expect(wbd.closeDebitPerShare, Decimal.zero);
        expect(wbd.closeFee, isNull);
      },
    );
  });

  group('S-254: past-expiration legs are only on the card', () {
    testWidgets('in no count and no row, but still in "Committed now"', (
      tester,
    ) async {
      // WBD's reading is old enough that the aging line would pick it up if
      // past-expiration legs were still in the list's own count.
      final repo = await _expiryBook(wbdReadingAgeDays: 9);
      await _pumpToday(tester, repo);

      expect(find.text('Open positions · 1'), findsOneWidget);
      _expectCount(tester, 'Roll', 1);
      _expectCount(tester, 'Assign', 0);
      _expectCount(tester, 'Close', 0);
      _expectCount(tester, 'Leave', 0);
      _expectCount(tester, 'No data', 0);
      expect(find.text('WBD'), findsNothing);
      expect(find.text('AAL'), findsNothing);
      expect(find.text('XYZ'), findsNothing);
      expect(find.textContaining('older than'), findsNothing);

      // ...they are on the card instead, and nowhere else.
      expect(find.text('Past expiration, still open'), findsOneWidget);
      expect(find.text('Expiring this week'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('past-expiration-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expiring-this-week-card')),
        findsOneWidget,
      );

      // The three are still open, so their cash is still committed:
      // WBD 1,100 + AAL 2,600 + XYZ 2,000 + SOFI 4,200.
      expect(find.text('\$9,900'), findsOneWidget);
    });
  });
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _weekdayText(DateTime d) => _weekdays[d.weekday - 1];
String _monthText(DateTime d) => _months[d.month - 1];

/// The expiry cards' own date form — `Fri Oct 2`, no comma (D-13).
String _weekdayShortText(DateTime d) =>
    '${_weekdayText(d)} ${_monthText(d)} ${d.day}';

/// `Last reading Sep 24: ...` — the reading line's own date form.
String _readingDateText(DateTime d) => '${_monthText(d)} ${d.day}';

/// S-246/S-247's book, built relative to [now] so the month and year-to-date
/// figures hold on any run date:
///
/// * INTC put $20 x4, SOFI put $14 x3 and T call $28 x1 all opened today, so
///   they credit this month: 240 + 165 + 40 = 445.
/// * F put $12 x2 was opened 40 days ago -- always a strictly earlier
///   calendar month -- and closed today for a 0.20 debit: 40 paid this month
///   and 140 credited in the earlier one.
///
/// So the month reads 445 - 40 = 405, year to date 585 - 40 = 545, and
/// committed capital is the two open puts at strike, 8,000 + 4,200 = 12,200
/// -- 41% of a 30,000 wheel capital, with INTC alone at 27%.
Future<InMemoryWheelRepository> _ledgerBook({
  required DateTime now,
  String? wheelCapital,
  bool secondConcentration = false,
}) async {
  final repo = InMemoryWheelRepository();
  if (wheelCapital != null) {
    await repo.updatePreferences(
      (await repo.getPreferences()).copyWith(
        wheelCapital: Decimal.parse(wheelCapital),
      ),
    );
  }

  await _addLeg(
    repo,
    ticker: 'INTC',
    strike: '20',
    contracts: 4,
    dteDays: 30,
    credit: '0.60',
    mark: '0.90',
    delta: -0.20,
    openedAt: now,
  );
  await _addLeg(
    repo,
    ticker: 'SOFI',
    strike: '14',
    contracts: 3,
    dteDays: 30,
    credit: '0.55',
    mark: '0.90',
    delta: -0.20,
    openedAt: now,
  );
  await _addLeg(
    repo,
    ticker: 'T',
    optionType: OptionType.call,
    strike: '28',
    contracts: 1,
    dteDays: 30,
    credit: '0.40',
    mark: '0.60',
    delta: -0.20,
    openedAt: now,
  );
  if (secondConcentration) {
    await _addLeg(
      repo,
      ticker: 'AAPL',
      strike: '39',
      contracts: 2,
      dteDays: 30,
      credit: '0.10',
      mark: '0.90',
      delta: -0.20,
      openedAt: now,
    );
  }

  final underlying = await repo.getOrCreateUnderlying('F');
  final closed = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('12'),
      expiration: _fixtureNow.add(const Duration(days: 30)),
      contracts: 2,
      openedAt: now.subtract(const Duration(days: 40)),
      openCreditPerShare: Decimal.parse('0.70'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  await repo.closeLeg(
    legId: closed.leg.id,
    reason: CloseReason.closedEarly,
    closeDebitPerShare: Decimal.parse('0.20'),
    closedAt: now,
  );
  return repo;
}

/// Stands in for the screener's "Track this position" (S-120): it writes the
/// cycle + first leg and returns to Today the way the real screen does -- a
/// push-then-pop that leaves Today alive underneath, so only a
/// refresh-on-arrival can show the new position.
class _TrackingScreenerStub extends StatelessWidget {
  const _TrackingScreenerStub({required this.repo});

  final InMemoryWheelRepository repo;

  Future<void> _trackAndReturn(BuildContext context) async {
    final underlying = await repo.getOrCreateUnderlying('NEWT');
    await repo.createCycle(
      underlyingId: underlying.id,
      firstLeg: NewLegInput(
        optionType: OptionType.put,
        strike: Decimal.parse('40'),
        expiration: DateTime.now().add(const Duration(days: 30)),
        contracts: 1,
        openedAt: DateTime.now(),
        openCreditPerShare: Decimal.parse('0.75'),
        ruleProfileVersionId: RuleProfileVersionIds.standardV1,
      ),
    );
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => _trackAndReturn(context),
        child: const Text('Track this position'),
      ),
    ),
  );
}
