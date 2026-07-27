import 'dart:io';
import 'dart:typed_data';

import 'package:amuwak_customer/src/data/customer_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// The Phase 3 (v1) schema, byte for byte — including `photo_local_path`, which
/// v2 drops now that photo bytes live in `local_photos`. Hand-written because the
/// app ships without drift's schema-dump tooling.
const _v1CartItems = '''
CREATE TABLE cart_items (
  id TEXT NOT NULL,
  kind TEXT NOT NULL,
  name TEXT NOT NULL,
  service_type TEXT NULL,
  est_kg REAL NULL,
  catalog_item_id TEXT NULL,
  unit_ugx INTEGER NULL,
  qty INTEGER NOT NULL DEFAULT 1,
  note TEXT NULL,
  photo_local_path TEXT NULL,
  photo_key TEXT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
''';

const _v1Outbox = '''
CREATE TABLE outbox (
  id TEXT NOT NULL,
  op_type TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT NULL,
  next_attempt_at INTEGER NULL,
  PRIMARY KEY (id)
);
''';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('amuwak_customer_v1'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can still hold the file handle; the temp dir is disposable.
    }
  });

  test('a v1 database upgrades: cart and queue survive, photos get a home',
      () async {
    final path = '${dir.path}${Platform.pathSeparator}customer.sqlite';
    final v1 = sqlite3.open(path);
    v1
      ..execute(_v1CartItems)
      ..execute(_v1Outbox)
      ..execute("INSERT INTO cart_items (id, kind, name, est_kg, qty, position) "
          "VALUES ('l1', 'weight', 'Wash & Iron', 6.0, 1, 0)")
      ..execute("INSERT INTO outbox (id, op_type, payload, created_at) "
          "VALUES ('o1', 'place_order', '{}', 0)")
      ..execute('PRAGMA user_version = 1');
    v1.dispose();

    final db = CustomerDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // The queued order and the cart line the customer left behind are intact.
    final items = await db.cartItemsOnce();
    expect(items.single.name, 'Wash & Iron');
    expect(items.single.estKg, 6);
    expect(items.single.photoKey, isNull);
    expect((await db.dueOutbox(DateTime.utc(2026, 7, 27))).single.id, 'o1');

    // v2 additions work against the upgraded file.
    await db.putLocalPhoto(
      key: 'customer/c1/cart/p1.jpg',
      bytes: Uint8List.fromList([1, 2, 3]),
      now: DateTime.utc(2026, 7, 27),
    );
    expect((await db.localPhoto('customer/c1/cart/p1.jpg'))!.bytes, [1, 2, 3]);

    // And the dead v1 column is gone rather than lingering.
    final columns = await db.customSelect('PRAGMA table_info(cart_items)').get();
    expect(
      columns.map((row) => row.data['name']),
      isNot(contains('photo_local_path')),
    );
  });
}
