/// Single source of truth for every in-app help topic (brief-followup
/// `docs/brief-followup.md` §C2). One file to review, translate, or
/// correct -- content is never inlined in a widget.
///
/// Content is **verbatim** from the brief. Do not paraphrase, tighten, or
/// "improve" any topic's wording -- including phrases that would have
/// tripped the old, broader banned-vocabulary list (e.g. `bucket_close`'s
/// "Buy it back and start fresh"); those are deliberate, and the narrowed
/// list (`docs/conventions.md` §4) passes this file as authored. The
/// source table's markdown bold markers (`**`) are not reproduced
/// literally in these plain-text strings -- that was a table-authoring
/// convention, not content, and rendering literal asterisks to the user
/// would be a display defect, not fidelity. Every word, all punctuation,
/// and the double-hyphen dash style are otherwise character-exact.
library;

/// One topic's content. [whereToFind] is only ever present for the
/// **Inputs** table (§C2's own "Where to find it" column) -- Outputs and
/// Buckets have no such column in the brief, so it stays `null` for those.
class HelpTopic {
  final String title;
  final String body;
  final String? whereToFind;

  const HelpTopic({required this.title, required this.body, this.whereToFind});
}

/// Keyed by the 27 topic ids in §C2's three tables (12 inputs, 10 outputs,
/// 5 buckets).
const Map<String, HelpTopic> helpTopics = {
  // --- Inputs (§C2, "Inputs" table) ---------------------------------
  'ticker': HelpTopic(
    title: 'Ticker',
    body: 'The stock symbol the option is written on.',
    whereToFind: "Top of your broker's position or chain screen.",
  ),
  'side': HelpTopic(
    title: 'Put or call',
    body:
        'A put obligates you to buy shares at the strike; a call obligates you to sell '
        'them. The wheel sells puts first, then calls after assignment.',
    whereToFind: 'The contract name, e.g. "SBET \$11 Call".',
  ),
  'strike': HelpTopic(
    title: 'Strike',
    body: 'The price at which the shares change hands if the option is exercised.',
    whereToFind: 'In the contract name.',
  ),
  'stock_price': HelpTopic(
    title: 'Stock price',
    body: 'What the share trades at right now.',
    whereToFind: "The underlying's quote, not the option's.",
  ),
  'credit': HelpTopic(
    title: 'Credit',
    body:
        'The premium you receive, per share. One contract covers 100 shares, so a '
        '\$0.31 credit pays \$31.',
    whereToFind: "Your fill price, or the bid when you're deciding.",
  ),
  'expiration': HelpTopic(
    title: 'Expiration',
    body: 'The date the contract dies. Listed equity options expire on Fridays.',
    whereToFind: 'In the contract name.',
  ),
  'contracts': HelpTopic(
    title: 'Contracts',
    body: 'How many you sold. Each is 100 shares.',
    whereToFind: 'Your position quantity, ignoring the minus sign.',
  ),
  'iv': HelpTopic(
    title: 'Implied volatility',
    body:
        'The annualised move the market is currently pricing in. Higher IV means '
        'fatter premiums and a wider expected range.',
    whereToFind: 'The option\'s detail screen. Robinhood lists it as "IV".',
  ),
  'iv_rank': HelpTopic(
    title: 'IV rank',
    body:
        "Where today's IV sits within its own past year, 0-100. This is the number "
        "that says whether premium is rich or cheap -- raw IV alone can't tell you.",
    whereToFind: 'Not on Robinhood. Barchart, Market Chameleon, Tastytrade or Thinkorswim.',
  ),
  'option_mark': HelpTopic(
    title: 'Option mark',
    body:
        "The contract's current price per share -- the midpoint of bid and ask. This "
        "is roughly what you'd pay to buy the position back.",
    whereToFind: 'Robinhood labels it "Mark".',
  ),
  'delta': HelpTopic(
    title: 'Delta',
    body:
        "How much the option's price moves per \$1 move in the stock. Useful "
        "shorthand: its absolute value is roughly the market's estimate of the "
        'chance the option finishes in the money.',
    whereToFind: 'Under "The Greeks" on the option\'s detail screen.',
  ),
  'delta_convention': HelpTopic(
    title: 'Delta convention',
    body:
        'Brokers differ on sign. Position delta is signed for the position you hold, '
        "so a short call shows negative. Contract delta is the option's own, always "
        'positive for calls and negative for puts. Robinhood shows position delta -- '
        'leave this on Position. Bucketing uses the absolute value either way; this '
        'only affects the portfolio exposure total.',
  ),

  // --- Outputs (§C2, "Outputs" table) --------------------------------
  'annualised_yield': HelpTopic(
    title: 'Annualised yield',
    body:
        '(credit / strike) x (365 / DTE). What this trade would return if you could '
        "repeat it all year. You can't -- it's a comparison tool for sizing one "
        'candidate against another, not a forecast.',
  ),
  'one_sigma': HelpTopic(
    title: 'One-sigma move',
    body:
        'stock price x IV x sqrt(DTE / 365). Roughly how far the stock could move by '
        'expiration, with about a 68% chance of staying inside that range.',
  ),
  'strike_distance': HelpTopic(
    title: 'Strike distance',
    body:
        'How far your strike sits from the stock price, in dollars and in sigmas. '
        'Sigmas matter more: on a high-IV name a strike 18% away can still be well '
        "inside one sigma, which means the market genuinely thinks it's reachable.",
  ),
  'hard_gates': HelpTopic(
    title: 'Hard gates',
    body:
        "Both must pass before you sell. IV rank says you're being paid enough for "
        'the risk; annualised yield says the premium is worth the capital. A failed '
        'gate means skip the trade, not adjust the trade.',
  ),
  'sorting_score': HelpTopic(
    title: 'Sorting score',
    body:
        "Ranks candidates against each other, 0-9. It is not a verdict and doesn't "
        'override the gates. The band edges were chosen for this app, not drawn from '
        'any published standard -- edit them in Settings.',
  ),
  'captured': HelpTopic(
    title: 'Credit captured',
    body:
        "(opening credit - current mark) / opening credit. How much of the premium "
        "you've actually banked. Closing at 50% is the default because the second "
        'half takes disproportionately longer to earn while the risk keeps rising.',
  ),
  'roll_band': HelpTopic(
    title: 'Roll band',
    body:
        'The delta at which this app flags the strike as threatened. It scales with '
        'IV, because on a volatile name delta 0.30 arrives while the strike is still '
        'far away -- a fixed threshold would fire constantly on positions that were '
        'never at risk.',
  ),
  'extrinsic': HelpTopic(
    title: 'Extrinsic remaining',
    body:
        "mark - intrinsic value. The time value left. Extrinsic decays; intrinsic "
        "doesn't. Once extrinsic is nearly gone there's almost nothing left to "
        'collect, and rolling stops paying.',
  ),
  'cumulative_credit': HelpTopic(
    title: 'Cycle cumulative credit',
    body:
        'Every credit collected on this cycle, minus every buyback debit. When a '
        "position has been rolled, the current leg's credit is only part of the "
        'story -- judge the trade on this number.',
  ),
  'wheel_basis': HelpTopic(
    title: 'Wheel-adjusted basis',
    body:
        'Assignment strike minus all credits collected. Your covered-call strike '
        'floor: selling below it locks in a loss if the shares get called. Not the '
        'same as tax basis.',
  ),

  // --- Buckets (§C2, "Buckets" table -- shown when the badge itself is
  // tapped). The source table has no separate title column for buckets;
  // titles here match `bucket_badge.dart`'s own neutral-verb labels so the
  // sheet's heading matches the badge the user just tapped. ------------
  'bucket_close': HelpTopic(
    title: 'Close',
    body:
        "You've captured enough of the credit that what's left isn't worth the "
        "remaining risk, or there's almost no time value left. Buy it back and start "
        'fresh.',
  ),
  'bucket_roll': HelpTopic(
    title: 'Roll',
    body:
        'Delta says the strike is genuinely threatened. Rolling closes this leg and '
        'opens a later one, ideally for a net credit. If the roll costs a net debit, '
        'taking assignment is usually the cleaner end.',
  ),
  'bucket_assign': HelpTopic(
    title: 'Assign',
    body:
        'Delta is high enough that assignment is the likely outcome. On the put side '
        'that means buying the shares; on the call side, having them called away. If '
        "you'd rather keep the shares, buying the call back is the alternative.",
  ),
  'bucket_leave': HelpTopic(
    title: 'Leave',
    body:
        "No rule fired. The profit target isn't hit and delta is below your roll "
        'band. Nothing to do -- check again in a week.',
  ),
  'bucket_unknown': HelpTopic(
    title: 'No data',
    body:
        'No snapshot on file yet, so nothing has been evaluated. Tap Update snapshot '
        'and enter the current numbers.',
  ),
};
