import 'package:drift/drift.dart';

class SyncWatermarks extends Table {
  // Dart name `forTable` avoids clashing with Drift's Table.tableName getter
  // (which is the optional SQL-name override on the base class). SQL column
  // name stays `table_name` for parity with Supabase queries.
  TextColumn     get forTable      => text().named('table_name')();
  DateTimeColumn get lastSyncedAt  => dateTime().named('last_synced_at')();

  @override
  Set<Column> get primaryKey => {forTable};
}
