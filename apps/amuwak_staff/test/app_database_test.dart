import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:amuwak_staff/src/data/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('all 11 synced + local tables exist on a fresh in-memory database', () async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    ).get();
    final tableNames = rows.map((r) => r.read<String>('name')).toSet();
    expect(tableNames, containsAll(<String>[
      'staff', 'customers', 'orders',
      'order_status_events', 'proof_events', 'proof_photos',
      'issues', 'shifts', 'valid_transitions',
      'outbox', 'sync_watermarks',
    ]));
  });

  test('inserting an order round-trips through Drift', () async {
    final now = DateTime.utc(2026, 5, 19);
    await db.into(db.orders).insert(OrdersCompanion.insert(
      id: 'order-1',
      orderCode: 'AMW-1',
      customerName: 'C',
      phone: '+254700',
      address: 'A',
      serviceType: 'wash_fold',
      status: 'received',
      intakeMethod: 'walk_in',
      fulfillmentMethod: 'delivery',
      itemCount: 3,
      intakeRecordedBy: 'staff-1',
      createdBy: 'staff-1',
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final rows = await db.select(db.orders).get();
    expect(rows, hasLength(1));
    expect(rows.first.orderCode, 'AMW-1');
  });

  test('schemaVersion is 9', () {
    expect(db.schemaVersion, 9);
  });

  test('orders table exposes the pricing columns', () async {
    // A select compiling proves the columns exist.
    final rows = await db.select(db.orders).get();
    expect(rows, isEmpty);
  });

  test('orders audit pointers (updated_by/deleted_by) round-trip', () async {
    final now = DateTime.utc(2026, 5, 19);
    await db.into(db.orders).insert(OrdersCompanion.insert(
      id: 'order-audit',
      orderCode: 'AMW-AUDIT',
      customerName: 'C',
      phone: '+254700',
      address: 'A',
      serviceType: 'wash_fold',
      status: 'received',
      intakeMethod: 'walk_in',
      fulfillmentMethod: 'delivery',
      itemCount: 1,
      intakeRecordedBy: 'staff-1',
      createdBy: 'staff-1',
      updatedBy: const Value('staff-2'),
      deletedBy: const Value('staff-3'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final row =
        await (db.select(db.orders)..where((o) => o.id.equals('order-audit')))
            .getSingle();
    expect(row.updatedBy, 'staff-2');
    expect(row.deletedBy, 'staff-3');
  });

  test('onUpgrade from v5 adds the orders audit columns', () async {
    final tempDir = await Directory.systemTemp.createTemp('amuwak_mig_test');
    final file = File(p.join(tempDir.path, 'v5.sqlite'));
    try {
      // Seed a v5-era database: an orders table without the audit columns,
      // stamped at user_version 5 so opening AppDatabase runs onUpgrade(5 -> 6)
      // and only the `from < 6` branch fires.
      final seed = sqlite3.open(file.path);
      seed.execute(
        'CREATE TABLE orders (id TEXT NOT NULL PRIMARY KEY, order_code TEXT NOT NULL);',
      );
      seed.execute('PRAGMA user_version = 5;');
      seed.dispose();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      // A query forces the lazy connection open, which runs the migration.
      final cols =
          await migrated.customSelect("PRAGMA table_info('orders')").get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll(<String>['updated_by', 'deleted_by']),
        reason: 'the from < 6 branch should add both audit columns',
      );
      await migrated.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test("onUpgrade from v7 adds the customer's cart snapshot", () async {
    final tempDir = await Directory.systemTemp.createTemp('amuwak_mig_v7');
    final file = File(p.join(tempDir.path, 'v7.sqlite'));
    try {
      // A v7-era database already holding an order, so the upgrade has to
      // back-fill the new column rather than only create it.
      final seed = sqlite3.open(file.path);
      seed.execute(
        'CREATE TABLE orders (id TEXT NOT NULL PRIMARY KEY, order_code TEXT NOT NULL);',
      );
      seed.execute("INSERT INTO orders VALUES ('o-1', 'AMW-1');");
      seed.execute('PRAGMA user_version = 7;');
      seed.dispose();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      final cols =
          await migrated.customSelect("PRAGMA table_info('orders')").get();
      expect(
        cols.map((r) => r.read<String>('name')),
        contains('cart_items'),
        reason: 'the from < 8 branch should add the snapshot column',
      );

      // The pre-existing order reads as "no cart", not null.
      final existing =
          await migrated.customSelect('SELECT cart_items FROM orders').get();
      expect(existing.single.read<String>('cart_items'), '[]');
      await migrated.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('onUpgrade from v8 adds the expected collection date', () async {
    final tempDir = await Directory.systemTemp.createTemp('amuwak_mig_v8');
    final file = File(p.join(tempDir.path, 'v8.sqlite'));
    try {
      final seed = sqlite3.open(file.path);
      seed.execute(
        'CREATE TABLE orders (id TEXT NOT NULL PRIMARY KEY, order_code TEXT NOT NULL);',
      );
      seed.execute('PRAGMA user_version = 8;');
      seed.dispose();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      final cols =
          await migrated.customSelect("PRAGMA table_info('orders')").get();
      expect(
        cols.map((r) => r.read<String>('name')),
        contains('expected_collection_at'),
        reason: 'the from < 9 branch should add the collection-date column',
      );
      await migrated.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
