import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/data/orders_seeder.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('seedIfEmpty inserts the four demo orders on first run', () async {
    final seeder = OrdersSeeder(clock: () => DateTime.utc(2026, 5, 21, 8));
    await seeder.seedIfEmpty(db);

    final rows = await db.select(db.orders).get();
    expect(rows, hasLength(4));
    expect(rows.map((r) => r.orderCode).toSet(),
        {'AMW-1024', 'AMW-1025', 'AMW-1026', 'AMW-1027'});
  });

  test('seedIfEmpty is a no-op when the table already has rows', () async {
    final seeder = OrdersSeeder(clock: () => DateTime.utc(2026, 5, 21, 8));
    await seeder.seedIfEmpty(db);
    await seeder.seedIfEmpty(db);

    final rows = await db.select(db.orders).get();
    expect(rows, hasLength(4));
  });

  test('seedIfEmpty writes no outbox rows (seed is local-only)', () async {
    final seeder = OrdersSeeder(clock: () => DateTime.utc(2026, 5, 21, 8));
    await seeder.seedIfEmpty(db);

    final outboxRows = await db.select(db.outbox).get();
    expect(outboxRows, isEmpty);
  });

  test('seedIfEmpty is a no-op when skipInRelease is true', () async {
    // Production release builds skip the seeder entirely so demo data never
    // leaks into a real rider's dashboard. `kReleaseMode` is `false` in
    // tests, so we have to inject the gate explicitly.
    final seeder = OrdersSeeder(
      clock: () => DateTime.utc(2026, 5, 21, 8),
      skipInRelease: true,
    );
    await seeder.seedIfEmpty(db);

    final rows = await db.select(db.orders).get();
    expect(rows, isEmpty);
  });
}
