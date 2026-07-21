import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/cart/cart_repository.dart';
import 'package:amuwak_customer/src/data/customer_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CustomerDatabase db;
  late CartRepository cart;
  var seq = 0;

  setUp(() {
    db = CustomerDatabase.forTesting(NativeDatabase.memory());
    seq = 0;
    cart = CartRepository(db, newId: () => 'id${seq++}');
  });
  tearDown(() => db.close());

  test('adds weight + piece items and preserves add order', () async {
    await cart.addWeightItem(service: ServiceType.washAndIron, estKg: 6);
    await cart.addPieceItem(
      item: CatalogItem(id: 'c1', name: 'Jacket', amountUgx: 8000),
      qty: 2,
    );

    final items = await cart.watch().first;
    expect(items.map((i) => i.name), ['Wash & Iron', 'Jacket']);
    expect(items[0].kind, 'weight');
    expect(items[0].estKg, 6);
    expect(items[1].kind, 'piece');
    expect(items[1].unitUgx, 8000);
    expect(items[1].qty, 2);
    expect(items[1].catalogItemId, 'c1');
  });

  test('setQty updates, and 0 removes the line', () async {
    await cart.addPieceItem(
      item: CatalogItem(id: 'c1', name: 'Jacket', amountUgx: 8000),
    );
    var items = await cart.watch().first;
    await cart.setQty(items.single, 5);
    items = await cart.watch().first;
    expect(items.single.qty, 5);

    await cart.setQty(items.single, 0);
    expect(await cart.watch().first, isEmpty);
  });

  test('cartEstimateInputs sums weight kg and maps piece lines', () async {
    await cart.addWeightItem(service: ServiceType.washAndIron, estKg: 6);
    await cart.addWeightItem(service: ServiceType.washOnly, estKg: 3);
    await cart.addPieceItem(
      item: CatalogItem(id: 'c1', name: 'Jacket', amountUgx: 8000),
      qty: 2,
    );
    final inputs = cartEstimateInputs(await cart.watch().first);
    expect(inputs.weightKg, 9);
    expect(inputs.pieces.single.name, 'Jacket');
    expect(inputs.pieces.single.unitUgx, 8000);
    expect(inputs.pieces.single.qty, 2);
  });

  test('cartItemsSnapshot captures the staff-facing fields', () async {
    await cart.addWeightItem(
        service: ServiceType.washAndIron, estKg: 6, note: 'delicate');
    final snap = cartItemsSnapshot(await cart.watch().first);
    expect(snap.single['kind'], 'weight');
    expect(snap.single['service_type'], ServiceType.washAndIron.name);
    expect(snap.single['est_kg'], 6);
    expect(snap.single['note'], 'delicate');
  });

  test('clear empties the cart', () async {
    await cart.addWeightItem(service: ServiceType.ironOnly, estKg: 2);
    await cart.clear();
    expect(await cart.watch().first, isEmpty);
  });
}
