import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart' as drift;
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';

drift.Order _orderRow({
  String id = 'AMW-1024',
  String status = 'in_progress',
  DateTime? scheduledFor,
  DateTime? createdAt,
  String customerName = 'Sarah N.',
  String serviceType = 'Wash & Iron',
  int itemCount = 8,
  String phone = '+256 700 123 456',
  String address = 'Kikoni',
  String notes = '',
}) {
  final created = createdAt ?? DateTime.utc(2026, 5, 19, 10, 0);
  return drift.Order(
    id: id,
    orderCode: id,
    customerId: null,
    customerName: customerName,
    phone: phone,
    address: address,
    serviceType: serviceType,
    status: status,
    intakeMethod: 'driver_pickup',
    fulfillmentMethod: 'delivery',
    itemCount: itemCount,
    notes: notes,
    scheduledFor: scheduledFor,
    assignedDriver: null,
    intakeRecordedBy: 's-1',
    createdBy: 's-1',
    createdAt: created,
    updatedAt: created,
    deletedAt: null,
    ratePerKgSnapshotUgx: 0,
    lineItems: '[]',
    manualAdjustmentUgx: 0,
    totalUgx: 0,
    deliveryFeeSnapshotUgx: 0,
    isExpress: false,
    expressFlatSnapshotUgx: 0,
    expressPctSnapshot: 0,
    paymentAmountUgx: 0,
  );
}

drift.ProofEvent _proofRow({
  required String id,
  required String orderId,
  required String type,
  required DateTime capturedAt,
  int itemCount = 8,
  String? notes,
}) {
  return drift.ProofEvent(
    id: id,
    orderId: orderId,
    type: type,
    capturedAt: capturedAt,
    itemCount: itemCount,
    notes: notes,
    capturedBy: 's-1',
    createdAt: capturedAt,
    updatedAt: capturedAt,
    deletedAt: null,
  );
}

void main() {
  group('LaundryOrderDriftX.fromDriftRow', () {
    test('maps each Postgres status string to the matching OrderStatus enum', () {
      // Six Postgres statuses (pending_pickup, received, in_progress, ready,
      // out_for_delivery, completed) collapse to the UI's four enum values.
      // received → inProgress and out_for_delivery → readyForDelivery are
      // intentional aliases — see TODO in the mapper for the follow-up UI plan.
      final cases = <String, OrderStatus>{
        'pending_pickup': OrderStatus.pendingPickup,
        'received': OrderStatus.inProgress,
        'in_progress': OrderStatus.inProgress,
        'ready': OrderStatus.readyForDelivery,
        'out_for_delivery': OrderStatus.readyForDelivery,
        'completed': OrderStatus.completed,
      };
      cases.forEach((pgStatus, expected) {
        final row = _orderRow(status: pgStatus);
        final mapped = LaundryOrderDriftX.fromDriftRow(row, const []);
        expect(mapped.status, expected, reason: 'for "$pgStatus"');
      });
    });

    test('every OrderStatus round-trips through toDbString → fromDriftRow', () {
      // The Drift row stores the Postgres canonical string; mapping it back must
      // recover the same enum for every status (guards the toDbString/mapper
      // pair against drift). Lives here, not in amuwak_core, because it depends
      // on the app-level LaundryOrder + Drift row.
      for (final s in OrderStatus.values) {
        final row = _orderRow(status: s.toDbString());
        final mapped = LaundryOrderDriftX.fromDriftRow(row, const []);
        expect(mapped.status, s, reason: 'for ${s.name} (db: ${s.toDbString()})');
      }
    });

    test('unknown status falls back to pendingPickup instead of throwing', () {
      // A status string added server-side before an app update must NOT crash
      // the orders stream — it degrades to pendingPickup.
      final row = _orderRow(status: 'banana');
      expect(
        LaundryOrderDriftX.fromDriftRow(row, const []).status,
        OrderStatus.pendingPickup,
      );
    });

    test('uses formatScheduled (date + time) when scheduledFor is set', () {
      final row = _orderRow(
        scheduledFor: DateTime(2026, 5, 19, 10, 30),
        createdAt: DateTime(2026, 5, 19, 8, 0),
      );
      final mapped = LaundryOrderDriftX.fromDriftRow(row, const []);
      // Past date relative to test "now" → weekday/month form.
      expect(mapped.timeLabel, contains('10:30 AM'));
      expect(mapped.timeLabel, contains('May'));
    });

    test("uses 'Pickup: now' when scheduledFor is null", () {
      final row = _orderRow(
        scheduledFor: null,
        createdAt: DateTime(2026, 5, 19, 14, 15),
      );
      final mapped = LaundryOrderDriftX.fromDriftRow(row, const []);
      expect(mapped.timeLabel, 'Pickup: now');
    });

    test('maps two proof events of different types to domain ProofEvents '
        'with photoPaths: const [] (photos deferred to Plan 4)', () {
      final pickupAt = DateTime(2026, 5, 19, 10, 30);
      final deliveryAt = DateTime(2026, 5, 19, 16, 0);
      final row = _orderRow(id: 'AMW-1');
      final events = [
        _proofRow(
          id: 'pe-1',
          orderId: 'AMW-1',
          type: 'pickup',
          capturedAt: pickupAt,
          itemCount: 8,
          notes: 'Carefully bagged',
        ),
        _proofRow(
          id: 'pe-2',
          orderId: 'AMW-1',
          type: 'delivery',
          capturedAt: deliveryAt,
          itemCount: 8,
          notes: null,
        ),
      ];
      final mapped = LaundryOrderDriftX.fromDriftRow(row, events);
      expect(mapped.proofEvents, hasLength(2));
      expect(mapped.proofEvents[0].type, ProofEventType.pickup);
      expect(mapped.proofEvents[0].capturedAt, pickupAt);
      expect(mapped.proofEvents[0].count, 8);
      expect(mapped.proofEvents[0].notes, 'Carefully bagged');
      expect(mapped.proofEvents[0].photoPaths, const <String>[]);
      expect(mapped.proofEvents[0].id, 'pe-1');
      expect(mapped.proofEvents[1].id, 'pe-2');
      expect(mapped.proofEvents[1].type, ProofEventType.delivery);
      expect(mapped.proofEvents[1].notes, isNull);
      expect(mapped.proofEvents[1].photoPaths, const <String>[]);
    });

    test('returns a LaundryOrder with no proof events when given an empty list', () {
      final mapped = LaundryOrderDriftX.fromDriftRow(_orderRow(), const []);
      expect(mapped.proofEvents, isEmpty);
    });

    test('unknown proof event type falls back to pickup instead of throwing', () {
      // Same rationale as the unknown-status case: never crash the stream on a
      // proof-event type synced from a newer backend.
      final row = _orderRow(id: 'AMW-1');
      final events = [
        _proofRow(
          id: 'pe-1',
          orderId: 'AMW-1',
          type: 'banana',
          capturedAt: DateTime(2026, 5, 19, 10, 30),
        ),
      ];
      final mapped = LaundryOrderDriftX.fromDriftRow(row, events);
      expect(mapped.proofEvents.single.type, ProofEventType.pickup);
    });

    test('copies the simple scalar fields onto LaundryOrder', () {
      final row = _orderRow(
        id: 'AMW-1027',
        customerName: 'Daniel M.',
        serviceType: 'Wash only',
        itemCount: 5,
        phone: '+256 703 333 222',
        address: 'Bwaise',
        notes: 'Paid in cash at pickup.',
      );
      final mapped = LaundryOrderDriftX.fromDriftRow(row, const []);
      expect(mapped.orderId, 'AMW-1027');
      expect(mapped.customerName, 'Daniel M.');
      expect(mapped.serviceType, ServiceType.washOnly);
      expect(mapped.itemCount, 5);
      expect(mapped.phone, '+256 703 333 222');
      expect(mapped.address, 'Bwaise');
      expect(mapped.notes, 'Paid in cash at pickup.');
    });

    test('plumbs orderCode, customerId, intakeMethod, fulfillmentMethod, '
        'scheduledFor from the Drift row onto the LaundryOrder', () {
      final scheduled = DateTime(2026, 6, 1, 9);
      final row = drift.Order(
        id: 'uuid-order-1',
        orderCode: 'AMW-9999',
        customerId: 'cust-xyz',
        customerName: 'Daniel M.',
        phone: '+256 703 333 222',
        address: 'Bwaise',
        serviceType: 'Wash only',
        status: 'pending_pickup',
        intakeMethod: 'walk_in',
        fulfillmentMethod: 'walk_out',
        itemCount: 5,
        notes: '',
        scheduledFor: scheduled,
        assignedDriver: null,
        intakeRecordedBy: 's-1',
        createdBy: 's-1',
        createdAt: DateTime(2026, 5, 25, 10),
        updatedAt: DateTime(2026, 5, 25, 10),
        deletedAt: null,
        ratePerKgSnapshotUgx: 0,
        lineItems: '[]',
        manualAdjustmentUgx: 0,
        totalUgx: 0,
        deliveryFeeSnapshotUgx: 0,
        isExpress: false,
        expressFlatSnapshotUgx: 0,
        expressPctSnapshot: 0,
        paymentAmountUgx: 0,
      );
      final mapped = LaundryOrderDriftX.fromDriftRow(row, const []);
      expect(mapped.orderCode, equals(row.orderCode));
      expect(mapped.customerId, equals(row.customerId));
      expect(mapped.intakeMethod, equals(row.intakeMethod));
      expect(mapped.fulfillmentMethod, equals(row.fulfillmentMethod));
      expect(mapped.scheduledFor, equals(row.scheduledFor));
    });

    test('collapses an empty-string orderCode to the orderId fallback', () {
      final row = _orderRow(id: 'AMW-2048');
      final mapped = LaundryOrderDriftX.fromDriftRow(
        row.copyWith(orderCode: ''),
        const [],
      );
      expect(mapped.orderCode, 'AMW-2048');
    });

    test('collapses a whitespace-only orderCode to the orderId fallback', () {
      final row = _orderRow(id: 'AMW-2049');
      final mapped = LaundryOrderDriftX.fromDriftRow(
        row.copyWith(orderCode: '   '),
        const [],
      );
      expect(mapped.orderCode, 'AMW-2049');
    });
  });
}
