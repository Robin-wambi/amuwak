import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/mfa_challenge_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockMfa extends Mock implements MfaService {}

class _MockAuthService extends Mock implements AuthService {}

Factor _verified(String id) => Factor(
      id: id,
      status: FactorStatus.verified,
      factorType: FactorType.totp,
      friendlyName: 'Authenticator',
      updatedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockMfa mfa;
  late _MockAuthService auth;

  setUp(() {
    mfa = _MockMfa();
    auth = _MockAuthService();
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);
  });

  Widget harness() => ProviderScope(
        overrides: [
          mfaServiceProvider.overrideWithValue(mfa),
          authServiceProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
            theme: buildAmuwakTheme(), home: const MfaChallengeScreen()),
      );

  testWidgets('asks for the code from the enrolled authenticator',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('authenticator app'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('verifies against the enrolled factor', (tester) async {
    when(() => mfa.submitCode(
        factorId: any(named: 'factorId'),
        code: any(named: 'code'))).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    verify(() => mfa.submitCode(factorId: 'factor-1', code: '123456'))
        .called(1);
  });

  testWidgets('keeps the field ready after a wrong code', (tester) async {
    when(() => mfa.submitCode(
            factorId: any(named: 'factorId'), code: any(named: 'code')))
        .thenThrow(AuthFailure('Invalid TOTP code entered'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.textContaining('did not match'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('offers sign out as the way off this screen', (tester) async {
    // Without this a staff member who lost their authenticator is stuck on a
    // screen they cannot satisfy and cannot leave. Signing out at least returns
    // them to login so a manager can unenrol the factor for them.
    when(() => auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });

  testWidgets('locks the button while verifying', (tester) async {
    final pending = Completer<void>();
    when(() => mfa.submitCode(
        factorId: any(named: 'factorId'),
        code: any(named: 'code'))).thenAnswer((_) => pending.future);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    pending.complete();
    await tester.pumpAndSettle();
    verify(() => mfa.submitCode(
        factorId: any(named: 'factorId'), code: any(named: 'code'))).called(1);
  });
}
