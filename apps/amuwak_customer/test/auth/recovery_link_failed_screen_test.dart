import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/app/router.dart';
import 'package:amuwak_customer/src/auth/recovery_link_failed_screen.dart';
import 'package:amuwak_customer/src/auth/recovery_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The screen navigates with `context.go`, so it needs a real router under it.
Widget _harness({RecoveryLinkResult outcome = RecoveryLinkResult.none}) {
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
    overrides: [recoveryLinkOutcomeProvider.overrideWithValue(outcome)],
    child: MaterialApp.router(
        theme: buildAmuwakTheme(), routerConfig: router),
  );
}

void main() {
  testWidgets('says a redeemed-or-expired link cannot be used twice',
      (tester) async {
    // A token hash the server rejected. It carries its own proof, so the
    // browser it is opened in is irrelevant — saying otherwise would send the
    // user hunting for a device problem that is not there.
    await tester.pumpWidget(_harness(outcome: RecoveryLinkResult.failed));
    await tester.pumpAndSettle();

    expect(find.textContaining('only be used once'), findsOneWidget);
    expect(find.textContaining('same browser'), findsNothing);
  });

  testWidgets('names the browser when a PKCE link is the one that failed',
      (tester) async {
    // The older `?code=` shape: the code verifier lives in the browser that
    // asked for the reset, so "open it here" is the entire fix and the user
    // cannot guess it.
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

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
