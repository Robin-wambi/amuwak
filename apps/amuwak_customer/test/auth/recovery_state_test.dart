import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/auth/recovery_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stands in for the auth stream so a test can drive one event at a time.
final _event = StateProvider<AuthChangeEvent?>((ref) => null);

ProviderContainer _containerAt(AuthChangeEvent? initial) {
  final container = ProviderContainer(
    overrides: [
      _event.overrideWith((ref) => initial),
      currentAuthEventProvider.overrideWith((ref) => ref.watch(_event)),
    ],
  );
  addTearDown(container.dispose);
  // Keep the notifier alive so its internal listener stays subscribed.
  container.listen(recoveringProvider, (_, __) {});
  return container;
}

void main() {
  group('recoveringProvider', () {
    test('is false when nothing is happening', () {
      final container = _containerAt(null);
      expect(container.read(recoveringProvider), isFalse);
    });

    test('seeds true when the app cold-starts on a recovery link', () {
      // supabase_flutter may exchange the ?code= before the first widget
      // builds, so the event can already have fired by the time we look.
      final container = _containerAt(AuthChangeEvent.passwordRecovery);
      expect(container.read(recoveringProvider), isTrue);
    });

    test('latches when a recovery event arrives', () {
      final container = _containerAt(null);
      container.read(_event.notifier).state = AuthChangeEvent.passwordRecovery;
      expect(container.read(recoveringProvider), isTrue);
    });

    test('survives a token refresh mid-reset', () {
      // The whole reason this is sticky: a background refresh must not eject
      // someone who is halfway through choosing a new password.
      final container = _containerAt(AuthChangeEvent.passwordRecovery);
      container.read(_event.notifier).state = AuthChangeEvent.tokenRefreshed;
      expect(container.read(recoveringProvider), isTrue);
    });

    test('releases on sign-out', () {
      // Completing a reset signs the user out, which is what ends recovery.
      final container = _containerAt(AuthChangeEvent.passwordRecovery);
      container.read(_event.notifier).state = AuthChangeEvent.signedOut;
      expect(container.read(recoveringProvider), isFalse);
    });
  });
}
