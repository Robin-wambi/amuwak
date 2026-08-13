import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'mfa_service.dart';
import 'recovery_codes_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final mfaServiceProvider = Provider<MfaService>((ref) => MfaService());

final recoveryCodesServiceProvider =
    Provider<RecoveryCodesService>((ref) => RecoveryCodesService());

/// Whether this session still owes a second factor.
///
/// Recomputed on every auth event, because clearing the challenge upgrades the
/// session to aal2 and raises `mfaChallengeVerified` — the gate has to notice
/// that and let the user through.
///
/// Fails open. `needsChallenge` parses the access token and casts its `amr`
/// claim, so a malformed or claim-stripped token throws — and AuthGate reads
/// this straight from `build()`, where an escaping error replaces the whole app
/// with a red screen offering no dashboard, no login, not even a sign-out. MFA
/// is opt-in, so a session that cannot be reasoned about is let through rather
/// than locked out.
final needsMfaChallengeProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  try {
    return ref.watch(mfaServiceProvider).needsChallenge;
  } catch (e, st) {
    developer.log('Could not read the assurance level; assuming no challenge.',
        name: 'needsMfaChallenge', error: e, stackTrace: st);
    return false;
  }
});

/// Whether this account has a verified second factor.
///
/// Drives the Account entry's On/Off label so an enrolled staff member is told
/// what they already have instead of being sent into a second enrolment that
/// can only fail. Callers `invalidate` it after enrolling or removing a factor.
///
/// Errors surface as [AsyncError] rather than throwing — callers show no label
/// rather than breaking the Account tab over a status line.
final mfaEnabledProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  final factors = await ref.watch(mfaServiceProvider).verifiedFactors();
  return factors.isNotEmpty;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserIdProvider = Provider<String?>((ref) {
  final fromStream = ref.watch(authStateProvider).valueOrNull?.session?.user.id;
  if (fromStream != null) return fromStream;
  // Cold-start window: supabase_flutter restores the persisted session during
  // initialize(), but `authStateProvider` only emits `initialSession` a frame or
  // two later. Fall back to the restored user so a returning staff member is
  // recognised immediately and AuthGate doesn't flash the login screen. On true
  // sign-out both sources are null, so this still resolves to null.
  return ref.watch(authServiceProvider).currentUser?.id;
});

/// The current auth lifecycle event (signedIn, passwordRecovery, …) from the
/// auth stream — not a sticky "last seen" latch; that stickiness lives in
/// `AuthGate`'s `_recovering` flag. AuthGate watches this to detect when an
/// invite/reset link lands so it can route to the Set Password screen. Exposed
/// as its own provider so tests can drive routing without constructing a full
/// [AuthState]/[Session].
final currentAuthEventProvider = Provider<AuthChangeEvent?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.event;
});

/// The staff role is injected by the custom_access_token_hook (Supabase
/// migration 0009, fixed in 0025) under the `user_role` claim. It must NOT use
/// the reserved `role` claim: PostgREST reads `role` to pick the Postgres role
/// for each request (`SET ROLE`), so overwriting it with a staff role like
/// 'manager' — which is not a real Postgres role — makes every data request
/// fail. Read the staff role from `user_role` instead.
///
/// Returns null if the token is missing, malformed, already expired, or has no
/// `user_role` claim. The `exp` check guards against the narrow window where a
/// background token refresh has rotated the JWT but `authStateProvider` has not
/// yet emitted — without it we'd serve a stale role from the dead token until
/// the StreamProvider catches up.
String? roleFromAccessToken(String? token) {
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  final padded = parts[1] + '=' * ((4 - parts[1].length % 4) % 4);
  final Map<String, dynamic> payload;
  try {
    payload = jsonDecode(utf8.decode(base64Url.decode(padded)))
        as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final exp = payload['exp'];
  if (exp is int) {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    // Allow a small clock-skew leeway so a device whose clock runs slightly
    // ahead of the token issuer doesn't reject an otherwise-valid token.
    const leeway = Duration(seconds: 30);
    if (DateTime.now().toUtc().isAfter(expiresAt.add(leeway))) return null;
  }
  final role = payload['user_role'];
  return role is String ? role : null;
}

final currentRoleProvider = Provider<String?>((ref) {
  final token = ref.watch(authStateProvider).valueOrNull?.session?.accessToken;
  return roleFromAccessToken(token);
});
