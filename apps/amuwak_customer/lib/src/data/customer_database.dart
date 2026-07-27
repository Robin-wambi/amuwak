import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'customer_database.g.dart';

/// One line in the customer's local cart. This table is the cart's SOURCE OF
/// TRUTH — the UI streams from it, so the cart works fully offline; a mirror to
/// the server `carts` table is queued through [Outbox] when online.
///
/// A line is either a weight item (`kind='weight'`, a [serviceType] + rough
/// [estKg]) or a piece item (`kind='piece'`, a catalog item at [unitUgx] ×
/// [qty]). [photoKey] is the `customer-uploads` object key of a damage photo
/// attached to the line; its bytes wait in [LocalPhotos] until the outbox
/// uploads them, and the key rides into the order's `cart_items` snapshot.
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
  TextColumn get photoKey => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Compressed bytes of a damage photo, held locally until the outbox uploads
/// them to the `customer-uploads` bucket. Keyed by the Storage object [key] the
/// photo is destined for, so the queued upload needs nothing but the key.
///
/// Bytes, not a file path: the customer app also ships as a web PWA, where
/// there is no filesystem — one code path beats a conditional `dart:io` import.
/// A row outlives its cart line (checkout clears the cart while the upload may
/// still be queued) and is deleted once uploaded and no longer previewed.
class LocalPhotos extends Table {
  TextColumn get key => text()();
  BlobColumn get bytes => blob()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
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

@DriftDatabase(tables: [CartItems, Outbox, LocalPhotos])
class CustomerDatabase extends _$CustomerDatabase {
  CustomerDatabase() : super(_open());

  /// In-memory database for tests (pass `NativeDatabase.memory()`).
  CustomerDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  /// v1 → v2 adds [LocalPhotos] and drops the never-used `cart_items
  /// .photo_local_path` (photo bytes live in [LocalPhotos] now). The cart is a
  /// local working set, so rows are carried over rather than rebuilt.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(localPhotos);
            await m.alterTable(TableMigration(cartItems));
          }
        },
      );

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

  // ---- Local photos ----

  Future<void> putLocalPhoto({
    required String key,
    required Uint8List bytes,
    required DateTime now,
  }) =>
      into(localPhotos).insertOnConflictUpdate(LocalPhotosCompanion.insert(
        key: key,
        bytes: bytes,
        createdAt: now,
      ));

  Future<LocalPhoto?> localPhoto(String key) =>
      (select(localPhotos)..where((t) => t.key.equals(key)))
          .getSingleOrNull();

  Future<void> deleteLocalPhoto(String key) =>
      (delete(localPhotos)..where((t) => t.key.equals(key))).go();

  Future<void> markPhotoUploaded(String key) =>
      (update(localPhotos)..where((t) => t.key.equals(key)))
          .write(const LocalPhotosCompanion(uploaded: Value(true)));

  /// Frees photo bytes nothing needs any more: already uploaded, and no longer
  /// previewed on a cart line. Run after the cart empties at checkout — bytes
  /// whose upload is still queued are deliberately kept.
  Future<void> sweepLocalPhotos() async {
    final uploadedKeys = await (select(localPhotos)
          ..where((t) => t.uploaded.equals(true)))
        .map((p) => p.key)
        .get();
    for (final key in uploadedKeys) {
      if (!await isPhotoReferenced(key)) await deleteLocalPhoto(key);
    }
  }

  /// Whether a cart line still shows this photo — the upload keeps the bytes
  /// around for the preview until nothing points at them.
  Future<bool> isPhotoReferenced(String key) async {
    final rows = await (select(cartItems)
          ..where((t) => t.photoKey.equals(key))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

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
