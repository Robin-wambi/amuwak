import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalog_item.dart';

typedef FetchCatalogRows = Future<List<Map<String, dynamic>>> Function(
    {required bool activeOnly});
typedef UpsertCatalogRow = Future<void> Function(Map<String, dynamic> values);

/// Reads and writes the `pricing_catalog_items` table.
///
/// Reads are one-shot (like `pricing_settings`; the table is not in the realtime
/// publication). The pickup/billing UI fetches active items; the catalog manager
/// fetches all and upserts edits. Rows are ordered by `sort_order` then `name`.
class PricingCatalogRepository {
  PricingCatalogRepository(this._supabase)
      : _fetchRowsOverride = null,
        _upsertRowOverride = null;

  /// Test seam: inject the raw fetch/upsert so unit tests don't mock
  /// SupabaseClient.
  PricingCatalogRepository.forTest({
    required FetchCatalogRows fetchRows,
    UpsertCatalogRow? upsertRow,
  })  : _supabase = null,
        _fetchRowsOverride = fetchRows,
        _upsertRowOverride = upsertRow;

  final SupabaseClient? _supabase;
  final FetchCatalogRows? _fetchRowsOverride;
  final UpsertCatalogRow? _upsertRowOverride;

  Future<List<Map<String, dynamic>>> _fetchRows({required bool activeOnly}) {
    final override = _fetchRowsOverride;
    if (override != null) return override(activeOnly: activeOnly);
    var query = _supabase!.from('pricing_catalog_items').select();
    if (activeOnly) query = query.eq('active', true);
    return query
        .order('sort_order')
        .order('name')
        .then((rows) => rows.cast<Map<String, dynamic>>());
  }

  /// Active items only, for the pickup/billing picker.
  Future<List<CatalogItem>> fetchActive() async {
    final rows = await _fetchRows(activeOnly: true);
    return rows.map(CatalogItem.fromSupabase).toList(growable: false);
  }

  /// All items including retired ones, for the catalog manager screen.
  Future<List<CatalogItem>> fetchAll() async {
    final rows = await _fetchRows(activeOnly: false);
    return rows.map(CatalogItem.fromSupabase).toList(growable: false);
  }

  /// Creates or updates a catalog item (upsert on the primary key). Deactivating
  /// is just an upsert of a copy with `active: false`.
  Future<void> upsertItem(CatalogItem item) async {
    final values = item.toSupabase();
    final override = _upsertRowOverride;
    if (override != null) {
      await override(values);
      return;
    }
    await _supabase!.from('pricing_catalog_items').upsert(values);
  }
}
