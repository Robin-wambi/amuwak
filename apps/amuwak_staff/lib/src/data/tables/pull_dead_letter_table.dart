import 'package:drift/drift.dart';

/// Rows that the sync puller's per-table mapper couldn't parse — typically
/// a schema drift on the server side or a null in a column the local Drift
/// schema declares non-null. Parking them here lets the puller advance its
/// watermark instead of stalling the whole table; the UI surfaces them via
/// SyncErrorsScreen so the back office can fix the row server-side.
class PullDeadLetter extends Table {
  // `forTable` rather than `tableName` to dodge Drift's Table base-class
  // `tableName` getter (same pattern as Outbox.forTable).  SQL column stays
  // `table_name`.
  TextColumn     get id              => text()();                          // synthesised '<table>:<rowId>:<recordedAtMicros>'
  TextColumn     get forTable        => text().named('table_name')();
  TextColumn     get rowPayloadJson  => text().named('row_payload_json')();
  TextColumn     get errorText       => text().named('error_text')();
  DateTimeColumn get recordedAt      => dateTime().named('recorded_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
