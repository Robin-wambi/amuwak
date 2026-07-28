import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// Read/write API over the `pull_dead_letter` Drift table. The puller writes
/// here when a mapper throws on a server row; the SyncErrorsScreen reads
/// from here to surface those failures.
class PullDeadLetterRepository {
  PullDeadLetterRepository(this._db);
  final AppDatabase _db;

  /// Quarantines a single row that the mapper couldn't ingest.
  ///
  /// Builds a synthetic id from `<table>:<rowId>:<recordedAtMicros>` so two
  /// distinct failures at different times don't collide.  `insertOrIgnore`
  /// silently drops the rare collision (same table, same row id, same
  /// microsecond) rather than throwing.
  Future<void> insert({
    required String forTable,
    required Map<String, dynamic> rowPayload,
    required String errorText,
    DateTime? recordedAt,
  }) {
    final now = recordedAt ?? DateTime.now().toUtc();
    final rowId = (rowPayload['id'] ?? '<no-id>').toString();
    final syntheticId =
        '$forTable:$rowId:${now.microsecondsSinceEpoch}';
    return _db.into(_db.pullDeadLetter).insert(
          PullDeadLetterCompanion.insert(
            id: syntheticId,
            forTable: forTable,
            rowPayloadJson: jsonEncode(rowPayload),
            errorText: errorText,
            recordedAt: Value(now),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Live stream of every quarantined row, newest-first.
  Stream<List<PullDeadLetterData>> watchAll() {
    return (_db.select(_db.pullDeadLetter)
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
        .watch();
  }

  /// Dismisses a quarantined row. The puller's watermark has already
  /// advanced past it so the row won't reappear unless its server copy
  /// changes (which would generate a new synthetic id).
  Future<void> delete(String id) {
    return (_db.delete(_db.pullDeadLetter)
          ..where((t) => t.id.equals(id)))
        .go();
  }
}
