import 'dart:async';
import 'dart:convert';

import 'package:amuwak_staff/src/bootstrap/timeout_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Inner client driven by an injected [send] handler so tests control timing
/// and can observe forwarding + close.
class _FakeInnerClient extends http.BaseClient {
  _FakeInnerClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;
  http.BaseRequest? lastRequest;
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    lastRequest = request;
    return _handler(request);
  }

  @override
  void close() => closeCount++;
}

http.StreamedResponse _okResponse() =>
    http.StreamedResponse(Stream.value(utf8.encode('ok')), 200);

http.BaseRequest _req() =>
    http.Request('GET', Uri.parse('https://example.test/orders'));

void main() {
  group('TimeoutHttpClient', () {
    test('returns the inner response when it resolves within the timeout',
        () async {
      final client = TimeoutHttpClient(
        _FakeInnerClient((_) async => _okResponse()),
        timeout: const Duration(seconds: 5),
      );

      final response = await client.send(_req());

      expect(response.statusCode, 200);
      expect(await response.stream.bytesToString(), 'ok');
    });

    test('throws TimeoutException when the inner send exceeds the timeout',
        () async {
      // Inner never completes → the wrapper's timeout must fire.
      final client = TimeoutHttpClient(
        _FakeInnerClient((_) => Completer<http.StreamedResponse>().future),
        timeout: const Duration(milliseconds: 20),
      );

      expect(client.send(_req()), throwsA(isA<TimeoutException>()));
    });

    test('forwards the request unchanged to the inner client', () async {
      final inner = _FakeInnerClient((_) async => _okResponse());
      final client = TimeoutHttpClient(inner);
      final request = _req();

      await client.send(request);

      expect(inner.lastRequest, same(request));
    });

    test('close() closes the inner client', () {
      final inner = _FakeInnerClient((_) async => _okResponse());
      TimeoutHttpClient(inner).close();

      expect(inner.closeCount, 1);
    });

    test('defaults to a 20 second timeout', () {
      final client = TimeoutHttpClient(_FakeInnerClient((_) async {
        return _okResponse();
      }));

      expect(client.timeout, const Duration(seconds: 20));
    });
  });
}
