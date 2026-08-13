import 'package:supabase_flutter/supabase_flutter.dart';

/// Callback shape the staff list depends on, so the screen can be tested with a
/// plain function instead of a live client. Mirrors [InviteStaffFn].
typedef ResetStaffMfaFn = Future<int> Function({required String staffId});

/// Raised when a reset can't be performed — caller isn't a manager, caller owes
/// their own MFA challenge, target not found. Carries the server's message.
class ResetMfaFailure implements Exception {
  ResetMfaFailure(this.message);
  final String message;
  @override
  String toString() => 'ResetMfaFailure: $message';
}

/// Clears a staff member's TOTP factors by calling the `reset-staff-mfa` Edge
/// Function, which runs with the service-role key and enforces the manager
/// check server-side. Nothing privileged happens in the client — the UI only
/// hides the button.
class ResetStaffMfaService {
  ResetStaffMfaService(this._client);

  final SupabaseClient _client;

  /// Returns the number of verified factors cleared. Zero is a success: the
  /// target simply had no authenticator set up.
  Future<int> reset({required String staffId}) async {
    try {
      final response = await _client.functions
          .invoke('reset-staff-mfa', body: {'target_staff_id': staffId});
      final data = response.data;
      if (data is Map && data['factors_cleared'] is int) {
        return data['factors_cleared'] as int;
      }
      return 0;
    } on FunctionException catch (e) {
      throw ResetMfaFailure(_messageFrom(e));
    }
  }

  /// Pulls the server's `{ "error": "..." }` body out of a FunctionException so
  /// the manager sees the real reason rather than a bare status code.
  static String _messageFrom(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    return 'Could not reset their two-factor. Please try again.';
  }
}
