import 'package:decimal/decimal.dart';

/// Converts a per-share price the user typed into what actually gets used,
/// given whether the "total per contract" preference is on (brief-followup
/// A2, Feature Invariant 21). When on, the user types the total premium for
/// one contract (e.g. `31`) and this divides by 100 — one contract covers
/// 100 shares — *before* the value reaches `checkCreditBound`, any other
/// per-share calculation, or a persisted field. One shared conversion so
/// all four entry points (screener credit, snapshot option mark, roll
/// planner `newCredit`/`buybackDebit`, assignment covered-call credit)
/// apply the toggle identically.
Decimal perShareValue(Decimal typed, {required bool totalPerContract}) {
  if (!totalPerContract) return typed;
  return (typed / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 6);
}
