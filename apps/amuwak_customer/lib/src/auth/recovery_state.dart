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
