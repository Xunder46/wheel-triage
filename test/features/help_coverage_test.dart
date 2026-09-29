import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/features/assignment/assignment_flow_screen.dart';
import 'package:wheel_triage/features/positions/position_detail_sheet.dart';
import 'package:wheel_triage/features/record/record_trade_screen.dart';
import 'package:wheel_triage/features/screener/screener_screen.dart';
import 'package:wheel_triage/state/record/record_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';
import 'package:wheel_triage/widgets/help_chip.dart';

/// S-082: every §C2 topic has a working `HelpChip` at every location the
/// fixture names it. A table-driven check per screen: any missing id fails
/// loudly by name, not by a generic "widget not found."
void _expectChips(WidgetTester tester, List<String> topicIds) {
  final present = tester
      .widgetList<HelpChip>(find.byType(HelpChip))
      .map((c) => c.topicId)
      .toSet();
  final missing = topicIds.where((id) => !present.contains(id)).toList();
  expect(missing, isEmpty, reason: 'missing HelpChip(s) for: $missing');
}

Future<void> _tallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('S-082: screener_screen.dart chips', () {
    testWidgets('all 14 fixture topics present', (tester) async {
      await _tallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
          child: const MaterialApp(home: ScreenerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      _expectChips(tester, const [
        'ticker',
        'side',
        'strike',
        'stock_price',
        'credit',
        'expiration',
        'contracts',
        'iv',
        'iv_rank',
        'annualised_yield',
        'one_sigma',
        'strike_distance',
        'hard_gates',
        'sorting_score',
      ]);
    });
  });

  group('S-082: snapshot sheet (position_detail_sheet.dart) chips', () {
    testWidgets('all 5 fixture topics present in the update-snapshot sheet', (tester) async {
      await _tallSurface(tester);
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('AAA');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: DateTime(2026, 3, 1),
          contracts: 1,
          openedAt: DateTime(2026, 1, 1),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: result.leg.id)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update snapshot'));
      await tester.pumpAndSettle();

      _expectChips(tester, const ['option_mark', 'stock_price', 'delta', 'delta_convention', 'iv']);
    });
  });

  group('S-082: position detail arithmetic card chips', () {
    testWidgets('all 5 fixture topics present', (tester) async {
      await _tallSurface(tester);
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('BBB');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('45'),
          expiration: DateTime(2026, 3, 1),
          contracts: 1,
          openedAt: DateTime(2026, 1, 1),
          openCreditPerShare: Decimal.parse('0.60'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );
      await repo.appendSnapshot(
        NewSnapshotInput(
          legId: result.leg.id,
          takenAt: DateTime(2026, 1, 1),
          optionMark: Decimal.parse('0.30'),
          underlyingPrice: Decimal.parse('46'),
          deltaAsEntered: -0.25,
          deltaConvention: DeltaConvention.position,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: PositionDetailSheet(legId: result.leg.id)),
        ),
      );
      await tester.pumpAndSettle();

      _expectChips(tester, const ['captured', 'roll_band', 'one_sigma', 'extrinsic', 'cumulative_credit']);
    });
  });

  group('S-082: assignment_flow_screen.dart chip', () {
    testWidgets('wheel_basis present after put assignment', (tester) async {
      await _tallSurface(tester);
      final repo = InMemoryWheelRepository();
      final underlying = await repo.getOrCreateUnderlying('CCC');
      final result = await repo.createCycle(
        underlyingId: underlying.id,
        firstLeg: NewLegInput(
          optionType: OptionType.put,
          strike: Decimal.parse('50'),
          expiration: DateTime(2026, 3, 1),
          contracts: 1,
          openedAt: DateTime(2026, 1, 1),
          openCreditPerShare: Decimal.parse('1.20'),
          ruleProfileVersionId: RuleProfileVersionIds.standardV1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: AssignmentFlowScreen(legId: result.leg.id)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm assignment'));
      await tester.pumpAndSettle();

      _expectChips(tester, const ['wheel_basis']);
    });
  });

  group('S-082: record_trade_screen.dart chips', () {
    testWidgets('every §C2 topic the Record screen shows is present', (tester) async {
      await _tallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wheelRepositoryProvider.overrideWithValue(InMemoryWheelRepository())],
          child: const MaterialApp(home: RecordTradeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // The optional-fields disclosure hides three of the topics until it is
      // opened, and the credit label (and so its chip) differs by side.
      ProviderScope.containerOf(tester.element(find.byType(RecordTradeScreen)))
          .read(recordControllerProvider.notifier)
        ..setSide(OptionType.call)
        ..setShowOptional(true);
      await tester.pumpAndSettle();

      _expectChips(tester, const [
        'ticker',
        'side',
        'strike',
        'expiration',
        'credit',
        'contracts',
        'stock_price',
        'iv',
        'iv_rank',
        'annualised_yield',
      ]);
    });
  });
}
