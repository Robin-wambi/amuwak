import '../data/customer_database.dart';

/// Handles one queued write. Throws on failure (which re-queues the row with
/// backoff). Registered per op-type by the feature that owns the write.
typedef OutboxHandler = Future<void> Function(String payload);

/// Drains the [Outbox]: when online, attempts each due row once, dispatching by
/// `opType` to a registered [OutboxHandler]. A failed attempt is re-queued with
/// exponential backoff — nothing is ever dead-lettered, so a transient network
/// error can never lose a placed order or a cart change (the lesson the staff
/// sync engine learned the hard way on poor networks).
class OutboxWorker {
  OutboxWorker(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final CustomerDatabase _db;
  final DateTime Function() _clock;
  final Map<String, OutboxHandler> _handlers = {};
  bool _draining = false;

  void register(String opType, OutboxHandler handler) =>
      _handlers[opType] = handler;

  /// Attempts every due row once. Re-entrant-safe: overlapping calls (e.g. an
  /// enqueue firing while a connectivity drain runs) collapse into one pass.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final due = await _db.dueOutbox(_clock());
      for (final row in due) {
        final handler = _handlers[row.opType];
        if (handler == null) continue; // op from a not-yet-wired feature
        try {
          await handler(row.payload);
          await _db.markDone(row.id);
        } catch (e) {
          final attempts = row.attempts + 1;
          await _db.recordFailure(
            id: row.id,
            attempts: attempts,
            error: e.toString(),
            nextAttemptAt: _clock().add(_backoff(attempts)),
          );
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// 5s, 10s, 20s … capped at ~5min, so a flapping connection retries quickly
  /// at first and then backs off.
  Duration _backoff(int attempts) {
    final capped = attempts.clamp(1, 6);
    return Duration(seconds: 5 * (1 << (capped - 1)));
  }
}
