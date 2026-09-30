import 'package:go_router/go_router.dart';

import '../features/assignment/assignment_flow_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/journal/share_card_screen.dart';
import '../features/onboarding/first_run_explainer.dart';
import '../features/paywall/paywall_route.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/portfolio/portfolio_screen.dart';
import '../features/positions/position_detail_sheet.dart';
import '../features/record/record_trade_screen.dart';
import '../features/roll/roll_planner_screen.dart';
import '../features/screener/screener_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';

/// Builds the app's full route graph (Screener, Today, Position detail, Roll
/// planner, Assignment flow, Settings, first-run explainer).
/// [initialLocation] defaults to `/positions` — Today is what the user
/// actually opens the app to check day to day; the other four destinations
/// are on the bottom bar (`AppBottomNav`).
/// `lib/main.dart` passes `/first-run` on a fresh install
/// (`!firstRunExplainerShown`) instead — a function rather than a `final`
/// singleton so that decision can be made once, at startup, from a loaded
/// preference, without needing a second router instance or a redirect that
/// would have to be async-aware.
GoRouter buildAppRouter({String initialLocation = '/positions', DateTime? portfolioNow}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/screener', builder: (context, state) => const ScreenerScreen()),
    GoRoute(path: '/record', builder: (context, state) => const RecordTradeScreen()),
    GoRoute(
      path: '/journal',
      builder: (context, state) => const JournalScreen(),
      routes: [
        // D-56: the card covers the month containing "now" and has no month
        // picker, so the route carries no parameter.
        GoRoute(path: 'share', builder: (context, state) => const ShareCardScreen()),
      ],
    ),
    // D-40: pushed from Today's "Committed now" tile, never a bottom-bar
    // destination. The gate decides whether the push happens at all, so this
    // route carries no entitlement check of its own.
    GoRoute(
      path: '/portfolio',
      builder: (context, state) => PortfolioScreen(now: portfolioNow),
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/first-run', builder: (context, state) => const FirstRunExplainerScreen()),
    // One route for all three entry points (D-30). The trigger travels in
    // `extra`, so the paywall knows why it was opened without a query
    // parameter that could be edited into a different sentence. A route
    // reached with no trigger at all — a deep link — gets the generic
    // explanation rather than an error.
    GoRoute(
      path: '/paywall',
      builder: (context, state) => PaywallScreen(trigger: paywallTriggerFrom(state.extra)),
    ),
    GoRoute(
      path: '/positions',
      builder: (context, state) => const TodayScreen(),
      routes: [
        GoRoute(
          path: ':legId',
          builder: (context, state) =>
              PositionDetailSheet(legId: state.pathParameters['legId']!),
          routes: [
            GoRoute(
              path: 'roll',
              builder: (context, state) =>
                  RollPlannerScreen(legId: state.pathParameters['legId']!),
            ),
            GoRoute(
              path: 'assign',
              builder: (context, state) =>
                  AssignmentFlowScreen(legId: state.pathParameters['legId']!),
            ),
          ],
        ),
      ],
    ),
  ],
);
