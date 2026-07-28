import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/bootstrap/app_bootstrap.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/data/orders_seeder.dart';

void main() {
  test('AppBootstrap.runSeed seeds the orders table once', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await AppBootstrap.runSeed(db, OrdersSeeder(clock: () => DateTime.utc(2026, 5, 21)));
    final rows = await db.select(db.orders).get();
    expect(rows, hasLength(4));
    await db.close();
  });
}
