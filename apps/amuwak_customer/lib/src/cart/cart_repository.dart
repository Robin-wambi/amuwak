import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:drift/drift.dart';

import '../data/customer_database.dart';

/// Local-first cart: reads/writes the Drift `cart_items` table, which is the
/// cart's source of truth (works fully offline). Checkout drains through the
/// outbox; a cross-device server mirror is a later addition.
class CartRepository {
  CartRepository(this._db, {String Function()? newId})
      : _newId = newId ?? defaultUuidV7;

  final CustomerDatabase _db;
  final String Function() _newId;

  Stream<List<CartItem>> watch() => _db.watchCart();

  Future<void> addWeightItem({
    required ServiceType service,
    double? estKg,
    String? note,
  }) async {
    await _db.upsertCartItem(CartItemsCompanion.insert(
      id: _newId(),
      kind: 'weight',
      name: service.label,
      serviceType: Value(service.name),
      estKg: Value(estKg),
      note: Value(note),
      position: Value(await _nextPosition()),
    ));
  }

  Future<void> addPieceItem({
    required CatalogItem item,
    int qty = 1,
    String? note,
  }) async {
    await _db.upsertCartItem(CartItemsCompanion.insert(
      id: _newId(),
      kind: 'piece',
      name: item.name,
      catalogItemId: Value(item.id),
      unitUgx: Value(item.amountUgx),
      qty: Value(qty),
      note: Value(note),
      position: Value(await _nextPosition()),
    ));
  }

  Future<void> setQty(CartItem item, int qty) async {
    if (qty <= 0) return remove(item.id);
    await _db.upsertCartItem(
        item.toCompanion(true).copyWith(qty: Value(qty)));
  }

  Future<void> setNote(CartItem item, String? note) =>
      _db.upsertCartItem(item.toCompanion(true).copyWith(note: Value(note)));

  /// Removes a line and any damage photo attached to it. Dropping the local
  /// bytes also cancels a still-queued upload — nothing will reference the
  /// object now that the line is gone.
  Future<void> remove(String id) async {
    String? photoKey;
    for (final item in await _db.cartItemsOnce()) {
      if (item.id == id) photoKey = item.photoKey;
    }
    await _db.removeCartItem(id);
    if (photoKey != null) await _db.deleteLocalPhoto(photoKey);
  }

  Future<void> clear() => _db.clearCart();

  Future<int> _nextPosition() async {
    final items = await _db.cartItemsOnce();
    if (items.isEmpty) return 0;
    return items.map((i) => i.position).reduce((a, b) => a > b ? a : b) + 1;
  }
}

/// Maps the cart's rows into the [composeCartEstimate] inputs: sum weight items'
/// kg, turn piece items into [CartPieceLine]s.
({double weightKg, List<CartPieceLine> pieces}) cartEstimateInputs(
    List<CartItem> items) {
  var weightKg = 0.0;
  final pieces = <CartPieceLine>[];
  for (final it in items) {
    if (it.kind == 'weight') {
      weightKg += it.estKg ?? 0;
    } else {
      pieces.add(CartPieceLine(
        name: it.name,
        unitUgx: it.unitUgx ?? 0,
        qty: it.qty,
      ));
    }
  }
  return (weightKg: weightKg, pieces: pieces);
}

/// The `orders.cart_items` snapshot (staff-facing itemized view) for a cart.
List<Map<String, dynamic>> cartItemsSnapshot(List<CartItem> items) => items
    .map((it) => {
          'kind': it.kind,
          'name': it.name,
          if (it.serviceType != null) 'service_type': it.serviceType,
          if (it.estKg != null) 'est_kg': it.estKg,
          if (it.unitUgx != null) 'unit_ugx': it.unitUgx,
          'qty': it.qty,
          if (it.note != null) 'note': it.note,
          if (it.photoKey != null) 'photo_key': it.photoKey,
        })
    .toList(growable: false);
