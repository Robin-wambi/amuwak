import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the user is part-way through a password recovery.
///
/// Sticky on purpose. A `passwordRecovery` event latches this on and only
/// `signedOut` releases it — notably NOT `tokenRefreshed`. Supabase refreshes
/// the JWT on its own schedule, and if that released the flag it would eject
/// someone in the middle of choosing a new password and drop them into the app
/// with their old one still live. The staff app's [AuthGate] carries the same
/// warning for the same reason.
///
/// Sticky across a page reload too, via [RecoveryIntentStore] — in-memory
/// stickiness alone is not enough, because the Supabase session persists but
/// the `passwordRecovery` event does not repeat.
///
/// The router reads this, so completing a reset ends recovery by signing out:
/// the `signedOut` event clears the flag, and the redirect then sends the user
/// to /login to sign in with the new password (OWASP: no auto-login after a
/// reset).
final recoveringProvider =
    NotifierProvider<RecoveringNotifier, bool>(RecoveringNotifier.new);

/// Where Supabase should send a recovery link back to — this app's own origin.
///
/// Both apps share one auth project and its Site URL names the staff app, so
/// without this a customer would follow the link into a PWA that has nothing
/// for them.
///
/// An origin, never a route: Supabase appends `?code=…`, and this app runs
/// Flutter web's default hash strategy, so naming a route would put a query
/// string after the fragment.
///
/// Null off the web, where `Uri.base` is a `file:` URI and `.origin` throws.
/// The customer app only ships to web, so that is a test or a debug run; the
/// null simply defers to the Site URL.
final passwordResetRedirectProvider = Provider<String?>((ref) {
  final base = Uri.base;
  final isWeb = base.isScheme('http') || base.isScheme('https');
  return isWeb ? base.origin : null;
});

/// The URL this app was opened with. A provider so tests can drive it, and
/// safe to read late: the app runs on Flutter web's hash strategy, so in-app
/// navigation only rewrites the fragment and leaves the query alone.
final launchUriProvider = Provider<Uri>((ref) => Uri.base);

/// What bootstrap made of the launch URL. Overridden in `main.dart`; the
/// default covers tests and any path that never ran bootstrap.
final recoveryLinkOutcomeProvider =
    Provider<RecoveryLinkResult>((ref) => RecoveryLinkResult.none);

/// Whether a recovery link arrived and never became a session.
///
/// Two link shapes fail two different ways, and the user cannot tell either of
/// them from an ordinary signed-out visit — they are dropped on /login with
/// nothing to say the emailed link was the problem, and go on requesting more.
///
/// `?token_hash=` is redeemed by [completeRecoveryLink] during bootstrap, so a
/// rejection is a return value, not anything on the auth stream.
///
/// `?code=` is redeemed by supabase_flutter, which reports the failure as an
/// error on the auth stream. Both halves of that test matter: a failed sign-in
/// errors the same stream, so the `code` parameter is what says a recovery
/// link is the thing that went wrong.
final recoveryLinkFailedProvider = Provider<bool>((ref) {
  if (ref.watch(recoveryLinkOutcomeProvider) == RecoveryLinkResult.failed) {
    return true;
  }
  final arrivedOnAPkceLink =
      ref.watch(launchUriProvider).queryParameters.containsKey('code');
  return arrivedOnAPkceLink && ref.watch(authStateProvider).hasError;
});

class RecoveringNotifier extends Notifier<bool> {
  @override
  bool build() {
    final store = ref.read(recoveryIntentStoreProvider);
    ref.listen<AuthChangeEvent?>(currentAuthEventProvider, (_, next) {
      if (next == AuthChangeEvent.passwordRecovery) {
        final userId = ref.read(currentUserIdProvider);
        if (userId != null) store.markPending(userId);
        state = true;
      } else if (next == AuthChangeEvent.signedOut && state) {
        // Only when this session is the one recovering. `clear()` wipes the
        // single stored entry whoever owns it, so an unrelated user signing
        // out of a shared browser would otherwise cancel someone else's
        // outstanding reset and hand them the app with their old password.
        //
        // Guarded on `state` rather than by passing a user id, because by the
        // time `signedOut` arrives the session is gone and
        // `currentUserIdProvider` is already null — there would be nothing
        // left to compare against. The staff [AuthGate] guards on its own
        // `_recovering` for the same reason.
        store.clear();
        state = false;
      }
    });
    final userId = ref.read(currentUserIdProvider);
    // Seed from the current event: supabase_flutter can exchange the ?code=
    // from a recovery link before the first frame builds, so the event may
    // already have fired by the time anything reads this.
    if (ref.read(currentAuthEventProvider) ==
        AuthChangeEvent.passwordRecovery) {
      if (userId != null) store.markPending(userId);
      return true;
    }
    // Otherwise fall back to what a previous run recorded, for this user only.
    // A reload restores the Supabase session and raises `initialSession`,
    // never a second `passwordRecovery`, so the event alone would forget an
    // unfinished reset and let the user into the app with their old password
    // still live. Scoped by user id because a reset abandoned on a shared
    // browser otherwise greets whoever signs in next.
    return userId != null && store.isPendingFor(userId);
  }
}
