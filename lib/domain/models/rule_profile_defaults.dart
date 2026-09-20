import 'package:decimal/decimal.dart';

/// The exact §4.4 defaults for the seeded `Standard` rule profile.
/// `Conservative` and `Aggressive` are exact placeholder copies of these
/// same numbers this run (Feature Invariant 8) — no UI exposes or lets the
/// user pick between profiles yet, so inventing distinct numbers now would
/// be guessing at thresholds the brief never specified.
///
/// Pure Dart, no Drift/Flutter import, so both `DriftWheelRepository`'s
/// migration seed step and `InMemoryWheelRepository`'s equivalent seeding
/// can share one canonical source of these numbers instead of risking two
/// copies drifting apart.
abstract final class StandardProfileDefaults {
  static const profitTargetPct = 50.0;
  static const assignThreshold = 0.70;
  static const baseRollBand = 0.30;
  static const midIvRollBand = 0.35;
  static const highIvRollBand = 0.40;
  static const midIvCutoff = 40.0;
  static const highIvCutoff = 70.0;
  static const tailDteDays = 3;
  static final tailExtrinsicThreshold = Decimal.parse('0.05');
  static const minIvRank = 30.0;
  static const minAnnualisedYield = 20.0;
  static const targetDteMin = 30;
  static const targetDteMax = 45;
  static const targetDelta = 0.30;
}
