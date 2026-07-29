import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_core/amuwak_core.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _FakeAuthResponse extends Fake implements AuthResponse {}

class _FakeUserResponse extends Fake implements UserResponse {}

void main() {
  late _MockGoTrue goTrue;
  late AuthService service;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
  });

  setUp(() {
    goTrue = _MockGoTrue();
    service = AuthService(goTrue: goTrue);
  });

  group('signInWithEmailPassword', () {
    test('forwards a trimmed, lower-cased email and the password', () async {
      when(() => goTrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => _FakeAuthResponse());

      await service.signInWithEmailPassword(
        email: '  Rider1@Amuwak.CO  ',
        password: 'secret-pass',
      );

      verify(() => goTrue.signInWithPassword(
            email: 'rider1@amuwak.co',
            password: 'secret-pass',
          )).called(1);
    });

    test('wraps AuthException in AuthFailure', () async {
      when(() => goTrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AuthException('Invalid login credentials'));

      await expectLater(
        service.signInWithEmailPassword(
          email: 'a@b.co',
          password: 'x',
        ),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          'Invalid login credentials',
        )),
      );
    });
  });

  group('signUpWithEmailPassword', () {
    test('forwards a trimmed, lower-cased email and the password', () async {
      when(() => goTrue.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => _FakeAuthResponse());

      await service.signUpWithEmailPassword(
        email: '  New@Amuwak.CO  ',
        password: 'secret-pass',
      );

      verify(() => goTrue.signUp(
            email: 'new@amuwak.co',
            password: 'secret-pass',
          )).called(1);
    });

    test('wraps AuthException in AuthFailure', () async {
      when(() => goTrue.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AuthException('User already registered'));

      await expectLater(
        service.signUpWithEmailPassword(email: 'a@b.co', password: 'x'),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          'User already registered',
        )),
      );
    });
  });

  group('refreshSession', () {
    test('delegates to GoTrue.refreshSession', () async {
      when(() => goTrue.refreshSession())
          .thenAnswer((_) async => _FakeAuthResponse());
      await service.refreshSession();
      verify(() => goTrue.refreshSession()).called(1);
    });

    test('wraps AuthException in AuthFailure', () async {
      when(() => goTrue.refreshSession())
          .thenThrow(const AuthException('refresh failed'));
      await expectLater(
        service.refreshSession(),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('updatePassword', () {
    test('calls updateUser with the new password', () async {
      when(() => goTrue.updateUser(any()))
          .thenAnswer((_) async => _FakeUserResponse());

      await service.updatePassword('brand-new-pass');

      final attrs = verify(() => goTrue.updateUser(captureAny()))
          .captured
          .single as UserAttributes;
      expect(attrs.password, 'brand-new-pass');
    });

    test('wraps AuthException in AuthFailure', () async {
      when(() => goTrue.updateUser(any()))
          .thenThrow(const AuthException('Password too short'));

      await expectLater(
        service.updatePassword('x'),
        throwsA(isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          'Password too short',
        )),
      );
    });
  });

  group('sendPasswordReset', () {
    test('forwards a trimmed, lower-cased email to resetPasswordForEmail',
        () async {
      when(() => goTrue.resetPasswordForEmail(any(),
          redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async {});

      await service.sendPasswordReset('  Rider1@Amuwak.CO ');

      verify(() => goTrue.resetPasswordForEmail('rider1@amuwak.co')).called(1);
    });

    test('wraps AuthException in AuthFailure', () async {
      when(() => goTrue.resetPasswordForEmail(any(),
              redirectTo: any(named: 'redirectTo')))
          .thenThrow(const AuthException('rate limited'));

      await expectLater(
        service.sendPasswordReset('a@b.co'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('forwards a caller-supplied redirect target', () async {
      // Two apps share this auth project and the Site URL can only point at
      // one of them, so the customer app has to name its own origin or its
      // customers land in the staff app.
      when(() => goTrue.resetPasswordForEmail(any(),
          redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async {});

      await service.sendPasswordReset(
        'a@b.co',
        redirectTo: 'https://amuwak-customer.pages.dev/',
      );

      verify(() => goTrue.resetPasswordForEmail('a@b.co',
          redirectTo: 'https://amuwak-customer.pages.dev/')).called(1);
    });

    test('omits the redirect when none is given, deferring to the Site URL',
        () async {
      when(() => goTrue.resetPasswordForEmail(any(),
          redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async {});

      await service.sendPasswordReset('a@b.co');

      verify(() => goTrue.resetPasswordForEmail('a@b.co', redirectTo: null))
          .called(1);
    });
  });
}
