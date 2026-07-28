import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_list_extensions.dart';
import 'package:amuwak_core/amuwak_core.dart';

// Order A: completed, final weight 2kg @ 5000 (= 10000 weight charge),
// one 8000 line item, express (flat 1000 + 20% of 18000 = 4600), delivery 3000,
// a 2000 discount. total = 10000 + 8000 + 4600 + 3000 - 2000 = 23600.
// Collected 20000 → 3600 still outstanding.
LaundryOrder _orderA() => LaundryOrder(
      orderId: 'A',
      customerName: 'Ada',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.completed,
      timeLabel: 't',
      itemCount: 4,
      phone: 'p',
      address: 'a',
      notes: '',
      ratePerKgSnapshotUgx: 5000,
      finalWeightKg: 2,
      lineItems: [LineItem(name: 'Blanket', amountUgx: 8000)],
      isExpress: true,
      expressFlatSnapshotUgx: 1000,
      expressPctSnapshot: 20,
      deliveryFeeSnapshotUgx: 3000,
      manualAdjustmentUgx: -2000,
      totalUgx: 23600,
      paymentAmountUgx: 20000,
    );

// Order B: in progress, provisional (estimate only) 1kg @ 5000 = 5000, no
// line items / express / delivery / adjustment. Nothing collected yet.
LaundryOrder _orderB() => LaundryOrder(
      orderId: 'B',
      customerName: 'Bob',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.inProgress,
      timeLabel: 't',
      itemCount: 2,
      phone: 'p',
      address: 'a',
      notes: '',
      ratePerKgSnapshotUgx: 5000,
      estimatedWeightKg: 1,
      totalUgx: 5000,
      paymentAmountUgx: 0,
    );

// A pending-pickup order with no price recorded yet (total 0).
LaundryOrder _pending() => LaundryOrder(
      orderId: 'P0',
      customerName: 'Pending',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
      totalUgx: 0,
      paymentAmountUgx: 0,
    );

void main() {
  group('OrderListStats finance', () {
    final orders = [_orderA(), _orderB()];

    test('collectedUgx sums the cash collected across orders', () {
      expect(orders.collectedUgx, 20000);
    });

    test('outstandingUgx sums each order\'s clamped balance owed', () {
      expect(orders.outstandingUgx, 8600); // 3600 + 5000
    });

    test('billedUgx equals collected plus outstanding', () {
      expect(orders.billedUgx, 28600);
      expect(orders.billedUgx, orders.collectedUgx + orders.outstandingUgx);
    });

    test('avgOrderValueUgx is billed divided by the count of priced orders', () {
      expect(orders.avgOrderValueUgx, 14300); // 28600 / 2
    });

    test('avgOrderValueUgx ignores zero-priced (pending) orders', () {
      // A pending order with no price yet must not drag the average down — the
      // metric is the average of orders that actually have a bill.
      final withPending = [
        _orderA(), // billed 23,600
        _pending(), // total 0
      ];
      expect(withPending.avgOrderValueUgx, 23600); // 23,600 / 1 priced, not / 2
    });

    test('avgOrderValueUgx is 0 for an empty list (no divide-by-zero)', () {
      expect(<LaundryOrder>[].avgOrderValueUgx, 0);
    });

    test('avgOrderValueUgx is 0 when no order is priced yet', () {
      expect([_pending(), _pending()].avgOrderValueUgx, 0);
    });

    test('discountsUgx sums the absolute value of negative adjustments only',
        () {
      expect(orders.discountsUgx, 2000);
    });

    test('provisional vs final revenue split by whether final weight is in', () {
      expect(orders.provisionalRevenueUgx, 5000); // B only
      expect(orders.finalRevenueUgx, 23600); // A only
      expect(
        orders.provisionalRevenueUgx + orders.finalRevenueUgx,
        orders.billedUgx,
      );
    });

    test('revenueBreakdown sums components and reconciles to net sales = billed',
        () {
      final b = orders.revenueBreakdown;
      expect(b.weightChargeUgx, 15000); // 10000 + 5000
      expect(b.lineItemsUgx, 8000);
      expect(b.expressUgx, 4600);
      expect(b.deliveryUgx, 3000);
      expect(b.grossChargesUgx, 30600);
      expect(b.discountsUgx, 2000);
      expect(b.surchargesUgx, 0);
      expect(b.netSalesUgx, 28600);
      expect(b.netSalesUgx, orders.billedUgx);
    });

    test('finance aggregates are 0 for an empty list', () {
      expect(<LaundryOrder>[].collectedUgx, 0);
      expect(<LaundryOrder>[].outstandingUgx, 0);
      expect(<LaundryOrder>[].billedUgx, 0);
      expect(<LaundryOrder>[].discountsUgx, 0);
      expect(<LaundryOrder>[].revenueBreakdown.netSalesUgx, 0);
    });
  });
}
