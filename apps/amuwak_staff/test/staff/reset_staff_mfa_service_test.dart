import 'package:amuwak_staff/src/staff/reset_staff_mfa_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  late _MockClient client;
  late _MockFunctions functions;
  late ResetStaffMfaService service;

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    service = ResetStaffMfaService(client);
  });

  test('reports how many factors were cleared', () async {
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(data: {'factors_cleared': 1}, status: 200),
    );

    final cleared = await service.reset(staffId: 'staff-1');

    expect(cleared, 1);
    verify(() => functions.invoke('reset-staff-mfa',
        body: {'target_staff_id': 'staff-1'})).called(1);
  });

  test('treats a target with no factors as a success, not an error', () async {
    // Resetting someone who never enrolled is harmless and idempotent — the
    // manager should be told plainly, not shown a failure.
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(data: {'factors_cleared': 0}, status: 200),
    );

    expect(await service.reset(staffId: 'staff-1'), 0);
  });

  test('surfaces the server message so the manager sees the real reason',
      () async {
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
      FunctionException(
        status: 403,
        details: {'error': 'Only managers can do that'},
      ),
    );

    await expectLater(
      service.reset(staffId: 'staff-1'),
      throwsA(isA<ResetMfaFailure>().having(
          (e) => e.message, 'message', 'Only managers can do that')),
    );
  });

  test('falls back to a generic message when the server sends no detail',
      () async {
    when(() => functions.invoke(any(), body: any(named: 'body')))
        .thenThrow(FunctionException(status: 500));

    await expectLater(
      service.reset(staffId: 'staff-1'),
      throwsA(isA<ResetMfaFailure>().having((e) => e.message, 'message',
          contains('Could not reset'))),
    );
  });
}
