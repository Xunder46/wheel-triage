/// `yyyy-MM-dd` — the date shape every screen in this app renders. There is
/// no locale-aware formatting here on purpose: the ledger's dates are
/// compared against broker statements and export files, where the sortable
/// form is the useful one.
String dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
