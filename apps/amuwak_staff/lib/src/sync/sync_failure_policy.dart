import 'dart:async';

/// True when [error] is a transient transport/connectivity failure that we
/// should retry indefinitely WITHOUT counting it toward the dead-letter
/// budget. A rider losing signal must never turn good uploads into errors.
///
/// Deliberately conservative: only transport-layer failures qualify. Anything
/// the server actually responded to (e.g. [PostgrestException]) or any logic
/// error (e.g. [StateError]) is treated as permanent so it can still
/// dead-letter and surface to the rider.
bool isTransientSyncError(Object error) {
  if (error is TimeoutException) return true;
  final type = error.runtimeType.toString();
  if (type == 'SocketException' ||
      type == 'ClientException' ||
      type == 'HttpException' ||
      type == 'HandshakeException') {
    return true;
  }
  // runtimeType names above are mangled in --obfuscate / release-web builds,
  // so the string fallback below is the real safety net there. Keep the
  // class-name substrings (handshakeexception, timeoutexception) in sync with
  // the type list above for that reason.
  final msg = error.toString().toLowerCase();
  return msg.contains('socketexception') ||
      msg.contains('clientexception') ||
      msg.contains('httpexception') ||
      msg.contains('handshakeexception') ||
      msg.contains('timeoutexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection closed before') ||
      msg.contains('connection refused') ||
      msg.contains('connection reset') ||
      msg.contains('connection attempt failed') ||
      msg.contains('network is unreachable') ||
      msg.contains('software caused connection abort') ||
      msg.contains('xmlhttprequest'); // web offline
}

/// Maps a stored raw outbox/pull error string to a short, rider-readable
/// line for the SyncErrorsScreen. Keeps the raw text out of the rider's face
/// while [isTransientSyncError] keeps the underlying engine behaviour correct.
String friendlySyncError(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Could not be saved.';
  final t = raw.toLowerCase();
  if (t.contains('23505') || t.contains('duplicate key')) {
    return 'Already saved on the server.';
  }
  if (t.contains('23503') || t.contains('foreign key')) {
    return 'Linked record is missing on the server.';
  }
  if (t.contains('row-level security') ||
      t.contains('42501') ||
      t.contains('permission denied') ||
      _hasStatus(t, 403)) {
    return 'Not allowed on the server (permissions).';
  }
  if (t.contains('jwt') ||
      _hasStatus(t, 401) ||
      t.contains('not authenticated')) {
    return 'Sign-in expired — sign out and back in.';
  }
  if (isTransientSyncError(raw)) {
    // This text is only ever shown on a dead-lettered row, which does NOT
    // retry on its own — so point the rider at the Retry button rather than
    // promising automatic recovery.
    return 'Connection problem — tap Retry to try again.';
  }
  return 'Could not be saved (server rejected it).';
}

/// Maps a stored pull (server-read) dead-letter error to a short, rider-
/// readable line for the SyncErrorsScreen. Mirrors [friendlySyncError] but
/// uses read-oriented phrasing — these rows are server-side data the rider
/// cannot retry locally, so the copy points at "needs a fix on the server"
/// rather than a Retry affordance. The raw error stays in local logs for
/// whoever fixes the server; it is kept out of the rider's face here.
String friendlyPullError(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return 'Server data could not be loaded.';
  }
  final t = raw.toLowerCase();
  if (t.contains('row-level security') ||
      t.contains('42501') ||
      t.contains('permission denied') ||
      _hasStatus(t, 403)) {
    return 'Not allowed to read this from the server (permissions).';
  }
  if (t.contains('jwt') ||
      _hasStatus(t, 401) ||
      t.contains('not authenticated')) {
    return 'Sign-in expired — sign out and back in.';
  }
  if (isTransientSyncError(raw)) {
    return 'Connection problem — could not load this server data.';
  }
  return 'Server data could not be loaded — needs a fix on the server.';
}

/// True when [haystack] mentions HTTP status [code] as a standalone token
/// rather than as digits embedded in a longer number or identifier. Avoids
/// a bare `contains('401')` misfiring on e.g. `"4012 retries"`, Postgres
/// code `"42P01"`, or a rowId that happens to contain those digits.
bool _hasStatus(String haystack, int code) =>
    RegExp('\\b$code\\b').hasMatch(haystack);
