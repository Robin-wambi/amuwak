import 'service_type.dart';

/// One line of the itemized cart a customer checked out, as frozen onto
/// `orders.cart_items` (jsonb, migration `0050`). Staff-facing and read-only:
/// the whole pickup is still weighed and priced with the staff tools, but this
/// tells them what the customer actually said they were sending — including a
/// damage photo of a garment they flagged.
///
/// Written by the customer app's `cartItemsSnapshot`; the field names here match
/// that shape exactly.
class CartSnapshotItem {
  const CartSnapshotItem({
    required this.kind,
    required this.name,
    this.serviceType,
    this.estKg,
    this.unitUgx,
    this.qty = 1,
    this.note,
    this.photoKey,
  });

  /// `'weight'` (a service + estimated kilos) or `'piece'` (a catalog item ×
  /// [qty]).
  final String kind;

  /// Service label or catalog-item name, as the customer saw it.
  final String name;

  /// Set on weight lines. Null when absent or unrecognised — a service this
  /// build doesn't know must not error the orders stream.
  final ServiceType? serviceType;
  final double? estKg;
  final int? unitUgx;
  final int qty;
  final String? note;

  /// Object key in the private `customer-uploads` bucket (migration `0052`).
  /// Staff read it through a signed URL; it may not be uploaded yet, since the
  /// customer's queued upload and their order drain independently.
  final String? photoKey;

  bool get isWeight => kind != 'piece';
  bool get hasPhoto => photoKey != null && photoKey!.isNotEmpty;

  /// The quantity line staff read under the item name.
  String get subtitle {
    if (!isWeight) return '× $qty';
    if (estKg == null) return 'weight not estimated';
    final kg = estKg! % 1 == 0 ? estKg!.toInt().toString() : estKg!.toString();
    return '~$kg kg';
  }

  /// Tolerant hydrator: every field degrades rather than throwing, because one
  /// malformed snapshot must not take down the staff orders stream (the same
  /// invariant the pricing snapshots follow).
  factory CartSnapshotItem.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] as String?)?.trim();
    return CartSnapshotItem(
      kind: json['kind'] == 'piece' ? 'piece' : 'weight',
      name: (rawName == null || rawName.isEmpty) ? 'Item' : rawName,
      serviceType: _serviceFromName(json['service_type']),
      estKg: (json['est_kg'] as num?)?.toDouble(),
      unitUgx: (json['unit_ugx'] as num?)?.toInt(),
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      note: json['note'] as String?,
      photoKey: json['photo_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'name': name,
        if (serviceType != null) 'service_type': serviceType!.name,
        if (estKg != null) 'est_kg': estKg,
        if (unitUgx != null) 'unit_ugx': unitUgx,
        'qty': qty,
        if (note != null) 'note': note,
        if (photoKey != null) 'photo_key': photoKey,
      };

  /// The snapshot stores the enum NAME (the customer app writes
  /// `ServiceType.name`), not the db label that [ServiceType.fromDbString]
  /// takes — and an unknown value degrades to null instead of throwing.
  static ServiceType? _serviceFromName(Object? raw) {
    if (raw is! String) return null;
    for (final s in ServiceType.values) {
      if (s.name == raw) return s;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CartSnapshotItem &&
      other.kind == kind &&
      other.name == name &&
      other.serviceType == serviceType &&
      other.estKg == estKg &&
      other.unitUgx == unitUgx &&
      other.qty == qty &&
      other.note == note &&
      other.photoKey == photoKey;

  @override
  int get hashCode => Object.hash(
      kind, name, serviceType, estKg, unitUgx, qty, note, photoKey);

  @override
  String toString() =>
      'CartSnapshotItem($kind, $name, $subtitle${hasPhoto ? ', photo' : ''})';
}

/// Parses `orders.cart_items` — a jsonb array already decoded to a [List] (or
/// null / anything else, which reads as an empty snapshot). Entries that aren't
/// maps are skipped rather than throwing.
List<CartSnapshotItem> parseCartSnapshot(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => CartSnapshotItem.fromJson(e.cast<String, dynamic>()))
      .toList(growable: false);
}
