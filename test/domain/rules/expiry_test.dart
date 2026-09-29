import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/rules/expiry.dart';

Leg _leg({
  required String id,
  required OptionType optionType,
  required String strike,
  required DateTime expiration,
  int contracts = 1,
  DateTime? closedAt,
}) => Leg(
  id: id,
  cycleId: 'cycle-$id',
  sequence: 0,
  optionType: optionType,
  strike: Decimal.parse(strike),
  expiration: expiration,
  contracts: contracts,
  openedAt: DateTime.utc(2026, 8, 1),
  openCreditPerShare: Decimal.parse('0.50'),
  closedAt: closedAt,
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

Snapshot _snapshot({required String id, required String spot, required DateTime takenAt}) => Snapshot(
  id: id,
  legId: 'leg-$id',
  takenAt: takenAt,
  optionMark: Decimal.parse('0.05'),
  underlyingPrice: Decimal.parse(spot),
  deltaAsEntered: -0.10,
  deltaConvention: DeltaConvention.position,
);

void main() {
  final now = DateTime.utc(2026, 9, 28);

  group('S-225: expiry batch eligibility', () {
    // WBD put $11, last reading $12.10 (OTM) -> eligible.
    final wbd = _leg(id: 'wbd', optionType: OptionType.put, strike: '11.00', expiration: DateTime.utc(2026, 9, 18));
    final wbdReading = _snapshot(id: 'wbd', spot: '12.10', takenAt: DateTime.utc(2026, 9, 24));
    // AAL put $13, last reading $12.60 (ITM) -> not eligible.
    final aal = _leg(id: 'aal', optionType: OptionType.put, strike: '13.00', expiration: DateTime.utc(2026, 9, 18));
    final aalReading = _snapshot(id: 'aal', spot: '12.60', takenAt: DateTime.utc(2026, 9, 23));
    // PFE put $25, no reading -> not eligible.
    final pfe = _leg(id: 'pfe', optionType: OptionType.put, strike: '25.00', expiration: DateTime.utc(2026, 9, 18));
    // A put exactly at its strike in its last reading -> eligible.
    final atStrike = _leg(id: 'at-strike', optionType: OptionType.put, strike: '20.00', expiration: DateTime.utc(2026, 9, 18));
    final atStrikeReading = _snapshot(id: 'at-strike', spot: '20.00', takenAt: DateTime.utc(2026, 9, 24));
    // A leg expiring today: not past expiration, so absent from the card.
    final today = _leg(id: 'today', optionType: OptionType.put, strike: '15.00', expiration: DateTime.utc(2026, 9, 28));

    test('isPastExpiration: strictly after the expiration date', () {
      expect(isPastExpiration(wbd, now), isTrue);
      expect(isPastExpiration(today, now), isFalse);
      expect(isPastExpiration(_leg(id: 'future', optionType: OptionType.put, strike: '15.00', expiration: DateTime.utc(2026, 10, 16)), now), isFalse);
    });

    test('WBD (OTM reading) is eligible', () {
      expect(expiryBatchEligible(leg: wbd, latestSnapshot: wbdReading, now: now), isTrue);
    });

    test('AAL (ITM reading) is not eligible', () {
      expect(expiryBatchEligible(leg: aal, latestSnapshot: aalReading, now: now), isFalse);
    });

    test('PFE (no reading) is not eligible', () {
      expect(expiryBatchEligible(leg: pfe, latestSnapshot: null, now: now), isFalse);
    });

    test('a reading exactly at the strike is not in the money, so it is eligible', () {
      expect(expiryBatchEligible(leg: atStrike, latestSnapshot: atStrikeReading, now: now), isTrue);
    });

    test('a leg expiring today is absent from the card entirely', () {
      final card = pastExpirationCard(
        legs: [
          (leg: wbd, latestSnapshot: wbdReading),
          (leg: aal, latestSnapshot: aalReading),
          (leg: pfe, latestSnapshot: null),
          (leg: atStrike, latestSnapshot: atStrikeReading),
          (leg: today, latestSnapshot: null),
        ],
        now: now,
      );
      expect(card.map((e) => e.leg.id).toList(), ['wbd', 'aal', 'pfe', 'at-strike']);
    });

    test('the partition puts WBD and the at-strike leg in "Mark all"', () {
      final card = pastExpirationCard(
        legs: [
          (leg: wbd, latestSnapshot: wbdReading),
          (leg: aal, latestSnapshot: aalReading),
          (leg: pfe, latestSnapshot: null),
          (leg: atStrike, latestSnapshot: atStrikeReading),
        ],
        now: now,
      );
      final eligible = card.where((e) => e.batchEligible).map((e) => e.leg.id).toList();
      final perLegOnly = card.where((e) => !e.batchEligible).map((e) => e.leg.id).toList();
      expect(eligible, ['wbd', 'at-strike']);
      expect(perLegOnly, ['aal', 'pfe']);
    });

    test('a call is in the money when the spot is above the strike', () {
      final call = _leg(id: 'call', optionType: OptionType.call, strike: '28.00', expiration: DateTime.utc(2026, 9, 18));
      expect(
        expiryBatchEligible(leg: call, latestSnapshot: _snapshot(id: 'call', spot: '29.00', takenAt: now), now: now),
        isFalse,
      );
      expect(
        expiryBatchEligible(leg: call, latestSnapshot: _snapshot(id: 'call', spot: '27.00', takenAt: now), now: now),
        isTrue,
      );
    });

    test('an already-closed past-expiration leg is not on the card', () {
      final closed = _leg(
        id: 'closed',
        optionType: OptionType.put,
        strike: '11.00',
        expiration: DateTime.utc(2026, 9, 18),
        closedAt: DateTime.utc(2026, 9, 18),
      );
      final card = pastExpirationCard(legs: [(leg: closed, latestSnapshot: wbdReading)], now: now);
      expect(card, isEmpty);
    });
  });

  group('S-253: recordedCloseDateForExpiry', () {
    test('a leg expiring before now records its own expiration date', () {
      final leg = _leg(id: 'a', optionType: OptionType.put, strike: '11.00', expiration: DateTime.utc(2026, 9, 25));
      expect(recordedCloseDateForExpiry(leg, now), DateTime.utc(2026, 9, 25));
    });

    test('a leg expiring in five days records the tap time', () {
      final leg = _leg(id: 'b', optionType: OptionType.put, strike: '11.00', expiration: DateTime.utc(2026, 10, 3));
      expect(recordedCloseDateForExpiry(leg, now), now);
    });

    test('a leg expiring today records the expiration date (on/after)', () {
      final leg = _leg(id: 'c', optionType: OptionType.put, strike: '11.00', expiration: DateTime.utc(2026, 9, 28));
      expect(recordedCloseDateForExpiry(leg, now), DateTime.utc(2026, 9, 28));
    });

    test('the recorded date is calendar-day based, not time-of-day based', () {
      final leg = _leg(id: 'd', optionType: OptionType.put, strike: '11.00', expiration: DateTime.utc(2026, 9, 28, 23, 59));
      expect(recordedCloseDateForExpiry(leg, DateTime.utc(2026, 9, 28, 0, 1)), DateTime.utc(2026, 9, 28, 23, 59));
    });
  });

  group('S-250 / S-251: the card copy', () {
    // The reference's own two legs: WBD out of the money, AAL in it.
    final wbd = _leg(id: 'copy-wbd', optionType: OptionType.put, strike: '11.00', expiration: DateTime.utc(2026, 9, 25));
    final wbdReading = _snapshot(id: 'copy-wbd', spot: '12.10', takenAt: DateTime.utc(2026, 9, 24));
    final aal = _leg(id: 'copy-aal', optionType: OptionType.put, strike: '13.00', expiration: DateTime.utc(2026, 9, 25));
    final aalReading = _snapshot(id: 'copy-aal', spot: '12.60', takenAt: DateTime.utc(2026, 9, 23));
    final atStrike = _leg(id: 'copy-at', optionType: OptionType.put, strike: '20.00', expiration: DateTime.utc(2026, 9, 25));
    final atStrikeReading = _snapshot(id: 'copy-at', spot: '20.00', takenAt: DateTime.utc(2026, 9, 24));
    final pfe = _leg(id: 'copy-pfe', optionType: OptionType.put, strike: '25.00', expiration: DateTime.utc(2026, 9, 25));

    test('the reading line names the reading date, the price and the side of the strike', () {
      expect(
        expiryReadingLine(ExpiryCardEntry(leg: wbd, latestSnapshot: wbdReading, batchEligible: true)),
        'Last reading Sep 24: stock \$12.10, above the strike',
      );
      expect(
        expiryReadingLine(ExpiryCardEntry(leg: aal, latestSnapshot: aalReading, batchEligible: false)),
        'Last reading Sep 23: stock \$12.60, below the strike',
      );
      expect(
        expiryReadingLine(ExpiryCardEntry(leg: atStrike, latestSnapshot: atStrikeReading, batchEligible: true)),
        'Last reading Sep 24: stock \$20.00, at the strike',
      );
    });

    test('a leg with no reading says so rather than rendering an empty line', () {
      expect(
        expiryReadingLine(ExpiryCardEntry(leg: pfe, latestSnapshot: null, batchEligible: false)),
        'No reading recorded',
      );
    });

    test('a one-leg batch names that leg and its expiration date', () {
      expect(
        expiryBatchExplanation(
          eligible: [ExpiryCardEntry(leg: wbd, latestSnapshot: wbdReading, batchEligible: true)],
          singleTicker: 'WBD',
        ),
        'Records WBD as expired worthless on Sep 25, no close debit. The close fee stays blank.',
      );
    });

    test('a longer batch says "each leg" instead of naming one', () {
      expect(
        expiryBatchExplanation(
          eligible: [
            ExpiryCardEntry(leg: wbd, latestSnapshot: wbdReading, batchEligible: true),
            ExpiryCardEntry(leg: atStrike, latestSnapshot: atStrikeReading, batchEligible: true),
          ],
          singleTicker: 'WBD',
        ),
        'Records each leg as expired worthless on its own expiration date, no close debit. '
        'The close fee stays blank.',
      );
    });
  });
}
