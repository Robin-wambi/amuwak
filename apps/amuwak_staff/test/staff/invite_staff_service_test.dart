import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_staff/src/staff/invite_staff_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _FakeFunctionResponse extends Fake implements FunctionResponse {}

void main() {
  late _MockSupabaseClient client;
  late _MockFunctionsClient functions;
  late InviteStaffService service;

  setUp(() {
    client = _MockSupabaseClient();
    functions = _MockFunctionsClient();
    when(() => client.functions).thenReturn(functions);
    service = InviteStaffService(client);
  });

  test('sends a normalised payload to the invite-staff function', () async {
    when(() => functions.invoke('invite-staff',
        body: any(named: 'body'))).thenAnswer((_) async => _FakeFunctionResponse());

    await service.invite(
      email: '  NewRider@Amuwak.CO ',
      displayName: '  Jane Doe ',
      username: '  JaneD ',
      role: 'driver',
    );

    final body = verify(() => functions.invoke('invite-staff',
        body: captureAny(named: 'body'))).captured.single as Map;
    expect(body['email'], 'newrider@amuwak.co');
    expect(body['display_name'], 'Jane Doe');
    expect(body['username'], 'janed');
    expect(body['role'], 'driver');
  });

  test('InviteFailure.toString carries the human-readable message', () {
    expect(InviteFailure('Username already taken').toString(),
        'InviteFailure: Username already taken');
  });

  test('maps a plain-string error detail to InviteFailure', () async {
    when(() => functions.invoke('invite-staff', body: any(named: 'body')))
        .thenThrow(const FunctionException(
      status: 500,
      details: 'Edge function crashed',
    ));

    await expectLater(
      service.invite(
        email: 'a@b.co',
        displayName: 'A B',
        username: 'ab',
        role: 'driver',
      ),
      throwsA(isA<InviteFailure>().having(
        (e) => e.message,
        'message',
        'Edge function crashed',
      )),
    );
  });

  test('falls back to a generic message when no usable detail is present',
      () async {
    when(() => functions.invoke('invite-staff', body: any(named: 'body')))
        .thenThrow(const FunctionException(status: 500, details: null));

    await expectLater(
      service.invite(
        email: 'a@b.co',
        displayName: 'A B',
        username: 'ab',
        role: 'driver',
      ),
      throwsA(isA<InviteFailure>().having(
        (e) => e.message,
        'message',
        'Could not send the invite. Please try again.',
      )),
    );
  });

  test('maps the server error body to InviteFailure', () async {
    when(() => functions.invoke('invite-staff', body: any(named: 'body')))
        .thenThrow(const FunctionException(
      status: 409,
      details: {'error': 'Username already taken'},
    ));

    await expectLater(
      service.invite(
        email: 'a@b.co',
        displayName: 'A B',
        username: 'ab',
        role: 'driver',
      ),
      throwsA(isA<InviteFailure>().having(
        (e) => e.message,
        'message',
        'Username already taken',
      )),
    );
  });
}
