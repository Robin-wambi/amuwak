import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/auth/password_reset_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthService auth;
  late PasswordResetController controller;

  setUp(() {
    auth = _MockAuthService();
    controller = PasswordResetController(authService: auth);
  });

  group('requestReset', () {
    test('sends the link to the app that asked for it', () async {
      when(() => auth.sendPasswordReset(any(),
          redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async {});

      await controller.requestReset(
        email: 'ada@example.com',
        redirectTo: 'https://amuwak-customer.pages.dev/',
      );

      verify(() => auth.sendPasswordReset('ada@example.com',
          redirectTo: 'https://amuwak-customer.pages.dev/')).called(1);
    });
  });

  group('setNewPassword', () {
    test('updates the password, then signs out — in that order', () async {
      when(() => auth.updatePassword(any())).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      await controller.setNewPassword('correct horse battery');

      // OWASP: no auto-login after a reset. Signing out also releases the
      // sticky recovery flag, so the router sends them to /login.
      verifyInOrder([
        () => auth.updatePassword('correct horse battery'),
        () => auth.signOut(),
      ]);
    });

    test('a failed update does not sign the user out', () async {
      when(() => auth.updatePassword(any()))
          .thenThrow(AuthFailure('network unreachable'));

      await expectLater(
        controller.setNewPassword('correct horse battery'),
        throwsA(isA<AuthFailure>()),
      );

      // Signing out here would destroy the recovery session, stranding them
      // with the old password and no way back except another emailed link.
      verifyNever(() => auth.signOut());
    });
  });
}
