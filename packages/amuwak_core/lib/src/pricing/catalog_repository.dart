import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalog_item.dart';

typedef FetchCatalogRows = Future<List<Map<String, dynamic>>> Function();

/// Read-only access to `pricing_catalog_items` for the customer app (piece-item
/// prices in the cart). Reads are one-shot (the table is not in the realtime
/// publication), ordered by `sort_order` then `name`, active items only.
/// Customers have SELECT via the `pricing_catalog_items_customer_read` policy.
class CatalogRepository {
  CatalogRepository(this._supabase) : _fetchRowsOverride = null;

  /// Test seam: inject the raw fetch so unit tests don't mock SupabaseClient.
  CatalogRepository.forTest({required FetchCatalogRows fetchRows})
      : _supabase = null,
        _fetchRowsOverride = fetchRows;

  final SupabaseClient? _supabase;
  final FetchCatalogRows? _fetchRowsOverride;

  Future<List<Map<String, dynamic>>> _fetchRows() {
    final override = _fetchRowsOverride;
    if (override != null) return override();
    return _supabase!
        .from('pricing_catalog_items')
        .select()
        .eq('active', true)
        .order('sort_order')
        .order('name')
        .then((rows) => rows.cast<Map<String, dynamic>>());
  }

  /// Active catalog items, ready to offer as piece choices in the cart.
  Future<List<CatalogItem>> fetchActive() async {
    final rows = await _fetchRows();
    return rows.map(CatalogItem.fromSupabase).toList(growable: false);
  }
}
