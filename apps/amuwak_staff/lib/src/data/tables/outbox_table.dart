import 'package:drift/drift.dart';

class Outbox extends Table {
  TextColumn     get id               => text()();
  // `forTable` rather than `tableName` to avoid clashing with the Drift
  // Table base class getter of the same name. SQL column stays `table_name`.
  TextColumn     get forTable         => text().named('table_name')();
  TextColumn     get op               => text()();           // 'insert' | 'update' | 'delete'
  TextColumn     get rowId            => text().named('row_id')();
  TextColumn     get payloadJson      => text().named('payload_json')();
  DateTimeColumn get createdAt        => dateTime().named('created_at').withDefault(currentDateAndTime)();
  IntColumn      get retryCount       => integer().named('retry_count').withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptedAt  => dateTime().named('last_attempted_at').nullable()();
  TextColumn     get lastError        => text().named('last_error').nullable()();
  TextColumn     get status           => text().withDefault(const Constant('pending'))();
  // Written by OutboxRepository: 'pending' (initial) | 'failed' (retryable)
  // | 'dead_letter' (retries exhausted). Successful syncs delete the row
  // rather than mark it 'sent'.

  @override
  Set<Column> get primaryKey => {id};
}
