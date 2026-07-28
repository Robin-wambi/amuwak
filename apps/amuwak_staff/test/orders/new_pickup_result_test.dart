import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/new_pickup_result.dart';

void main() {
  group('NewPickupResult', () {
    test('exposes the order id and start-pickup flag', () {
      const r = NewPickupResult(orderId: 'AMW-1', startPickupNow: true);
      expect(r.orderId, 'AMW-1');
      expect(r.startPickupNow, isTrue);
    });

    test('is equal by value (identical short-circuit and field compare)', () {
      const r = NewPickupResult(orderId: 'AMW-1', startPickupNow: false);
      // identical(this, other) branch.
      expect(r == r, isTrue);
      // field-by-field branch on a distinct instance.
      expect(
        const NewPickupResult(orderId: 'AMW-1', startPickupNow: false),
        const NewPickupResult(orderId: 'AMW-1', startPickupNow: false),
      );
    });

    test('differs when orderId or startPickupNow differ', () {
      const base = NewPickupResult(orderId: 'AMW-1', startPickupNow: true);
      expect(
        base == const NewPickupResult(orderId: 'AMW-2', startPickupNow: true),
        isFalse,
      );
      expect(
        base == const NewPickupResult(orderId: 'AMW-1', startPickupNow: false),
        isFalse,
      );
      // ignore: unrelated_type_equality_checks
      expect(base == 'AMW-1', isFalse);
    });

    test('equal results share a hashCode; different ones differ', () {
      const a = NewPickupResult(orderId: 'AMW-1', startPickupNow: true);
      const b = NewPickupResult(orderId: 'AMW-1', startPickupNow: true);
      const c = NewPickupResult(orderId: 'AMW-1', startPickupNow: false);
      expect(a.hashCode, b.hashCode);
      expect(a.hashCode, isNot(c.hashCode));
    });
  });
}
