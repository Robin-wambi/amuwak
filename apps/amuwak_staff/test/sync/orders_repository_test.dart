import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';

Future<void> _insertOrder(
  AppDatabase db, {
  required String id,
  String status = 'in_progress',
  String customerName = 'Sarah N.',
  DateTime? scheduledFor,
  DateTime? createdAt,
  DateTime? updatedAt,
}) async {
  final t = createdAt ?? DateTime.utc(2026, 5, 19, 10, 0);
  await db.into(db.orders).insert(OrdersCompanion.insert(
        id: id,
        orderCode: id,
        customerName: customerName,
        phone: '+256 700 000 000',
        address: 'Kikoni',
        serviceType: ServiceType.washAndIron.toDbString(),
        status: status,
        intakeMethod: 'driver_pickup',
        fulfillmentMethod: 'delivery',
        itemCount: 5,
        intakeRecordedBy: 's-1',
        createdBy: 's-1',
        scheduledFor: Value(scheduledFor),
        createdAt: Value(t),
        updatedAt: Value(updatedAt ?? t),
      ));
}

Future<void> _insertProofEvent(
  AppDatabase db, {
  required String id,
  required String orderId,
  required String type,
  required DateTime capturedAt,
  int itemCount = 5,
  String? notes,
}) async {
  await db.into(db.proofEvents).insert(ProofEventsCompanion.insert(
        id: id,
        orderId: orderId,
        type: type,
        capturedAt: capturedAt,
        itemCount: itemCount,
        notes: Value(notes),
        capturedBy: 's-1',
        createdAt: capturedAt,
        updatedAt: capturedAt,
      ));
}

void main() {
  late AppDatabase db;
  late OrdersRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = OrdersRepository(db);
  });

  tearDown(() async => db.close());

  group('OrdersRepository.watchAll', () {
    test('emits an empty list when the orders table is empty', () async {
      final list = await repo.watchAll().first;
      expect(list, isEmpty);
    });

    test('emits LaundryOrders joined to their proof events', () async {
      await _insertOrder(db, id: 'AMW-A', status: 'in_progress');
      await _insertOrder(db, id: 'AMW-B', status: 'pending_pickup');
      await _insertProofEvent(
        db,
        id: 'pe-1',
        orderId: 'AMW-A',
        type: 'pickup',
        capturedAt: DateTime.utc(2026, 5, 19, 10, 30),
      );
      await _insertProofEvent(
        db,
        id: 'pe-2',
        orderId: 'AMW-A',
        type: 'delivery',
        capturedAt: DateTime.utc(2026, 5, 19, 16, 0),
      );

      final list = await repo.watchAll().first;
      list.sort((a, b) => a.orderId.compareTo(b.orderId));

      expect(list, hasLength(2));
      expect(list[0].orderId, 'AMW-A');
      expect(list[0].status, OrderStatus.inProgress);
      expect(list[0].proofEvents, hasLength(2));
      expect(
        list[0].proofEvents.map((e) => e.type),
        containsAll(<ProofEventType>[
          ProofEventType.pickup,
          ProofEventType.delivery,
        ]),
      );

      expect(list[1].orderId, 'AMW-B');
      expect(list[1].status, OrderStatus.pendingPickup);
      expect(list[1].proofEvents, isEmpty);
    });

    test('re-emits when an order\'s status changes', () async {
      await _insertOrder(db, id: 'AMW-A', status: 'in_progress');
      final emissions = <List<LaundryOrder>>[];
      final sub = repo.watchAll().listen(emissions.add);

      // Wait for the first emission to settle.
      await Future<void>.delayed(Duration.zero);
      expect(emissions, isNotEmpty);
      expect(emissions.last.single.status, OrderStatus.inProgress);

      await (db.update(db.orders)..where((t) => t.id.equals('AMW-A')))
          .write(const OrdersCompanion(status: Value('ready')));

      // Wait for the watcher to re-fire.
      await Future<void>.delayed(Duration.zero);
      expect(emissions.last.single.status, OrderStatus.readyForDelivery);

      await sub.cancel();
    });
  });

  group('OrdersRepository.watchById', () {
    test('emits null for an unknown id', () async {
      final value = await repo.watchById('does-not-exist').first;
      expect(value, isNull);
    });

    test('emits a LaundryOrder with its proof events for a known id', () async {
      await _insertOrder(db, id: 'AMW-A', status: 'pending_pickup');
      await _insertProofEvent(
        db,
        id: 'pe-1',
        orderId: 'AMW-A',
        type: 'pickup',
        capturedAt: DateTime.utc(2026, 5, 19, 10, 30),
      );

      final value = await repo.watchById('AMW-A').first;
      expect(value, isNotNull);
      expect(value!.orderId, 'AMW-A');
      expect(value.status, OrderStatus.pendingPickup);
      expect(value.proofEvents, hasLength(1));
      expect(value.proofEvents.single.type, ProofEventType.pickup);
    });

    test('does not include proof events from other orders', () async {
      await _insertOrder(db, id: 'AMW-A');
      await _insertOrder(db, id: 'AMW-B');
      await _insertProofEvent(
        db,
        id: 'pe-other',
        orderId: 'AMW-B',
        type: 'pickup',
        capturedAt: DateTime.utc(2026, 5, 19, 10, 30),
      );

      final value = await repo.watchById('AMW-A').first;
      expect(value, isNotNull);
      expect(value!.proofEvents, isEmpty);
    });
  });

  group('soft-delete filtering', () {
    test('watchAll omits orders with a non-null deletedAt', () async {
      await _insertOrder(db, id: 'AMW-LIVE', status: 'pending_pickup');
      await _insertOrder(db, id: 'AMW-GONE', status: 'pending_pickup');
      await (db.update(db.orders)..where((t) => t.id.equals('AMW-GONE')))
          .write(OrdersCompanion(
              deletedAt: Value(DateTime.utc(2026, 5, 22, 12, 0))));

      final list = await repo.watchAll().first;
      expect(list.map((o) => o.orderId), ['AMW-LIVE']);
    });

    test('watchById returns null for a soft-deleted order', () async {
      await _insertOrder(db, id: 'AMW-GONE', status: 'pending_pickup');
      await (db.update(db.orders)..where((t) => t.id.equals('AMW-GONE')))
          .write(OrdersCompanion(deletedAt: Value(DateTime.utc(2026, 5, 22))));

      final value = await repo.watchById('AMW-GONE').first;
      expect(value, isNull);
    });
  });
}
