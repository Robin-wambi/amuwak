import 'package:drift/drift.dart';

class OrderStatusEvents extends Table {
  TextColumn     get id              => text()();
  TextColumn     get orderId         => text().named('order_id')();
  TextColumn     get fromStatus      => text().named('from_status').nullable()();
  TextColumn     get toStatus        => text().named('to_status')();
  TextColumn     get changedBy       => text().named('changed_by')();
  DateTimeColumn get changedAt       => dateTime().named('changed_at')();
  TextColumn     get source          => text()();
  TextColumn     get deviceEventId   => text().named('device_event_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
