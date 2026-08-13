import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/auth/recovery_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stands in for the auth stream so a test can drive one event at a time.
final _event = StateProvider<AuthChangeEvent?>((ref) => null);

ProviderContainer _containerAt(
  AuthChangeEvent? initial, {
  RecoveryIntentStore? store,
  String? userId = 'u1',
}) {
  final container = ProviderContainer(
    overrides: [
      _event.overrideWith((ref) => initial),
      currentAuthEventProvider.overrideWith((ref) => ref.watch(_event)),
      // A pending reset is scoped to the user it belongs to, so the notifier
      // reads this. Overridden rather than left real, because the live
      // provider reaches through AuthService for a Supabase instance no unit
      // test initialises.
      currentUserIdProvider.overrideWithValue(userId),
      if (store != null) recoveryIntentStoreProvider.overrideWithValue(store),
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

    test('survives a page reload mid-reset', () {
      // The Supabase session persists to localStorage, but `passwordRecovery`
      // does not fire twice: a reload restores the session and raises
      // `initialSession` instead. Without a persisted intent the flag would
      // reseed false and the router would wave the user into the app with
      // their old password still live.
      final store = InMemoryRecoveryIntentStore();
      final first = _containerAt(AuthChangeEvent.passwordRecovery,
          store: store);
      expect(first.read(recoveringProvider), isTrue);

      final reloaded =
          _containerAt(AuthChangeEvent.initialSession, store: store);
      expect(reloaded.read(recoveringProvider), isTrue);
    });

    test('does not resurrect a finished reset on the next reload', () {
      // Signing out is how a completed reset ends, so it has to clear the
      // persisted intent too — otherwise every later visit would demand a new
      // password.
      final store = InMemoryRecoveryIntentStore();
      final first = _containerAt(AuthChangeEvent.passwordRecovery,
          store: store);
      first.read(_event.notifier).state = AuthChangeEvent.signedOut;
      expect(first.read(recoveringProvider), isFalse);

      final reloaded =
          _containerAt(AuthChangeEvent.initialSession, store: store);
      expect(reloaded.read(recoveringProvider), isFalse);
    });

    test('does not hand one user the reset another user abandoned', () {
      // A reset abandoned by u1 can outlive its session without ever raising
      // `signedOut` here, and nothing else clears the flag. Unscoped, the next
      // person to sign in on that browser inherits it.
      final store = InMemoryRecoveryIntentStore();
      final first = _containerAt(AuthChangeEvent.passwordRecovery,
          store: store);
      expect(first.read(recoveringProvider), isTrue);

      final somebodyElse = _containerAt(AuthChangeEvent.initialSession,
          store: store, userId: 'u2');
      expect(somebodyElse.read(recoveringProvider), isFalse);
    });
  });

  group('recoveryLinkFailedProvider', () {
    /// GoTrue pushes a failed `?code=` exchange onto the auth stream as an
    /// error and never establishes a session, which is the only trace the app
    /// gets of a recovery link that could not be opened.
    Future<ProviderContainer> containerWith({
      required String url,
      required bool exchangeFailed,
    }) async {
      final container = ProviderContainer(
        overrides: [
          launchUriProvider.overrideWithValue(Uri.parse(url)),
          authStateProvider.overrideWith(
            (ref) => exchangeFailed
                ? Stream<AuthState>.error(const AuthException(
                    'Code verifier could not be found in local storage.'))
                : Stream<AuthState>.value(
                    AuthState(AuthChangeEvent.initialSession, null)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authStateProvider.future)
          .then((_) {}, onError: (_) {});
      return container;
    }

    test('is true when a link arrived and its code could not be exchanged',
        () async {
      final container = await containerWith(
          url: 'https://amuwak-customer.pages.dev/?code=abc123',
          exchangeFailed: true);
      expect(container.read(recoveryLinkFailedProvider), isTrue);
    });

    test('is false for an auth error with no link involved', () async {
      // A failed sign-in errors the same stream. Only a URL carrying a
      // one-time code means a recovery link is what went wrong.
      final container = await containerWith(
          url: 'https://amuwak-customer.pages.dev/', exchangeFailed: true);
      expect(container.read(recoveryLinkFailedProvider), isFalse);
    });

    test('is false when the link exchanged cleanly', () async {
      final container = await containerWith(
          url: 'https://amuwak-customer.pages.dev/?code=abc123',
          exchangeFailed: false);
      expect(container.read(recoveryLinkFailedProvider), isFalse);
    });
  });
}
