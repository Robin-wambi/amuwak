import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/app/router.dart';
import 'package:amuwak_customer/src/auth/recovery_link_failed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The screen navigates with `context.go`, so it needs a real router under it.
Widget _harness() {
  final router = GoRouter(
    initialLocation: kRecoveryLinkFailedRoute,
    routes: [
      GoRoute(
          path: kRecoveryLinkFailedRoute,
          builder: (_, __) => const RecoveryLinkFailedScreen()),
      GoRoute(
          path: kForgotPasswordRoute,
          builder: (_, __) => const Scaffold(body: Text('forgot page'))),
      GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('login page'))),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
        theme: buildAmuwakTheme(), routerConfig: router),
  );
}

void main() {
  testWidgets('names the one thing the user has to do differently',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // PKCE keeps the code verifier in the browser that asked for the reset, so
    // "open it here" is the entire fix — and the user cannot guess it.
    expect(find.textContaining('same browser'), findsOneWidget);
  });

  testWidgets('sends the user to ask for a fresh link', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request a new link'));
    await tester.pumpAndSettle();

    expect(find.text('forgot page'), findsOneWidget);
  });

  testWidgets('leaves a way back to sign in', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
  });
}
