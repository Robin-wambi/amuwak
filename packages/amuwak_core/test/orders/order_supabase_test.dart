import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `LaundryOrder.fromSupabase` is the Drift-free read-path hydrator shared by
/// the staff and customer apps. These tests pin its column mapping, the
/// degrade-to-0 rules for rows that predate later pricing/payment columns, and
/// the soft-deleted-proof filter.
void main() {
  group('LaundryOrder.fromSupabase', () {
    test('maps a full row + folds its proof events', () {
      final order = LaundryOrder.fromSupabase(
        {
          'id': 'o1',
          'order_code': 'AMW-2026-0007',
          'customer_id': 'c1',
          'customer_name': 'Ada',
          'phone': '0700',
          'address': '12 Kira Rd',
          'service_type': 'Wash & Iron',
          'status': 'ready',
          'item_count': 4,
          'notes': 'gate code 4',
          'intake_method': 'customer_app',
          'fulfillment_method': 'delivery',
          'scheduled_for': DateTime.utc(2026, 6, 3, 9).toIso8601String(),
          'rate_per_kg_snapshot_ugx': 5000,
          'estimated_weight_kg': 2.5,
          'final_weight_kg': 3.0,
          'line_items': [
            {'name': 'Blanket', 'amount_ugx': 8000},
          ],
          'manual_adjustment_ugx': -1000,
          'total_ugx': 22000,
          'delivery_fee_snapshot_ugx': 3000,
          'is_express': true,
          'express_flat_snapshot_ugx': 2000,
          'express_pct_snapshot': 30,
          'payment_amount_ugx': 10000,
        },
        [
          {
            'id': 'pe1',
            'order_id': 'o1',
            'type': 'pickup',
            'captured_at': DateTime.utc(2026, 6, 3, 10).toIso8601String(),
            'item_count': 4,
            'notes': null,
            'deleted_at': null,
          },
        ],
      );

      expect(order.orderId, 'o1');
      expect(order.orderCode, 'AMW-2026-0007');
      expect(order.customerId, 'c1');
      expect(order.serviceType, ServiceType.washAndIron);
      expect(order.status, OrderStatus.readyForDelivery);
      expect(order.intakeMethod, 'customer_app');
      expect(order.ratePerKgSnapshotUgx, 5000);
      expect(order.estimatedWeightKg, 2.5);
      expect(order.finalWeightKg, 3.0);
      expect(order.lineItems.single.name, 'Blanket');
      expect(order.lineItems.single.amountUgx, 8000);
      expect(order.totalUgx, 22000);
      expect(order.paymentAmountUgx, 10000);
      expect(order.outstandingUgx, 12000);
      expect(order.proofEvents.single.type, ProofEventType.pickup);
      // Photo binaries live in Storage — never hydrated from the row.
      expect(order.proofEvents.single.photoPaths, isEmpty);
    });

    test('degrades missing pricing/payment columns to 0 and defaults', () {
      final order = LaundryOrder.fromSupabase(
        {
          'id': 'o2',
          'order_code': null,
          'customer_id': null,
          'customer_name': 'Bob',
          'phone': 'p',
          'address': 'a',
          'service_type': 'Wash only',
          'status': 'pending_pickup',
          'item_count': 1,
          // no pricing / payment / intake / fulfillment columns present
        },
        const [],
      );

      // A blank/absent order_code falls back to the id (offline placeholder).
      expect(order.orderCode, 'o2');
      expect(order.hasServerCode, isFalse);
      expect(order.ratePerKgSnapshotUgx, 0);
      expect(order.estimatedWeightKg, isNull);
      expect(order.finalWeightKg, isNull);
      expect(order.lineItems, isEmpty);
      expect(order.totalUgx, 0);
      expect(order.deliveryFeeSnapshotUgx, 0);
      expect(order.isExpress, isFalse);
      expect(order.paymentAmountUgx, 0);
      expect(order.intakeMethod, 'driver_pickup');
      expect(order.fulfillmentMethod, 'delivery');
    });

    test('drops soft-deleted proof rows', () {
      final order = LaundryOrder.fromSupabase(
        {
          'id': 'o3',
          'order_code': 'AMW-3',
          'customer_name': 'Cid',
          'phone': 'p',
          'address': 'a',
          'service_type': 'Wash only',
          'status': 'completed',
          'item_count': 1,
        },
        [
          {
            'id': 'pe-live',
            'order_id': 'o3',
            'type': 'delivery',
            'captured_at': DateTime.utc(2026, 6, 4).toIso8601String(),
            'item_count': 1,
            'notes': null,
            'deleted_at': null,
          },
          {
            'id': 'pe-dead',
            'order_id': 'o3',
            'type': 'delivery',
            'captured_at': DateTime.utc(2026, 6, 4).toIso8601String(),
            'item_count': 1,
            'notes': null,
            'deleted_at': DateTime.utc(2026, 6, 5).toIso8601String(),
          },
        ],
      );

      expect(order.proofEvents, hasLength(1));
      expect(order.proofEvents.single.id, 'pe-live');
    });
  });
}
