import 'package:amuwak_core/amuwak_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kReleaseMode;

import 'app_database.dart';

class OrdersSeeder {
  OrdersSeeder({DateTime Function()? clock, bool? skipInRelease})
      : _clock = clock ?? DateTime.now,
        _skipInRelease = skipInRelease ?? kReleaseMode;
  final DateTime Function() _clock;
  // Production release builds skip seeding so the four fake-but-plausible
  // Ugandan demo orders (AMW-1024..1027) never leak into a real rider's
  // dashboard — including after a sign-out truncate. Tests run in debug
  // and pass `skipInRelease: false` only if they explicitly need to bypass.
  final bool _skipInRelease;

  Future<void> seedIfEmpty(AppDatabase db) async {
    if (_skipInRelease) return;
    final existing = await (db.select(db.orders)..limit(1)).get();
    if (existing.isNotEmpty) return;
    final now = _clock();
    await db.batch((batch) {
      batch.insertAll(db.orders, _fixtureOrders(now));
    });
  }

  // TODO(post-PR-B): remove this seeder once real orders flow from
  // Supabase. These four fixtures only exist so the dashboard isn't
  // empty during local dev; once the New Pickup form (PR-B) lands and
  // riders create their own orders, drop the entire OrdersSeeder
  // class and the AppBootstrap.runSeed call.
  //
  // Deterministic hardcoded ids so re-runs don't duplicate and tests can rely
  // on them. Mirrors the four LaundryOrder literals currently at
  // lib/src/dashboard/staff_dashboard_screen.dart:34-78.
  List<OrdersCompanion> _fixtureOrders(DateTime now) => [
    OrdersCompanion.insert(
      id: '00000000-0000-7000-8000-0000aaa01024',
      orderCode: 'AMW-1024',
      customerName: 'Sarah N.',
      phone: '+256 700 123 456',
      address: 'Kikoni, near Makerere western gate',
      serviceType: ServiceType.washAndIron.toDbString(),
      status: 'pending_pickup',
      intakeMethod: 'driver_pickup',
      fulfillmentMethod: 'delivery',
      itemCount: 8,
      notes: const Value('Customer requested careful handling for white shirts.'),
      intakeRecordedBy: '00000000-0000-4000-8000-000000000001',
      createdBy: '00000000-0000-4000-8000-000000000001',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    OrdersCompanion.insert(
      id: '00000000-0000-7000-8000-0000aaa01025',
      orderCode: 'AMW-1025',
      customerName: 'Brian K.',
      phone: '+256 701 456 789',
      address: 'Wandegeya, opposite main stage',
      serviceType: ServiceType.dryCleaning.toDbString(),
      status: 'in_progress',
      intakeMethod: 'driver_pickup',
      fulfillmentMethod: 'delivery',
      itemCount: 3,
      notes: const Value('Suit jacket and trousers. Keep separate from regular wash.'),
      intakeRecordedBy: '00000000-0000-4000-8000-000000000001',
      createdBy: '00000000-0000-4000-8000-000000000001',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    OrdersCompanion.insert(
      id: '00000000-0000-7000-8000-0000aaa01026',
      orderCode: 'AMW-1026',
      customerName: 'Grace A.',
      phone: '+256 702 222 111',
      address: 'Nakulabye, close to Shell',
      serviceType: ServiceType.ironOnly.toDbString(),
      status: 'ready',
      intakeMethod: 'driver_pickup',
      fulfillmentMethod: 'delivery',
      itemCount: 6,
      notes: const Value('Call before delivery.'),
      intakeRecordedBy: '00000000-0000-4000-8000-000000000001',
      createdBy: '00000000-0000-4000-8000-000000000001',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    OrdersCompanion.insert(
      id: '00000000-0000-7000-8000-0000aaa01027',
      orderCode: 'AMW-1027',
      customerName: 'Daniel M.',
      phone: '+256 703 333 222',
      address: 'Bwaise, main road',
      serviceType: ServiceType.washOnly.toDbString(),
      status: 'completed',
      intakeMethod: 'driver_pickup',
      fulfillmentMethod: 'delivery',
      itemCount: 5,
      notes: const Value('Paid in cash at pickup.'),
      intakeRecordedBy: '00000000-0000-4000-8000-000000000001',
      createdBy: '00000000-0000-4000-8000-000000000001',
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  ];
}
