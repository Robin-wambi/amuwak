import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

// `SupabaseClient.rpc<T>()` returns a `PostgrestFilterBuilder<T>`, not a
// `Future` — mocktail cannot stub `thenAnswer((_) async => [...])` against
// that declared return type. RecoveryCodesService exposes an injectable
// [RpcFn] seam for exactly this; `_RpcCallable` gives that plain function
// type something mocktail can mock (a `call` method), per the fallback
// documented in the task brief.
abstract class _RpcCallable {
  Future<dynamic> call(String fn);
}

class _MockRpc extends Mock implements _RpcCallable {}

void main() {
  late _MockClient client;
  late _MockFunctions functions;
  late RecoveryCodesService service;

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    service = RecoveryCodesService(client: client);
  });

  group('generate', () {
    late _MockRpc rpc;

    setUp(() {
      rpc = _MockRpc();
      service = RecoveryCodesService(client: client, rpc: rpc.call);
    });

    test('returns the codes the server minted', () async {
      when(() => rpc('generate_mfa_recovery_codes'))
          .thenAnswer((_) async => ['AAAAA-BBBBB-CCCCC-DDDDD', 'EEEEE-FFFFF-00000-11111']);

      final codes = await service.generate();

      expect(codes, hasLength(2));
      expect(codes.first, 'AAAAA-BBBBB-CCCCC-DDDDD');
    });

    test('an aal1 caller is rejected, not silently given codes', () async {
      // The database raises here. Surfacing it as AuthFailure keeps the UI on
      // one error type.
      when(() => rpc('generate_mfa_recovery_codes'))
          .thenThrow(PostgrestException(
              message: 'generate_mfa_recovery_codes requires an aal2 session'));

      await expectLater(service.generate(), throwsA(isA<AuthFailure>()));
    });
  });

  group('redeem', () {
    test('posts the code to the edge function', () async {
      when(() => functions.invoke('redeem-recovery-code',
              body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(status: 200, data: {'ok': true}));

      await service.redeem('AAAAA-BBBBB-CCCCC-DDDDD');

      verify(() => functions.invoke('redeem-recovery-code',
          body: {'code': 'AAAAA-BBBBB-CCCCC-DDDDD'})).called(1);
    });

    test('a rejected code surfaces the server message', () async {
      when(() => functions.invoke('redeem-recovery-code',
              body: any(named: 'body')))
          .thenThrow(FunctionException(
              status: 400, details: {'error': 'That recovery code is not valid.'}));

      await expectLater(
        service.redeem('NOPE'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.message, 'message', contains('not valid'))
            .having((f) => f.retryable, 'retryable', isFalse)),
      );
    });

    test('a server-side failure is retryable, a bad code is not', () async {
      // 5xx means we never got a verdict — "try again" is honest advice here
      // and misleading for a 400.
      when(() => functions.invoke('redeem-recovery-code',
              body: any(named: 'body')))
          .thenThrow(FunctionException(
              status: 500, details: {'error': 'Could not check that code.'}));

      await expectLater(
        service.redeem('AAAAA-BBBBB-CCCCC-DDDDD'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.retryable, 'retryable', isTrue)),
      );
    });
  });
}
