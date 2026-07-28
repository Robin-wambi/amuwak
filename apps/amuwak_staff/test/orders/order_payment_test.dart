import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart' as drift;
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';

LaundryOrder _order({int totalUgx = 10000, int paymentAmountUgx = 0}) =>
    LaundryOrder(
      orderId: 'AMW-1',
      customerName: 'Sarah N.',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.inProgress,
      timeLabel: 'Pickup: now',
      itemCount: 4,
      phone: '+256 700 123 456',
      address: 'Kikoni',
      notes: '',
      totalUgx: totalUgx,
      paymentAmountUgx: paymentAmountUgx,
    );

drift.Order _driftOrderRow({int totalUgx = 10000, int paymentAmountUgx = 0}) =>
    drift.Order(
      id: 'AMW-1',
      orderCode: 'AMW-1',
      customerId: null,
      customerName: 'Sarah N.',
      phone: '+256 700 123 456',
      address: 'Kikoni',
      serviceType: 'Wash & Iron',
      status: 'in_progress',
      intakeMethod: 'driver_pickup',
      fulfillmentMethod: 'delivery',
      itemCount: 4,
      notes: '',
      scheduledFor: null,
      assignedDriver: null,
      intakeRecordedBy: 's-1',
      createdBy: 's-1',
      createdAt: DateTime.utc(2026, 6, 1, 10),
      updatedAt: DateTime.utc(2026, 6, 1, 10),
      deletedAt: null,
      ratePerKgSnapshotUgx: 0,
      lineItems: '[]',
      manualAdjustmentUgx: 0,
      totalUgx: totalUgx,
      deliveryFeeSnapshotUgx: 0,
      isExpress: false,
      expressFlatSnapshotUgx: 0,
      expressPctSnapshot: 0,
      paymentAmountUgx: paymentAmountUgx,
      cartItems: '[]',
    );

Map<String, dynamic> _supabaseRow({
  int totalUgx = 10000,
  Object? paymentAmountUgx = 0,
}) =>
    {
      'id': 'AMW-1',
      'order_code': 'AMW-1',
      'customer_id': null,
      'customer_name': 'Sarah N.',
      'phone': '+256 700 123 456',
      'address': 'Kikoni',
      'service_type': 'Wash & Iron',
      'status': 'in_progress',
      'intake_method': 'driver_pickup',
      'fulfillment_method': 'delivery',
      'item_count': 4,
      'notes': '',
      'scheduled_for': null,
      'total_ugx': totalUgx,
      if (paymentAmountUgx != null) 'payment_amount_ugx': paymentAmountUgx,
    };

void main() {
  group('LaundryOrder.outstandingUgx', () {
    test('is total minus collected when partly paid', () {
      expect(_order(totalUgx: 10000, paymentAmountUgx: 4000).outstandingUgx,
          6000);
    });

    test('is zero when fully paid', () {
      expect(_order(totalUgx: 10000, paymentAmountUgx: 10000).outstandingUgx, 0);
    });

    test('never goes negative when collected exceeds total', () {
      expect(_order(totalUgx: 10000, paymentAmountUgx: 12000).outstandingUgx, 0);
    });
  });

  group('LaundryOrder.isFullyPaid', () {
    test('true when collected meets or exceeds a non-zero total', () {
      expect(_order(totalUgx: 10000, paymentAmountUgx: 10000).isFullyPaid,
          isTrue);
    });

    test('false when collected is short of total', () {
      expect(
          _order(totalUgx: 10000, paymentAmountUgx: 4000).isFullyPaid, isFalse);
    });

    test('false for a zero-total order even with zero collected', () {
      expect(_order(totalUgx: 0, paymentAmountUgx: 0).isFullyPaid, isFalse);
    });
  });

  group('LaundryOrderDriftX.fromDriftRow', () {
    test('reads payment_amount_ugx from the row', () {
      final mapped = LaundryOrderDriftX.fromDriftRow(
        _driftOrderRow(paymentAmountUgx: 7000),
        const [],
      );
      expect(mapped.paymentAmountUgx, 7000);
    });
  });

  group('LaundryOrder.fromSupabase', () {
    test('reads payment_amount_ugx from the row', () {
      final mapped = LaundryOrder.fromSupabase(
        _supabaseRow(paymentAmountUgx: 7000),
        const [],
      );
      expect(mapped.paymentAmountUgx, 7000);
    });

    test('degrades a missing payment_amount_ugx column to 0', () {
      final mapped = LaundryOrder.fromSupabase(
        _supabaseRow(paymentAmountUgx: null),
        const [],
      );
      expect(mapped.paymentAmountUgx, 0);
    });
  });

  group('LaundryOrder.copyWith', () {
    test('updates paymentAmountUgx and leaves it otherwise unchanged', () {
      final base = _order(paymentAmountUgx: 1000);
      expect(base.copyWith(paymentAmountUgx: 5000).paymentAmountUgx, 5000);
      expect(base.copyWith().paymentAmountUgx, 1000);
    });
  });
}
