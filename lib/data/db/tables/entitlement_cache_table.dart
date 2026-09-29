import 'package:drift/drift.dart';

import '../../../domain/models/entitlement_cache_defaults.dart';
import '../type_converters.dart';

/// Single fixed-id row (schema v6, Pro Wave 2 D-25) — this table only ever
/// holds one row, at id `EntitlementCacheDefaults.rowId` ('default').
/// Mirrors `lib/domain/models/entitlement_cache.dart` 1:1 plus this
/// table-only `id` primary key, which `DriftWheelRepository` never surfaces
/// through `WheelRepository`.
///
/// Every non-nullable column carries a SQL-level `withDefault` so a fresh
/// `onCreate` and the `5 -> 6` migration's `createTable` + seed produce the
/// same row from the same `EntitlementCacheDefaults` constants. The three
/// nullable timestamps have no default: "never checked" / "no expiry" /
/// "no purchase date" backfill to `null`, never to an epoch.
///
/// `plan_kind` reuses `ProPlanKindConverter` (stored as `.name` text, never
/// an index) rather than declaring a second mapping for the same enum.
@DataClassName('EntitlementCacheRow')
class EntitlementCacheTable extends Table {
  @override
  String get tableName => 'entitlement_cache';

  TextColumn get id => text()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(EntitlementCacheDefaults.isActive))();
  TextColumn get planKind => text()
      .map(const ProPlanKindConverter())
      .withDefault(const Constant(EntitlementCacheDefaults.planKindName))();
  IntColumn get expiresAtMs =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const DateTimeMsConverter()))();
  BoolColumn get willRenew =>
      boolean().withDefault(const Constant(EntitlementCacheDefaults.willRenew))();
  BoolColumn get billingIssue =>
      boolean().withDefault(const Constant(EntitlementCacheDefaults.billingIssue))();
  IntColumn get purchasedAtMs =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const DateTimeMsConverter()))();
  IntColumn get checkedAtMs =>
      integer().nullable().map(NullAwareTypeConverter.wrap(const DateTimeMsConverter()))();

  @override
  Set<Column> get primaryKey => {id};
}