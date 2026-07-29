import 'package:amuwak_core/amuwak_core.dart';

/// The two halves of a password recovery, kept out of the widgets so they can
/// be unit tested without pumping a router or a form.
///
/// A plain injectable class, matching [SignupController] and
/// [CompleteProfileController].
class PasswordResetController {
  PasswordResetController({required AuthService authService})
      : _auth = authService;

  final AuthService _auth;

  /// Ask Supabase to email a recovery link.
  ///
  /// [redirectTo] must be this app's own origin: the Site URL points at the
  /// staff app, so without it a customer follows the link into the wrong
  /// application.
  ///
  /// Deliberately reports nothing about whether the address is registered —
  /// Supabase's endpoint is enumeration-safe and the UI keeps it that way by
  /// showing one message either way.
  Future<void> requestReset({
    required String email,
    required String redirectTo,
  }) =>
      _auth.sendPasswordReset(email, redirectTo: redirectTo);

  /// Set the new password and end the recovery session.
  ///
  /// The sign-out is not incidental. OWASP requires a normal login after a
  /// reset rather than auto-login, and the recovery link signs the user in, so
  /// something has to end that session deliberately. It also releases the
  /// sticky recovery flag, which is what lets the router move them on.
  ///
  /// Order matters: a failed update must NOT sign the user out. Doing so would
  /// destroy the recovery session and strand them with their old password and
  /// no way back except requesting another link.
  Future<void> setNewPassword(String password) async {
    await _auth.updatePassword(password);
    await _auth.signOut();
  }
}
