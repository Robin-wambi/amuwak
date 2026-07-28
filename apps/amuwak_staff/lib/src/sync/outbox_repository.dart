import 'dart:convert';
import 'package:drift/drift.dart';
import '../data/app_database.dart';

/// Wraps the local `outbox` Drift table. Callers enqueue pending mutations;
/// the OutboxWorker drains them via Supabase.
///
/// The Drift column for the target table name is `forTable` (rather than
/// `tableName`) because Drift's Table base class already exposes a
/// `tableName` getter. We carry that naming through this repository too.
class OutboxRepository {
  OutboxRepository(this._db);
  final AppDatabase _db;

  /// Builds a deterministic outbox key. Callers that may retry the same
  /// logical mutation (e.g. capture screens after a network blip) MUST pass
  /// the SAME key on retry — the outbox's [InsertMode.insertOrIgnore] then
  /// makes the second enqueue a SQL-level no-op.
  ///
  /// Format: `forTable:op:rowId[:extra]`. `extra` is typically the row's
  /// `updated_at` ISO string so that genuinely-distinct mutations to the
  /// same row (e.g. two successive status changes) get distinct keys.
  static String dedupKeyFor({
    required String forTable,
    required String op,
    required String rowId,
    String? extra,
  }) {
    return extra == null
        ? '$forTable:$op:$rowId'
        : '$forTable:$op:$rowId:$extra';
  }

  /// Enqueues a pending mutation, keyed by [id].
  ///
  /// Uses [InsertMode.insertOrIgnore] **intentionally**: callers MAY pass the
  /// same [id] across retries (e.g. capture screens that cache a mutation id
  /// in widget state so a partial-failure retry doesn't double-enqueue). On
  /// a duplicate id the insert silently no-ops at the SQL layer — the
  /// already-queued row remains intact with its earlier payload.
  ///
  /// Implication: callers MUST NOT mutate the payload between retries and
  /// then expect the new payload to land — only the first enqueue wins. If
  /// you need a different payload, use a different [id].
  Future<void> enqueue({
    required String id,
    required String forTable,
    required String op,                // 'insert' | 'update' | 'delete'
    required String rowId,
    required Map<String, dynamic> payload,
  }) {
    return _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            id: id,
            forTable: forTable,
            op: op,
            rowId: rowId,
            payloadJson: jsonEncode(payload),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<List<OutboxData>> peekPending({required int limit}) {
    final query = _db.select(_db.outbox)
      ..where((t) => t.status.isIn(<String>['pending', 'failed']))
      // Drain in strict enqueue order. `created_at` alone is NOT enough: it is
      // second-granularity (Drift's `currentDateAndTime`), so two mutations
      // enqueued in the same second share a timestamp and would drain in an
      // undefined order. That matters because a `create_pickup` RPC and a
      // follow-up `orders:update` for the SAME order can tie — dispatch the
      // update first and it hits 0 server rows (a silent no-op that "succeeds"
      // and is deleted), losing the change. SQLite's implicit `rowid` is a
      // monotonic insertion counter, so ordering by it guarantees the create
      // drains before any later write to the same row. (`rowid`, spelled
      // without an underscore, is the implicit rowid — distinct from this
      // table's `row_id` TEXT column, which holds the mutation's target id.)
      ..orderBy([(_) => OrderingTerm.asc(const CustomExpression<int>('rowid'))])
      ..limit(limit);
    return query.get();
  }

  Future<void> markSent(String id) {
    return (_db.delete(_db.outbox)..where((t) => t.id.equals(id))).go();
  }

  /// Live stream of rows currently parked in `dead_letter`, newest-first.
  /// Drives the dashboard's sync-errors badge and the SyncErrorsScreen.
  Stream<List<OutboxData>> watchDeadLettered() {
    return (_db.select(_db.outbox)
          ..where((t) => t.status.equals('dead_letter'))
          ..orderBy([(t) => OrderingTerm.desc(t.lastAttemptedAt)]))
        .watch();
  }

  /// Resets a dead-lettered row back to `'pending'` so the outbox worker
  /// picks it up on its next drain.  Retry counter and last-error text are
  /// cleared so the user-visible counter starts fresh.
  ///
  /// Guarded to `dead_letter` status (mirroring [discard]) so a stale id can
  /// never reset the retry counter on a still-`pending`/`failed` row out from
  /// under an in-flight drain.
  Future<void> requeue(String id) {
    return (_db.update(_db.outbox)
          ..where((t) => t.id.equals(id) & t.status.equals('dead_letter')))
        .write(
      const OutboxCompanion(
        status: Value('pending'),
        retryCount: Value(0),
        lastError: Value(null),
        lastAttemptedAt: Value(null),
      ),
    );
  }

  /// Requeues EVERY dead-lettered row back to `'pending'` (retry counter and
  /// last-error cleared), returning how many rows were revived.
  ///
  /// This app ships no manual retry UI, so a dead-lettered write would
  /// otherwise be stranded forever. The SyncOrchestrator calls this on sign-in
  /// and on every reconnect so a parked mutation gets fresh drain attempts
  /// automatically. Now that transport errors never dead-letter (they retry in
  /// place), a revived row is either a legacy transient failure — which now
  /// succeeds — or a genuine permanent rejection, which simply re-parks after
  /// its budget: bounded per reconnect, never an infinite tight loop.
  ///
  /// Guarded to `dead_letter` status (like [requeue]) so it can never reset the
  /// retry counter on a still-`pending`/`failed` row out from under an
  /// in-flight drain.
  Future<int> requeueAllDeadLettered() {
    return (_db.update(_db.outbox)
          ..where((t) => t.status.equals('dead_letter')))
        .write(
      const OutboxCompanion(
        status: Value('pending'),
        retryCount: Value(0),
        lastError: Value(null),
        lastAttemptedAt: Value(null),
      ),
    );
  }

  /// Permanently drops a dead-lettered mutation the rider has chosen to give
  /// up on. Unlike [requeue], this does NOT retry — the local change is
  /// discarded for good. Intended only for `dead_letter` rows surfaced in the
  /// SyncErrorsScreen, where retrying a genuinely-poison row would loop
  /// forever.
  ///
  /// Guarded to `dead_letter` status so a stale id can never silently drop a
  /// still-`pending` row out from under the worker.
  Future<void> discard(String id) {
    return (_db.delete(_db.outbox)
          ..where((t) => t.id.equals(id) & t.status.equals('dead_letter')))
        .go();
  }

  /// Record a failed dispatch attempt for [id]. Bumps `retry_count` and stores
  /// [error]. Once `retry_count > deadLetterAfter`, the row is flipped to
  /// `dead_letter` status, which excludes it from [peekPending] so a single
  /// permanently-failing row cannot head-of-line block the rest of the
  /// queue. Recovery from dead_letter is a separate manual / UI flow.
  Future<void> markFailed(String id, String error,
      {int deadLetterAfter = 5}) {
    // The read (current retry_count) and the write (count + 1, new status) must
    // be atomic: a concurrent markFailed reading the same count would otherwise
    // clobber this one's increment and lose a retry. A transaction serializes
    // the pair so the invariant is enforced at the storage layer rather than
    // relying on the caller's drain-concurrency discipline.
    return _db.transaction(() async {
      final row =
          await (_db.select(_db.outbox)..where((t) => t.id.equals(id)))
              .getSingleOrNull();
      if (row == null) return;
      final nextRetry = row.retryCount + 1;
      final newStatus = nextRetry > deadLetterAfter ? 'dead_letter' : 'failed';
      await (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
        OutboxCompanion(
          retryCount: Value(nextRetry),
          lastError: Value(error),
          status: Value(newStatus),
          lastAttemptedAt: Value(DateTime.now()),
        ),
      );
    });
  }
}
