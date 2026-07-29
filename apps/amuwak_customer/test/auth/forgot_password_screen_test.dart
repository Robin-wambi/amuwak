import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/app/router.dart';
import 'package:amuwak_customer/src/auth/forgot_password_screen.dart';
import 'package:amuwak_customer/src/auth/recovery_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

Widget _harness(AuthService auth) {
  final router = GoRouter(
    initialLocation: kForgotPasswordRoute,
    routes: [
      GoRoute(
        path: kForgotPasswordRoute,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('sign in screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      passwordResetRedirectProvider
          .overrideWithValue('https://customer.test/'),
    ],
    child: MaterialApp.router(routerConfig: router, theme: buildAmuwakTheme()),
  );
}

void main() {
  late _MockAuthService auth;

  setUp(() => auth = _MockAuthService());

  void stubSend() {
    when(() => auth.sendPasswordReset(any(),
        redirectTo: any(named: 'redirectTo'))).thenAnswer((_) async {});
  }

  void verifyNeverSent() {
    verifyNever(() => auth.sendPasswordReset(any(),
        redirectTo: any(named: 'redirectTo')));
  }

  testWidgets('will not send to an address that is not an email',
      (tester) async {
    stubSend();
    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    verifyNeverSent();
  });

  testWidgets('sends the link back to this app, not the staff app',
      (tester) async {
    stubSend();
    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ada@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    verify(() => auth.sendPasswordReset('ada@example.com',
        redirectTo: 'https://customer.test/')).called(1);
  });

  testWidgets('confirms conditionally, never revealing whether the account exists',
      (tester) async {
    // OWASP: the response must not differ for a registered vs unregistered
    // address. Supabase's endpoint is already enumeration-safe; the wording has
    // to keep that promise rather than assert an email was sent.
    stubSend();
    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ada@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(find.text('Send reset link'), findsNothing);
  });

  testWidgets('offers a retry when sending fails', (tester) async {
    when(() => auth.sendPasswordReset(any(),
            redirectTo: any(named: 'redirectTo')))
        .thenThrow(AuthFailure('rate limited'));

    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ada@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not send'), findsOneWidget);
    // Still on the form, and able to try again.
    expect(find.text('Send reset link'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('locks the button while sending', (tester) async {
    final pending = Completer<void>();
    when(() => auth.sendPasswordReset(any(),
        redirectTo: any(named: 'redirectTo'))).thenAnswer((_) => pending.future);

    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ada@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    pending.complete();
    await tester.pumpAndSettle();
    verify(() => auth.sendPasswordReset(any(),
        redirectTo: any(named: 'redirectTo'))).called(1);
  });

  testWidgets('offers a way back to sign in', (tester) async {
    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.text('sign in screen'), findsOneWidget);
  });
}
