import 'package:drift/drift.dart';

class ProofEvents extends Table {
  TextColumn     get id            => text()();
  TextColumn     get orderId       => text().named('order_id')();
  TextColumn     get type          => text()();
  DateTimeColumn get capturedAt    => dateTime().named('captured_at')();
  IntColumn      get itemCount     => integer().named('item_count')();
  TextColumn     get notes         => text().nullable()();
  TextColumn     get capturedBy    => text().named('captured_by')();
  DateTimeColumn get createdAt     => dateTime().named('created_at')();
  DateTimeColumn get updatedAt     => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt     => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
