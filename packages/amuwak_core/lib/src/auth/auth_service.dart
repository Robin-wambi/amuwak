import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message, {this.retryable = false});
  final String message;

  /// True when the call never reached a verdict — a timeout, a dropped
  /// connection, a 5xx. The distinction matters to whoever is reading the
  /// error: "try again" is sound advice for these and actively misleading for
  /// a rejected credential, which no amount of retrying will fix.
  ///
  /// Only [MfaService] sets this today. `AuthRetryableFetchException` extends
  /// `AuthException`, so without it a dropped connection and a wrong code are
  /// indistinguishable to callers.
  final bool retryable;

  @override
  String toString() => 'AuthFailure: $message';
}

class AuthService {
  AuthService({GoTrueClient? goTrue})
      : _goTrue = goTrue ?? Supabase.instance.client.auth;

  final GoTrueClient _goTrue;

  /// Sign in with a real email + password. Email is trimmed and lower-cased so
  /// that casing/whitespace differences don't cause spurious auth failures.
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _goTrue.signInWithPassword(
        email: _normalizeEmail(email),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Register a new user with email + password (the customer app's self-signup).
  /// Email is trimmed and lower-cased to match [signInWithEmailPassword]. With
  /// email confirmation disabled (customer-app v1), this establishes a session
  /// immediately, so the caller can link the customers row on the same run.
  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _goTrue.signUp(
        email: _normalizeEmail(email),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Forces a JWT refresh so a just-issued custom claim (e.g. the `customer`
  /// role minted by the access-token hook after [signUpWithEmailPassword] +
  /// linking) is present on the access token without waiting for the next
  /// scheduled refresh.
  Future<void> refreshSession() async {
    try {
      await _goTrue.refreshSession();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Set the signed-in user's password. Used both when accepting an invite
  /// (the invite link establishes a session, then the user picks a password)
  /// and when completing a password reset.
  Future<void> updatePassword(String password) async {
    try {
      await _goTrue.updateUser(UserAttributes(password: password));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Send a password-reset email.
  ///
  /// With no [redirectTo] the link targets the project's Site URL. That is only
  /// correct for whichever app the Site URL happens to name — both apps share
  /// one auth project, so the other must pass its own origin or its users land
  /// in the wrong application.
  ///
  /// Pass an origin, not a route: Supabase appends `?code=…` to this URL, and a
  /// Flutter web app on the default hash strategy would end up with a query
  /// string after the fragment. supabase_flutter exchanges the code on startup
  /// and raises `passwordRecovery`; routing to a reset screen is the app's job.
  Future<void> sendPasswordReset(String email, {String? redirectTo}) async {
    try {
      await _goTrue.resetPasswordForEmail(
        _normalizeEmail(email),
        redirectTo: redirectTo,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Redeem a recovery link that carries a `token_hash` rather than a PKCE
  /// `?code=`, establishing the session and raising `passwordRecovery`.
  ///
  /// This is the device-independent half of password recovery. The PKCE
  /// exchange needs a code verifier that [sendPasswordReset] wrote to the
  /// localStorage of the browser that asked for the reset, so that link only
  /// completes there — open it on a phone after requesting it on a laptop and
  /// there is nothing to exchange against. A token hash carries its own proof
  /// and works from anywhere.
  Future<void> verifyRecoveryToken(String tokenHash) async {
    try {
      await _goTrue.verifyOTP(type: OtpType.recovery, tokenHash: tokenHash);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// End the session. GoTrue drops the local session and raises `signedOut`
  /// before it calls the server, so a failure here means the revoke request
  /// failed — the user is signed out locally either way.
  Future<void> signOut() async {
    try {
      await _goTrue.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  Session? get currentSession => _goTrue.currentSession;
  User?    get currentUser    => _goTrue.currentUser;
  Stream<AuthState> get authStateChanges => _goTrue.onAuthStateChange;
}
