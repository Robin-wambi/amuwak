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

class RecoveringNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<AuthChangeEvent?>(currentAuthEventProvider, (_, next) {
      if (next == AuthChangeEvent.passwordRecovery) {
        state = true;
      } else if (next == AuthChangeEvent.signedOut) {
        state = false;
      }
    });
    // Seed from the current event: supabase_flutter can exchange the ?code=
    // from a recovery link before the first frame builds, so the event may
    // already have fired by the time anything reads this.
    return ref.read(currentAuthEventProvider) ==
        AuthChangeEvent.passwordRecovery;
  }
}
