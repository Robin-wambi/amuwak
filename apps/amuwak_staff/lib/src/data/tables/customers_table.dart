import 'package:drift/drift.dart';

class Customers extends Table {
  TextColumn get id            => text()();
  TextColumn get name          => text()();
  TextColumn get phone         => text()();
  TextColumn get address       => text().nullable()();
  TextColumn get notes         => text().nullable()();
  RealColumn     get customRatePerKgUgx => real().named('custom_rate_per_kg_ugx').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
