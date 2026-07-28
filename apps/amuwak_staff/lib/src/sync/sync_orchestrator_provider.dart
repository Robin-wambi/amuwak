import 'dart:developer' as developer;

import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connectivity_watcher.dart';
import 'outbox_repository.dart';
import 'outbox_worker.dart';
import 'repository_providers.dart';
import 'sync_orchestrator.dart';
import 'sync_puller.dart';
import 'sync_status.dart';
import 'valid_transitions_loader.dart';

/// Builds the singleton [SyncOrchestrator] that owns the sync engine for
/// the current Supabase session. Constructs every primitive (outbox
/// repository, worker, puller, connectivity watcher, transitions loader)
/// inline so tests can override this provider with a mock orchestrator
/// without having to override every dependency too.
final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = Supabase.instance.client;
  return SyncOrchestrator(
    worker: OutboxWorker(
      repo: OutboxRepository(db),
      dispatch: OutboxWorker.supabaseDispatcher(supabase),
      // Sourced from confirmed pull round-trips (see serverReachableProvider),
      // NOT connectivity_plus — so a poor-network interface-up device never
      // dead-letters a good write, while a server that hangs on one payload
      // still parks that row instead of blocking the queue.
      serverReachable: () => ref.read(serverReachableProvider),
    ),
    puller: SyncPuller(
      db: db,
      fetch: SyncPuller.supabaseFetcher(supabase),
      deadLetter: ref.watch(pullDeadLetterRepositoryProvider),
    ),
    watcher: ConnectivityWatcher(),
    transitions: ValidTransitionsLoader(
      db: db,
      fetch: SyncPuller.supabaseFetcher(supabase),
    ),
    setOnline: (online) =>
        ref.read(onlineProvider.notifier).state = online,
    setReachable: (reachable) =>
        ref.read(serverReachableProvider.notifier).state = reachable,
  );
});

/// Side-effecting provider that watches [authStateProvider] and toggles
/// the orchestrator's start/stop based on whether there's a live
/// Supabase session. Must be eagerly `ref.watch`ed somewhere in the
/// widget tree (Task 16 mounts it from `main.dart`) for the lifecycle
/// to fire at all.
///
/// Edge semantics — only the session !=null → session ==null transition
/// (and the reverse) triggers a side effect. Repeated emissions of the
/// same signed-in / signed-out state are no-ops.
final syncLifecycleProvider = Provider<void>((ref) {
  final orchestrator = ref.read(syncOrchestratorProvider);
  bool? lastSignedIn;

  // Single in-flight Future chain — every start()/stop() awaits the previous
  // one. Without this, a rapid auth flap (signed-in → signed-out before
  // start() completes) would let stop() tear down state concurrently with
  // an in-progress _kickoffPull, which could write rows to an
  // already-truncated DB. Errors are logged but never poison the chain.
  Future<void> chain = Future.value();
  void enqueue(String label, Future<void> Function() action) {
    chain = chain
        .then((_) => action())
        .catchError((Object e, StackTrace st) {
      developer.log(label,
          name: 'syncLifecycle', error: e, stackTrace: st);
    });
  }

  ref.listen<AsyncValue<AuthState>>(
    authStateProvider,
    (prev, next) {
      final signedIn = next.valueOrNull?.session != null;
      if (lastSignedIn == signedIn) return;
      final wasSignedIn = lastSignedIn;
      lastSignedIn = signedIn;
      if (signedIn) {
        enqueue('orchestrator.start failed', orchestrator.start);
      } else if (wasSignedIn == true) {
        // First-ever emission of signed-out is the initial state; there
        // is nothing to stop yet. Only react to a real signed-in →
        // signed-out transition.
        enqueue('orchestrator.stop failed', orchestrator.stop);
      }
    },
  );

  ref.onDispose(() {
    enqueue('dispose-time orchestrator.stop failed', orchestrator.stop);
  });
});
