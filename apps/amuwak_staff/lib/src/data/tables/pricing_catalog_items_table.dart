import 'package:drift/drift.dart';

/// Managed catalog of priced service items staff pick from at billing. Retired
/// items keep `active = false` (hidden from the picker, preserved for history).
///
/// NB: like `PricingSettings`, this table is part of the local Drift schema for
/// future use but has no offline path yet — `PricingCatalogRepository` reads and
/// writes Supabase directly (one-shot, refetched after edits).
class PricingCatalogItems extends Table {
  TextColumn     get id        => text()();
  TextColumn     get name      => text()();
  IntColumn      get amountUgx => integer().named('amount_ugx')();
  BoolColumn     get active    => boolean().withDefault(const Constant(true))();
  IntColumn      get sortOrder => integer().named('sort_order').withDefault(const Constant(0))();
  TextColumn     get category  => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
