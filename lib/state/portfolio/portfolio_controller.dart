import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/wheel_repository.dart';
import '../../domain/models/leg.dart';
import '../../domain/rules/bucket.dart';
import '../../domain/rules/capital_committed.dart' as capital;
import '../../domain/rules/classify.dart';
import '../../domain/rules/expiry.dart' as expiry;
import '../../domain/rules/formulas.dart' as formulas;
import '../../domain/rules/obligation.dart' as obligation;
import '../../domain/rules/position_delta.dart' as delta;
import '../../domain/rules/reading_age.dart' as reading;
import '../../domain/rules/triage_input.dart';
import '../book/book_reads.dart';
import '../repository_providers.dart';

/// One underlying's committed capital, as the concentration card renders it.
typedef PortfolioBar = ({String ticker, Decimal committed, int percent});

/// One date's obligations in the shown month (D-45), with the ticker and the
/// leg so the row can render `SOFI $14 put ×3 · $4,200 cash if assigned`
/// without re-reading the repository.
typedef PortfolioObligation = ({DateTime date, String ticker, Leg leg});

/// Everything the Portfolio screen renders (Pro Wave 3 D-42…D-46).
///
/// Assembled once, at load, so the screen never re-derives a figure and never
/// touches the repository. Every number comes from a shipped rules function —
/// this class is orchestration and type mapping, nothing more.
class PortfolioState {
  const PortfolioState({
    this.isLoading = false,
    this.error,
    this.committedNow,
    this.wheelCapital,
    this.concentrationLimitPct = 25,
    this.percentOfWheelCapital,
    this.bars = const [],
    this.flags = const [],
    this.definitionLine = '',
    this.keyLine,
    this.flagLines = const [],
    this.inviteLine,
    this.deltaShares = 0,
    this.leftOutLine,
    this.agingLine,
    this.calendarMonth,
    this.obligations = const [],
    this.bucketCounts = const [],
  });

  final bool isLoading;
  final String? error;

  /// The big figure: `currentCapitalCommitted` over the whole book. `null`
  /// only before the first load.
  final Decimal? committedNow;

  /// `null` when the user has not set one — the card then shows dollars only.
  final Decimal? wheelCapital;

  final double concentrationLimitPct;

  /// The total as a whole percent of wheel capital, or `null` with no wheel
  /// capital set.
  final int? percentOfWheelCapital;

  /// The bars, ordered exactly as `concentrationFlags` orders its flags.
  final List<PortfolioBar> bars;

  final List<capital.ConcentrationFlag> flags;

  /// `committedNowDefinition` plus, when any past-expiration leg contributes,
  /// D-42's `Includes A and B, past expiration and not yet recorded.`
  final String definitionLine;

  /// `Limit 25% · bars run to 30%`, or `null` with no wheel capital set.
  final String? keyLine;

  /// One line per breaching underlying, or empty.
  final List<String> flagLines;

  /// The no-wheel-capital invitation, or `null` when wheel capital is set.
  final String? inviteLine;

  /// The book's net position delta, in shares (D-43).
  final double deltaShares;

  /// D-43's "Left out" line, or `null` when every leg is included.
  final String? leftOutLine;

  /// D-44's aging note, or `null` when no reading is old enough.
  final String? agingLine;

  /// The month the calendar opens on (D-45).
  final DateTime? calendarMonth;

  /// The shown month's obligations, ascending by date.
  final List<PortfolioObligation> obligations;

  /// The five counts in `kBucketOrder` (D-46), including zeros.
  final List<({Bucket bucket, int count})> bucketCounts;
}

/// Portfolio's state (Pro Wave 3 D-42…D-46). Read-only: it calls no write
/// method on `WheelRepository`, so a lapsed subscription costs the user the
/// *view* and nothing else (D-41).
class PortfolioController extends StateNotifier<PortfolioState> {
  PortfolioController(this._repo) : super(const PortfolioState());

  final WheelRepository _repo;

  Future<void> load({DateTime? now}) async {
    state = const PortfolioState(isLoading: true);
    try {
      final effectiveNow = now ?? DateTime.now();
      final allLegs = await _repo.getAllLegs();
      final prefs = await _repo.getPreferences();
      final inputs = await capitalInputsFor(_repo, allLegs);

      final committedNow = capital.currentCapitalCommitted(inputs, now: effectiveNow);
      final byUnderlying = capital.capitalCommittedByUnderlying(inputs);
      final flags = capital.concentrationFlags(
        capitalByUnderlying: byUnderlying,
        wheelCapital: prefs.wheelCapital,
        concentrationLimitPct: prefs.concentrationLimitPct,
      );

      // The book, as D-43's own entry type: every cycle with its ticker, its
      // legs and their latest readings.
      final book = <delta.DeltaCycleEntry>[];
      final aging = <reading.AgingEntry>[];
      final buckets = <Bucket>[];

      for (final input in inputs) {
        final legEntries = <delta.DeltaLegEntry>[];
        for (final leg in input.legs) {
          final snapshot = await _repo.getLatestSnapshotForLeg(leg.id);
          legEntries.add((leg: leg, latestSnapshot: snapshot));

          if (leg.closedAt != null) continue;
          // D-13/D-44: a past-expiration leg is in none of Today's five
          // counts, so it is in none of these either — the two screens read
          // one population, and the same predicate defines it.
          if (expiry.isPastExpiration(leg, effectiveNow)) continue;
          final profile = await profileForLeg(_repo, leg.ruleProfileVersionId);
          buckets.add(
            classify(
              triageInputFor(
                leg: leg,
                snapshot: snapshot,
                dte: formulas.dte(leg.expiration, effectiveNow),
              ),
              profile,
            ),
          );
          if (snapshot != null) {
            aging.add((ticker: input.ticker, snapshot: snapshot));
          }
        }
        book.add((
          cycle: input.cycle,
          ticker: input.ticker,
          legs: legEntries,
          shareLot: input.shareLot,
        ));
      }

      final netDelta = delta.netPositionDelta(book: book, now: effectiveNow);
      final leftOut = delta.leftOutLine(netDelta);
      final agingLine = reading.agingLine(legs: aging, now: effectiveNow);

      // D-45: the calendar opens on the next upcoming expiration's month, or
      // the month containing today. Only legs expiring today or later appear.
      final openLegs = [
        for (final leg in allLegs)
          if (leg.closedAt == null) leg,
      ];
      final month = obligation.calendarMonth(now: effectiveNow, openLegs: openLegs);
      // `calendarMonth` returns a UTC month identifier; the grid compares
      // calendar dates, so it is normalized back to a local date here.
      final monthDate = DateTime(month.year, month.month, 1);
      final obligations = <PortfolioObligation>[];
      for (final group in obligation.expirationsInMonth(
        legs: openLegs,
        month: monthDate,
        now: effectiveNow,
      )) {
        for (final leg in group.legs) {
          obligations.add((
            date: DateTime(group.date.year, group.date.month, group.date.day),
            ticker: _tickerFor(inputs, leg),
            leg: leg,
          ));
        }
      }

      state = PortfolioState(
        committedNow: committedNow,
        wheelCapital: prefs.wheelCapital,
        concentrationLimitPct: prefs.concentrationLimitPct,
        percentOfWheelCapital: prefs.wheelCapital == null
            ? null
            : capital.concentrationPercent(
                capital: committedNow,
                wheelCapital: prefs.wheelCapital,
              ),
        bars: [
          for (final bar in capital.concentrationBars(
            capitalByUnderlying: byUnderlying,
            wheelCapital: prefs.wheelCapital,
            concentrationLimitPct: prefs.concentrationLimitPct,
          ))
            (ticker: bar.ticker, committed: bar.committed, percent: bar.percent),
        ],
        flags: flags,
        definitionLine: capital.portfolioCommittedDefinition(
          committedNow: committedNow,
          wheelCapital: prefs.wheelCapital,
          pastExpirationTickers: netDelta.pastExpirationTickers,
        ),
        keyLine: prefs.wheelCapital == null
            ? null
            : capital.concentrationKeyLine(prefs.concentrationLimitPct),
        flagLines: [for (final flag in flags) capital.concentrationFlagLine(flag)],
        inviteLine: prefs.wheelCapital == null ? capital.kConcentrationInviteLine : null,
        deltaShares: netDelta.shares,
        leftOutLine: leftOut.isEmpty ? null : leftOut,
        agingLine: agingLine.isEmpty ? null : agingLine,
        calendarMonth: monthDate,
        obligations: obligations,
        bucketCounts: bucketCountsFor(buckets),
      );
    } catch (e) {
      state = PortfolioState(error: 'Could not load the portfolio: $e');
    }
  }

  /// The ticker a leg belongs to, from the inputs already assembled — the
  /// calendar never re-reads the repository for a name it already has.
  String _tickerFor(List<capital.CycleCapitalInput> inputs, Leg leg) {
    for (final input in inputs) {
      if (input.legs.any((l) => l.id == leg.id)) return input.ticker;
    }
    return '?';
  }
}

/// Portfolio's controller. `.autoDispose` so a lapsed subscription's figures
/// are not held in memory, and so Settings' invalidation (D-40) is a real
/// reload rather than a no-op.
final portfolioControllerProvider =
    StateNotifierProvider.autoDispose<PortfolioController, PortfolioState>((ref) {
      return PortfolioController(ref.watch(wheelRepositoryProvider));
    });
