import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// What the user needs on screen to finish enrolling an authenticator app.
///
/// [otpauthUri] and [secret] are both the second factor: anyone holding either
/// can generate valid codes. Never log them — see [toString], which is written
/// to keep them out of anything that interpolates this object.
class TotpEnrolment {
  const TotpEnrolment({
    required this.factorId,
    required this.otpauthUri,
    required this.secret,
  });

  /// Identifies the factor in the follow-up verify call.
  final String factorId;

  /// The raw `otpauth://` URI the QR encodes. Render it with the app's existing
  /// QR widget, or hand it to the OS to open an authenticator app directly.
  ///
  /// Supabase also returns a pre-drawn SVG of this same QR. It is deliberately
  /// not carried here: both apps already ship `qr_flutter` for order tags, so
  /// the SVG would only be a second copy of the secret with no reader.
  final String otpauthUri;

  /// Shown alongside the QR for anyone who cannot scan one — a cracked screen
  /// or a desktop browser with no camera.
  final String secret;

  /// Redacted on purpose. The default would print the secret and the URI that
  /// embeds it, so one interpolated log line would leak the factor.
  @override
  String toString() => 'TotpEnrolment(factorId: $factorId, secret: <redacted>)';
}

/// TOTP multi-factor auth, wrapping the parts of GoTrue's MFA API the apps use
/// and translating [AuthException] into [AuthFailure] the way [AuthService]
/// does, so callers handle one error type.
///
/// TOTP rather than SMS deliberately: it is free on every Supabase project,
/// works with no signal, and is not vulnerable to SIM swapping. The phone
/// factor is a paid add-on and weaker.
///
/// This matters beyond defence in depth. NIST SP 800-63B Rev. 4 permits an
/// 8-character minimum only where a second authenticator exists — otherwise it
/// wants 15. The shared password policy assumes this service is in use.
class MfaService {
  MfaService({GoTrueClient? goTrue})
      : _goTrue = goTrue ?? Supabase.instance.client.auth;

  final GoTrueClient _goTrue;

  /// Begin enrolling an authenticator app. The factor exists but is inert until
  /// [submitCode] verifies it, so an abandoned enrolment cannot lock anyone out.
  Future<TotpEnrolment> enrollTotp({String friendlyName = 'Authenticator'}) =>
      _wrap(() async {
        final response = await _goTrue.mfa.enroll(
          factorType: FactorType.totp,
          issuer: 'Amuwak',
          friendlyName: friendlyName,
        );
        final totp = response.totp;
        if (totp == null) {
          throw AuthFailure('Could not start authenticator setup.');
        }
        return TotpEnrolment(
          factorId: response.id,
          otpauthUri: totp.uri,
          secret: totp.secret,
        );
      });

  /// Submit a 6-digit code — both to activate a new factor and to clear the
  /// challenge at sign-in. GoTrue treats these identically, so one method keeps
  /// callers from having to know which case they are in.
  Future<void> submitCode({
    required String factorId,
    required String code,
  }) =>
      _wrap(() =>
          _goTrue.mfa.challengeAndVerify(factorId: factorId, code: code));

  /// Whether this session has a second factor still to clear.
  ///
  /// True only when a verified factor exists (`nextLevel` aal2) and the current
  /// session has not satisfied it. Signed out, or never enrolled, both read
  /// false — there is nothing to challenge.
  bool get needsChallenge {
    final aal = _goTrue.mfa.getAuthenticatorAssuranceLevel();
    return aal.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
        aal.currentLevel != AuthenticatorAssuranceLevels.aal2;
  }

  /// The factors that actually count. Enrolment that was started and abandoned
  /// leaves an unverified factor behind; treating those as MFA would demand a
  /// code the user has no way to produce.
  Future<List<Factor>> verifiedFactors() => _wrap(() async {
        final response = await _goTrue.mfa.listFactors();
        return response.all
            .where((f) => f.status == FactorStatus.verified)
            .toList();
      });

  Future<void> removeFactor(String factorId) =>
      _wrap(() => _goTrue.mfa.unenroll(factorId));

  static Future<T> _wrap<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthRetryableFetchException catch (e) {
      // Caught ahead of AuthException, which it extends. Collapsing the two
      // reports a dropped connection as a rejected code, sending the user back
      // to an authenticator that was right all along.
      throw AuthFailure(e.message, retryable: true);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
