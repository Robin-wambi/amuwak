import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fromJson', () {
    test('reads a weight line', () {
      final item = CartSnapshotItem.fromJson(const {
        'kind': 'weight',
        'name': 'Wash & Iron',
        'service_type': 'washAndIron',
        'est_kg': 6.0,
        'qty': 1,
        'note': 'delicate',
      });

      expect(item.isWeight, isTrue);
      expect(item.name, 'Wash & Iron');
      expect(item.serviceType, ServiceType.washAndIron);
      expect(item.estKg, 6);
      expect(item.note, 'delicate');
      expect(item.hasPhoto, isFalse);
    });

    test('reads a piece line with a damage photo', () {
      final item = CartSnapshotItem.fromJson(const {
        'kind': 'piece',
        'name': 'Jacket',
        'unit_ugx': 8000,
        'qty': 2,
        'photo_key': 'customer/c1/cart/p1.jpg',
      });

      expect(item.isWeight, isFalse);
      expect(item.qty, 2);
      expect(item.unitUgx, 8000);
      expect(item.photoKey, 'customer/c1/cart/p1.jpg');
      expect(item.hasPhoto, isTrue);
      expect(item.serviceType, isNull);
    });

    test('an int est_kg from jsonb still reads as a double', () {
      // Postgres jsonb hands back 6 (not 6.0) for a whole number.
      expect(
        CartSnapshotItem.fromJson(
            const {'kind': 'weight', 'name': 'W', 'est_kg': 6}).estKg,
        6.0,
      );
    });

    test('degrades a malformed line instead of erroring the orders stream', () {
      final item = CartSnapshotItem.fromJson(const {'name': 'Mystery'});

      expect(item.kind, 'weight', reason: 'unknown kind is not a piece');
      expect(item.qty, 1);
      expect(item.estKg, isNull);
      expect(item.unitUgx, isNull);
    });

    test('an unrecognised service_type degrades to null, not a throw', () {
      expect(
        CartSnapshotItem.fromJson(const {
          'kind': 'weight',
          'name': 'W',
          'service_type': 'dry_cleaning_deluxe',
        }).serviceType,
        isNull,
      );
    });

    test('a blank name falls back to something staff can read', () {
      expect(CartSnapshotItem.fromJson(const {'kind': 'piece'}).name, 'Item');
    });
  });

  test('toJson round-trips through the snapshot shape', () {
    const item = CartSnapshotItem(
      kind: 'piece',
      name: 'Jacket',
      unitUgx: 8000,
      qty: 2,
      note: 'stained collar',
      photoKey: 'customer/c1/cart/p1.jpg',
    );

    expect(CartSnapshotItem.fromJson(item.toJson()), item);
  });

  test('a weight line round-trips its service type', () {
    const item = CartSnapshotItem(
      kind: 'weight',
      name: 'Wash & Iron',
      serviceType: ServiceType.washAndIron,
      estKg: 6,
    );

    expect(item.toJson()['service_type'], 'washAndIron');
    expect(CartSnapshotItem.fromJson(item.toJson()), item);
  });

  group('subtitle', () {
    test('a weight line reads as approximate kilos', () {
      expect(
        const CartSnapshotItem(kind: 'weight', name: 'W', estKg: 6).subtitle,
        '~6 kg',
      );
      expect(
        const CartSnapshotItem(kind: 'weight', name: 'W', estKg: 2.5).subtitle,
        '~2.5 kg',
      );
    });

    test('a weight line the customer left unestimated says so', () {
      expect(
        const CartSnapshotItem(kind: 'weight', name: 'W').subtitle,
        'weight not estimated',
      );
    });

    test('a piece line reads as a quantity', () {
      expect(
        const CartSnapshotItem(kind: 'piece', name: 'Jacket', qty: 2).subtitle,
        '× 2',
      );
    });
  });

  test('parseCartSnapshot reads a jsonb list and ignores junk entries', () {
    final items = parseCartSnapshot([
      const {'kind': 'weight', 'name': 'Wash & Iron', 'est_kg': 6},
      'not a map',
      const {'kind': 'piece', 'name': 'Jacket', 'qty': 2},
    ]);

    expect(items.map((i) => i.name), ['Wash & Iron', 'Jacket']);
  });

  test('parseCartSnapshot treats null or a non-list as an empty snapshot', () {
    expect(parseCartSnapshot(null), isEmpty);
    expect(parseCartSnapshot('[]'), isEmpty);
  });
}
