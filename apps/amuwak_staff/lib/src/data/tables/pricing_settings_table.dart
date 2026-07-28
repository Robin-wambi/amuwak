import 'package:drift/drift.dart';

class PricingSettings extends Table {
  TextColumn     get id                   => text()();
  RealColumn     get defaultRatePerKgUgx  => real().named('default_rate_per_kg_ugx')();
  DateTimeColumn get updatedAt            => dateTime().named('updated_at')();
  TextColumn     get updatedBy            => text().named('updated_by').nullable()();

  IntColumn      get deliveryFeeUgx          => integer().named('delivery_fee_ugx').withDefault(const Constant(0))();
  IntColumn      get expressSurchargeFlatUgx => integer().named('express_surcharge_flat_ugx').withDefault(const Constant(0))();
  RealColumn     get expressSurchargePct     => real().named('express_surcharge_pct').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
