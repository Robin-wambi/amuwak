import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'customer_database.g.dart';

/// One line in the customer's local cart. This table is the cart's SOURCE OF
/// TRUTH — the UI streams from it, so the cart works fully offline; a mirror to
/// the server `carts` table is queued through [Outbox] when online.
///
/// A line is either a weight item (`kind='weight'`, a [serviceType] + rough
/// [estKg]) or a piece item (`kind='piece'`, a catalog item at [unitUgx] ×
/// [qty]). [photoLocalPath] is a damaged-item photo captured offline; once
/// uploaded it also carries the Storage [photoKey].
class CartItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // 'weight' | 'piece'
  TextColumn get name => text()(); // service label or catalog name
  TextColumn get serviceType => text().nullable()();
  RealColumn get estKg => real().nullable()();
  TextColumn get catalogItemId => text().nullable()();
  IntColumn get unitUgx => integer().nullable()();
  IntColumn get qty => integer().withDefault(const Constant(1))();
  TextColumn get note => text().nullable()();
  TextColumn get photoLocalPath => text().nullable()();
  TextColumn get photoKey => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Durable queue of writes that must reach Supabase: `place_order`, `cart_sync`,
/// `photo_upload`. Drained by the OutboxWorker when online; a failed attempt is
/// re-queued with a later [nextAttemptAt] (transient errors never dead-letter —
/// the same lesson the staff sync engine learned on poor networks).
class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get opType => text()();
  TextColumn get payload => text()(); // JSON
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CartItems, Outbox])
class CustomerDatabase extends _$CustomerDatabase {
  CustomerDatabase() : super(_open());

  /// In-memory database for tests (pass `NativeDatabase.memory()`).
  CustomerDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ---- Cart ----
  Stream<List<CartItem>> watchCart() =>
      (select(cartItems)..orderBy([(t) => OrderingTerm(expression: t.position)]))
          .watch();

  Future<List<CartItem>> cartItemsOnce() =>
      (select(cartItems)..orderBy([(t) => OrderingTerm(expression: t.position)]))
          .get();

  Future<void> upsertCartItem(CartItemsCompanion item) =>
      into(cartItems).insertOnConflictUpdate(item);

  Future<void> removeCartItem(String id) =>
      (delete(cartItems)..where((t) => t.id.equals(id))).go();

  Future<void> clearCart() => delete(cartItems).go();

  // ---- Outbox ----
  Future<void> enqueue({
    required String id,
    required String opType,
    required String payload,
    required DateTime now,
  }) =>
      into(outbox).insert(OutboxCompanion.insert(
        id: id,
        opType: opType,
        payload: payload,
        createdAt: now,
      ));

  /// Rows ready to attempt now (no backoff, or the backoff has elapsed), oldest
  /// first.
  Future<List<OutboxData>> dueOutbox(DateTime now) => (select(outbox)
        ..where((t) =>
            t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
      .get();

  Stream<int> watchPendingCount() {
    final count = outbox.id.count();
    final q = selectOnly(outbox)..addColumns([count]);
    return q.map((r) => r.read(count) ?? 0).watchSingle();
  }

  Future<void> markDone(String id) =>
      (delete(outbox)..where((t) => t.id.equals(id))).go();

  Future<void> recordFailure({
    required String id,
    required int attempts,
    required String error,
    required DateTime nextAttemptAt,
  }) =>
      (update(outbox)..where((t) => t.id.equals(id))).write(OutboxCompanion(
        attempts: Value(attempts),
        lastError: Value(error),
        nextAttemptAt: Value(nextAttemptAt),
      ));
}

QueryExecutor _open() => LazyDatabase(
      () async => driftDatabase(
        name: 'amuwak_customer',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
