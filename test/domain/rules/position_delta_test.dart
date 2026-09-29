// `docs/brief-pro.md` D-P14 / Pro Wave 3 D-43: the book's net position delta.
// Two scenarios -- S-296 (all four sign quadrants) and S-297 (the exclusions,
// each named once).

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/format.dart';
import 'package:wheel_triage/domain/models/leg.dart';
import 'package:wheel_triage/domain/models/share_lot.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/domain/models/wheel_cycle.dart';
import 'package:wheel_triage/domain/rules/position_delta.dart';

final _now = DateTime.utc(2026, 9, 28);

/// A leg that is open unless [closedAt] says otherwise, expiring after today
/// unless [expiration] says otherwise.
Leg _leg({
  required String id,
  OptionType optionType = OptionType.put,
  int contracts = 1,
  String strike = '10.00',
  DateTime? expiration,
  DateTime? closedAt,
}) => Leg(
  id: id,
  cycleId: 'cycle-$id',
  sequence: 0,
  optionType: optionType,
  strike: Decimal.parse(strike),
  expiration: expiration ?? DateTime.utc(2026, 10, 16),
  contracts: contracts,
  openedAt: DateTime.utc(2026, 9, 1),
  openCreditPerShare: Decimal.parse('0.50'),
  closedAt: closedAt,
  ruleProfileVersionId: 'rule-profile-standard-v1',
);

Snapshot _snapshot({
  required String legId,
  required double delta,
  required DeltaConvention convention,
}) => Snapshot(
  id: 'snap-$legId',
  legId: legId,
  takenAt: DateTime.utc(2026, 9, 25),
  optionMark: Decimal.parse('0.50'),
  underlyingPrice: Decimal.parse('10.00'),
  deltaAsEntered: delta,
  deltaConvention: convention,
);

/// One leg with a reading.
DeltaLegEntry _open({
  required String id,
  required double delta,
  required DeltaConvention convention,
  OptionType optionType = OptionType.put,
  int contracts = 1,
  String strike = '10.00',
  DateTime? expiration,
}) => (
  leg: _leg(id: id, optionType: optionType, contracts: contracts, strike: strike, expiration: expiration),
  latestSnapshot: _snapshot(legId: id, delta: delta, convention: convention),
);

/// One leg with no reading at all.
DeltaLegEntry _unread({
  required String id,
  OptionType optionType = OptionType.put,
  int contracts = 1,
  String strike = '10.00',
  DateTime? expiration,
}) => (
  leg: _leg(id: id, optionType: optionType, contracts: contracts, strike: strike, expiration: expiration),
  latestSnapshot: null,
);

WheelCycle _cycle({required String id, WheelCycleStatus status = WheelCycleStatus.sellingPuts}) => WheelCycle(
  id: id,
  underlyingId: 'underlying-$id',
  startedAt: DateTime.utc(2026, 8, 1),
  status: status,
);

ShareLot _lot({required String cycleId, required int contracts}) => ShareLot(
  id: 'lot-$cycleId',
  cycleId: cycleId,
  assignedAt: DateTime.utc(2026, 8, 15),
  assignmentStrike: Decimal.parse('10.00'),
  contracts: contracts,
);

DeltaCycleEntry _entry({
  required String ticker,
  WheelCycleStatus status = WheelCycleStatus.sellingPuts,
  List<DeltaLegEntry> legs = const [],
  ShareLot? shareLot,
}) => (
  cycle: _cycle(id: 'cycle-$ticker', status: status),
  ticker: ticker,
  legs: legs,
  shareLot: shareLot,
);

void main() {
  group('S-296: net position delta -- all four sign quadrants', () {
    // Q1: a short put, entered either way, is +0.40.
    final putAsPosition = _open(id: 'q1a', delta: 0.40, convention: DeltaConvention.position);
    final putAsOption = _open(id: 'q1b', delta: -0.40, convention: DeltaConvention.option);
    // Q2: a short call, entered either way, is -0.30.
    final callAsPosition = _open(id: 'q2a', delta: -0.30, convention: DeltaConvention.position, optionType: OptionType.call);
    final callAsOption = _open(id: 'q2b', delta: 0.30, convention: DeltaConvention.option, optionType: OptionType.call);

    final book = <DeltaCycleEntry>[
      _entry(ticker: 'AAA', legs: [putAsPosition]),
      _entry(ticker: 'BBB', legs: [putAsOption]),
      _entry(ticker: 'CCC', legs: [callAsPosition]),
      _entry(ticker: 'DDD', legs: [callAsOption]),
      // Q3: a holdingShares cycle with no call leg at all -- the shares it
      // holds are +100 x contracts.
      _entry(ticker: 'EEE', status: WheelCycleStatus.holdingShares, shareLot: _lot(cycleId: 'cycle-EEE', contracts: 1)),
      // Q4: a put plus a two-contract lot: +40 + 200.
      _entry(
        ticker: 'FFF',
        status: WheelCycleStatus.holdingShares,
        legs: [_open(id: 'q4', delta: 0.20, convention: DeltaConvention.position, contracts: 2)],
        shareLot: _lot(cycleId: 'cycle-FFF', contracts: 2),
      ),
    ];

    test('the four quadrants sum to +360 shares', () {
      final delta = netPositionDelta(book: book, now: _now);
      expect(delta.shares, 360.0);
      expect(signedSharesText(delta.shares), '+360 shares');
    });

    test('nothing is excluded, so there is no "Left out" line', () {
      final delta = netPositionDelta(book: book, now: _now);
      expect(delta.pastExpirationTickers, isEmpty);
      expect(delta.noReadingTickers, isEmpty);
      expect(leftOutLine(delta), '');
    });

    test('the same position under either convention produces the same number', () {
      expect(legShares(putAsPosition.leg, putAsPosition.latestSnapshot!), 40.0);
      expect(legShares(putAsOption.leg, putAsOption.latestSnapshot!), 40.0);
      expect(legShares(callAsPosition.leg, callAsPosition.latestSnapshot!), -30.0);
      expect(legShares(callAsOption.leg, callAsOption.latestSnapshot!), -30.0);
    });

    test('the option convention is the exact negation of the position one', () {
      // A long call entered as +0.30 under the position convention and a short
      // call entered as +0.30 under the option convention are mirror images.
      expect(
        positionDelta(_snapshot(legId: 'x', delta: 0.30, convention: DeltaConvention.option)),
        -positionDelta(_snapshot(legId: 'x', delta: 0.30, convention: DeltaConvention.position)),
      );
    });

    test('shares held come from the lot, and only while the cycle holds shares', () {
      final holding = _cycle(id: 'c1', status: WheelCycleStatus.holdingShares);
      final selling = _cycle(id: 'c2');
      final lot = _lot(cycleId: 'c1', contracts: 2);
      expect(sharesHeld(holding, lot), 200);
      expect(sharesHeld(selling, lot), 0);
      expect(sharesHeld(holding, null), 0);
    });

    test('a closed leg is excluded without being named', () {
      final closed = (
        leg: _leg(id: 'gone', closedAt: DateTime.utc(2026, 9, 20)),
        latestSnapshot: _snapshot(legId: 'gone', delta: 0.40, convention: DeltaConvention.position),
      );
      final delta = netPositionDelta(book: [_entry(ticker: 'AAA', legs: [closed])], now: _now);
      expect(delta.shares, 0.0);
      expect(leftOutLine(delta), '');
    });

    test('a zero total renders "0 shares" with no sign', () {
      expect(signedSharesText(0.0), '0 shares');
      expect(signedSharesText(-0.0), '0 shares');
      expect(signedSharesText(null), '--');
    });

    test('a negative total renders the app\'s own minus sign', () {
      final delta = netPositionDelta(
        book: [_entry(ticker: 'AAA', legs: [callAsPosition])],
        now: _now,
      );
      expect(delta.shares, -30.0);
      expect(signedSharesText(delta.shares), '−30 shares');
    });
  });

  group('S-297: the delta\'s exclusions, named once each', () {
    // PFE: open, live, no reading -> "no reading".
    final pfe = _unread(id: 'pfe', strike: '25.00');
    // AAL: past expiration, with a reading -> "past expiration", and its
    // reading is not counted anywhere.
    final aal = _open(id: 'aal', delta: 0.29, convention: DeltaConvention.option, contracts: 2, expiration: DateTime.utc(2026, 9, 18));
    // WBD: past expiration *and* no reading -> named once, under past
    // expiration, because that is the actionable list.
    final wbd = _unread(id: 'wbd', strike: '9.00', expiration: DateTime.utc(2026, 9, 18));
    // INTC: the one included leg.
    final intc = _open(id: 'intc', delta: -0.19, convention: DeltaConvention.option, contracts: 4, strike: '20.00');

    final book = <DeltaCycleEntry>[
      _entry(ticker: 'PFE', legs: [pfe]),
      _entry(ticker: 'AAL', legs: [aal]),
      _entry(ticker: 'WBD', legs: [wbd]),
      _entry(ticker: 'INTC', legs: [intc]),
    ];

    test('only the included leg counts, and the line names each exclusion once', () {
      final delta = netPositionDelta(book: book, now: _now);
      // 0.19 x 100 x 4. AAL's reading is not counted anywhere, and a
      // past-expiration leg contributes nothing.
      expect(delta.shares, 76.0);
      expect(signedSharesText(delta.shares), '+76 shares');
      expect(delta.pastExpirationTickers, ['AAL', 'WBD']);
      expect(delta.noReadingTickers, ['PFE']);
      // A-Z within a clause, per D-43's rule ("tickers A-Z within a clause").
      // S-297's own pinned string reads "WBD, AAL" -- see the plan's Assumption
      // Log entry for this run.
      expect(leftOutLine(delta), 'Left out: PFE (no reading); AAL, WBD (past expiration)');
      // WBD appears once, under past expiration, and not under both.
      expect(leftOutLine(delta).split('WBD').length - 1, 1);
    });

    test('a leg that is both past expiration and unread is named only once', () {
      final delta = netPositionDelta(book: [_entry(ticker: 'WBD', legs: [wbd])], now: _now);
      expect(delta.pastExpirationTickers, ['WBD']);
      expect(delta.noReadingTickers, isEmpty);
    });

    test('the exclusion lists are deduplicated and A-Z across a whole book', () {
      final delta = netPositionDelta(
        book: [
          _entry(ticker: 'WBD', legs: [_unread(id: 'wbd-1', expiration: DateTime.utc(2026, 9, 18))]),
          _entry(ticker: 'AAL', legs: [_unread(id: 'aal-1', expiration: DateTime.utc(2026, 9, 18))]),
          _entry(ticker: 'WBD', legs: [_unread(id: 'wbd-2', expiration: DateTime.utc(2026, 9, 18))]),
        ],
        now: _now,
      );
      expect(delta.pastExpirationTickers, ['AAL', 'WBD']);
    });

    test('a book with nothing left out renders no line at all', () {
      final delta = netPositionDelta(
        book: [_entry(ticker: 'INTC', legs: [_open(id: 'intc', delta: 0.19, convention: DeltaConvention.position, contracts: 4)])],
        now: _now,
      );
      expect(leftOutLine(delta), '');
    });

    test('a leg expiring today is still live, not past expiration', () {
      final delta = netPositionDelta(
        book: [_entry(ticker: 'T', legs: [_unread(id: 't', expiration: DateTime.utc(2026, 9, 28))])],
        now: _now,
      );
      expect(delta.pastExpirationTickers, isEmpty);
      expect(delta.noReadingTickers, ['T']);
    });
  });
}
