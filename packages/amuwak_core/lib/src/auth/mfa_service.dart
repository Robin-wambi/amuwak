import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// What the user needs on screen to finish enrolling an authenticator app.
///
/// Both fields are secrets: they are equivalent to the second factor itself, so
/// never log them.
class TotpEnrolment {
  const TotpEnrolment({
    required this.factorId,
    required this.qrCodeSvg,
    required this.otpauthUri,
    required this.secret,
  });

  /// Identifies the factor in the follow-up verify call.
  final String factorId;

  /// An SVG, not a URL. Render it directly, or prepend
  /// `data:image/svg+xml;utf-8,` to use it as an image source.
  ///
  /// Both apps prefer [otpauthUri] — they already ship `qr_flutter` for order
  /// tags, so drawing the code themselves avoids adding an SVG renderer.
  final String qrCodeSvg;

  /// The raw `otpauth://` URI the QR encodes. Render it with the app's existing
  /// QR widget, or hand it to the OS to open an authenticator app directly.
  final String otpauthUri;

  /// Shown alongside the QR for anyone who cannot scan one — a cracked screen
  /// or a desktop browser with no camera.
  final String secret;
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
          qrCodeSvg: totp.qrCode,
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
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
