import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'outbox_repository.dart';
import 'sync_failure_policy.dart';

/// Function called for each row drained from the outbox. Implementations
/// throw to signal failure; the worker will catch and call repo.markFailed.
typedef OutboxDispatch = Future<void> Function(
  String forTable,
  String op,
  String rowId,
  Map<String, dynamic> payload,
);

class OutboxWorker {
  OutboxWorker({
    required this.repo,
    required this.dispatch,
    this.serverReachable = _assumeUnreachable,
    this.batchSize = 25,
    this.deadLetterAfter = 5,
  });

  final OutboxRepository repo;
  final OutboxDispatch dispatch;

  /// Reports whether the Supabase server is currently *reachable* — and this
  /// must be sourced from a CONFIRMED server round-trip (a successful
  /// [SyncPuller.pullAll]), NOT from `connectivity_plus`. That distinction is
  /// the whole point: an attached Wi-Fi/cellular interface reports "online"
  /// long before (or without ever) the server being reachable, so trusting it
  /// would dead-letter a rider's good write on a poor network — the very bug
  /// this class was fixed for.
  ///
  /// It disambiguates the two ways a transient transport error can arise:
  ///   - server unreachable (a pull would also be failing) → device-wide blip,
  ///     retry the row forever, never penalise it;
  ///   - server reachable (a pull just succeeded) yet THIS row still times out
  ///     → the failure is row-specific (e.g. an RPC that hangs on this
  ///     payload), so count it toward the dead-letter budget where it can no
  ///     longer head-of-line block the queue.
  ///
  /// Defaults to [_assumeUnreachable] (`() => false`) — the fail-safe: with no
  /// wired signal we never turn a transient failure into a dead-letter.
  final bool Function() serverReachable;

  static bool _assumeUnreachable() => false;

  final int batchSize;

  /// After this many failed attempts the row is parked in `dead_letter`
  /// status so it stops blocking later mutations. A separate UI / admin
  /// flow surfaces dead-lettered rows for manual review.
  final int deadLetterAfter;

  Timer? _timer;

  /// Tracks the currently-running drainOnce so [stop] can await it AND so a
  /// concurrent [drainOnce] (next timer tick fires while the previous drain
  /// is still dispatching) skips re-entry. Without the latter, two drains
  /// would `peekPending` the same rows and the dual `markFailed` writes
  /// (read-then-write on `attempts`) would double-increment the retry
  /// counter, dead-lettering rows after `deadLetterAfter / 2` real failures.
  Future<void>? _inFlightDrain;

  /// Default dispatcher backed by the real Supabase client.
  ///
  /// The `rpc` op calls a Postgres function ([forTable] is the function name,
  /// [payload] the params) instead of a table write — used for `create_pickup`,
  /// which a rider cannot do as a direct `orders`/`customers` insert under RLS.
  /// The RPC is idempotent server-side and the real minted `order_code` is
  /// reconciled onto the local placeholder row by the puller (it pulls the now-
  /// synced server row), so the dispatcher does not need the RPC's return value.
  static OutboxDispatch supabaseDispatcher(SupabaseClient client) {
    return (forTable, op, rowId, payload) async {
      switch (op) {
        case 'insert':
          await client.from(forTable).insert(payload);
          break;
        case 'update':
          await client.from(forTable).update(payload).eq('id', rowId);
          break;
        case 'delete':
          await client.from(forTable).delete().eq('id', rowId);
          break;
        case 'rpc':
          // For rpc ops [forTable] holds the Postgres function name (e.g.
          // 'create_pickup'), not a table, and [payload] is the params map.
          await client.rpc(forTable, params: payload);
          break;
        default:
          throw StateError('OutboxWorker: unknown op "$op"');
      }
    };
  }

  /// Revives every dead-lettered row so the next drain retries it, returning
  /// how many were revived. The orchestrator calls this on sign-in and on
  /// reconnect — with no manual retry UI, this is the only recovery path for a
  /// parked write. The running drain timer picks the revived rows up on its
  /// next tick.
  Future<int> recoverDeadLettered() => repo.requeueAllDeadLettered();

  /// Pump one batch of pending mutations. Returns the count successfully sent.
  /// Stops on the first failure to avoid hammering a flaky backend.
  Future<int> drainOnce() {
    if (_inFlightDrain != null) return Future.value(0);
    final work = _drainOnce();
    _inFlightDrain = work.then(
      (_) => _inFlightDrain = null,
      onError: (Object _) => _inFlightDrain = null,
    );
    return work;
  }

  Future<int> _drainOnce() async {
    final batch = await repo.peekPending(limit: batchSize);
    var sent = 0;
    for (final row in batch) {
      try {
        final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        await dispatch(row.forTable, row.op, row.rowId, payload);
        await repo.markSent(row.id);
        sent++;
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          // Unique-violation: the row is already on the server. This happens
          // when a prior attempt's INSERT succeeded but the client never got
          // the ack (network dropped after the write). Treat it as success so
          // we don't burn the dead-letter budget and surface a false sync
          // error for data that was actually saved.
          await repo.markSent(row.id);
          sent++;
          continue;
        }
        await repo.markFailed(row.id, '${e.code ?? ''}: ${e.message}',
            deadLetterAfter: deadLetterAfter);
        return sent;
      } catch (e) {
        if (isTransientSyncError(e) && !serverReachable()) {
          // Transport-layer failure (timeout, dropped socket, DNS) AND no
          // confirmed server contact: a device-wide blip, not this row's fault.
          // Leave it pending and stop this drain; the next cycle retries
          // WITHOUT burning the dead-letter budget. This is what keeps a
          // poor-network rider's good write from being permanently parked.
          return sent;
        }
        // Either a permanent, row-specific error (e.g. a StateError from an
        // unknown op), OR a transient failure while the server is confirmed
        // reachable (a pull just succeeded) — which makes the failure
        // row-specific (e.g. an RPC that hangs on this payload). Count it
        // toward the dead-letter budget so one persistently-failing head row
        // can't head-of-line block the rest of the queue; auto-requeue on the
        // next reconnect gives it fresh attempts.
        await repo.markFailed(row.id, e.toString(),
            deadLetterAfter: deadLetterAfter);
        return sent;
      }
    }
    return sent;
  }

  /// Start a periodic drain (default 5s). Cancel with `stop()`.
  void start({Duration interval = const Duration(seconds: 5)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => drainOnce());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final inflight = _inFlightDrain;
    if (inflight != null) await inflight;
  }
}
