import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Seam for [RecoveryCodesService.generate]'s RPC call.
///
/// `SupabaseClient.rpc<T>()` returns a `PostgrestFilterBuilder<T>`, not a
/// `Future` — it is awaitable only because the builder implements `Future`.
/// mocktail cannot stub that return type with a plain `Future`-returning
/// closure, so tests inject a real function here instead of stubbing
/// `SupabaseClient.rpc` directly.
typedef RpcFn = Future<dynamic> Function(String fn);

/// Recovery codes: the way back in for a staff member who has lost their
/// authenticator.
///
/// The two paths are deliberately asymmetric.
///
///   * [generate] calls the RPC directly. The caller is already at aal2 and
///     needs no elevated privilege.
///   * [redeem] goes through the `redeem-recovery-code` Edge Function and NEVER
///     the RPC directly. The RPC alone burns the code without deleting the
///     factor, which would leave the user locked out and a code down.
///
/// After a successful [redeem] the caller must refresh the session: the
/// assurance level is computed from factors cached on the session user, so
/// without a refresh the gate would not notice the factor is gone.
class RecoveryCodesService {
  RecoveryCodesService({SupabaseClient? client, RpcFn? rpc})
      : _client = client ?? Supabase.instance.client,
        _rpc = rpc;

  final SupabaseClient _client;
  final RpcFn? _rpc;

  Future<dynamic> _callRpc(String fn) =>
      _rpc != null ? _rpc(fn) : _client.rpc<dynamic>(fn);

  /// Mint a fresh set, replacing any previous one. The plaintext exists only in
  /// this return value — it is never stored and never retrievable again.
  Future<List<String>> generate() async {
    try {
      final result = await _callRpc('generate_mfa_recovery_codes');
      return (result as List).cast<String>();
    } on PostgrestException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Spend a code. On success the user's TOTP factor is gone and two-factor is
  /// off until they enrol again.
  Future<void> redeem(String code) async {
    try {
      await _client.functions
          .invoke('redeem-recovery-code', body: {'code': code});
    } on FunctionException catch (e) {
      // A 5xx never reached a verdict, so "try again" is honest. A 400 means
      // the code was read and rejected — retrying it changes nothing.
      throw AuthFailure(_messageFrom(e), retryable: e.status >= 500);
    }
  }

  static String _messageFrom(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Could not use that recovery code. Please try again.';
  }
}
