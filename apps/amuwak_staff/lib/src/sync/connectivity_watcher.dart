import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityWatcher {
  ConnectivityWatcher({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Subscribes to `connectivity_plus` and dispatches:
  ///   - [onOnline] whenever the device transitions offline → online,
  ///   - [onOffline] whenever the device transitions online → offline.
  ///
  /// Idempotent: calling [start] a second time cancels the prior
  /// subscription before installing the new one.
  void start({
    required void Function() onOnline,
    void Function()? onOffline,
  }) {
    _sub?.cancel();
    bool wasOnline = false;
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && !wasOnline) {
        onOnline();
      } else if (!online && wasOnline) {
        onOffline?.call();
      }
      wasOnline = online;
    });
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() => _sub?.cancel();
}
