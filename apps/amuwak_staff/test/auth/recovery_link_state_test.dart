import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_staff/src/auth/recovery_link_state.dart';

/// The detection itself is core's, and tested there. These cover the wiring:
/// that the staff app feeds it the right three inputs, so a rider's dead link
/// is noticed here the same way a customer's is.
void main() {
  group('recoveryLinkFailedProvider', () {
    Future<ProviderContainer> containerWith({
      required String url,
      required bool exchangeFailed,
    }) async {
      final container = ProviderContainer(overrides: [
        launchUriProvider.overrideWithValue(Uri.parse(url)),
        authStateProvider.overrideWith(
          (ref) => exchangeFailed
              ? Stream<AuthState>.error(const AuthException(
                  'Code verifier could not be found in local storage.'))
              : Stream<AuthState>.value(
                  AuthState(AuthChangeEvent.initialSession, null)),
        ),
      ]);
      addTearDown(container.dispose);
      await container
          .read(authStateProvider.future)
          .then((_) {}, onError: (_) {});
      return container;
    }

    test('is true when a token-hash link was rejected at bootstrap', () async {
      // The shape that reaches a rider on a second device. verifyOtp just
      // throws, so nothing lands on the auth stream — bootstrap's verdict is
      // the whole record.
      final container = ProviderContainer(overrides: [
        recoveryLinkOutcomeProvider.overrideWithValue(RecoveryLinkResult.failed),
      ]);
      addTearDown(container.dispose);

      expect(container.read(recoveryLinkFailedProvider), isTrue);
    });

    test('is false when a token-hash link was redeemed', () async {
      final container = ProviderContainer(overrides: [
        recoveryLinkOutcomeProvider
            .overrideWithValue(RecoveryLinkResult.verified),
      ]);
      addTearDown(container.dispose);

      expect(container.read(recoveryLinkFailedProvider), isFalse);
    });

    test('is true when a link arrived and its code could not be exchanged',
        () async {
      final container = await containerWith(
          url: 'https://robin-wambi.github.io/amuwak/?code=abc123',
          exchangeFailed: true);
      expect(container.read(recoveryLinkFailedProvider), isTrue);
    });

    test('is false for an auth error with no link involved', () async {
      // A rider mistyping their password errors the same stream, and that must
      // not be blamed on an email nobody opened.
      final container = await containerWith(
          url: 'https://robin-wambi.github.io/amuwak/', exchangeFailed: true);
      expect(container.read(recoveryLinkFailedProvider), isFalse);
    });

    test('is false on an ordinary visit', () async {
      final container = await containerWith(
          url: 'https://robin-wambi.github.io/amuwak/', exchangeFailed: false);
      expect(container.read(recoveryLinkFailedProvider), isFalse);
    });
  });
}
