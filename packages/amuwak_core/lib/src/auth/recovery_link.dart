import 'auth_service.dart';

/// What a launch URL turned out to be.
enum RecoveryLinkResult {
  /// Nothing for us here — an ordinary visit, or a link supabase_flutter owns.
  none,

  /// A token hash was redeemed; `passwordRecovery` has been raised.
  verified,

  /// A token hash was present and the server rejected it.
  failed,
}

/// Redeems a recovery link of the form `?token_hash=…&type=recovery`, which is
/// the only shape of reset link that works from a device other than the one
/// that asked for it.
///
/// The default link is not. `resetPasswordForEmail` generates a PKCE code
/// verifier and stores it in *that browser's* localStorage; the `?code=` in
/// the email can only be exchanged against it. Request the reset on a laptop
/// and open the mail on a phone — or in an email client's isolated in-app
/// browser — and the exchange has nothing to work with. A token hash carries
/// its own proof, so [AuthService.verifyRecoveryToken] needs no local state.
///
/// Call this once, from bootstrap, before the first frame: `verifyOTP` raises
/// `passwordRecovery` and both apps' gates seed from that event. It reaches
/// them even though it fires before they mount, because GoTrue's
/// `onAuthStateChange` is a `BehaviorSubject` and replays its last event to a
/// new subscriber.
///
/// Deliberately inert for every other link shape. `?code=` belongs to
/// supabase_flutter's deeplink observer and the code can only be spent once,
/// so racing it here would break the flow this is meant to widen. A token hash
/// of some other `type` — signup confirmation, email change — is likewise not
/// ours; redeeming one as a recovery would drop the user on a
/// set-a-new-password screen they never asked for.
Future<RecoveryLinkResult> completeRecoveryLink({
  required Uri uri,
  required AuthService auth,
}) async {
  final params = uri.queryParameters;
  final tokenHash = params['token_hash'];
  if (tokenHash == null || params['type'] != 'recovery') {
    return RecoveryLinkResult.none;
  }
  try {
    await auth.verifyRecoveryToken(tokenHash);
    return RecoveryLinkResult.verified;
  } on AuthFailure catch (_) {
    // Expired or already spent. Nothing to retry — the caller has to say so,
    // because no session is established and this otherwise looks exactly like
    // an ordinary signed-out visit.
    return RecoveryLinkResult.failed;
  }
}

/// Whether a recovery link arrived and never became a session.
///
/// Both apps need this and neither can infer it from the auth state alone: a
/// link that fails leaves the user signed out, which is indistinguishable from
/// an ordinary visit. Left unsaid, they are dropped on the sign-in screen with
/// nothing to explain why the emailed link did nothing, and go on requesting
/// more of them.
///
/// The two link shapes fail in two different places, so both are checked here
/// rather than in each app:
///
///   * `?token_hash=` is redeemed by [completeRecoveryLink] during bootstrap,
///     so a rejection is [outcome], a return value — it never reaches the auth
///     stream at all.
///   * `?code=` is redeemed by supabase_flutter, which reports the failure as
///     an error on the auth stream.
///
/// [authStreamHasError] alone is not enough for the second: a failed sign-in
/// errors the same stream. The `code` parameter on [launchUri] is what says an
/// emailed link is the thing that went wrong.
///
/// Shared rather than duplicated per app on purpose — a new link shape has to
/// be handled in one place, not remembered in two.
bool recoveryLinkFailed({
  required RecoveryLinkResult outcome,
  required Uri launchUri,
  required bool authStreamHasError,
}) {
  if (outcome == RecoveryLinkResult.failed) return true;
  final arrivedOnAPkceLink = launchUri.queryParameters.containsKey('code');
  return arrivedOnAPkceLink && authStreamHasError;
}
