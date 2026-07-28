import 'package:drift/drift.dart';

import '../data/app_database.dart';
import 'sync_puller.dart' show SyncFetch;
import 'sync_registry.dart';

/// One-shot bootstrap loader for the static `valid_transitions` seed table.
///
/// `valid_transitions` is reference data: tiny (~20 rows), changes only via
/// migration, and has no per-row `updated_at`. The puller's incremental
/// watermark machinery doesn't fit, so [SyncOrchestrator] calls
/// [loadOnce] once per app start (after sign-in) and never writes a row to
/// `sync_watermarks`.
class ValidTransitionsLoader {
  ValidTransitionsLoader({required this.db, required this.fetch});

  final AppDatabase db;
  final SyncFetch fetch;

  /// `created_at` is present on every row in Postgres; the loader passes
  /// it to satisfy [SyncFetch]'s shape but never reads it back.
  static const SyncTable _table = SyncTable(
    name: 'valid_transitions',
    watermarkColumn: 'created_at',
  );

  /// Fetches every transition row and upserts it locally. Errors from the
  /// fetcher are rethrown unchanged; the local table is only touched if
  /// the fetch succeeds.
  Future<void> loadOnce() async {
    final rows = await fetch(_table, DateTime.utc(1970));
    if (rows.isEmpty) return;

    await db.batch((batch) {
      for (final r in rows) {
        batch.insert(
          db.validTransitions,
          ValidTransitionsCompanion.insert(
            id: r['id'] as String,
            intakeMethod: r['intake_method'] as String,
            fulfillmentMethod: r['fulfillment_method'] as String,
            fromStatus: Value(r['from_status'] as String?),
            toStatus: r['to_status'] as String,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
