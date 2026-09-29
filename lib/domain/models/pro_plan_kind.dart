/// Which Pro plan the store reports the user owns (Pro Wave 2, D-25/D-31).
///
/// `none` is the free tier — the value a fresh install, a lapsed
/// subscription and a never-checked cache all carry. Stored on disk as the
/// enum's own `.name` text, never an integer index
/// (`ProPlanKindConverter`), so reordering or inserting a value later never
/// silently reinterprets an existing row.
///
/// Pure Dart, no imports: this is a persisted domain value. The
/// product-id -> kind mapping lives in `lib/core/purchases/pro_plans.dart`,
/// not here, and nothing in `lib/domain/models/` knows about the store.
enum ProPlanKind { none, monthly, annual, lifetime }