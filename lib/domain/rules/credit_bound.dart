import 'package:decimal/decimal.dart';

import '../models/leg.dart';

/// The no-arbitrage bound check on a per-share option price (brief-followup
/// A2, Feature Invariant 20). **Not** put-call parity — a call can never be
/// worth more than the stock itself (its owner could always just buy the
/// stock instead), and a put can never be worth more than its strike, since
/// the strike is the most it can ever pay out (the stock going to zero).
/// Applies uniformly at the four entry points named in Feature Invariant
/// 20 (screener credit, snapshot-sheet option mark, roll-planner
/// `newCredit`/`buybackDebit`, assignment-flow covered-call credit); this
/// file owns only the pure arithmetic and the exact user-facing message
/// text, matching `classify()`'s own precedent of owning its reason strings
/// inside `lib/domain/rules/` rather than the UI layer. Phase 10 wires this
/// into each of the four fields; this is the pure-function half only.
enum CreditBoundLevel { ok, softWarn, hardReject }

/// [checkCreditBound]'s result. [message] is non-null for [ok] never; it is
/// always non-null for [CreditBoundLevel.softWarn]/[CreditBoundLevel.hardReject].
class CreditBoundResult {
  final CreditBoundLevel level;
  final String? message;

  const CreditBoundResult({required this.level, this.message});

  /// Hard reject blocks the owning submit action; soft warn never does.
  bool get blocks => level == CreditBoundLevel.hardReject;

  static const ok = CreditBoundResult(level: CreditBoundLevel.ok);
}

const String _kDivideHint =
    "Did you enter the total for the contract? Divide by 100 — one contract "
    'covers 100 shares.';

/// `value > spot` (call) / `value > strike` (put) hard-rejects with the
/// verbatim Feature Invariant 20 message; `value > spot * 0.5` (call) /
/// `value > strike * 0.5` (put) soft-warns, never blocking. Callers with no
/// known [spot] yet (no snapshot recorded) must skip calling this entirely
/// rather than pass a stale/guessed value — that skip is the caller's own
/// responsibility (Feature Invariant 20's tail clause, S-057), not
/// something this function can detect.
CreditBoundResult checkCreditBound({
  required Decimal value,
  required OptionType side,
  required Decimal spot,
  required Decimal strike,
}) {
  final isCall = side == OptionType.call;
  final bound = isCall ? spot : strike;
  final halfBound = bound * Decimal.parse('0.5');
  final subject = isCall ? 'share price' : 'strike price';

  if (value > bound) {
    return CreditBoundResult(
      level: CreditBoundLevel.hardReject,
      message: "A premium can't exceed the $subject. $_kDivideHint",
    );
  }
  if (value > halfBound) {
    return CreditBoundResult(
      level: CreditBoundLevel.softWarn,
      message:
          'This is above half the $subject — legitimate on a deep-ITM or '
          'high-IV contract, but usually a units mistake. $_kDivideHint',
    );
  }
  return CreditBoundResult.ok;
}
