import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'mfa_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final mfaServiceProvider = Provider<MfaService>((ref) => MfaService());

/// Whether this session still owes a second factor.
///
/// Recomputed on every auth event, because clearing the challenge upgrades the
/// session to aal2 and raises `mfaChallengeVerified` — the gate has to notice
/// that and let the user through.
final needsMfaChallengeProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(mfaServiceProvider).needsChallenge;
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
