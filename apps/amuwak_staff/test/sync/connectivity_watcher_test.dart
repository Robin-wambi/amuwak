import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/sync/connectivity_watcher.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> controller;
  late ConnectivityWatcher watcher;

  setUp(() {
    connectivity = _MockConnectivity();
    controller = StreamController<List<ConnectivityResult>>.broadcast();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => controller.stream);
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => const [ConnectivityResult.wifi]);
    watcher = ConnectivityWatcher(connectivity: connectivity);
  });

  tearDown(() async {
    watcher.dispose();
    await controller.close();
  });

  group('start: connectivity edges', () {
    test('fires onOnline on every offline→online transition', () async {
      var onlineCount = 0;
      watcher.start(onOnline: () => onlineCount++);

      controller.add(const [ConnectivityResult.wifi]); // initial → online (1)
      await Future<void>.delayed(Duration.zero);
      controller.add(const [ConnectivityResult.none]); // offline
      await Future<void>.delayed(Duration.zero);
      controller.add(const [ConnectivityResult.mobile]); // online again (2)
      await Future<void>.delayed(Duration.zero);

      expect(onlineCount, 2);
    });

    test('fires onOffline on online→offline transitions', () async {
      var offlineCount = 0;
      watcher.start(onOnline: () {}, onOffline: () => offlineCount++);

      controller.add(const [ConnectivityResult.wifi]); // online
      await Future<void>.delayed(Duration.zero);
      controller.add(const [ConnectivityResult.none]); // offline (1)
      await Future<void>.delayed(Duration.zero);
      controller.add(const [ConnectivityResult.mobile]); // online
      await Future<void>.delayed(Duration.zero);
      controller.add(const [ConnectivityResult.none]); // offline (2)
      await Future<void>.delayed(Duration.zero);

      expect(offlineCount, 2);
    });

    test('treats an empty result list as offline', () async {
      var offlineCount = 0;
      watcher.start(onOnline: () {}, onOffline: () => offlineCount++);

      controller.add(const [ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      controller.add(const <ConnectivityResult>[]);
      await Future<void>.delayed(Duration.zero);

      expect(offlineCount, 1);
    });

    test('onOffline is optional (no callback registered)', () async {
      var onlineCount = 0;
      watcher.start(onOnline: () => onlineCount++);

      controller.add(const [ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      // No throw despite no onOffline.
      controller.add(const [ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      controller.add(const [ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      expect(onlineCount, 2);
    });
  });

  group('start: idempotence', () {
    test('a second start() cancels and replaces the prior subscription', () async {
      var oldOnlineCount = 0;
      var newOnlineCount = 0;

      watcher.start(onOnline: () => oldOnlineCount++);
      watcher.start(onOnline: () => newOnlineCount++);

      controller.add(const [ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      expect(oldOnlineCount, 0,
          reason: 'the first subscription should have been cancelled');
      expect(newOnlineCount, 1);
    });
  });

  group('isOnline', () {
    test('returns true when checkConnectivity reports wifi', () async {
      expect(await watcher.isOnline(), isTrue);
    });

    test('returns false when checkConnectivity reports none', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => const [ConnectivityResult.none]);
      expect(await watcher.isOnline(), isFalse);
    });

    test('returns false when checkConnectivity returns an empty list', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => const <ConnectivityResult>[]);
      expect(await watcher.isOnline(), isFalse);
    });
  });
}
