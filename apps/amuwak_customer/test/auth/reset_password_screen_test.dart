import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/auth/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

Widget _harness(AuthService auth) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: MaterialApp(
          theme: buildAmuwakTheme(), home: const ResetPasswordScreen()),
    );

void main() {
  late _MockAuthService auth;

  setUp(() => auth = _MockAuthService());

  void stubHappyPath() {
    when(() => auth.updatePassword(any())).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});
  }

  Finder passwordField() => find.byType(TextFormField).at(0);
  Finder confirmField() => find.byType(TextFormField).at(1);

  Future<void> enterBoth(WidgetTester tester, String a, String b) async {
    await tester.enterText(passwordField(), a);
    await tester.enterText(confirmField(), b);
  }

  testWidgets('applies the shared password policy', (tester) async {
    stubHappyPath();
    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await enterBoth(tester, 'short12', 'short12');
    await tester.tap(find.text('Set password'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
    verifyNever(() => auth.updatePassword(any()));
  });

  testWidgets('will not set a password the user typed twice differently',
      (tester) async {
    stubHappyPath();
    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await enterBoth(tester, 'correct horse', 'correct hoarse');
    await tester.tap(find.text('Set password'));
    await tester.pumpAndSettle();

    expect(find.textContaining('do not match'), findsOneWidget);
    verifyNever(() => auth.updatePassword(any()));
  });

  testWidgets('sets the password and then ends the recovery session',
      (tester) async {
    stubHappyPath();
    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await enterBoth(tester, 'correct horse battery', 'correct horse battery');
    await tester.tap(find.text('Set password'));
    await tester.pumpAndSettle();

    // Signing out is what enforces OWASP's "no auto-login after a reset": it
    // releases the sticky recovery flag and the router then asks for a fresh
    // sign-in with the new password.
    verifyInOrder([
      () => auth.updatePassword('correct horse battery'),
      () => auth.signOut(),
    ]);
  });

  testWidgets('keeps the form usable when the update fails', (tester) async {
    when(() => auth.updatePassword(any()))
        .thenThrow(AuthFailure('network unreachable'));

    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await enterBoth(tester, 'correct horse battery', 'correct horse battery');
    await tester.tap(find.text('Set password'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not set'), findsOneWidget);
    // Never sign out on failure — that would destroy the recovery session and
    // strand the user with their old password.
    verifyNever(() => auth.signOut());
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('locks the button while saving', (tester) async {
    final pending = Completer<void>();
    when(() => auth.updatePassword(any())).thenAnswer((_) => pending.future);
    when(() => auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await enterBoth(tester, 'correct horse battery', 'correct horse battery');
    await tester.tap(find.text('Set password'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    pending.complete();
    await tester.pumpAndSettle();
    verify(() => auth.updatePassword(any())).called(1);
  });
}
