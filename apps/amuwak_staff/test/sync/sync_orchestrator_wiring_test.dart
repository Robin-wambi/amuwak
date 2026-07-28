import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator_provider.dart';

class _MockOrchestrator extends Mock implements SyncOrchestrator {}

class _FakeSession extends Fake implements Session {}

/// Builds an [AuthState] whose `session` is non-null for signed-in
/// scenarios. AuthChangeEvent is forced to the closest matching event;
/// the lifecycle provider keys off `session != null`, not the event type.
AuthState _signedIn() => AuthState(AuthChangeEvent.signedIn, _FakeSession());

AuthState _signedOut() => AuthState(AuthChangeEvent.signedOut, null);

void main() {
  late _MockOrchestrator orchestrator;
  late StreamController<AuthState> controller;

  setUp(() {
    orchestrator = _MockOrchestrator();
    when(() => orchestrator.start()).thenAnswer((_) async {});
    when(() => orchestrator.stop()).thenAnswer((_) async {});
    controller = StreamController<AuthState>.broadcast();
  });

  tearDown(() async {
    await controller.close();
  });

  ProviderContainer buildContainer() => ProviderContainer(overrides: [
        syncOrchestratorProvider.overrideWithValue(orchestrator),
        authStateProvider.overrideWith((ref) => controller.stream),
      ]);

  test('initially signed-out: lifecycle provider does not call start()',
      () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(syncLifecycleProvider);
    controller.add(_signedOut());
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => orchestrator.start());
    verifyNever(() => orchestrator.stop());
  });

  test('signed-in transition calls start() exactly once', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(syncLifecycleProvider);
    controller.add(_signedIn());
    await Future<void>.delayed(Duration.zero);

    verify(() => orchestrator.start()).called(1);
    verifyNever(() => orchestrator.stop());
  });

  test('signed-in → signed-out flips to stop()', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(syncLifecycleProvider);
    controller.add(_signedIn());
    await Future<void>.delayed(Duration.zero);
    controller.add(_signedOut());
    await Future<void>.delayed(Duration.zero);

    verify(() => orchestrator.start()).called(1);
    verify(() => orchestrator.stop()).called(1);
  });

  test('a second signed-in transition calls start() again', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(syncLifecycleProvider);
    controller.add(_signedIn());
    await Future<void>.delayed(Duration.zero);
    controller.add(_signedOut());
    await Future<void>.delayed(Duration.zero);
    controller.add(_signedIn());
    await Future<void>.delayed(Duration.zero);

    verify(() => orchestrator.start()).called(2);
    verify(() => orchestrator.stop()).called(1);
  });

  test('repeated same-session emissions do not retrigger start/stop',
      () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(syncLifecycleProvider);
    controller.add(_signedIn());
    await Future<void>.delayed(Duration.zero);
    controller.add(_signedIn()); // duplicate
    await Future<void>.delayed(Duration.zero);

    verify(() => orchestrator.start()).called(1);
    verifyNever(() => orchestrator.stop());
  });

  test('container.dispose triggers orchestrator.stop()', () async {
    final container = buildContainer();
    container.read(syncLifecycleProvider);
    controller.add(_signedIn());
    await Future<void>.delayed(Duration.zero);

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    verify(() => orchestrator.stop()).called(1);
  });

  test(
    'rapid signed-in → signed-out waits for start() before invoking stop()',
    () async {
      // Reproduces the race the lifecycle serialisation guards against: if
      // start() is slow and stop() is fired right after, the two MUST NOT
      // run concurrently (a concurrent stop() while start()'s _kickoffPull
      // is still writing would corrupt watermark state).
      final startCompleter = Completer<void>();
      var stopCalled = false;
      when(() => orchestrator.start())
          .thenAnswer((_) => startCompleter.future);
      when(() => orchestrator.stop()).thenAnswer((_) async {
        // If stop() runs while start() is still pending, fail the test.
        expect(startCompleter.isCompleted, isTrue,
            reason: 'stop() ran while start() was still in flight');
        stopCalled = true;
      });

      final container = buildContainer();
      addTearDown(container.dispose);

      container.read(syncLifecycleProvider);
      controller.add(_signedIn());
      await Future<void>.delayed(Duration.zero);
      controller.add(_signedOut());
      await Future<void>.delayed(Duration.zero);

      // start() is still pending; stop() must be queued, not yet executed.
      expect(stopCalled, isFalse);

      // Release start(); stop() should now run after it.
      startCompleter.complete();
      await Future<void>.delayed(Duration.zero);
      // One more pump to let the chained .then() resolve.
      await Future<void>.delayed(Duration.zero);

      expect(stopCalled, isTrue);
      verify(() => orchestrator.start()).called(1);
      verify(() => orchestrator.stop()).called(1);
    },
  );
}
