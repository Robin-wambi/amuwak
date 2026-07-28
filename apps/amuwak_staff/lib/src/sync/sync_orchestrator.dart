import 'dart:async';

import 'connectivity_watcher.dart';
import 'outbox_worker.dart';
import 'sync_puller.dart';
import 'valid_transitions_loader.dart';

/// Owns the runtime lifecycle of the sync engine: starts/stops the outbox
/// worker timer, runs a periodic puller, drives the online/offline state
/// callback from connectivity edges, and triggers an extra pullAll on every
/// offline→online transition.
///
/// **Design note — Ref vs callback.** The Plan 3a plan suggests passing
/// Riverpod's [Ref] in here so the orchestrator can flip
/// `onlineProvider.notifier.state`. I deliberately kept this class
/// pure-Dart and accept a `setOnline(bool)` callback instead — the wiring
/// code in Task 12 supplies
/// `(b) => ref.read(onlineProvider.notifier).state = b`. Same effect,
/// trivially testable without spinning up a ProviderContainer.
class SyncOrchestrator {
  SyncOrchestrator({
    required this.worker,
    required this.puller,
    required this.watcher,
    required this.transitions,
    required this.setOnline,
    required this.setReachable,
    this.workerInterval = const Duration(seconds: 5),
    this.pullerInterval = const Duration(seconds: 15),
    this.recoverSweepInterval = const Duration(minutes: 5),
  });

  final OutboxWorker worker;
  final SyncPuller puller;
  final ConnectivityWatcher watcher;
  final ValidTransitionsLoader transitions;
  final void Function(bool isOnline) setOnline;

  /// Publishes whether the server is *reachable*, derived from whether the last
  /// [SyncPuller.pullAll] actually completed (a confirmed round-trip) rather
  /// than from `connectivity_plus` interface state. The OutboxWorker consumes
  /// this to decide whether a transient failure is a device-wide blip (retry
  /// forever) or a row-specific hang (dead-letter). Kept distinct from
  /// [setOnline] precisely so interface-presence can never drive that decision.
  final void Function(bool reachable) setReachable;
  final Duration workerInterval;
  final Duration pullerInterval;

  /// How often to re-requeue dead-lettered rows while the server is reachable.
  /// Edge-triggered recovery ([_reportReachable]) only fires on the
  /// unreachable→reachable transition, so it misses a row dead-lettered while
  /// the server stayed reachable throughout (e.g. an asymmetric connection
  /// where reads succeed but this write keeps timing out). This low-frequency
  /// sweep gives such a row periodic fresh attempts so it self-heals without
  /// waiting for a disconnect/reconnect cycle or an app restart.
  final Duration recoverSweepInterval;

  bool _started = false;
  Timer? _pullTimer;
  Timer? _recoverTimer;

  /// Last reachability we published, so [_reportReachable] can fire the
  /// unreachable→reachable recovery exactly on the edge (a pull succeeding
  /// after failures) instead of on every successful pull.
  bool _reachable = false;

  /// Tracks the currently-running pullAll (immediate, periodic, or
  /// connectivity-triggered) so [stop] can wait for it to settle before
  /// returning AND so a concurrent [_kickoffPull] (next timer tick fires
  /// while the previous pull is still in flight) skips re-entry. Without
  /// the latter the orphaned earlier pull is no longer tracked, and
  /// [stop] only awaits the most recent one — letting the orphan race
  /// with `_truncateAllTables` on sign-out (Task 15).
  Future<void>? _inFlightPull;

  /// Tracks the currently-running [OutboxWorker.recoverDeadLettered] write so
  /// [stop] can await it before `signOutAndReset` truncates the outbox — the
  /// same orphan-vs-truncate race [_inFlightPull] guards. A concurrent
  /// [_kickoffRecover] (start() plus a near-simultaneous reconnect edge) skips
  /// re-entry rather than orphaning the earlier write.
  Future<void>? _inFlightRecover;

  Future<void> start() async {
    if (_started) return;

    worker.start(interval: workerInterval);
    watcher.start(
      onOnline: _handleOnline,
      onOffline: _handleOffline,
    );

    try {
      final initiallyOnline = await watcher.isOnline();
      setOnline(initiallyOnline);

      await transitions.loadOnce();
    } catch (_) {
      // Tear down the worker + watcher we just armed so a retry (the next
      // `signedIn` re-emission from auth, typically once the network comes
      // back) starts from a clean slate. Without this, _started would
      // remain false but the worker timer and connectivity stream would
      // keep running and the periodic pull timer would never be created.
      await worker.stop();
      watcher.dispose();
      rethrow;
    }

    _started = true;
    // Kick the first pull. When it completes it publishes reachability, and the
    // unreachable→reachable edge (see [_reportReachable]) is what revives any
    // write parked in dead_letter — the app has no manual retry UI, and there
    // is no point requeueing until a round-trip proves the server is back.
    _kickoffPull();
    _pullTimer = Timer.periodic(pullerInterval, (_) => _kickoffPull());
    _recoverTimer = Timer.periodic(recoverSweepInterval, (_) {
      // Only sweep while the server is reachable: requeueing a row when the
      // server is unreachable just churns it back to pending where it skips
      // anyway. When reachable, this revives any write parked without a
      // reachability edge (the asymmetric reads-ok/writes-fail case).
      if (_reachable) _kickoffRecover();
    });
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;

    _pullTimer?.cancel();
    _pullTimer = null;
    _recoverTimer?.cancel();
    _recoverTimer = null;
    await worker.stop();
    watcher.dispose();

    final inflightPull = _inFlightPull;
    if (inflightPull != null) await inflightPull;
    final inflightRecover = _inFlightRecover;
    if (inflightRecover != null) await inflightRecover;
  }

  /// Manual refresh — pull every registered table now. Used by a "swipe
  /// to refresh" affordance (Plan 3b) and by integration tests. If a
  /// pull is already in flight (periodic or connectivity-triggered)
  /// this coalesces onto it rather than starting a second concurrent
  /// pull — keeping the single-pull invariant that [stop] relies on.
  Future<void> syncNow() async {
    _kickoffPull();
    final inflight = _inFlightPull;
    if (inflight != null) await inflight;
  }

  void _handleOnline() {
    setOnline(true);
    // Interface came back. Kick a pull to confirm the server is actually
    // reachable; its success edge (see [_reportReachable]) is what revives any
    // parked write — we don't trust interface presence alone.
    _kickoffPull();
  }

  void _handleOffline() {
    setOnline(false);
    // Interface down ⇒ definitively unreachable. Publish it immediately rather
    // than waiting for the next pull to fail, so the worker stops penalising
    // transient write failures right away.
    _reportReachable(false);
  }

  /// Publishes a reachability change and, on the unreachable→reachable edge,
  /// revives any write parked in dead_letter while the server was down. That
  /// edge is the recovery trigger for the case a connectivity edge can't cover:
  /// the interface stayed up the whole time and only the server was
  /// unreachable, so [_handleOnline] never fired.
  void _reportReachable(bool reachable) {
    final was = _reachable;
    _reachable = reachable;
    setReachable(reachable);
    if (reachable && !was) _kickoffRecover();
  }

  void _kickoffRecover() {
    if (_inFlightRecover != null) return;
    final f = worker.recoverDeadLettered();
    // Mirror [_kickoffPull]: track the write so [stop] can await it, and
    // swallow any error here so a failed requeue can't escape as an unhandled
    // async exception (the drain timer retries the underlying work anyway).
    _inFlightRecover = f.then(
      (_) => _inFlightRecover = null,
      onError: (Object _) => _inFlightRecover = null,
    );
  }

  void _kickoffPull() {
    if (_inFlightPull != null) return;
    final f = puller.pullAll();
    _inFlightPull = f.then(
      (_) {
        _inFlightPull = null;
        // A completed pull is a confirmed server round-trip — the server is
        // reachable, so the worker may now treat a still-timing-out write as
        // row-specific.
        _reportReachable(true);
      },
      onError: (Object _) {
        _inFlightPull = null;
        // pullAll threw (fetch failed) — the server is unreachable, so the
        // worker must keep retrying transient write failures without penalty.
        _reportReachable(false);
      },
    );
  }
}
