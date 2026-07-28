import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';

void main() {
  group('OrdersRepository pricing', () {
    test('recomputeOrderTotal overwrites a stale caller total', () {
      final stale = LaundryOrder(
        orderId: 'o1',
        customerName: 'A',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Pickup: now',
        itemCount: 0,
        phone: 'p',
        address: 'a',
        notes: '',
        ratePerKgSnapshotUgx: 5000,
        finalWeightKg: 4,
        totalUgx: 999999, // deliberately wrong
      );
      final corrected = OrdersRepository.recomputeOrderTotal(stale);
      expect(corrected.totalUgx, 20000); // 4 * 5000
    });

    test('recomputeOrderTotal includes delivery fee and express surcharge', () {
      final order = LaundryOrder(
        orderId: 'o2',
        customerName: 'B',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Pickup: now',
        itemCount: 0,
        phone: 'p',
        address: 'a',
        notes: '',
        ratePerKgSnapshotUgx: 5000,
        finalWeightKg: 2, // weight charge 10000
        deliveryFeeSnapshotUgx: 3000,
        isExpress: true,
        expressFlatSnapshotUgx: 1000,
        expressPctSnapshot: 20, // 20% of 10000 = 2000; + flat 1000 = 3000
      );
      final priced = OrdersRepository.recomputeOrderTotal(order);
      expect(priced.totalUgx, 16000); // 10000 + 3000 express + 3000 delivery
    });

    test('resolveRatePerKg prefers the customer override', () {
      expect(
        OrdersRepository.resolveRatePerKg(
            customRate: 4000, defaultRate: 5000),
        4000,
      );
    });

    test('resolveRatePerKg falls back to the default when no override', () {
      expect(
        OrdersRepository.resolveRatePerKg(
            customRate: null, defaultRate: 5000),
        5000,
      );
    });
  });
}
