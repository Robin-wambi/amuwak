/// A managed, priced service item (blanket, duvet, jacket…) with a fixed
/// per-piece price. In the cart, picking one adds a piece line; on checkout it
/// becomes an ordinary `LineItem` on the order (the catalog is a source of
/// suggestions, not a per-order structure).
///
/// `name` is trimmed and must be non-empty; `amountUgx` is integer UGX >= 0.
/// `active` is false for retired items (kept for history, hidden from pickers).
/// `sortOrder` controls display order (lower first). `category` is an optional
/// free-form grouping (e.g. "Dry Cleaning").
///
/// Mirrors the staff app's `CatalogItem` and the `pricing_catalog_items` table;
/// the customer app reads it (RLS `pricing_catalog_items_customer_read`) to
/// price piece items. Kept as its own copy for now so this change touches only
/// `amuwak_core`; unifying the two definitions is deferred.
class CatalogItem {
  CatalogItem({
    required this.id,
    required String name,
    required this.amountUgx,
    this.active = true,
    this.sortOrder = 0,
    String? category,
  })  : name = name.trim(),
        category = (category != null && category.trim().isNotEmpty)
            ? category.trim()
            : null {
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (amountUgx < 0) {
      throw ArgumentError.value(amountUgx, 'amountUgx', 'must be >= 0');
    }
  }

  final String id;
  final String name;
  final int amountUgx;
  final bool active;
  final int sortOrder;
  final String? category;

  /// Reads a Supabase `pricing_catalog_items` row. `active`/`sort_order` degrade
  /// to their defaults if absent.
  factory CatalogItem.fromSupabase(Map<String, dynamic> r) => CatalogItem(
        id: r['id'] as String,
        name: r['name'] as String,
        amountUgx: (r['amount_ugx'] as num).toInt(),
        active: (r['active'] as bool?) ?? true,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
        category: r['category'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is CatalogItem &&
      other.id == id &&
      other.name == name &&
      other.amountUgx == amountUgx &&
      other.active == active &&
      other.sortOrder == sortOrder &&
      other.category == category;

  @override
  int get hashCode =>
      Object.hash(id, name, amountUgx, active, sortOrder, category);

  @override
  String toString() =>
      'CatalogItem($id, $name, $amountUgx, active: $active, sort: $sortOrder, '
      'category: $category)';
}
