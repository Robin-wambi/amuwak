import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/cart/checkout_service.dart';
import 'package:amuwak_customer/src/data/customer_database.dart';
import 'package:flutter_test/flutter_test.dart';

PricingSettings _settings({int threshold = 0}) => PricingSettings(
      id: 's',
      defaultRatePerKgUgx: 3000,
      updatedAt: DateTime(2026, 1, 1),
      deliveryFeeUgx: 5000,
      expressFlatUgx: 0,
      expressPct: 30,
      freeDeliveryThresholdUgx: threshold,
    );

List<CartItem> _cart() => const [
      CartItem(
        id: 'w',
        kind: 'weight',
        name: 'Wash & Iron',
        serviceType: 'washAndIron',
        estKg: 6,
        qty: 1,
        position: 0,
      ),
      CartItem(
        id: 'p',
        kind: 'piece',
        name: 'Jacket',
        unitUgx: 8000,
        qty: 2,
        position: 1,
      ),
    ];

void main() {
  test('buildCartOrderDraft aggregates weight + pieces into one order', () {
    final draft = buildCartOrderDraft(
      items: _cart(),
      customerId: 'c1',
      customerName: 'Ada',
      phone: '0700',
      settings: _settings(),
      fulfillmentMethod: 'delivery',
      address: 'Kololo',
      newId: () => 'order-1',
    );

    expect(draft.orderId, 'order-1');
    expect(draft.intakeMethod, 'customer_app');
    expect(draft.status, OrderStatus.pendingPickup);
    expect(draft.serviceType, ServiceType.washAndIron); // primary weight item
    expect(draft.estimatedWeightKg, 6);
    expect(draft.itemCount, 3); // 2 pieces + 1 weight bag
    expect(draft.lineItems.single.name, 'Jacket ×2');
    expect(draft.lineItems.single.amountUgx, 16000);
    expect(draft.deliveryFeeSnapshotUgx, 5000);
    expect(draft.totalUgx, 39000); // 18000 + 16000 + 5000
    expect(draft.finalWeightKg, isNull); // provisional
  });

  test('free-delivery threshold waives the frozen delivery fee', () {
    final draft = buildCartOrderDraft(
      items: _cart(),
      customerId: 'c1',
      customerName: 'Ada',
      phone: '0700',
      settings: _settings(threshold: 30000), // subtotal 34000 >= 30000
      fulfillmentMethod: 'delivery',
      address: 'Kololo',
      newId: () => 'order-2',
    );
    expect(draft.deliveryFeeSnapshotUgx, 0);
    expect(draft.totalUgx, 34000);
  });

  test('buildPlaceOrderPayload drops order_code and adds attribution + snapshot',
      () {
    final draft = buildCartOrderDraft(
      items: _cart(),
      customerId: 'c1',
      customerName: 'Ada',
      phone: '0700',
      settings: _settings(),
      fulfillmentMethod: 'delivery',
      address: 'Kololo',
      newId: () => 'order-3',
    );
    final payload = buildPlaceOrderPayload(
      draft: draft,
      items: _cart(),
      now: DateTime.utc(2026, 7, 20, 12),
    );

    expect(payload.containsKey('order_code'), isFalse); // minted at drain
    expect(payload['placed_by_customer_id'], 'c1');
    expect(payload['intake_method'], 'customer_app');
    expect(payload['status'], 'pending_pickup');
    expect(payload['created_by'], kCustomerAppSentinelStaffId);
    final snapshot = payload['cart_items'] as List;
    expect(snapshot, hasLength(2));
    expect(snapshot.first['kind'], 'weight');
    expect(snapshot.first['service_type'], 'washAndIron');
    expect(snapshot[1]['unit_ugx'], 8000);
    expect(snapshot[1]['qty'], 2);
  });
}
