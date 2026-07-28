import 'package:drift/drift.dart';

import '../data/app_database.dart' as drift;
import '../orders/proof_event.dart';
import 'outbox_repository.dart';

/// Read/write repository for proof events — OFFLINE-FIRST mode.
///
/// Reads stream from the local Drift `proof_events` table; [insertEvent] writes
/// locally (idempotent on the event id via `insertOrIgnore`, so a capture-screen
/// retry with the same id is a no-op) and enqueues an outbox `insert` for the
/// SyncOrchestrator to dispatch to Supabase.
class ProofEventsRepository {
  ProofEventsRepository(
    this._db, {
    OutboxRepository? outbox,
    DateTime Function()? clock,
  })  : _outbox = outbox,
        _clock = clock ?? DateTime.now;

  final drift.AppDatabase _db;
  final OutboxRepository? _outbox;
  final DateTime Function() _clock;

  OutboxRepository _requireOutbox() {
    final o = _outbox;
    if (o == null) {
      throw StateError('ProofEventsRepository was constructed without an '
          'OutboxRepository; insertEvent is unavailable.');
    }
    return o;
  }

  // ----- READ -----

  /// Non-deleted proof events for [orderId], ordered by `captured_at`.
  Stream<List<drift.ProofEvent>> watchByOrder(String orderId) {
    return (_db.select(_db.proofEvents)
          ..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.capturedAt)]))
        .watch();
  }

  // ----- WRITE -----

  /// Inserts a proof event locally and enqueues its outbox row. Idempotent on
  /// the event id: a retry with the same id is a local no-op and a dedup no-op
  /// on the outbox.
  Future<void> insertEvent(
    ProofEvent event, {
    required String orderId,
    required String actorStaffId,
  }) async {
    final outbox = _requireOutbox();
    final now = _clock();
    await _db.transaction(() async {
      await _db.into(_db.proofEvents).insert(
            drift.ProofEventsCompanion.insert(
              id: event.id,
              orderId: orderId,
              type: event.type.name,
              capturedAt: event.capturedAt,
              itemCount: event.count,
              notes: Value(event.notes),
              capturedBy: actorStaffId,
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'proof_events', op: 'insert', rowId: event.id),
        forTable: 'proof_events',
        op: 'insert',
        rowId: event.id,
        payload: <String, dynamic>{
          'id': event.id,
          'order_id': orderId,
          'type': event.type.name,
          'captured_at': event.capturedAt.toUtc().toIso8601String(),
          'item_count': event.count,
          'notes': event.notes,
          'captured_by': actorStaffId,
          'created_at': now.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
        },
      );
    });
  }
}
