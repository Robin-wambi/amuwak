import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/outbox_repository.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late OrdersRepository repo;
  DateTime clock() => DateTime.utc(2026, 5, 21, 12, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    repo = OrdersRepository(db, outbox: outbox, clock: clock);
  });
  tearDown(() async => db.close());

  group('upsertOrder', () {
    test('writes the row and enqueues exactly one outbox insert', () async {
      const order = LaundryOrder(
        orderId: 'AMW-A',
        customerName: 'Sarah',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: '10:00 AM',
        itemCount: 3,
        phone: '+256',
        address: 'addr',
        notes: '',
      );

      await repo.upsertOrder(order, actorStaffId: 's-1');

      final row = await (db.select(db.orders)..where((t) => t.id.equals('AMW-A'))).getSingle();
      expect(row.status, 'pending_pickup');
      expect(row.customerName, 'Sarah');
      expect(row.intakeRecordedBy, 's-1');
      expect(row.createdBy, 's-1');

      final outboxRows = await db.select(db.outbox).get();
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single.forTable, 'orders');
      expect(outboxRows.single.op, 'insert');
      expect(outboxRows.single.rowId, 'AMW-A');
      final payload = jsonDecode(outboxRows.single.payloadJson) as Map;
      expect(payload['id'], 'AMW-A');
      expect(payload['status'], 'pending_pickup');
      expect(payload['order_code'], 'AMW-A');
      expect(payload['customer_name'], 'Sarah');
      expect(payload['phone'], '+256');
      expect(payload['address'], 'addr');
      expect(payload['service_type'], ServiceType.washOnly.toDbString());
      expect(payload['intake_method'], 'driver_pickup');
      expect(payload['fulfillment_method'], 'delivery');
      expect(payload['item_count'], 3);
      expect(payload['notes'], '');
      expect(payload['intake_recorded_by'], 's-1');
      expect(payload['created_by'], 's-1');
      expect(payload['created_at'], '2026-05-21T12:00:00.000Z');
      expect(payload['updated_at'], '2026-05-21T12:00:00.000Z');
      expect(
        outboxRows.single.id,
        'orders:insert:AMW-A:2026-05-21T12:00:00.000Z',
      );
    });

    test('plumbs orderCode, customerId, intakeMethod, '
        'fulfillmentMethod, and scheduledFor through to the orders row',
        () async {
      final scheduled = DateTime(2026, 6, 1, 9, 0);
      final order = LaundryOrder(
        orderId: 'uuid-test-1',
        orderCode: 'AMW-9999',
        customerId: 'cust-test-1',
        customerName: 'X',
        serviceType: ServiceType.dryCleaning,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 3,
        phone: '+256 700 000 001',
        address: 'Test address',
        notes: 'gate locked',
        intakeMethod: 'driver_pickup',
        fulfillmentMethod: 'delivery',
        scheduledFor: scheduled,
      );

      await repo.upsertOrder(order, actorStaffId: 'staff-1');

      final row =
          await (db.select(db.orders)..where((t) => t.id.equals('uuid-test-1')))
              .getSingle();
      expect(row.orderCode, 'AMW-9999');
      expect(row.customerId, 'cust-test-1');
      expect(row.serviceType, ServiceType.dryCleaning.toDbString());
      expect(row.intakeMethod, 'driver_pickup');
      expect(row.fulfillmentMethod, 'delivery');
      expect(row.scheduledFor, scheduled);
    });
  });

  group('updateStatus', () {
    test("updates the row's status + updated_at and enqueues an outbox update", () async {
      // Seed an order directly
      await db.into(db.orders).insert(OrdersCompanion.insert(
        id: 'AMW-A',
        orderCode: 'AMW-A',
        customerName: 'Sarah',
        phone: '+256', address: 'addr', serviceType: ServiceType.washOnly.toDbString(),
        status: 'in_progress',
        intakeMethod: 'driver_pickup', fulfillmentMethod: 'delivery',
        itemCount: 3,
        intakeRecordedBy: 's-1', createdBy: 's-1',
      ));

      await repo.updateStatus('AMW-A', OrderStatus.readyForDelivery, actorStaffId: 's-1');

      final row = await (db.select(db.orders)..where((t) => t.id.equals('AMW-A'))).getSingle();
      expect(row.status, 'ready');
      expect(row.updatedAt.toUtc(), DateTime.utc(2026, 5, 21, 12, 0));

      final outboxRows = await db.select(db.outbox).get();
      expect(outboxRows, hasLength(1));
      expect(outboxRows.single.op, 'update');
      expect(outboxRows.single.rowId, 'AMW-A');
      final payload = jsonDecode(outboxRows.single.payloadJson) as Map;
      expect(payload['status'], 'ready');
      expect(payload['updated_at'], '2026-05-21T12:00:00.000Z');
    });

    test('throws StateError when no row matches the orderId, and writes no outbox row', () async {
      // No seed — empty DB

      await expectLater(
        () => repo.updateStatus('does-not-exist', OrderStatus.completed, actorStaffId: 's-1'),
        throwsA(isA<StateError>()),
      );

      // Confirm no outbox row leaked through despite the throw
      final outboxRows = await db.select(db.outbox).get();
      expect(outboxRows, isEmpty);
    });

    test(
        'called twice with the same updatedAt enqueues ONE outbox row (Plan 4 dedup)',
        () async {
      // Seed an orders row.
      await db.into(db.orders).insert(OrdersCompanion.insert(
            id: 'AMW-A',
            orderCode: 'AMW-A',
            customerName: 'Sarah',
            phone: '+256', address: 'addr', serviceType: ServiceType.washOnly.toDbString(),
            status: 'in_progress',
            intakeMethod: 'driver_pickup', fulfillmentMethod: 'delivery',
            itemCount: 3,
            intakeRecordedBy: 's-1', createdBy: 's-1',
          ));

      final stableUpdatedAt = DateTime.utc(2026, 5, 21, 12, 0);
      await repo.updateStatus(
        'AMW-A',
        OrderStatus.readyForDelivery,
        actorStaffId: 's-1',
        updatedAt: stableUpdatedAt,
      );
      await repo.updateStatus(
        'AMW-A',
        OrderStatus.readyForDelivery,
        actorStaffId: 's-1',
        updatedAt: stableUpdatedAt,
      );

      final rows = await db.select(db.outbox).get();
      expect(rows, hasLength(1));
      expect(
        rows.single.id,
        'orders:update:AMW-A:ready:2026-05-21T12:00:00.000Z',
      );
    });
  });

  group('write methods without outbox', () {
    test('write methods throw StateError when no outbox is wired', () async {
      // Construct without outbox — read-only configuration
      final readOnlyRepo = OrdersRepository(db);  // no outbox: param

      const order = LaundryOrder(
        orderId: 'AMW-A',
        customerName: 'Sarah',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: '10:00 AM',
        itemCount: 3,
        phone: '+256',
        address: 'addr',
        notes: '',
      );

      await expectLater(
        () => readOnlyRepo.upsertOrder(order, actorStaffId: 's-1'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => readOnlyRepo.updateStatus('AMW-A', OrderStatus.completed, actorStaffId: 's-1'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
