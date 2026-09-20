import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';

void main() {
  group('Leg round-trip (S-030)', () {
    test('all optional fields null', () {
      final leg = Leg(
        id: 'l1',
        cycleId: 'c1',
        sequence: 0,
        optionType: OptionType.put,
        strike: Decimal.parse('45.00'),
        expiration: DateTime.utc(2026, 3, 20),
        contracts: 1,
        openedAt: DateTime.utc(2026, 2, 1),
        openCreditPerShare: Decimal.parse('0.60'),
        ruleProfileVersionId: 'rule-profile-standard-v1',
      );

      final json = leg.toJson();
      final restored = Leg.fromJson(json);

      expect(restored, leg);
      expect(restored.closedAt, isNull);
      expect(restored.closeDebitPerShare, isNull);
      expect(restored.closeReason, isNull);
      expect(restored.rolledFromLegId, isNull);
      expect(restored.ivAtOpen, isNull);
      expect(restored.ivRankAtOpen, isNull);
      expect(restored.deltaAtOpen, isNull);
      expect(restored.underlyingPriceAtOpen, isNull);
      // Phase 15: not passed here -> openFee/closeFee null (never zero),
      // acceptsAssignment defaults to true.
      expect(restored.openFee, isNull);
      expect(restored.closeFee, isNull);
      expect(restored.acceptsAssignment, isTrue);
    });

    test('all optional fields populated', () {
      final leg = Leg(
        id: 'l2',
        cycleId: 'c1',
        sequence: 1,
        optionType: OptionType.call,
        strike: Decimal.parse('52.50'),
        expiration: DateTime.utc(2026, 4, 17),
        contracts: 2,
        openedAt: DateTime.utc(2026, 3, 1),
        openCreditPerShare: Decimal.parse('0.9500'),
        closedAt: DateTime.utc(2026, 3, 15),
        closeDebitPerShare: Decimal.parse('0.8000'),
        closeReason: CloseReason.rolled,
        rolledFromLegId: 'l1',
        ruleProfileVersionId: 'rule-profile-standard-v1',
        ivAtOpen: 45.5,
        ivRankAtOpen: 40.0,
        deltaAtOpen: -0.32,
        underlyingPriceAtOpen: Decimal.parse('48.00'),
        openFee: Decimal.parse('1.50'),
        closeFee: Decimal.parse('0.65'),
        acceptsAssignment: false,
      );

      final json = leg.toJson();
      final restored = Leg.fromJson(json);

      expect(restored, leg);
      expect(restored.strike, Decimal.parse('52.50'));
      expect(restored.closeDebitPerShare, Decimal.parse('0.8000'));
      expect(restored.rolledFromLegId, 'l1');
      expect(restored.openFee, Decimal.parse('1.50'));
      expect(restored.closeFee, Decimal.parse('0.65'));
      expect(restored.acceptsAssignment, isFalse);
    });
  });
}
