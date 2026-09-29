import '../models/leg.dart';
import '../models/share_lot.dart';
import '../models/snapshot.dart';
import '../models/wheel_cycle.dart';
import 'expiry.dart' show isPastExpiration;
import 'listing.dart' show listPhraseWithReason;

/// `docs/brief-pro.md` D-P14 / Pro Wave 3 D-43: the book's net position
/// delta, in shares. Pure, zero Flutter imports, zero I/O; `now` is a
/// parameter (`docs/conventions.md` §3).
///
/// The delta is dimensionless (`docs/conventions.md` §2), so it is a
/// `double`: it reaches no gate, no money value, no persisted field and no
/// repository method. Gates keep reading `formulas.deltaMagnitude` only —
/// **no signed value is introduced upstream of a magnitude comparison**.

/// One leg and its latest reading, as the caller already has them.
typedef DeltaLegEntry = ({Leg leg, Snapshot? latestSnapshot});

/// One cycle's worth of the book: the cycle itself, its ticker, every leg in
/// it, and its **active** share lot (`WheelRepository.getShareLotForCycle`),
/// non-null only while the cycle is `holdingShares`.
typedef DeltaCycleEntry = ({
  WheelCycle cycle,
  String ticker,
  List<DeltaLegEntry> legs,
  ShareLot? shareLot,
});

/// The book's net position delta in shares, plus the tickers left out of it
/// under each reason. Both lists are deduplicated and A–Z; a ticker appears
/// in at most one of them (a leg that is both past expiration and unread is
/// named once, under past expiration — that is the actionable list).
typedef NetPositionDelta = ({
  double shares,
  List<String> pastExpirationTickers,
  List<String> noReadingTickers,
});

/// The reading's **position** delta: `+` for a short put, `−` for a short
/// call. The `option` convention records the option's own delta, which is
/// the exact negation for the short leg this app models — one short leg at a
/// time, no spreads (`leg.dart`), so the sign flip is the whole conversion.
///
/// The convention is read from the **snapshot**, never from Settings
/// (Feature Invariant 5): flipping the default never reinterprets history.
double positionDelta(Snapshot snapshot) =>
    snapshot.deltaConvention == DeltaConvention.position ? snapshot.deltaAsEntered : -snapshot.deltaAsEntered;

/// One leg's contribution to the total: its position delta × 100 shares ×
/// its own contract count.
double legShares(Leg leg, Snapshot snapshot) => positionDelta(snapshot) * 100 * leg.contracts;

/// The shares a `holdingShares` cycle holds — from the **share lot**, not
/// from the call leg, so a covered call contributes its 100 × contracts
/// shares *and* its short call's negative delta. Zero for any other status,
/// and for a `holdingShares` cycle whose lot is missing.
int sharesHeld(WheelCycle cycle, ShareLot? shareLot) =>
    cycle.status == WheelCycleStatus.holdingShares ? (shareLot?.contracts ?? 0) * 100 : 0;

/// The book's net position delta (D-43).
///
/// ```
/// net = Σ legShares over INCLUDED legs
///     + Σ sharesHeld over the book's holdingShares cycles
/// ```
///
/// A leg is **included** when it is open (`closedAt == null`), not past
/// expiration, and has a latest reading. Everything else is excluded and
/// named. A closed leg is excluded silently — it is not part of the book.
NetPositionDelta netPositionDelta({required Iterable<DeltaCycleEntry> book, required DateTime now}) {
  var shares = 0.0;
  final pastExpiration = <String>{};
  final noReading = <String>{};

  for (final entry in book) {
    for (final legEntry in entry.legs) {
      final leg = legEntry.leg;
      if (leg.closedAt != null) continue;
      // Past expiration is evaluated first, so a leg that is both past
      // expiration and unread is named once — under the actionable reason.
      if (isPastExpiration(leg, now)) {
        pastExpiration.add(entry.ticker);
        continue;
      }
      final snapshot = legEntry.latestSnapshot;
      if (snapshot == null) {
        noReading.add(entry.ticker);
        continue;
      }
      shares += legShares(leg, snapshot);
    }
    shares += sharesHeld(entry.cycle, entry.shareLot);
  }

  return (
    shares: shares,
    pastExpirationTickers: _sorted(pastExpiration),
    noReadingTickers: _sorted(noReading),
  );
}

/// D-43's "Left out" line — `Left out: PFE (no reading); WBD, AAL (past
/// expiration)`. One clause per non-empty reason, tickers A–Z within a
/// clause, clauses separated by `; `. **The line is absent entirely** when
/// every leg is included, so the caller renders nothing rather than an empty
/// sentence. Pinned by S-297.
String leftOutLine(NetPositionDelta delta) {
  final clauses = <String>[
    listPhraseWithReason(delta.noReadingTickers, 'no reading'),
    listPhraseWithReason(delta.pastExpirationTickers, 'past expiration'),
  ].where((clause) => clause.isNotEmpty).toList();
  if (clauses.isEmpty) return '';
  return 'Left out: ${clauses.join('; ')}';
}

List<String> _sorted(Set<String> tickers) => tickers.toList()..sort();
