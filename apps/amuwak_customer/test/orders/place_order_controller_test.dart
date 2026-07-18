import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/orders/place_order/place_order_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final settings = PricingSettings(
    id: 'ps1',
    defaultRatePerKgUgx: 5000,
    updatedAt: DateTime.utc(2026, 7, 1),
    deliveryFeeUgx: 3000,
    expressFlatUgx: 2000,
    expressPct: 30,
  );

  PlaceOrderController controller(
      {required Future<List<Map<String, dynamic>>> Function(Map<String, dynamic>)
          insertRow,
      required Future<Object?> Function() code}) {
    final repo = CustomerOrdersRepository.forTest(
      clock: () => DateTime.utc(2026, 7, 18, 9),
      nextOrderCode: code,
      insertRow: insertRow,
    );
    return PlaceOrderController(
      ordersRepository: repo,
      idGen: () => 'ord-fixed',
    );
  }

  test('builds a customer_app draft with frozen estimate + attribution',
      () async {
    Map<String, dynamic>? sent;
    final c = controller(
      code: () async => 'AMW-2026-0100',
      insertRow: (values) async {
        sent = values;
        return [
          {'id': values['id']}
        ];
      },
    );

    final id = await c.submit(
      customerId: 'cust-1',
      customerName: 'Ada',
      phone: '0700123456',
      settings: settings,
      serviceType: ServiceType.washAndIron,
      fulfillmentMethod: 'delivery',
      address: '12 Kira Rd',
      estimatedWeightKg: 4,
      itemCount: 3,
      isExpress: true,
    );

    expect(id, 'ord-fixed');
    expect(sent!['id'], 'ord-fixed');
    expect(sent!['intake_method'], 'customer_app');
    expect(sent!['status'], OrderStatus.pendingPickup.toDbString());
    expect(sent!['order_code'], 'AMW-2026-0100');
    expect(sent!['placed_by_customer_id'], 'cust-1');
    expect(sent!['delivery_fee_snapshot_ugx'], 3000);
    expect(sent!['is_express'], true);
    // 4kg*5000=20000 weight; +3000 delivery; express 30% of 20000 = 6000 + flat
    // 2000 = 8000 surcharge → 20000 + 8000 + 3000 = 31000.
    expect(sent!['total_ugx'], 31000);
    expect(sent!['final_weight_kg'], isNull);
    expect(sent!['estimated_weight_kg'], 4);
  });

  test('customer_collect drops the delivery fee', () async {
    Map<String, dynamic>? sent;
    final c = controller(
      code: () async => 'AMW-2026-0101',
      insertRow: (values) async {
        sent = values;
        return [
          {'id': values['id']}
        ];
      },
    );

    await c.submit(
      customerId: 'cust-1',
      customerName: 'Ada',
      phone: '0700',
      settings: settings,
      serviceType: ServiceType.washOnly,
      fulfillmentMethod: 'customer_collect',
      address: '',
      estimatedWeightKg: 2,
    );

    expect(sent!['delivery_fee_snapshot_ugx'], 0);
    expect(sent!['fulfillment_method'], 'customer_collect');
    // 2kg*5000 = 10000, no delivery, no express.
    expect(sent!['total_ugx'], 10000);
  });
}
