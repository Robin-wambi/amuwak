import 'package:http/http.dart' as http;

/// An [http.Client] that caps how long a single request may wait for a
/// response, so a dead or stalled network fails fast with a [TimeoutException]
/// instead of hanging the caller indefinitely.
///
/// Passed to `Supabase.initialize(httpClient: ...)`, it covers every PostgREST
/// read/write, RPC, Storage, and Auth call. Realtime uses a separate websocket
/// transport and is unaffected. A [TimeoutException] is classified transient by
/// `isTransientSyncError`, so once the outbox is live a timed-out queued write
/// skips without burning the dead-letter budget.
///
/// The timeout bounds time-to-response (headers); the response body stream is
/// small for our PostgREST calls and arrives with the headers, so this is the
/// right guard for the "hangs on poor network" failure we're fixing.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, {this.timeout = const Duration(seconds: 20)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() => _inner.close();
}
