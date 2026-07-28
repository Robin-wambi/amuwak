/// A managed, priced service item staff can pick at billing (blanket, duvet,
/// jacket…). Picking one appends an ordinary `LineItem` to the order — the
/// catalog is the source of suggestions, not a per-order structure.
///
/// `name` is trimmed and must be non-empty; `amountUgx` is integer UGX >= 0.
/// `active` is false for retired items (kept for history, hidden from the
/// picker). `sortOrder` controls display order (lower first).
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

  static const Object _unset = Object();

  final String id;
  final String name;
  final int amountUgx;
  final bool active;
  final int sortOrder;

  /// Optional free-form grouping (e.g. "Dry Cleaning"); null = uncategorised.
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

  /// The snake_case shape written to `pricing_catalog_items`.
  Map<String, dynamic> toSupabase() => {
        'id': id,
        'name': name,
        'amount_ugx': amountUgx,
        'active': active,
        'sort_order': sortOrder,
        'category': category,
      };

  CatalogItem copyWith({
    String? name,
    int? amountUgx,
    bool? active,
    int? sortOrder,
    Object? category = _unset,
  }) =>
      CatalogItem(
        id: id,
        name: name ?? this.name,
        amountUgx: amountUgx ?? this.amountUgx,
        active: active ?? this.active,
        sortOrder: sortOrder ?? this.sortOrder,
        category:
            identical(category, _unset) ? this.category : category as String?,
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
