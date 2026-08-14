import 'package:drift/drift.dart';

class Orders extends Table {
  TextColumn     get id                 => text()();
  TextColumn     get orderCode          => text().named('order_code')();
  TextColumn     get customerId         => text().named('customer_id').nullable()();
  TextColumn     get customerName       => text().named('customer_name')();
  TextColumn     get phone              => text()();
  TextColumn     get address            => text()();
  TextColumn     get serviceType        => text().named('service_type')();
  TextColumn     get status             => text()();
  TextColumn     get intakeMethod       => text().named('intake_method')();
  TextColumn     get fulfillmentMethod  => text().named('fulfillment_method')();
  IntColumn      get itemCount          => integer().named('item_count')();
  TextColumn     get notes              => text().withDefault(const Constant(''))();
  DateTimeColumn get scheduledFor       => dateTime().named('scheduled_for').nullable()();
  // The promised ready-for-collection date (Supabase migration 0058). Nullable:
  // rider intake may leave it unset. Distinct from scheduled_for (pickup time).
  DateTimeColumn get expectedCollectionAt => dateTime().named('expected_collection_at').nullable()();
  TextColumn     get assignedDriver     => text().named('assigned_driver').nullable()();
  TextColumn     get intakeRecordedBy   => text().named('intake_recorded_by')();
  TextColumn     get createdBy          => text().named('created_by')();
  // Audit pointers for post-creation mutations, mirroring Supabase migration
  // 0029. Nullable: historical rows have none, and they are write-on-Supabase /
  // read-back-only here (no on-device UI surfaces them yet).
  TextColumn     get updatedBy          => text().named('updated_by').nullable()();
  TextColumn     get deletedBy          => text().named('deleted_by').nullable()();
  DateTimeColumn get createdAt          => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt          => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt          => dateTime().named('deleted_at').nullable()();

  RealColumn     get ratePerKgSnapshotUgx => real().named('rate_per_kg_snapshot_ugx').withDefault(const Constant(0))();
  RealColumn     get estimatedWeightKg    => real().named('estimated_weight_kg').nullable()();
  RealColumn     get finalWeightKg        => real().named('final_weight_kg').nullable()();
  TextColumn     get lineItems            => text().named('line_items').withDefault(const Constant('[]'))();
  IntColumn      get manualAdjustmentUgx  => integer().named('manual_adjustment_ugx').withDefault(const Constant(0))();
  IntColumn      get totalUgx             => integer().named('total_ugx').withDefault(const Constant(0))();

  IntColumn      get deliveryFeeSnapshotUgx => integer().named('delivery_fee_snapshot_ugx').withDefault(const Constant(0))();
  BoolColumn     get isExpress             => boolean().named('is_express').withDefault(const Constant(false))();
  IntColumn      get expressFlatSnapshotUgx => integer().named('express_flat_snapshot_ugx').withDefault(const Constant(0))();
  RealColumn     get expressPctSnapshot     => real().named('express_pct_snapshot').withDefault(const Constant(0))();

  // Cumulative cash collected against the order (Supabase migration 0031).
  // Outstanding = total_ugx - this; paid/partial/unpaid is derived, not stored.
  IntColumn      get paymentAmountUgx       => integer().named('payment_amount_ugx').withDefault(const Constant(0))();

  // The customer's itemized cart, frozen at checkout (Supabase migration 0050),
  // as a JSON array — same storage shape as line_items. Empty for orders a rider
  // or the shop took. Read-only here: pulled from Supabase and rendered for
  // staff, never written back.
  TextColumn     get cartItems              => text().named('cart_items').withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}
