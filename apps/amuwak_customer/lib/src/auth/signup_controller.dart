import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';

/// Orchestrates customer self-signup: create the auth user, link/create the
/// `customers` row, then refresh the JWT so the `customer` role claim (minted by
/// the access-token hook once linked) is present for subsequent RLS-gated calls.
///
/// A plain injectable class (not a provider) so it can be unit-tested with a
/// mocked [AuthService] + [CustomerProfileRepository]; the screen constructs it
/// from the corresponding providers.
class SignupController {
  SignupController({
    required AuthService authService,
    required CustomerProfileRepository profileRepository,
  })  : _auth = authService,
        _profiles = profileRepository;

  final AuthService _auth;
  final CustomerProfileRepository _profiles;

  /// Signs up and links, returning the new `customers.id`. Order matters:
  /// signup must establish a session (email confirmation is disabled for v1)
  /// before `linkOrCreate` can run under the authenticated caller, and the
  /// session refresh must come last so the `customer` claim reflects the link.
  Future<String> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _auth.signUpWithEmailPassword(email: email, password: password);
    final customerId = await _profiles.linkOrCreate(
      name: name,
      phone: phone,
      email: email,
    );
    await _auth.refreshSession();
    return customerId;
  }
}
