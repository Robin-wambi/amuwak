import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';

/// Links an already-authenticated user to a `customers` row.
///
/// This is the repair path for an account stranded mid-signup: [SignupController]
/// creates the auth user, links, then refreshes, and a failure between the first
/// two steps left a user who could sign in forever without ever having a
/// customers row — every screen empty, because customer data is scoped by
/// `auth_customer_id()`. Signing in again never fixed it, since sign-in has no
/// name/phone to link with. Asking for them once, here, does.
///
/// `link_or_create_customer` is idempotent (it returns an existing link rather
/// than raising), so running this against an already-linked account is safe.
///
/// A plain injectable class, matching [SignupController], so it can be unit
/// tested with a mocked [AuthService] + [CustomerProfileRepository].
class CompleteProfileController {
  CompleteProfileController({
    required AuthService authService,
    required CustomerProfileRepository profileRepository,
  })  : _auth = authService,
        _profiles = profileRepository;

  final AuthService _auth;
  final CustomerProfileRepository _profiles;

  /// Links the caller and returns the `customers.id`. The session refresh must
  /// come last: the `customer` role claim is minted by the access-token hook
  /// only once the link exists, and the router keys off that claim.
  Future<String> complete({
    required String name,
    required String phone,
    required String email,
  }) async {
    final customerId = await _profiles.linkOrCreate(
      name: name,
      phone: phone,
      email: email,
    );
    await _auth.refreshSession();
    return customerId;
  }
}
