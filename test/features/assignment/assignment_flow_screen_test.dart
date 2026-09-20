import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/dates/nearest_friday.dart';
import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/features/assignment/assignment_flow_screen.dart';
import 'package:wheel_triage/state/repository_providers.dart';

void main() {
  group('S-055: assignment-flow covered-call entry -- same date-picker fix as the screener', () {
    testWidgets(
      'default expiration is Friday-snapped (never DateTime.now().add(Duration(days: dte)))',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = InMemoryWheelRepository();
        final underlying = await repo.getOrCreateUnderlying('COV');
        final result = await repo.createCycle(
          underlyingId: underlying.id,
          firstLeg: NewLegInput(
            optionType: OptionType.put,
            strike: Decimal.parse('50'),
            expiration: DateTime.now().add(const Duration(days: 10)),
            contracts: 1,
            openedAt: DateTime.now(),
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

        // Step 1: confirm assignment with the pre-filled strike/contracts.
        await tester.tap(find.text('Confirm assignment'));
        await tester.pumpAndSettle();

        // Step 2/3: the covered-call form's default expiration is always a
        // Friday (Feature Invariant 22) -- no warning shown by default.
        expect(find.textContaining('Not a Friday'), findsNothing);

        // Fill in the remaining required fields and open the covered call.
        await tester.enterText(find.widgetWithText(TextField, 'Credit (\$ per share)'), '0.50');
        await tester.tap(find.text('Open covered call'));
        await tester.pumpAndSettle();

        final legs = await repo.getLegsForCycle(result.cycle.id);
        final callLeg = legs.firstWhere((l) => l.optionType == OptionType.call);
        // Exactly the picker's Friday-snapped default -- not the old
        // `DateTime.now().add(Duration(days: 30))` (a fixed, un-snapped,
        // frequently-non-Friday date).
        final expectedDefault = defaultExpiration(DateTime.now());
        expect(callLeg.expiration.year, expectedDefault.year);
        expect(callLeg.expiration.month, expectedDefault.month);
        expect(callLeg.expiration.day, expectedDefault.day);
        expect(isFriday(callLeg.expiration), isTrue);
      },
    );
  });
}
