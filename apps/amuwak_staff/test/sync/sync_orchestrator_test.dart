import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/sync/connectivity_watcher.dart';
import 'package:amuwak_staff/src/sync/outbox_worker.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator.dart';
import 'package:amuwak_staff/src/sync/sync_puller.dart';
import 'package:amuwak_staff/src/sync/valid_transitions_loader.dart';

class _MockWorker extends Mock implements OutboxWorker {}

class _MockPuller extends Mock implements SyncPuller {}

class _MockWatcher extends Mock implements ConnectivityWatcher {}

class _MockTransitions extends Mock implements ValidTransitionsLoader {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late _MockWorker worker;
  late _MockPuller puller;
  late _MockWatcher watcher;
  late _MockTransitions transitions;
  late List<bool> onlineStates;
  late List<bool> reachableStates;
  late SyncOrchestrator orchestrator;
  late void Function()? capturedOnOnline;
  late void Function()? capturedOnOffline;

  setUp(() {
    worker = _MockWorker();
    puller = _MockPuller();
    watcher = _MockWatcher();
    transitions = _MockTransitions();
    onlineStates = [];
    reachableStates = [];
    capturedOnOnline = null;
    capturedOnOffline = null;

    when(() => worker.start(interval: any(named: 'interval'))).thenReturn(null);
    when(() => worker.stop()).thenAnswer((_) async {});
    when(() => worker.recoverDeadLettered()).thenAnswer((_) async => 0);
    when(() => puller.pullAll()).thenAnswer((_) async => 0);
    when(() => transitions.loadOnce()).thenAnswer((_) async {});
    when(() => watcher.isOnline()).thenAnswer((_) async => true);
    when(() => watcher.dispose()).thenReturn(null);
    when(() => watcher.start(
          onOnline: any(named: 'onOnline'),
          onOffline: any(named: 'onOffline'),
        )).thenAnswer((invocation) {
      capturedOnOnline =
          invocation.namedArguments[#onOnline] as void Function();
      capturedOnOffline =
          invocation.namedArguments[#onOffline] as void Function()?;
    });

    orchestrator = SyncOrchestrator(
      worker: worker,
      puller: puller,
      watcher: watcher,
      transitions: transitions,
      setOnline: (b) => onlineStates.add(b),
      setReachable: (b) => reachableStates.add(b),
      workerInterval: const Duration(milliseconds: 50),
      pullerInterval: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    await orchestrator.stop();
  });

  group('start()', () {
    test('starts the worker timer with the configured interval', () async {
      await orchestrator.start();
      verify(() => worker.start(interval: const Duration(milliseconds: 50)))
          .called(1);
    });

    test('loads valid_transitions exactly once on startup', () async {
      await orchestrator.start();
      verify(() => transitions.loadOnce()).called(1);
    });

    test('kicks off an immediate pullAll on startup', () async {
      await orchestrator.start();
      // Allow microtasks to drain.
      await Future<void>.delayed(Duration.zero);
      verify(() => puller.pullAll()).called(1);
    });

    test('recovers dead-lettered rows on startup (no manual retry UI)',
        () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      verify(() => worker.recoverDeadLettered()).called(1);
    });

    test('seeds the setOnline callback from watcher.isOnline()', () async {
      when(() => watcher.isOnline()).thenAnswer((_) async => true);
      await orchestrator.start();
      expect(onlineStates, contains(true));
    });

    test('registers connectivity callbacks via watcher.start()', () async {
      await orchestrator.start();
      verify(() => watcher.start(
            onOnline: any(named: 'onOnline'),
            onOffline: any(named: 'onOffline'),
          )).called(1);
      expect(capturedOnOnline, isNotNull);
      expect(capturedOnOffline, isNotNull);
    });

    test('an online edge triggers another pullAll and reports online=true',
        () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      // 1 immediate pullAll from startup.
      verify(() => puller.pullAll()).called(1);

      capturedOnOnline!();
      await Future<void>.delayed(Duration.zero);

      verify(() => puller.pullAll()).called(1);
      expect(onlineStates.last, isTrue);
    });

    test('a completed pull publishes reachable=true', () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      expect(reachableStates.last, isTrue);
    });

    test('a failed pull publishes reachable=false', () async {
      when(() => puller.pullAll())
          .thenAnswer((_) async => throw Exception('server unreachable'));
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      expect(reachableStates.last, isFalse);
    });

    test('the offline edge publishes reachable=false', () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      capturedOnOffline!();
      expect(reachableStates.last, isFalse);
    });

    test(
        'recovers dead-lettered rows on the unreachable→reachable edge, even '
        'with no connectivity edge (interface stayed up)', () async {
      // First pull FAILS (server unreachable behind an up interface) → nothing
      // recovered. A later pull SUCCEEDS → the reachability edge revives parked
      // writes exactly once. This is the recovery path a connectivity edge
      // can't provide when the interface never dropped.
      var pulls = 0;
      when(() => puller.pullAll()).thenAnswer((_) async {
        pulls++;
        if (pulls == 1) throw Exception('server unreachable');
        return 0;
      });

      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => worker.recoverDeadLettered());
      expect(reachableStates.last, isFalse);

      // A subsequent pull now reaches the server.
      await orchestrator.syncNow();
      await Future<void>.delayed(Duration.zero);

      verify(() => worker.recoverDeadLettered()).called(1);
      expect(reachableStates.last, isTrue);
    });

    test(
        'a periodic sweep keeps re-requeueing dead-lettered rows while the '
        'server stays reachable (no further edge)', () async {
      // The asymmetric case: reads keep succeeding (reachable stays true, so no
      // false→true edge) while a write stays dead-lettered. The sweep alone
      // must keep giving it fresh attempts so it self-heals without a
      // disconnect/reconnect cycle.
      final swept = SyncOrchestrator(
        worker: worker,
        puller: puller,
        watcher: watcher,
        transitions: transitions,
        setOnline: (b) => onlineStates.add(b),
        setReachable: (b) => reachableStates.add(b),
        workerInterval: const Duration(milliseconds: 50),
        // Keep periodic pulls out of the way so only the sweep drives recovery.
        pullerInterval: const Duration(seconds: 30),
        recoverSweepInterval: const Duration(milliseconds: 40),
      );
      addTearDown(swept.stop);

      await swept.start();
      // Startup pull succeeds → reachable=true and the edge fires one recover.
      await Future<void>.delayed(Duration.zero);
      clearInteractions(worker);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      verify(() => worker.recoverDeadLettered())
          .called(greaterThanOrEqualTo(2));
    });

    test('the periodic sweep does NOT requeue while the server is unreachable',
        () async {
      when(() => puller.pullAll())
          .thenAnswer((_) async => throw Exception('server unreachable'));
      final swept = SyncOrchestrator(
        worker: worker,
        puller: puller,
        watcher: watcher,
        transitions: transitions,
        setOnline: (b) => onlineStates.add(b),
        setReachable: (b) => reachableStates.add(b),
        workerInterval: const Duration(milliseconds: 50),
        pullerInterval: const Duration(seconds: 30),
        recoverSweepInterval: const Duration(milliseconds: 40),
      );
      addTearDown(swept.stop);

      await swept.start();
      // Startup pull fails → reachable=false, so no edge recover.
      await Future<void>.delayed(Duration.zero);
      clearInteractions(worker);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      verifyNever(() => worker.recoverDeadLettered());
    });

    test('an offline edge reports online=false and does NOT trigger pullAll',
        () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      clearInteractions(puller);

      capturedOnOffline!();
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => puller.pullAll());
      expect(onlineStates.last, isFalse);
    });

    test('is idempotent: a second start() does not re-arm timers or re-load',
        () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      clearInteractions(worker);
      clearInteractions(puller);
      clearInteractions(transitions);
      clearInteractions(watcher);

      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => worker.start(interval: any(named: 'interval')));
      verifyNever(() => transitions.loadOnce());
      verifyNever(() => watcher.start(
            onOnline: any(named: 'onOnline'),
            onOffline: any(named: 'onOffline'),
          ));
      verifyNever(() => puller.pullAll());
    });

    test('the periodic pull timer fires pullAll on its cadence', () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      // 1 from immediate kick-off.
      verify(() => puller.pullAll()).called(1);

      // Wait for ~2 tick intervals so the timer fires at least twice.
      await Future<void>.delayed(const Duration(milliseconds: 130));
      verify(() => puller.pullAll()).called(greaterThanOrEqualTo(2));
    });

    test(
        'a failed transitions.loadOnce leaves orchestrator retryable and '
        'tears down side-effects', () async {
      var loadCalls = 0;
      when(() => transitions.loadOnce()).thenAnswer((_) async {
        loadCalls++;
        if (loadCalls == 1) {
          throw StateError('offline at first sign-in');
        }
      });

      await expectLater(orchestrator.start(), throwsA(isA<StateError>()));

      // Side-effects from the half-started call must be torn down so the
      // worker timer and connectivity stream don't keep running.
      verify(() => worker.stop()).called(1);
      verify(() => watcher.dispose()).called(1);

      // The retry must fully start the orchestrator — including arming the
      // periodic pull timer, not just the connectivity-triggered pulls.
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      verify(() => puller.pullAll()).called(1);

      await Future<void>.delayed(const Duration(milliseconds: 130));
      verify(() => puller.pullAll()).called(greaterThanOrEqualTo(2));
    });
  });

  group('stop()', () {
    test('stops the worker, disposes the watcher, halts the pull timer',
        () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);

      await orchestrator.stop();

      verify(() => worker.stop()).called(1);
      verify(() => watcher.dispose()).called(1);

      // After stop the periodic pull timer should not fire any more.
      clearInteractions(puller);
      await Future<void>.delayed(const Duration(milliseconds: 130));
      verifyNever(() => puller.pullAll());
    });

    test('is safe to call before start()', () async {
      await expectLater(orchestrator.stop(), completes);
      verifyNever(() => worker.stop());
      verifyNever(() => watcher.dispose());
    });

    test('awaits any in-flight recoverDeadLettered before returning', () async {
      // recoverDeadLettered() issues a DB write (UPDATE outbox ... WHERE
      // status='dead_letter'). signOutAndReset calls stop() then truncates the
      // outbox, so — exactly like the in-flight pullAll it already tracks —
      // stop() must await this write first, or a stale requeue can land after
      // the truncate and (on a shared device) revive a dead_letter row into the
      // next rider's outbox.
      final inflight = Completer<int>();
      when(() => worker.recoverDeadLettered())
          .thenAnswer((_) async => inflight.future);

      await orchestrator.start();
      // The startup pull confirms reachability; its unreachable→reachable edge
      // kicks off recoverDeadLettered. Let that settle so it's in flight.
      await Future<void>.delayed(Duration.zero);

      final stopFuture = orchestrator.stop();
      var stopCompleted = false;
      unawaited(stopFuture.then((_) => stopCompleted = true));

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(stopCompleted, isFalse,
          reason: 'stop should be waiting on the in-flight recover');

      inflight.complete(0);
      await stopFuture;
      expect(stopCompleted, isTrue);
    });

    test('awaits any in-flight pullAll before returning', () async {
      // Make pullAll resolve on a controllable completer so we can verify
      // the orchestrator's stop() awaits it.
      final inflight = Completer<int>();
      when(() => puller.pullAll())
          .thenAnswer((_) async => inflight.future);

      await orchestrator.start();
      // start() awaits transitions.loadOnce + watcher.isOnline, then kicks
      // off pullAll without awaiting. The future is now sitting in flight.

      // Begin stop() — it should not complete until inflight resolves.
      final stopFuture = orchestrator.stop();
      var stopCompleted = false;
      stopFuture.then((_) => stopCompleted = true);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(stopCompleted, isFalse,
          reason: 'stop should be waiting on the in-flight pullAll');

      inflight.complete(0);
      await stopFuture;
      expect(stopCompleted, isTrue);
    });
  });

  group('syncNow()', () {
    test('triggers an extra pullAll on demand', () async {
      await orchestrator.start();
      await Future<void>.delayed(Duration.zero);
      clearInteractions(puller);

      await orchestrator.syncNow();

      verify(() => puller.pullAll()).called(1);
    });

    test(
        'coalesces onto an in-flight periodic pull rather than orphaning it '
        'from stop()\'s view', () async {
      final blocker = Completer<int>();
      when(() => puller.pullAll())
          .thenAnswer((_) async => blocker.future);

      await orchestrator.start();
      // Pull #1 (from start()) is now in flight and tracked by
      // _inFlightPull.
      await Future<void>.delayed(Duration.zero);
      verify(() => puller.pullAll()).called(1);

      // Manual refresh while a pull is already running: must NOT start
      // a second pullAll. Otherwise _inFlightPull gets overwritten and
      // the original pull is orphaned from stop()'s view, which can
      // race with _truncateAllTables on sign-out.
      final syncFuture = orchestrator.syncNow();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => puller.pullAll());

      // Releasing the in-flight pull completes syncNow().
      blocker.complete(0);
      await syncFuture;
    });
  });

  group('re-entrancy guard on _kickoffPull', () {
    test(
        'a connectivity online edge while a pull is in flight does NOT '
        'start a second pullAll', () async {
      final blocker = Completer<int>();
      when(() => puller.pullAll())
          .thenAnswer((_) async => blocker.future);

      await orchestrator.start();
      // Pull #1 from startup is now in flight.
      await Future<void>.delayed(Duration.zero);
      verify(() => puller.pullAll()).called(1);

      // Online edge tries to kick off another pull — must be a no-op
      // while a pull is still running. Otherwise the periodic timer
      // and connectivity edge can compound to N concurrent pulls and
      // stop() only awaits the most recent one.
      capturedOnOnline!();
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => puller.pullAll());

      // After the in-flight pull completes the guard clears: the next
      // edge produces a fresh pull.
      blocker.complete(0);
      await Future<void>.delayed(Duration.zero);
      when(() => puller.pullAll()).thenAnswer((_) async => 0);

      capturedOnOnline!();
      await Future<void>.delayed(Duration.zero);
      verify(() => puller.pullAll()).called(1);
    });
  });
}
