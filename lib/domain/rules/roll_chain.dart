import 'package:decimal/decimal.dart';

import '../models/leg.dart';

/// Net credit actually kept on one leg: what it was opened for, minus what
/// it cost to close (zero if the leg is still open). Derived, never stored
/// (brief §3.3).
Decimal legNetCredit(Leg leg) =>
    leg.openCreditPerShare - (leg.closeDebitPerShare ?? Decimal.zero);

/// Sum of [legNetCredit] across every leg in a cycle. This is the figure
/// the position detail sheet shows *beside* Gate 1's leg-only `capturedPct`
/// (Feature Invariant 1) -- never substituted into the gate itself.
///
/// Deliberately left unweighted, per-share (Feature Invariant 25): this is
/// NOT a dollar total and must never be presented as one. Any dollar figure
/// (journal/cycle P&L) must use [cycleTotalPremium] instead.
Decimal cycleCumulativeCredit(List<Leg> legs) =>
    legs.fold(Decimal.zero, (sum, leg) => sum + legNetCredit(leg));

/// The contract-weighted dollar total of every leg's own net credit --
/// `Σ (legNetCredit(leg) x 100 x leg.contracts)` (Feature Invariant 25, the
/// coordinator's named fourth formula error). Unlike [cycleCumulativeCredit]
/// (a deliberately unweighted per-share figure kept exactly as built), this
/// is a genuine dollar total and is what every cycle-P&L/journal figure
/// (`netResult`'s `totalPremium`, `lib/domain/rules/cycle_pnl.dart`) must
/// use -- summing each leg's own `contracts` before adding it in, never a
/// per-share sum multiplied by a single leg's contract count after the
/// fact. Correct the instant a roll changes contract count mid-cycle
/// (S-105): nothing in the schema or repository enforces uniform contracts
/// across a cycle's legs (Feature Invariant 26), so this must be right for
/// every leg independently.
Decimal cycleTotalPremium(List<Leg> legs) => legs.fold(
  Decimal.zero,
  (sum, leg) => sum + legNetCredit(leg) * Decimal.fromInt(100) * Decimal.fromInt(leg.contracts),
);

/// The net of one roll pair: the new leg's credit minus the closing leg's
/// buyback debit. Can be negative -- a **debit roll** -- and callers must
/// label it as such, never display it as income (brief §3.3, §5.3, S-013).
Decimal netRollCredit(Leg closingLeg, Leg newLeg) =>
    newLeg.openCreditPerShare - (closingLeg.closeDebitPerShare ?? Decimal.zero);
