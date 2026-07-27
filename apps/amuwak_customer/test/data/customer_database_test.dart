import 'package:amuwak_customer/src/data/customer_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CustomerDatabase db;

  setUp(() => db = CustomerDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('cart', () {
    test('upsert, order by position, remove, clear', () async {
      await db.upsertCartItem(CartItemsCompanion.insert(
        id: 'b',
        kind: 'weight',
        name: 'Wash & Iron',
        position: const Value(1),
        estKg: const Value(6),
      ));
      await db.upsertCartItem(CartItemsCompanion.insert(
        id: 'a',
        kind: 'piece',
        name: 'Jacket',
        position: const Value(0),
        unitUgx: const Value(8000),
        qty: const Value(2),
      ));

      var items = await db.cartItemsOnce();
      expect(items.map((i) => i.id), ['a', 'b']); // ordered by position

      // Upsert replaces by id.
      await db.upsertCartItem(CartItemsCompanion.insert(
        id: 'a',
        kind: 'piece',
        name: 'Jacket',
        position: const Value(0),
        unitUgx: const Value(8000),
        qty: const Value(3),
      ));
      items = await db.cartItemsOnce();
      expect(items.firstWhere((i) => i.id == 'a').qty, 3);

      await db.removeCartItem('a');
      expect((await db.cartItemsOnce()).map((i) => i.id), ['b']);

      await db.clearCart();
      expect(await db.cartItemsOnce(), isEmpty);
    });
  });

  group('outbox', () {
    test('enqueue is due immediately; recordFailure delays it', () async {
      final now = DateTime.utc(2026, 7, 20, 12);
      await db.enqueue(
          id: 'op1', opType: 'place_order', payload: '{}', now: now);

      expect((await db.dueOutbox(now)).map((r) => r.id), ['op1']);

      // A failed attempt pushes nextAttemptAt into the future.
      await db.recordFailure(
        id: 'op1',
        attempts: 1,
        error: 'timeout',
        nextAttemptAt: now.add(const Duration(seconds: 30)),
      );
      expect(await db.dueOutbox(now), isEmpty); // not due yet
      expect(
        (await db.dueOutbox(now.add(const Duration(minutes: 1)))).map((r) => r.id),
        ['op1'], // due again after the backoff
      );

      final row = (await db.dueOutbox(now.add(const Duration(minutes: 1)))).single;
      expect(row.attempts, 1);
      expect(row.lastError, 'timeout');

      await db.markDone('op1');
      expect(await db.dueOutbox(now.add(const Duration(hours: 1))), isEmpty);
    });

    test('watchPendingCount reflects the queue', () async {
      final now = DateTime.utc(2026, 7, 20, 12);
      expect(await db.watchPendingCount().first, 0);
      await db.enqueue(id: 'x', opType: 'cart_sync', payload: '{}', now: now);
      await db.enqueue(id: 'y', opType: 'cart_sync', payload: '{}', now: now);
      expect(await db.watchPendingCount().first, 2);
      await db.markDone('x');
      expect(await db.watchPendingCount().first, 1);
    });
  });
}
