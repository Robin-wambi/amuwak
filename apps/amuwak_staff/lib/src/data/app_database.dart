import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/staff_table.dart';
import 'tables/customers_table.dart';
import 'tables/orders_table.dart';
import 'tables/order_status_events_table.dart';
import 'tables/proof_events_table.dart';
import 'tables/proof_photos_table.dart';
import 'tables/issues_table.dart';
import 'tables/shifts_table.dart';
import 'tables/valid_transitions_table.dart';
import 'tables/outbox_table.dart';
import 'tables/sync_watermarks_table.dart';
import 'tables/pull_dead_letter_table.dart';
import 'tables/pricing_settings_table.dart';
import 'tables/pricing_catalog_items_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Staff, Customers, Orders, OrderStatusEvents,
  ProofEvents, ProofPhotos, Issues, Shifts,
  ValidTransitions, Outbox, SyncWatermarks,
  PullDeadLetter, PricingSettings, PricingCatalogItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(pullDeadLetter);
          }
          if (from < 3) {
            await m.addColumn(orders, orders.ratePerKgSnapshotUgx);
            await m.addColumn(orders, orders.estimatedWeightKg);
            await m.addColumn(orders, orders.finalWeightKg);
            await m.addColumn(orders, orders.lineItems);
            await m.addColumn(orders, orders.manualAdjustmentUgx);
            await m.addColumn(orders, orders.totalUgx);
            await m.addColumn(customers, customers.customRatePerKgUgx);
            await m.createTable(pricingSettings);
          }
          if (from < 4) {
            await m.addColumn(orders, orders.deliveryFeeSnapshotUgx);
            await m.addColumn(orders, orders.isExpress);
            await m.addColumn(orders, orders.expressFlatSnapshotUgx);
            await m.addColumn(orders, orders.expressPctSnapshot);
            await m.addColumn(pricingSettings, pricingSettings.deliveryFeeUgx);
            await m.addColumn(
                pricingSettings, pricingSettings.expressSurchargeFlatUgx);
            await m.addColumn(
                pricingSettings, pricingSettings.expressSurchargePct);
            await m.createTable(pricingCatalogItems);
          }
          // Only DBs created at v4 lack `category`: the `from < 4` branch above
          // runs createTable(pricingCatalogItems) against the current (v5)
          // schema, which already includes the column. Guarding on `from >= 4`
          // avoids a duplicate-column error for v1–v3 → v5 upgrades.
          if (from >= 4 && from < 5) {
            await m.addColumn(pricingCatalogItems, pricingCatalogItems.category);
          }
          if (from < 6) {
            await m.addColumn(orders, orders.updatedBy);
            await m.addColumn(orders, orders.deletedBy);
          }
          if (from < 7) {
            await m.addColumn(orders, orders.paymentAmountUgx);
          }
          if (from < 8) {
            await m.addColumn(orders, orders.cartItems);
          }
          if (from < 9) {
            await m.addColumn(orders, orders.expectedCollectionAt);
          }
        },
      );
}

QueryExecutor _openConnection() => LazyDatabase(
      () async => driftDatabase(
        name: 'amuwak_staff',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
