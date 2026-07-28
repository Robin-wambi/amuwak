import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/outbox_repository.dart';

/// Offline-first mutation wiring for [OrdersRepository]: each write lands in the
/// local Drift `orders` table AND enqueues the right outbox row (forTable/op/
/// rowId/payload). Complements orders_repository_write_test.dart (upsertOrder +
/// updateStatus) with the createPickup RPC path and the pricing/details/
/// soft-delete updates. Pure payload shapes are pinned in
/// supabase_payloads_test.dart; here we verify the repo writes locally and
/// queues the matching mutation.
void main() {
  final clock = DateTime.utc(2026, 6, 24, 10, 30);
  late AppDatabase db;
  late OutboxRepository outbox;
  late OrdersRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    repo = OrdersRepository(db, outbox: outbox, clock: () => clock);
  });

  tearDown(() async => db.close());

  LaundryOrder order({String id = 'o1', String code = 'AMW-1'}) => LaundryOrder(
        orderId: id,
        orderCode: code,
        customerName: 'Ada',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.inProgress,
        timeLabel: 't',
        itemCount: 5,
        phone: '0700',
        address: 'Kira',
        notes: 'gate 4',
        scheduledFor: DateTime.utc(2026, 6, 25, 9),
        // Pricing snapshot that must never leak into a descriptive update.
        ratePerKgSnapshotUgx: 5000,
        totalUgx: 19500,
      );

  Customer customer({String id = 'c1'}) => Customer(
        id: id,
        name: 'Ada',
        phone: '0700',
        address: 'Kira',
        notes: null,
        createdAt: clock,
        updatedAt: clock,
        deletedAt: null,
        customRatePerKgUgx: null,
      );

  /// Inserts a base order row so update/soft-delete tests have something to hit.
  Future<void> seed(String id) =>
      db.into(db.orders).insert(OrdersCompanion.insert(
            id: id,
            orderCode: id,
            customerName: 'Ada',
            phone: '0700',
            address: 'Kira',
            serviceType: ServiceType.washAndIron.toDbString(),
            status: 'in_progress',
            intakeMethod: 'driver_pickup',
            fulfillmentMethod: 'delivery',
            itemCount: 5,
            intakeRecordedBy: 's-1',
            createdBy: 's-1',
          ));

  Future<Map<String, dynamic>> singlePendingPayload() async {
    final pending = await outbox.peekPending(limit: 10);
    expect(pending, hasLength(1));
    return jsonDecode(pending.single.payloadJson) as Map<String, dynamic>;
  }

  group('createPickup', () {
    test('writes local customer + order and enqueues a create_pickup rpc row',
        () async {
      final result = await repo.createPickup(
          order(id: 'o1'), customer(id: 'c1'), actorStaffId: 's1');

      expect(result.orderId, 'o1');

      expect((await db.select(db.orders).get()).single.id, 'o1');
      expect((await db.select(db.customers).get()).single.id, 'c1');

      final pending = await outbox.peekPending(limit: 10);
      expect(pending, hasLength(1));
      expect(pending.single.forTable, 'create_pickup');
      expect(pending.single.op, 'rpc');
      expect(pending.single.rowId, 'o1');
      final payload =
          jsonDecode(pending.single.payloadJson) as Map<String, dynamic>;
      expect((payload['p_customer'] as Map)['id'], 'c1');
      expect((payload['p_order'] as Map)['id'], 'o1');
      // The RPC owns the code/attribution; the client passes descriptive +
      // pricing fields.
      expect((payload['p_order'] as Map)['service_type'], 'Wash & Iron');
    });

    test('is idempotent: a retry with the same order id does not duplicate',
        () async {
      await repo.createPickup(order(id: 'o1'), customer(id: 'c1'),
          actorStaffId: 's1');
      await repo.createPickup(order(id: 'o1'), customer(id: 'c1'),
          actorStaffId: 's1');

      expect(await db.select(db.orders).get(), hasLength(1));
      expect(await outbox.peekPending(limit: 10), hasLength(1),
          reason: 'the create_pickup:rpc:<id> dedup key absorbs the retry');
    });

    test('without an outbox throws StateError', () async {
      final noOutbox = OrdersRepository(db, clock: () => clock);
      expect(
        () => noOutbox.createPickup(order(), customer(), actorStaffId: 's'),
        throwsStateError,
      );
    });
  });

  group('updatePricing', () {
    LaundryOrder pricedOrder() => order().copyWith(
          finalWeightKg: 4,
          manualAdjustmentUgx: 500,
          deliveryFeeSnapshotUgx: 2000,
        );

    test('writes recomputed pricing locally and enqueues an update row',
        () async {
      await seed('o1');
      final o = pricedOrder();
      final recomputed = OrdersRepository.recomputeOrderTotal(o).totalUgx;

      await repo.updatePricing(o, actorStaffId: 'staff-7');

      final row =
          await (db.select(db.orders)..where((t) => t.id.equals('o1')))
              .getSingle();
      expect(row.finalWeightKg, 4);
      expect(row.manualAdjustmentUgx, 500);
      expect(row.totalUgx, recomputed);
      expect(row.totalUgx, isNot(19500), reason: 'recomputed, not the stale total');
      expect(row.updatedBy, 'staff-7');

      final payload = await singlePendingPayload();
      expect(payload['total_ugx'], recomputed);
      expect(payload['updated_by'], 'staff-7');
      // Descriptive/status/creation columns must never leak into a pricing edit.
      expect(payload.containsKey('customer_name'), isFalse);
      expect(payload.containsKey('status'), isFalse);
      expect(payload.containsKey('created_by'), isFalse);
    });

    test('throws StateError when no local row matches', () async {
      expect(
        () => repo.updatePricing(pricedOrder(), actorStaffId: 's'),
        throwsStateError,
      );
    });
  });

  group('updateOrderDetails', () {
    test('writes descriptive columns locally and enqueues an update row',
        () async {
      await seed('o1');

      await repo.updateOrderDetails(order(), actorStaffId: 'staff-7');

      final row =
          await (db.select(db.orders)..where((t) => t.id.equals('o1')))
              .getSingle();
      expect(row.customerName, 'Ada');
      expect(row.itemCount, 5);
      expect(row.notes, 'gate 4');
      expect(row.updatedBy, 'staff-7');

      final payload = await singlePendingPayload();
      expect(payload['customer_name'], 'Ada');
      expect(payload['updated_by'], 'staff-7');
      // Creation metadata, status, and pricing snapshots must never leak.
      expect(payload.containsKey('created_by'), isFalse);
      expect(payload.containsKey('status'), isFalse);
      expect(payload.containsKey('total_ugx'), isFalse);
    });

    test('throws StateError when no local row matches', () async {
      expect(
        () => repo.updateOrderDetails(order(id: 'missing'), actorStaffId: 's'),
        throwsStateError,
      );
    });
  });

  group('softDelete', () {
    test('sets deleted_at/deleted_by locally and enqueues an update row',
        () async {
      await seed('o9');

      await repo.softDelete('o9', actorStaffId: 'staff-7');

      final row =
          await (db.select(db.orders)..where((t) => t.id.equals('o9')))
              .getSingle();
      expect(row.deletedAt, clock);
      expect(row.deletedBy, 'staff-7');

      final pending = await outbox.peekPending(limit: 10);
      expect(pending.single.op, 'update');
      final payload =
          jsonDecode(pending.single.payloadJson) as Map<String, dynamic>;
      expect(payload['deleted_at'], '2026-06-24T10:30:00.000Z');
      expect(payload['deleted_by'], 'staff-7');
    });

    test('throws StateError when no local row matches', () async {
      expect(
        () => repo.softDelete('missing', actorStaffId: 's'),
        throwsStateError,
      );
    });
  });
}
