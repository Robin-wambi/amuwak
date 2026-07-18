import 'package:http/http.dart' as http;

/// An [http.Client] that caps how long a single request may wait for a
/// response, so a dead or stalled network fails fast with a [TimeoutException]
/// instead of hanging the caller indefinitely.
///
/// Passed to `Supabase.initialize(httpClient: ...)`, it covers every PostgREST
/// read/write, RPC, Storage, and Auth call. Realtime uses a separate websocket
/// transport and is unaffected. Mirrors the staff app's client of the same name.
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
