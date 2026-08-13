import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/login_screen.dart';
import 'package:amuwak_staff/src/auth/recovery_link_state.dart';

class _MockAuthService extends Mock implements AuthService {}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required AuthService authService,
  RecoveryLinkResult recoveryLink = RecoveryLinkResult.none,
  String launchUrl = 'https://robin-wambi.github.io/amuwak/',
  bool codeExchangeFailed = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        recoveryLinkOutcomeProvider.overrideWithValue(recoveryLink),
        launchUriProvider.overrideWithValue(Uri.parse(launchUrl)),
        // How supabase_flutter reports a `?code=` it could not exchange: an
        // error on the auth stream, never a return value.
        if (codeExchangeFailed)
          authStateProvider.overrideWith((ref) => Stream<AuthState>.error(
              const AuthException(
                  'Code verifier could not be found in local storage.'))),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
}

void main() {
  late _MockAuthService auth;

  setUp(() {
    auth = _MockAuthService();
  });

  testWidgets('empty fields show validation messages on tap', (tester) async {
    await _pumpLogin(tester, authService: auth);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    verifyNever(() => auth.signInWithEmailPassword(
        email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('successful login calls the service and shows no error',
      (tester) async {
    when(() => auth.signInWithEmailPassword(
        email: any(named: 'email'),
        password: any(named: 'password'))).thenAnswer((_) async {});

    await _pumpLogin(tester, authService: auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'rider1@amuwak.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret-pass');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => auth.signInWithEmailPassword(
        email: 'rider1@amuwak.co', password: 'secret-pass')).called(1);
  });

  testWidgets('AuthFailure shows the error message and stays on login',
      (tester) async {
    when(() => auth.signInWithEmailPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(AuthFailure('Invalid login credentials'));

    await _pumpLogin(tester, authService: auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'rider1@amuwak.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'nope');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a non-AuthFailure error on login shows a generic message',
      (tester) async {
    when(() => auth.signInWithEmailPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(Exception('SocketException: connection failed'));

    await _pumpLogin(tester, authService: auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'rider1@amuwak.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret-pass');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Could not sign in. Please try again.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'a non-AuthFailure error on forgot-password shows a generic message',
      (tester) async {
    when(() => auth.sendPasswordReset(any()))
        .thenThrow(Exception('SocketException: connection failed'));

    await _pumpLogin(tester, authService: auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'rider1@amuwak.co');
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Could not send the reset link. Please try again.'),
        findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'an AuthFailure on forgot-password shows the failure message',
      (tester) async {
    when(() => auth.sendPasswordReset(any()))
        .thenThrow(AuthFailure('Email not found'));

    await _pumpLogin(tester, authService: auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'rider1@amuwak.co');
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Email not found'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('submitting the password field logs in (onFieldSubmitted)',
      (tester) async {
    when(() => auth.signInWithEmailPassword(
        email: any(named: 'email'),
        password: any(named: 'password'))).thenAnswer((_) async {});

    await _pumpLogin(tester, authService: auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'rider1@amuwak.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret-pass');
    // Triggers onFieldSubmitted on the password field rather than the button.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => auth.signInWithEmailPassword(
        email: 'rider1@amuwak.co', password: 'secret-pass')).called(1);
  });

  testWidgets('Forgot password with no email prompts for one and does not send',
      (tester) async {
    await _pumpLogin(tester, authService: auth);

    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(find.text('Enter your email first'), findsOneWidget);
    verifyNever(() => auth.sendPasswordReset(any()));
  });

  testWidgets('Forgot password with an email sends a reset and confirms',
      (tester) async {
    when(() => auth.sendPasswordReset(any())).thenAnswer((_) async {});

    await _pumpLogin(tester, authService: auth);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'rider1@amuwak.co');
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    verify(() => auth.sendPasswordReset('rider1@amuwak.co')).called(1);
    expect(find.textContaining('reset link'), findsOneWidget);
  });

  group('recovery link notice', () {
    testWidgets('says nothing on an ordinary visit', (tester) async {
      await _pumpLogin(tester, authService: auth);

      expect(find.textContaining('That link'), findsNothing);
    });

    testWidgets('explains a token hash the server rejected', (tester) async {
      // The cross-device shape. A rider who opened the mail on their phone got
      // no session and, without this, no reason to think the link was why.
      await _pumpLogin(
        tester,
        authService: auth,
        recoveryLink: RecoveryLinkResult.failed,
        launchUrl:
            'https://robin-wambi.github.io/amuwak/?token_hash=stale&type=recovery',
      );

      expect(find.text('That link has already been used'), findsOneWidget);
      // Where it was opened is irrelevant for a spent token, and saying
      // otherwise sends the rider hunting a device fault that is not there.
      expect(find.textContaining('same browser'), findsNothing);
    });

    testWidgets('explains a PKCE code that could not be exchanged',
        (tester) async {
      await _pumpLogin(
        tester,
        authService: auth,
        launchUrl: 'https://robin-wambi.github.io/amuwak/?code=abc123',
        codeExchangeFailed: true,
      );
      await tester.pump();

      expect(find.text('That link could not be opened here'), findsOneWidget);
      expect(find.textContaining('same browser'), findsOneWidget);
    });

    testWidgets('does not blame a link for an ordinary failed sign-in',
        (tester) async {
      // A mistyped password errors the same auth stream. Without the URL check
      // every bad login would accuse an email nobody opened.
      await _pumpLogin(
        tester,
        authService: auth,
        codeExchangeFailed: true,
      );
      await tester.pump();

      expect(find.textContaining('That link'), findsNothing);
    });

    testWidgets('leaves the rider a way to get a fresh link', (tester) async {
      // The notice is only useful next to the fix, which is why it lives on
      // this screen rather than a dead-end of its own.
      await _pumpLogin(
        tester,
        authService: auth,
        recoveryLink: RecoveryLinkResult.failed,
      );

      expect(find.text('Forgot password?'), findsOneWidget);
    });
  });
}
