import 'package:supabase_flutter/supabase_flutter.dart';

/// Callback shape the invite form depends on. Lets the screen be tested with a
/// plain function and lets the dashboard wire it to [InviteStaffService.invite].
typedef InviteStaffFn = Future<void> Function({
  required String email,
  required String displayName,
  required String username,
  required String role,
});

/// Raised when an invite can't be issued (caller isn't a manager, duplicate
/// username/email, validation failure on the server, …). Carries a
/// human-readable message for the UI.
class InviteFailure implements Exception {
  InviteFailure(this.message);
  final String message;
  @override
  String toString() => 'InviteFailure: $message';
}

/// Issues staff invites by calling the `invite-staff` Edge Function. The
/// function runs with the service-role key server-side — it verifies the caller
/// is a manager, sends the Supabase invite email, and inserts the staff row.
/// Nothing privileged happens in the client.
class InviteStaffService {
  InviteStaffService(this._client);

  final SupabaseClient _client;

  Future<void> invite({
    required String email,
    required String displayName,
    required String username,
    required String role,
  }) async {
    try {
      await _client.functions.invoke('invite-staff', body: {
        'email': email.trim().toLowerCase(),
        'display_name': displayName.trim(),
        'username': username.trim().toLowerCase(),
        'role': role,
      });
    } on FunctionException catch (e) {
      throw InviteFailure(_messageFrom(e));
    }
  }

  /// Pulls the server's `{ "error": "..." }` body out of a FunctionException so
  /// the rider sees the real reason (e.g. "Username already taken") rather than
  /// a bare status code.
  static String _messageFrom(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    return 'Could not send the invite. Please try again.';
  }
}
