import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customer_database.dart';
import 'outbox_worker.dart';

/// The app's single local Drift database (cart source of truth + outbox).
final customerDatabaseProvider = Provider<CustomerDatabase>((ref) {
  final db = CustomerDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Whether the device has a network interface up. Per `connectivity_plus` this
/// is interface state, NOT reachability — a write may still time out and get
/// re-queued by the outbox. Emits the current state immediately, then updates.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool up(List<ConnectivityResult> rs) =>
      rs.any((r) => r != ConnectivityResult.none);
  yield up(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(up);
});

/// Count of writes still queued in the outbox (drives the sync banner).
final pendingSyncCountProvider = StreamProvider<int>(
  (ref) => ref.watch(customerDatabaseProvider).watchPendingCount(),
);

/// The outbox worker. Feature layers (cart checkout, photo upload) register
/// their handlers on it; the [outboxDriverProvider] pumps it.
final outboxWorkerProvider = Provider<OutboxWorker>(
  (ref) => OutboxWorker(ref.watch(customerDatabaseProvider)),
);

/// Keeps the outbox draining: on every offline→online transition, attempt the
/// queue. Kept alive by a `ref.watch` in the app shell. Also drain once on
/// startup so a queue left from a previous session flushes.
final outboxDriverProvider = Provider<void>((ref) {
  final worker = ref.watch(outboxWorkerProvider);
  ref.listen<AsyncValue<bool>>(onlineProvider, (prev, next) {
    if (next.valueOrNull == true) worker.drain();
  });
  // Startup flush (best-effort; no-op if offline / nothing queued).
  Future.microtask(worker.drain);
});
