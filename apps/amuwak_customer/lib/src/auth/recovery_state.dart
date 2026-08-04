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

/// Whether a recovery link arrived but its one-time `?code=` never became a
/// session.
///
/// PKCE writes the code verifier to the localStorage of the browser that asked
/// for the reset, so a link opened anywhere else — another device, or an email
/// client's isolated in-app browser — cannot complete the exchange. GoTrue
/// reports that as an error on the auth stream and no session is established,
/// which on its own looks exactly like an ordinary signed-out visit: the user
/// is dropped on /login and left to request more links that cannot work
/// either.
///
/// Both halves matter. A failed sign-in errors the same stream, so the `?code=`
/// is what says a recovery link is the thing that went wrong.
final recoveryLinkFailedProvider = Provider<bool>((ref) {
  final arrivedOnALink =
      ref.watch(launchUriProvider).queryParameters.containsKey('code');
  return arrivedOnALink && ref.watch(authStateProvider).hasError;
});

class RecoveringNotifier extends Notifier<bool> {
  @override
  bool build() {
    final store = ref.read(recoveryIntentStoreProvider);
    ref.listen<AuthChangeEvent?>(currentAuthEventProvider, (_, next) {
      if (next == AuthChangeEvent.passwordRecovery) {
        store.markPending();
        state = true;
      } else if (next == AuthChangeEvent.signedOut) {
        store.clear();
        state = false;
      }
    });
    // Seed from the current event: supabase_flutter can exchange the ?code=
    // from a recovery link before the first frame builds, so the event may
    // already have fired by the time anything reads this.
    if (ref.read(currentAuthEventProvider) ==
        AuthChangeEvent.passwordRecovery) {
      store.markPending();
      return true;
    }
    // Otherwise fall back to what a previous run recorded. A reload restores
    // the Supabase session and raises `initialSession`, never a second
    // `passwordRecovery`, so the event alone would forget an unfinished reset
    // and let the user into the app with their old password still live.
    return store.isPending;
  }
}
