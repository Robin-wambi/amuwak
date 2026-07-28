import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/outbox_repository.dart';
import 'package:amuwak_staff/src/sync/outbox_worker.dart';

class _DispatchRecorder {
  final List<List<dynamic>> calls = [];
  Object? throwThis;
  Completer<void>? blockOn;

  Future<void> dispatch(
    String forTable,
    String op,
    String rowId,
    Map<String, dynamic> payload,
  ) async {
    calls.add([forTable, op, rowId, payload]);
    if (blockOn != null) await blockOn!.future;
    if (throwThis != null) throw throwThis!;
  }
}

void main() {
  late AppDatabase db;
  late OutboxRepository repo;
  late _DispatchRecorder recorder;
  late OutboxWorker worker;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = OutboxRepository(db);
    recorder = _DispatchRecorder();
    worker = OutboxWorker(
      repo: repo,
      dispatch: recorder.dispatch,
    );
  });

  tearDown(() async => db.close());

  test('drainOnce dispatches insert with the right (table, op, rowId, payload)',
      () async {
    await repo.enqueue(
      id: 'mut-1', forTable: 'orders', op: 'insert',
      rowId: 'order-1',
      payload: {'id': 'order-1', 'order_code': 'AMW-1'},
    );

    final drained = await worker.drainOnce();

    expect(drained, 1);
    expect(recorder.calls, hasLength(1));
    expect(recorder.calls.first, [
      'orders', 'insert', 'order-1',
      {'id': 'order-1', 'order_code': 'AMW-1'},
    ]);
    expect(await repo.peekPending(limit: 10), isEmpty,
        reason: 'successful row should be removed by markSent');
  });

  test('on PostgrestException, drainOnce marks failed and stops processing later rows',
      () async {
    // 23503 (FK violation) is a genuine server rejection — distinct from the
    // 23505 duplicate-key case which is treated as success (see below).
    recorder.throwThis = const PostgrestException(
        message: 'foreign key violation', code: '23503');

    await repo.enqueue(id: 'm1', forTable: 'orders', op: 'insert',
                       rowId: 'r1', payload: const {});
    await repo.enqueue(id: 'm2', forTable: 'orders', op: 'insert',
                       rowId: 'r2', payload: const {});

    final drained = await worker.drainOnce();

    expect(drained, 0);
    final pending = await repo.peekPending(limit: 10);
    expect(pending, hasLength(2));
    expect(pending.first.lastError, contains('23503'));
    expect(pending.first.lastError, contains('foreign key violation'));
    expect(pending.first.status, 'failed');
    expect(recorder.calls, hasLength(1),
        reason: 'second row should not be dispatched after first fails');
  });

  test('23505 duplicate-key is treated as success (already on server)',
      () async {
    // INSERT succeeded server-side but the ack was lost; the retry hits a
    // unique violation. The row IS saved, so mark it sent rather than
    // dead-lettering it and surfacing a false sync error.
    recorder.throwThis =
        const PostgrestException(message: 'duplicate key', code: '23505');

    await repo.enqueue(id: 'm1', forTable: 'orders', op: 'insert',
                       rowId: 'r1', payload: const {});
    await repo.enqueue(id: 'm2', forTable: 'orders', op: 'insert',
                       rowId: 'r2', payload: const {});

    final drained = await worker.drainOnce();

    expect(drained, 2, reason: 'both already-present rows count as sent');
    expect(await repo.peekPending(limit: 10), isEmpty,
        reason: '23505 rows are removed via markSent, not left failed');
    expect(await repo.watchDeadLettered().first, isEmpty);
    expect(recorder.calls, hasLength(2),
        reason: 'drain continues past a 23505 instead of stopping');
  });

  test('stop() awaits an in-flight drainOnce before returning', () async {
    // Block dispatch in flight so drainOnce can't complete on its own.
    final blocker = Completer<void>();
    recorder.blockOn = blocker;

    await repo.enqueue(
      id: 'm1', forTable: 'orders', op: 'insert',
      rowId: 'r1', payload: const {},
    );

    final draining = worker.drainOnce();
    // Let drainOnce reach the awaited dispatch.
    await Future<void>.delayed(Duration.zero);
    expect(recorder.calls, hasLength(1),
        reason: 'dispatch should have started');

    var stopDone = false;
    final stopFuture = worker.stop().whenComplete(() => stopDone = true);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(stopDone, isFalse,
        reason: 'stop should be waiting on the in-flight drain');

    // Release; both drain and stop should now finish.
    blocker.complete();
    await draining;
    await stopFuture;
    expect(stopDone, isTrue);
  });

  test('stop() is safe to call when no drain is in flight', () async {
    await expectLater(worker.stop(), completes);
  });

  test(
      'drainOnce is re-entrancy guarded: a concurrent call is a no-op and '
      'does not re-dispatch', () async {
    final blocker = Completer<void>();
    recorder.blockOn = blocker;

    await repo.enqueue(
      id: 'm1', forTable: 'orders', op: 'insert',
      rowId: 'r1', payload: const {},
    );

    // First call starts and blocks in dispatch.
    final first = worker.drainOnce();
    await Future<void>.delayed(Duration.zero);
    expect(recorder.calls, hasLength(1),
        reason: 'first drain should have dispatched one row');

    // Second call while first is in flight must be a no-op.
    final second = await worker.drainOnce();
    expect(second, 0,
        reason: 'concurrent drain should report nothing sent');
    expect(recorder.calls, hasLength(1),
        reason: 'concurrent drain must NOT trigger another dispatch');

    // Release; first completes normally.
    blocker.complete();
    expect(await first, 1);

    // After completion the guard clears: a fresh drain works normally.
    recorder.blockOn = null;
    await repo.enqueue(
      id: 'm2', forTable: 'orders', op: 'insert',
      rowId: 'r2', payload: const {},
    );
    expect(await worker.drainOnce(), 1);
    expect(recorder.calls, hasLength(2));
  });

  test(
      'transient (offline) errors do NOT dead-letter: row stays pending with '
      'retryCount 0 no matter how many drains run', () async {
    recorder.throwThis = SocketException('failed host lookup');

    await repo.enqueue(
      id: 'm1', forTable: 'orders', op: 'insert',
      rowId: 'r1', payload: const {},
    );

    // Far more drains than deadLetterAfter (5) — a real offline spell.
    for (var i = 0; i < 10; i++) {
      expect(await worker.drainOnce(), 0);
    }

    final pending = await repo.peekPending(limit: 10);
    expect(pending, hasLength(1),
        reason: 'the row must remain queued, not dead-lettered');
    expect(pending.first.status, 'pending',
        reason: 'offline blips must not flip status to failed/dead_letter');
    expect(pending.first.retryCount, 0,
        reason: 'transient errors must not burn the retry budget');
    expect(await repo.watchDeadLettered().first, isEmpty);
  });

  test('permanent (non-Postgrest) errors still dead-letter after the budget',
      () async {
    recorder.throwThis = StateError('OutboxWorker: unknown op "frobnicate"');

    await repo.enqueue(
      id: 'm1', forTable: 'orders', op: 'insert',
      rowId: 'r1', payload: const {},
    );

    for (var i = 0; i < 6; i++) {
      await worker.drainOnce();
    }

    expect(await repo.peekPending(limit: 10), isEmpty,
        reason: 'dead-lettered rows are excluded from peekPending');
    expect(await repo.watchDeadLettered().first, hasLength(1));
  });

  test(
      'transport errors never dead-letter: a good write on a flaky network '
      'retries forever instead of being permanently parked', () async {
    // The reported bug. connectivity_plus reports "online" the moment a Wi-Fi/
    // cellular interface is attached — NOT when the server is actually
    // reachable. On a poor network the interface is up but every dispatch times
    // out. A transport failure (timeout/dropped socket/DNS) is device-wide, not
    // caused by this row's payload, so it must NEVER burn the dead-letter
    // budget — otherwise a rider's saved create_pickup is permanently parked
    // and its real order code never syncs, even after the network recovers.
    //
    // A genuinely row-specific rejection reaches the server and comes back as a
    // PostgrestException (or a logic StateError) — those still dead-letter (see
    // the tests above), so a real poison row can't head-of-line block the queue.
    recorder.throwThis = TimeoutException('deadline exceeded');

    await repo.enqueue(
      id: 'create_pickup:rpc:o1', forTable: 'create_pickup', op: 'rpc',
      rowId: 'o1', payload: const {},
    );

    // Far more drains than deadLetterAfter (5) — a sustained flaky-network spell.
    for (var i = 0; i < 10; i++) {
      expect(await worker.drainOnce(), 0);
    }

    final pending = await repo.peekPending(limit: 10);
    expect(pending, hasLength(1),
        reason: 'the row must remain queued, not dead-lettered');
    expect(pending.first.status, 'pending',
        reason: 'a flaky-network timeout must not flip status to dead_letter');
    expect(pending.first.retryCount, 0,
        reason: 'transport errors must not burn the retry budget');
    expect(await repo.watchDeadLettered().first, isEmpty);
  });

  test(
      'a transient error DOES dead-letter when the server is reachable, so a '
      'row that hangs the server cannot head-of-line block the queue', () async {
    // The remaining edge the reachability gate closes. A successful pull has
    // confirmed the server IS reachable, yet this create_pickup RPC keeps
    // timing out — the hang is specific to this row's payload, not the network.
    // It must dead-letter (bounded) so the healthy row queued behind it can
    // sync, rather than retrying forever and blocking the queue.
    final dispatched = <String>[];
    final worker = OutboxWorker(
      repo: repo,
      dispatch: (forTable, op, rowId, payload) async {
        dispatched.add(rowId);
        if (rowId == 'poison') throw TimeoutException('server hang');
      },
      serverReachable: () => true,
    );

    await repo.enqueue(
      id: 'poison', forTable: 'create_pickup', op: 'rpc',
      rowId: 'poison', payload: const {},
    );
    // Enqueued after ⇒ sits behind the poison head row in FIFO order.
    await repo.enqueue(
      id: 'healthy', forTable: 'orders', op: 'update',
      rowId: 'healthy', payload: const {},
    );

    // Budget is 5, so the 6th attempt dead-letters the poison head row.
    for (var i = 0; i < 6; i++) {
      await worker.drainOnce();
    }
    expect((await repo.watchDeadLettered().first).map((r) => r.id).toList(),
        ['poison'],
        reason: 'a row-specific transient hang must dead-letter when the '
            'server is confirmed reachable');

    // Head row gone from peekPending; the row behind it now syncs.
    await worker.drainOnce();
    expect(dispatched, contains('healthy'),
        reason: 'the row behind the poison head must sync once it is parked');
    expect(await repo.peekPending(limit: 10), isEmpty);
  });
}
