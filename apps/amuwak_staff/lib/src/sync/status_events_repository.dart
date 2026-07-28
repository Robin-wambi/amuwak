import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import 'supabase_mappers.dart';

/// Read-side repository for the append-only `order_status_events` table —
/// ONLINE-ONLY mode. Streams the status history live from Supabase. Mutations
/// are written server-side / via the orders write path; intentionally no
/// `update`/`delete`/`append` method exists here. The offline (local Drift)
/// implementation is preserved in the commented block at the bottom.
class StatusEventsRepository {
  StatusEventsRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Status history for [orderId], ordered chronologically by `changed_at`.
  Stream<List<OrderStatusEvent>> watchByOrder(String orderId) {
    return _supabase
        .from('order_status_events')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('changed_at')
        .map((rows) =>
            rows.map(orderStatusEventFromSupabase).toList(growable: false));
  }
}

/* ============================================================================
 * OFFLINE (local Drift reads) — PRESERVED FOR RE-ENABLE
 * ----------------------------------------------------------------------------
 * import 'package:drift/drift.dart';
 * import '../data/app_database.dart';
 *
 * class StatusEventsRepository {
 *   StatusEventsRepository(this._db);
 *   final AppDatabase _db;
 *
 *   Stream<List<OrderStatusEvent>> watchByOrder(String orderId) {
 *     return (_db.select(_db.orderStatusEvents)
 *           ..where((t) => t.orderId.equals(orderId))
 *           ..orderBy([(t) => OrderingTerm(expression: t.changedAt)])).watch();
 *   }
 * }
 * ========================================================================== */
