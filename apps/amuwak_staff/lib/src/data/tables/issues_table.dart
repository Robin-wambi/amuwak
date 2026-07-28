import 'package:drift/drift.dart';

class Issues extends Table {
  TextColumn     get id           => text()();
  TextColumn     get orderId      => text().named('order_id').nullable()();
  TextColumn     get kind         => text()();
  TextColumn     get description  => text()();
  TextColumn     get reportedBy   => text().named('reported_by')();
  DateTimeColumn get reportedAt   => dateTime().named('reported_at')();
  DateTimeColumn get resolvedAt   => dateTime().named('resolved_at').nullable()();
  TextColumn     get resolvedBy   => text().named('resolved_by').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
