import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/sync/supabase_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Online-only mode maps Supabase JSON rows (snake_case) straight into the
/// Drift data classes the read repositories return, and into the [LaundryOrder]
/// domain model. These pure mappers replace the SyncPuller's JSON→Companion
/// mappers on the read path; the offline puller is preserved but unused.
void main() {
  group('customerFromSupabase', () {
    test('maps all columns including nullable address/notes/deletedAt', () {
      final c = customerFromSupabase(<String, dynamic>{
        'id': 'c1',
        'name': 'Ada',
        'phone': '0700',
        'address': '12 Kira Rd',
        'notes': 'gate code 4',
        'created_at': '2026-06-01T08:00:00.000Z',
        'updated_at': '2026-06-02T09:00:00.000Z',
        'deleted_at': null,
      });
      expect(c.id, 'c1');
      expect(c.name, 'Ada');
      expect(c.phone, '0700');
      expect(c.address, '12 Kira Rd');
      expect(c.notes, 'gate code 4');
      expect(c.createdAt, DateTime.parse('2026-06-01T08:00:00.000Z'));
      expect(c.updatedAt, DateTime.parse('2026-06-02T09:00:00.000Z'));
      expect(c.deletedAt, isNull);
    });

    test('tolerates missing optional fields', () {
      final c = customerFromSupabase(<String, dynamic>{
        'id': 'c2',
        'name': 'Bob',
        'phone': '0701',
        'created_at': '2026-06-01T08:00:00.000Z',
        'updated_at': '2026-06-01T08:00:00.000Z',
      });
      expect(c.address, isNull);
      expect(c.notes, isNull);
      expect(c.deletedAt, isNull);
    });
  });

  group('staffFromSupabase', () {
    test('maps columns and defaults active/mustChangePin', () {
      final s = staffFromSupabase(<String, dynamic>{
        'id': 's1',
        'username': 'rider1',
        'display_name': 'Rider One',
        'phone': null,
        'role': 'rider',
        'created_at': '2026-06-01T08:00:00.000Z',
        'updated_at': '2026-06-01T08:00:00.000Z',
      });
      expect(s.id, 's1');
      expect(s.username, 'rider1');
      expect(s.displayName, 'Rider One');
      expect(s.phone, isNull);
      expect(s.role, 'rider');
      expect(s.active, isTrue);
      expect(s.mustChangePin, isFalse);
    });
  });

  group('orderStatusEventFromSupabase', () {
    test('maps append-only event with nullable fromStatus/deviceEventId', () {
      final e = orderStatusEventFromSupabase(<String, dynamic>{
        'id': 'e1',
        'order_id': 'o1',
        'from_status': null,
        'to_status': 'in_progress',
        'changed_by': 's1',
        'changed_at': '2026-06-02T10:00:00.000Z',
        'source': 'app',
        'device_event_id': null,
      });
      expect(e.id, 'e1');
      expect(e.orderId, 'o1');
      expect(e.fromStatus, isNull);
      expect(e.toStatus, 'in_progress');
      expect(e.changedBy, 's1');
      expect(e.changedAt, DateTime.parse('2026-06-02T10:00:00.000Z'));
      expect(e.source, 'app');
      expect(e.deviceEventId, isNull);
    });
  });

  group('proofEventRowFromSupabase', () {
    test('maps a proof_events row into the Drift data class', () {
      final p = proofEventRowFromSupabase(<String, dynamic>{
        'id': 'p1',
        'order_id': 'o1',
        'type': 'pickup',
        'captured_at': '2026-06-02T10:05:00.000Z',
        'item_count': 3,
        'notes': null,
        'captured_by': 's1',
        'created_at': '2026-06-02T10:05:00.000Z',
        'updated_at': '2026-06-02T10:05:00.000Z',
        'deleted_at': null,
      });
      expect(p.id, 'p1');
      expect(p.orderId, 'o1');
      expect(p.type, 'pickup');
      expect(p.itemCount, 3);
      expect(p.capturedBy, 's1');
      expect(p.deletedAt, isNull);
    });
  });

  group('LaundryOrder.fromSupabase', () {
    test('hydrates order + joined proof events, dropping soft-deleted proofs',
        () {
      final order = LaundryOrder.fromSupabase(
        <String, dynamic>{
          'id': 'o1',
          'order_code': 'AMU-1',
          'customer_id': 'c1',
          'customer_name': 'Ada',
          'phone': '0700',
          'address': '12 Kira Rd',
          'service_type': 'Wash & Iron',
          'status': 'in_progress',
          'intake_method': 'driver_pickup',
          'fulfillment_method': 'delivery',
          'item_count': 5,
          'notes': 'handle with care',
          'scheduled_for': null,
          'rate_per_kg_snapshot_ugx': 4000,
          'estimated_weight_kg': null,
          'final_weight_kg': null,
          'line_items': <Map<String, dynamic>>[],
          'manual_adjustment_ugx': 0,
          'total_ugx': 0,
          'created_at': '2026-06-02T09:00:00.000Z',
          'updated_at': '2026-06-02T10:00:00.000Z',
        },
        <Map<String, dynamic>>[
          {
            'id': 'p1',
            'order_id': 'o1',
            'type': 'pickup',
            'captured_at': '2026-06-02T10:05:00.000Z',
            'item_count': 5,
            'notes': null,
            'captured_by': 's1',
            'created_at': '2026-06-02T10:05:00.000Z',
            'updated_at': '2026-06-02T10:05:00.000Z',
            'deleted_at': null,
          },
          {
            'id': 'p2',
            'order_id': 'o1',
            'type': 'delivery',
            'captured_at': '2026-06-02T11:05:00.000Z',
            'item_count': 5,
            'notes': null,
            'captured_by': 's1',
            'created_at': '2026-06-02T11:05:00.000Z',
            'updated_at': '2026-06-02T11:05:00.000Z',
            'deleted_at': '2026-06-02T12:00:00.000Z',
          },
        ],
      );

      expect(order.orderId, 'o1');
      expect(order.orderCode, 'AMU-1');
      expect(order.customerId, 'c1');
      expect(order.customerName, 'Ada');
      expect(order.serviceType, ServiceType.washAndIron);
      expect(order.status, OrderStatus.fromDbString('in_progress'));
      expect(order.itemCount, 5);
      expect(order.notes, 'handle with care');
      // Only the non-deleted proof event survives.
      expect(order.proofEvents.length, 1);
      expect(order.proofEvents.single.type, ProofEventType.pickup);
      expect(order.hasPickupProof, isTrue);
      expect(order.hasDeliveryProof, isFalse);
    });

    test('defaults missing order_code/notes and parses scheduled_for', () {
      final order = LaundryOrder.fromSupabase(
        <String, dynamic>{
          'id': 'o2',
          'customer_name': 'Bob',
          'phone': '0701',
          'address': 'x',
          'service_type': 'Wash & Iron',
          'status': 'received',
          'intake_method': 'driver_pickup',
          'fulfillment_method': 'delivery',
          'item_count': 1,
          'scheduled_for': '2026-06-03T14:00:00.000Z',
          'rate_per_kg_snapshot_ugx': 4000,
          'estimated_weight_kg': null,
          'final_weight_kg': null,
          'line_items': <Map<String, dynamic>>[],
          'manual_adjustment_ugx': 0,
          'total_ugx': 0,
          'created_at': '2026-06-02T09:00:00.000Z',
          'updated_at': '2026-06-02T09:00:00.000Z',
        },
        const <Map<String, dynamic>>[],
      );
      expect(order.orderCode, 'o2'); // falls back to orderId
      expect(order.notes, '');
      expect(order.scheduledFor, DateTime.parse('2026-06-03T14:00:00.000Z'));
      expect(order.proofEvents, isEmpty);
    });

    test('collapses an empty-string order_code to the orderId fallback', () {
      final order = LaundryOrder.fromSupabase(
        <String, dynamic>{
          'id': 'o3',
          'order_code': '',
          'customer_name': 'Carol',
          'phone': '0702',
          'address': 'x',
          'service_type': 'Wash & Iron',
          'status': 'received',
          'intake_method': 'driver_pickup',
          'fulfillment_method': 'delivery',
          'item_count': 1,
          'scheduled_for': null,
          'rate_per_kg_snapshot_ugx': 4000,
          'estimated_weight_kg': null,
          'final_weight_kg': null,
          'line_items': <Map<String, dynamic>>[],
          'manual_adjustment_ugx': 0,
          'total_ugx': 0,
          'created_at': '2026-06-02T09:00:00.000Z',
          'updated_at': '2026-06-02T09:00:00.000Z',
        },
        const <Map<String, dynamic>>[],
      );
      expect(order.orderCode, 'o3'); // empty collapses to orderId fallback
    });

    test('collapses a whitespace-only order_code to the orderId fallback', () {
      final order = LaundryOrder.fromSupabase(
        <String, dynamic>{
          'id': 'o4',
          'order_code': '   ',
          'customer_name': 'Dan',
          'phone': '0703',
          'address': 'x',
          'service_type': 'Wash & Iron',
          'status': 'received',
          'intake_method': 'driver_pickup',
          'fulfillment_method': 'delivery',
          'item_count': 1,
          'scheduled_for': null,
          'rate_per_kg_snapshot_ugx': 4000,
          'estimated_weight_kg': null,
          'final_weight_kg': null,
          'line_items': <Map<String, dynamic>>[],
          'manual_adjustment_ugx': 0,
          'total_ugx': 0,
          'created_at': '2026-06-02T09:00:00.000Z',
          'updated_at': '2026-06-02T09:00:00.000Z',
        },
        const <Map<String, dynamic>>[],
      );
      expect(order.orderCode, 'o4'); // whitespace collapses to orderId fallback
    });
  });

  group('hydrateOrders', () {
    test('drops soft-deleted orders and groups proofs by order_id', () {
      final orders = hydrateOrders(
        <Map<String, dynamic>>[
          _orderRow(id: 'o1'),
          _orderRow(id: 'o2'),
          _orderRow(id: 'o3', deletedAt: '2026-06-02T12:00:00.000Z'),
        ],
        <Map<String, dynamic>>[
          _proofRow(id: 'p1', orderId: 'o1', type: 'pickup'),
          _proofRow(id: 'p2', orderId: 'o2', type: 'pickup'),
          _proofRow(id: 'p3', orderId: 'o2', type: 'delivery'),
          // Proof for a deleted order is simply ignored (no matching order).
          _proofRow(id: 'p4', orderId: 'o3', type: 'pickup'),
        ],
      );

      // o3 (soft-deleted) is excluded.
      expect(orders.map((o) => o.orderId), ['o1', 'o2']);
      // Proofs are routed to the right order.
      expect(orders[0].proofEvents.map((e) => e.id), ['p1']);
      expect(orders[1].proofEvents.map((e) => e.id).toSet(), {'p2', 'p3'});
    });

    test('order with no proofs gets an empty proofEvents list', () {
      final orders = hydrateOrders(
        <Map<String, dynamic>>[_orderRow(id: 'o1')],
        const <Map<String, dynamic>>[],
      );
      expect(orders.single.proofEvents, isEmpty);
    });

    test('empty / all-deleted inputs yield an empty list', () {
      expect(hydrateOrders(const [], const []), isEmpty);
      expect(
        hydrateOrders(
          <Map<String, dynamic>>[
            _orderRow(id: 'o1', deletedAt: '2026-06-02T12:00:00.000Z'),
          ],
          const <Map<String, dynamic>>[],
        ),
        isEmpty,
      );
    });
  });

  group('hydrateOrder', () {
    test('returns the order with its proofs', () {
      final order = hydrateOrder(
        <Map<String, dynamic>>[_orderRow(id: 'o1')],
        <Map<String, dynamic>>[
          _proofRow(id: 'p1', orderId: 'o1', type: 'pickup'),
        ],
      );
      expect(order, isNotNull);
      expect(order!.orderId, 'o1');
      expect(order.proofEvents.single.id, 'p1');
    });

    test('returns null when the row set is empty', () {
      expect(hydrateOrder(const [], const []), isNull);
    });

    test('returns null when the only matching order is soft-deleted', () {
      final order = hydrateOrder(
        <Map<String, dynamic>>[
          _orderRow(id: 'o1', deletedAt: '2026-06-02T12:00:00.000Z'),
        ],
        const <Map<String, dynamic>>[],
      );
      expect(order, isNull);
    });
  });
}

/// Minimal `orders` row for hydration tests.
Map<String, dynamic> _orderRow({required String id, String? deletedAt}) => {
      'id': id,
      'order_code': 'AMW-$id',
      'customer_id': 'c1',
      'customer_name': 'Ada',
      'phone': '0700',
      'address': 'x',
      'service_type': 'Wash & Iron',
      'status': 'pending_pickup',
      'intake_method': 'driver_pickup',
      'fulfillment_method': 'delivery',
      'item_count': 1,
      'notes': null,
      'scheduled_for': null,
      'rate_per_kg_snapshot_ugx': 4000,
      'estimated_weight_kg': null,
      'final_weight_kg': null,
      'line_items': <Map<String, dynamic>>[],
      'manual_adjustment_ugx': 0,
      'total_ugx': 0,
      'created_at': '2026-06-02T09:00:00.000Z',
      'updated_at': '2026-06-02T09:00:00.000Z',
      'deleted_at': deletedAt,
    };

/// Minimal non-deleted `proof_events` row for hydration tests.
Map<String, dynamic> _proofRow({
  required String id,
  required String orderId,
  required String type,
}) =>
    {
      'id': id,
      'order_id': orderId,
      'type': type,
      'captured_at': '2026-06-02T10:00:00.000Z',
      'item_count': 1,
      'notes': null,
      'captured_by': 's1',
      'created_at': '2026-06-02T10:00:00.000Z',
      'updated_at': '2026-06-02T10:00:00.000Z',
      'deleted_at': null,
    };
