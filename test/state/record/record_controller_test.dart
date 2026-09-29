import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/data/wheel_repository.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/rule_profile_ids.dart';
import 'package:wheel_triage/domain/rules/credit_bound.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/record/record_controller.dart';
import 'package:wheel_triage/state/repository_providers.dart';

final _now = DateTime(2026, 9, 28, 10); // a Monday
final _friday = DateTime(2026, 10, 2); // a Friday

Future<Leg> _openCycle(
  InMemoryWheelRepository repo, {
  required String ticker,
  required DateTime openedAt,
  DateTime? closedAt,
}) async {
  final underlying = await repo.getOrCreateUnderlying(ticker);
  final result = await repo.createCycle(
    underlyingId: underlying.id,
    firstLeg: NewLegInput(
      optionType: OptionType.put,
      strike: Decimal.parse('30'),
      expiration: DateTime(2026, 11, 20),
      contracts: 1,
      openedAt: openedAt,
      openCreditPerShare: Decimal.parse('0.50'),
      ruleProfileVersionId: RuleProfileVersionIds.standardV1,
    ),
  );
  if (closedAt != null) {
    await repo.closeLeg(
      legId: result.leg.id,
      reason: CloseReason.closedEarly,
      closeDebitPerShare: Decimal.parse('0.10'),
      closedAt: closedAt,
    );
  }
  return result.leg;
}

void main() {
  late InMemoryWheelRepository repo;
  late ProviderContainer container;

  ProviderContainer build({DateTime? now}) {
    final c = ProviderContainer(
      overrides: [
        wheelRepositoryProvider.overrideWithValue(repo),
        recordControllerProvider.overrideWith(
          (ref) => RecordController(ref, now: now ?? _now),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(recordControllerProvider, (previous, next) {});
    c.listen(preferencesControllerProvider, (previous, next) {});
    return c;
  }

  setUp(() => repo = InMemoryWheelRepository());

  RecordController controller() => container.read(recordControllerProvider.notifier);
  RecordFormState form() => container.read(recordControllerProvider);

  group('S-229: recently used ticker chips', () {
    test(
      'distinct tickers, most recent leg first, closed cycles included, capped at six',
      () async {
        await _openCycle(repo, ticker: 'CCL', openedAt: _now.subtract(const Duration(days: 10)));
        await _openCycle(repo, ticker: 'INTC', openedAt: _now.subtract(const Duration(days: 8)));
        await _openCycle(
          repo,
          ticker: 'KO',
          openedAt: _now.subtract(const Duration(days: 20)),
          closedAt: _now.subtract(const Duration(days: 15)),
        );
        // KO's most recent leg opened after INTC's.
        await _openCycle(repo, ticker: 'KO', openedAt: _now.subtract(const Duration(days: 6)));
        await _openCycle(
          repo,
          ticker: 'SNAP',
          openedAt: _now.subtract(const Duration(days: 5)),
          closedAt: _now.subtract(const Duration(days: 4)),
        );

        container = build();
        await controller().load();

        expect(form().recentTickers, ['SNAP', 'KO', 'INTC', 'CCL']);

        controller().selectRecentTicker('KO');
        expect(form().ticker, 'KO');
      },
    );

    test('is capped at six distinct tickers', () async {
      for (var i = 0; i < 8; i++) {
        await _openCycle(
          repo,
          ticker: 'T$i',
          openedAt: _now.subtract(Duration(days: 30 - i)),
        );
      }

      container = build();
      await controller().load();

      expect(form().recentTickers, hasLength(6));
      expect(form().recentTickers.first, 'T7');
    });
  });

  group('S-230: expiration chips', () {
    test('from Friday 2026-10-02 the chips are the next four Fridays', () async {
      container = build(now: _friday);
      await controller().load();

      expect(form().fridayOptions, [
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 16),
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 30),
      ]);
      // The farthest chip is pre-selected.
      expect(form().expiration, DateTime(2026, 10, 30));
      expect(form().dte, 28);
    });

    test('from Monday 2026-09-28 today itself is not offered', () async {
      container = build();
      await controller().load();

      expect(form().fridayOptions, [
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 16),
        DateTime(2026, 10, 23),
      ]);
      expect(form().expiration, DateTime(2026, 10, 23));
      expect(form().dte, 25);

      controller().setExpiration(DateTime(2026, 10, 16));
      expect(form().dte, 18);

      // A Thursday through the picker warns and is not blocked.
      controller().setExpiration(DateTime(2026, 10, 15));
      expect(form().nonFridayWarning, isTrue);
      expect(form().expiration, DateTime(2026, 10, 15));
    });
  });

  group('S-231: the credit bound on Record', () {
    test('a put is hard-rejected with no stock price entered', () async {
      container = build();
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('34'));

      final bound = c.creditBound;
      expect(bound, isNotNull);
      expect(bound!.level, CreditBoundLevel.hardReject);
      expect(bound.message, contains('strike price'));

      final ok = await c.save();
      expect(ok, isFalse);
      expect(form().error, bound.message);
      expect(await repo.getAllLegs(), isEmpty);
    });

    test('with the toggle on, 34.00 is divided by 100 and passes', () async {
      container = build();
      final prefs = container.read(preferencesControllerProvider.notifier);
      await prefs.ready;
      await prefs.update((p) => p.copyWith(totalPerContractToggle: true));
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('34'));

      expect(form().credit, Decimal.parse('0.34'));
      expect(c.creditBound!.level, CreditBoundLevel.ok);
      expect(await c.save(), isTrue);
      expect((await repo.getOpenLegs()).single.openCreditPerShare, Decimal.parse('0.34'));
    });

    test('a call with no stock price skips the check rather than guessing', () async {
      container = build();
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('50'));

      expect(c.creditBound, isNull);
      expect(form().error, isNull);
    });

    test('a call with a stock price below the credit hard-rejects', () async {
      container = build();
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('50'))
        ..setSpot(Decimal.parse('18'));

      expect(c.creditBound!.level, CreditBoundLevel.hardReject);
      expect(await c.save(), isFalse);
      expect(await repo.getAllLegs(), isEmpty);
    });
  });

  group('S-232: total per contract on Record', () {
    test('typing 34.00 for one contract persists 0.34 per share', () async {
      container = build();
      final prefs = container.read(preferencesControllerProvider.notifier);
      await prefs.ready;
      await prefs.update((p) => p.copyWith(totalPerContractToggle: true));
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('34'))
        ..setExpiration(DateTime(2026, 10, 16))
        ..setContracts(1);

      expect(form().credit, Decimal.parse('0.34'));
      expect(c.annualisedYield, closeTo(36.287, 0.01));

      expect(await c.save(), isTrue);
      expect((await repo.getOpenLegs()).single.openCreditPerShare, Decimal.parse('0.34'));
    });
  });

  group('S-237: Record\'s preview figures', () {
    test('annualised yield and capital committed', () async {
      container = build();
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 16))
        ..setContracts(2);

      expect(form().dte, 18);
      expect(c.annualisedYield, closeTo(36.287, 0.01));
      expect(c.capitalCommitted, Decimal.parse('3800'));
    });

    test('the same formula at a second DTE', () async {
      container = build();
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 9))
        ..setContracts(1);

      expect(form().dte, 11);
      expect(c.annualisedYield, closeTo(0.34 / 19 * 365 / 11 * 100, 0.0001));
      expect(c.capitalCommitted, Decimal.parse('1900'));
    });
  });

  group('S-228: saving through the controller', () {
    test('the optionals left blank persist as null, never zero', () async {
      container = build();
      await controller().load();
      final c = controller();
      c
        ..setTicker('ccl')
        ..setSide(OptionType.put)
        ..setStrike(Decimal.parse('19'))
        ..setCredit(Decimal.parse('0.34'))
        ..setExpiration(DateTime(2026, 10, 16))
        ..setContracts(2);

      expect(await c.save(), isTrue);
      expect(form().saved, isTrue);
      expect(form().confirmation, contains('CCL'));

      final leg = (await repo.getOpenLegs()).single;
      expect(leg.openFee, isNull);
      expect(leg.ivAtOpen, isNull);
      expect(leg.ivRankAtOpen, isNull);
      expect(leg.underlyingPriceAtOpen, isNull);
      expect(leg.acceptsAssignment, isTrue);
    });

    test('a call with no shares is refused and the form keeps its values', () async {
      container = build();
      await controller().load();
      final c = controller();
      c
        ..setTicker('CCL')
        ..setSide(OptionType.call)
        ..setStrike(Decimal.parse('28'))
        ..setCredit(Decimal.parse('0.30'))
        ..setSpot(Decimal.parse('28'))
        ..setExpiration(DateTime(2026, 10, 16));

      expect(await c.save(), isFalse);
      expect(
        form().error,
        'Calls are recorded against shares held from an assignment, and there '
        'are no CCL shares on record.',
      );
      expect(form().ticker, 'CCL');
      expect(form().strike, Decimal.parse('28'));
      expect(form().credit, Decimal.parse('0.30'));
      expect(form().saved, isFalse);
      expect(await repo.getAllLegs(), isEmpty);
    });
  });
}
