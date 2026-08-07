import 'dart:developer' as developer;

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
    final dynamic result;
    try {
      result = await _callRpc('generate_mfa_recovery_codes');
    } on PostgrestException catch (e) {
      throw AuthFailure(e.message);
    } catch (e, st) {
      // Not a PostgrestException — a dropped connection, DNS failure, or
      // timeout reached no verdict, so "try again" is honest advice. This is
      // the client boundary in front of an Edge Function whose first real
      // test is a manual production run, so log what actually happened
      // rather than losing it behind the generic message below.
      developer.log('generate_mfa_recovery_codes failed unexpectedly.',
          name: 'RecoveryCodesService', error: e, stackTrace: st);
      throw AuthFailure(
        'Could not reach the server. Please try again.',
        retryable: true,
      );
    }
    // Checked eagerly and outside the try above: an unchecked `as List` throws
    // a raw TypeError the UI has no way to render, and a lazy `.cast<String>()`
    // would defer that failure to whatever iterates the result later, far from
    // this error boundary.
    if (result is List && result.every((e) => e is String)) {
      return List<String>.from(result);
    }
    throw AuthFailure('Could not read the recovery codes from the server.');
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
    } catch (e, st) {
      // Not a FunctionException — a dropped connection, DNS failure, or
      // timeout, exactly the class of failure riders on poor connections hit.
      // No verdict was reached, so this is retryable. Log what actually
      // happened — this is the client boundary in front of an Edge Function
      // whose first real test is a manual production run. Deliberately does
      // NOT log `code`: it is the recovery code itself.
      developer.log('redeem-recovery-code failed unexpectedly.',
          name: 'RecoveryCodesService', error: e, stackTrace: st);
      throw AuthFailure(
        'Could not reach the server. Please try again.',
        retryable: true,
      );
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
