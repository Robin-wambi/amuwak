import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The online write path sends these snake_case row maps to Supabase. These
/// pure builders are the counterparts to the read mappers; testing them pins
/// the column names, enum→string folding, and UTC ISO timestamps without
/// mocking the Supabase client.
///
/// The Drift-`Customer`-based `customerUpsertPayload` stays in the staff app;
/// its test stays with it (`test/sync/customer_upsert_payload_test.dart`).
void main() {
  group('orderUpsertPayload', () {
    test('maps every column, folds enums, and stamps UTC ISO timestamps', () {
      const order = LaundryOrder(
        orderId: 'o1',
        orderCode: 'AMW-1',
        customerId: 'c1',
        customerName: 'Ada',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Today',
        itemCount: 5,
        phone: '0700',
        address: '12 Kira Rd',
        notes: 'handle with care',
        intakeMethod: 'driver_pickup',
        fulfillmentMethod: 'delivery',
      );
      // A non-UTC local time must be serialised as UTC.
      final now = DateTime(2026, 6, 2, 12, 0);

      final p = orderUpsertPayload(order, actorStaffId: 's1', now: now);

      expect(p['id'], 'o1');
      expect(p['order_code'], 'AMW-1');
      expect(p['customer_id'], 'c1');
      expect(p['customer_name'], 'Ada');
      expect(p['phone'], '0700');
      expect(p['address'], '12 Kira Rd');
      expect(p['service_type'], ServiceType.washAndIron.toDbString());
      expect(p['status'], OrderStatus.pendingPickup.toDbString());
      expect(p['intake_method'], 'driver_pickup');
      expect(p['fulfillment_method'], 'delivery');
      expect(p['item_count'], 5);
      expect(p['notes'], 'handle with care');
      expect(p['scheduled_for'], isNull);
      expect(p['expected_collection_at'], isNull);
      expect(p['intake_recorded_by'], 's1');
      expect(p['created_by'], 's1');
      expect(p['created_at'], now.toUtc().toIso8601String());
      expect(p['updated_at'], now.toUtc().toIso8601String());
    });

    test('serialises scheduledFor as a UTC ISO string when present', () {
      final order = LaundryOrder(
        orderId: 'o2',
        customerName: 'Bob',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
        scheduledFor: DateTime.utc(2026, 6, 3, 9),
      );
      final p =
          orderUpsertPayload(order, actorStaffId: 's1', now: DateTime(2026, 6, 2));
      expect(p['scheduled_for'], DateTime.utc(2026, 6, 3, 9).toIso8601String());
    });

    test('serialises expectedCollectionAt as a UTC ISO string when present', () {
      final order = LaundryOrder(
        orderId: 'o3',
        customerName: 'Cid',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
        expectedCollectionAt: DateTime.utc(2026, 6, 5, 17),
      );
      final p = orderUpsertPayload(order,
          actorStaffId: 's1', now: DateTime(2026, 6, 2));
      expect(p['expected_collection_at'],
          DateTime.utc(2026, 6, 5, 17).toIso8601String());
    });
  });

  group('orderStatusUpdatePayload', () {
    test('carries the folded status, the actor, and a UTC updated_at', () {
      final now = DateTime(2026, 6, 2, 15, 30);
      final p = orderStatusUpdatePayload(OrderStatus.readyForDelivery,
          actorStaffId: 's1', now: now);
      expect(p.keys,
          unorderedEquals(<String>['status', 'updated_by', 'updated_at']));
      expect(p['status'], OrderStatus.readyForDelivery.toDbString());
      expect(p['updated_by'], 's1');
      expect(p['updated_at'], now.toUtc().toIso8601String());
    });
  });

  group('orderPaymentUpdatePayload', () {
    test('carries only payment_amount_ugx, the actor, and a UTC updated_at', () {
      final now = DateTime(2026, 6, 2, 15, 30);
      final p = orderPaymentUpdatePayload(6000, actorStaffId: 's1', now: now);
      expect(
        p.keys,
        unorderedEquals(
            <String>['payment_amount_ugx', 'updated_by', 'updated_at']),
      );
      expect(p['payment_amount_ugx'], 6000);
      expect(p['updated_by'], 's1');
      expect(p['updated_at'], now.toUtc().toIso8601String());
    });
  });

  group('orderDetailsUpdatePayload', () {
    test('carries only the descriptive columns + UTC updated_at', () {
      final order = LaundryOrder(
        orderId: 'o1',
        orderCode: 'AMW-1',
        customerId: 'c1',
        customerName: 'Ada',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.inProgress,
        timeLabel: 'Today',
        itemCount: 5,
        phone: '0700',
        address: '12 Kira Rd',
        notes: 'handle with care',
        scheduledFor: DateTime.utc(2026, 6, 3, 9),
        // Pricing/snapshot fields must NOT leak into the descriptive update.
        ratePerKgSnapshotUgx: 5000,
        totalUgx: 19500,
      );
      final now = DateTime(2026, 6, 2, 12, 0);

      final p = orderDetailsUpdatePayload(order, actorStaffId: 's1', now: now);

      expect(
        p.keys,
        unorderedEquals(<String>[
          'customer_name',
          'phone',
          'address',
          'service_type',
          'item_count',
          'notes',
          'scheduled_for',
          'expected_collection_at',
          'updated_by',
          'updated_at',
        ]),
      );
      expect(p['customer_name'], 'Ada');
      expect(p['phone'], '0700');
      expect(p['address'], '12 Kira Rd');
      expect(p['service_type'], ServiceType.washAndIron.toDbString());
      expect(p['item_count'], 5);
      expect(p['notes'], 'handle with care');
      expect(p['scheduled_for'], DateTime.utc(2026, 6, 3, 9).toIso8601String());
      expect(p['updated_by'], 's1');
      expect(p['updated_at'], now.toUtc().toIso8601String());
      // Never touches creation metadata, status, or pricing snapshots.
      expect(p.containsKey('created_at'), isFalse);
      expect(p.containsKey('created_by'), isFalse);
      expect(p.containsKey('status'), isFalse);
      expect(p.containsKey('total_ugx'), isFalse);
      expect(p.containsKey('rate_per_kg_snapshot_ugx'), isFalse);
    });

    test('passes scheduled_for through as null for an immediate order', () {
      const order = LaundryOrder(
        orderId: 'o2',
        customerName: 'Bob',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Pickup: now',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      final p = orderDetailsUpdatePayload(order,
          actorStaffId: 's1', now: DateTime(2026, 6, 2));
      expect(p['scheduled_for'], isNull);
    });
  });

  group('orderSoftDeletePayload', () {
    test('tombstones with deleted_at/deleted_by and a matching updated_at', () {
      final now = DateTime(2026, 6, 2, 18, 5);
      final p = orderSoftDeletePayload(actorStaffId: 's1', now: now);
      expect(p.keys,
          unorderedEquals(<String>['deleted_at', 'deleted_by', 'updated_at']));
      expect(p['deleted_at'], now.toUtc().toIso8601String());
      expect(p['deleted_by'], 's1');
      expect(p['updated_at'], now.toUtc().toIso8601String());
    });
  });

  group('proofEventUpsertPayload', () {
    test('maps the domain ProofEvent to a proof_events row', () {
      final event = ProofEvent(
        id: 'pe1',
        type: ProofEventType.delivery,
        capturedAt: DateTime(2026, 6, 2, 16, 13),
        count: 7,
        photoPaths: const ['memory://x'],
        notes: 'left at gate',
      );
      final now = DateTime(2026, 6, 2, 16, 14);

      final p = proofEventUpsertPayload(
        event,
        orderId: 'o1',
        actorStaffId: 's1',
        now: now,
      );

      expect(p['id'], 'pe1');
      expect(p['order_id'], 'o1');
      expect(p['type'], 'delivery');
      expect(p['captured_at'],
          DateTime(2026, 6, 2, 16, 13).toUtc().toIso8601String());
      expect(p['item_count'], 7);
      expect(p['notes'], 'left at gate');
      expect(p['captured_by'], 's1');
      expect(p['created_at'], now.toUtc().toIso8601String());
      expect(p['updated_at'], now.toUtc().toIso8601String());
      // Photo binaries live in Storage — never in the row payload.
      expect(p.containsKey('photo_paths'), isFalse);
    });
  });

  test('orderUpsertPayload serializes pricing fields', () {
    final order = LaundryOrder(
      orderId: 'o1',
      orderCode: 'AMW-2026-0001',
      customerName: 'Aisha',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.pendingPickup,
      timeLabel: 'Pickup: now',
      itemCount: 0,
      phone: '+256 700000000',
      address: 'Kampala',
      notes: '',
      ratePerKgSnapshotUgx: 5000,
      estimatedWeightKg: 2.5,
      lineItems: [LineItem(name: 'Blanket', amountUgx: 8000)],
      manualAdjustmentUgx: -1000,
      totalUgx: 19500,
      deliveryFeeSnapshotUgx: 3000,
      isExpress: true,
      expressFlatSnapshotUgx: 2000,
      expressPctSnapshot: 30,
    );
    final p = orderUpsertPayload(order,
        actorStaffId: 's1', now: DateTime.utc(2026, 6, 6));
    expect(p['rate_per_kg_snapshot_ugx'], 5000);
    expect(p['estimated_weight_kg'], 2.5);
    expect(p['final_weight_kg'], isNull);
    expect(p['line_items'], [
      {'name': 'Blanket', 'amount_ugx': 8000}
    ]);
    expect(p['manual_adjustment_ugx'], -1000);
    expect(p['delivery_fee_snapshot_ugx'], 3000);
    expect(p['is_express'], true);
    expect(p['express_flat_snapshot_ugx'], 2000);
    expect(p['express_pct_snapshot'], 30);
    expect(p['total_ugx'], 19500);
  });

  test('orderUpsertPayload carries payment_amount_ugx so a prepayment persists',
      () {
    final order = LaundryOrder(
      orderId: 'o1',
      customerName: 'Aisha',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.pendingPickup,
      timeLabel: 'Pickup: now',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
      totalUgx: 10000,
      paymentAmountUgx: 4000,
    );
    final p = orderUpsertPayload(order,
        actorStaffId: 's1', now: DateTime.utc(2026, 6, 6));
    expect(p['payment_amount_ugx'], 4000);
  });
}
