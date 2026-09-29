/// Pro Wave 3 D-43: the shared way two lines name a list of tickers — the
/// net-position-delta's "Left out" line and Portfolio's past-expiration
/// sentence. Pure, zero Flutter imports, zero I/O.
///
/// The two callers render the same shape (`A, B and C`, optionally with one
/// reason in parentheses), so the phrasing lives in one place rather than
/// being restated at each call site.

library;

/// `A` / `A and B` / `A, B and C`. An empty list renders **nothing at all** —
/// never a stray `and` — so a caller can join the result into a sentence
/// without testing for emptiness first.
String listPhrase(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.single;
  final head = items.sublist(0, items.length - 1).join(', ');
  return '$head and ${items.last}';
}

/// `A, B (reason)` — the reason clause of a line that names several tickers
/// inside one parenthesis. Deliberately a bare comma list rather than
/// [listPhrase]'s sentence form: inside a clause that is one of several
/// separated by `; `, an `and` would read as if the clause ended the sentence.
/// An empty list renders nothing, so a reason with no members is absent
/// rather than a bare `(reason)`. Callers supply their tickers already
/// deduplicated and ordered.
String listPhraseWithReason(List<String> tickers, String reason) {
  if (tickers.isEmpty) return '';
  return '${tickers.join(', ')} ($reason)';
}
