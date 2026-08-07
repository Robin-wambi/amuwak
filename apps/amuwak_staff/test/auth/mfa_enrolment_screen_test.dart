import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/mfa_enrolment_screen.dart';
import 'package:amuwak_staff/src/auth/recovery_codes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockMfa extends Mock implements MfaService {}

class _MockRecovery extends Mock implements RecoveryCodesService {}

const _enrolment = TotpEnrolment(
  factorId: 'factor-1',
  otpauthUri: 'otpauth://totp/Amuwak:rider1?secret=JBSWY3DPEHPK3PXP',
  secret: 'JBSWY3DPEHPK3PXP',
);

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
  late _MockRecovery recovery;
  int completed = 0;
  bool? lastEnabled;

  setUp(() {
    mfa = _MockMfa();
    completed = 0;
    lastEnabled = null;
    // Default: nothing enrolled yet, so the screen goes straight to setup.
    when(() => mfa.verifiedFactors()).thenAnswer((_) async => <Factor>[]);
    recovery = _MockRecovery();
    when(() => recovery.generate())
        .thenAnswer((_) async => ['AAAAA-BBBBB-CCCCC-DDDDD']);
  });

  Widget harness() => ProviderScope(
        overrides: [
          mfaServiceProvider.overrideWithValue(mfa),
          recoveryCodesServiceProvider.overrideWithValue(recovery),
        ],
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: MfaEnrolmentScreen(onCompleted: ({required enabled}) {
            completed++;
            lastEnabled = enabled;
          }),
        ),
      );

  void stubEnroll() {
    when(() => mfa.enrollTotp(friendlyName: any(named: 'friendlyName')))
        .thenAnswer((_) async => _enrolment);
  }

  testWidgets('shows a scannable code and the secret to type instead',
      (tester) async {
    stubEnroll();
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    // The secret is shown too: a cracked screen or a desktop browser with no
    // camera cannot scan, and locking those staff out of MFA is worse than
    // displaying the secret they already control.
    expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsOneWidget);
  });

  testWidgets('reports a failure to start enrolment', (tester) async {
    when(() => mfa.enrollTotp(friendlyName: any(named: 'friendlyName')))
        .thenThrow(AuthFailure('already enrolled'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not start'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('will not submit a code that is not six digits', (tester) async {
    stubEnroll();
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    // Specifically the validator message — the instruction copy above the QR
    // also mentions "6-digit", so textContaining would match both.
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    verifyNever(() => mfa.submitCode(
        factorId: any(named: 'factorId'), code: any(named: 'code')));
  });

  testWidgets('activates the factor and reports completion', (tester) async {
    stubEnroll();
    when(() => mfa.submitCode(
        factorId: any(named: 'factorId'),
        code: any(named: 'code'))).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    verify(() => mfa.submitCode(factorId: 'factor-1', code: '123456'))
        .called(1);
    // Completion now waits on the recovery-codes handoff — see "hands over
    // the recovery codes before reporting success" below.
    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(lastEnabled, isTrue);
  });

  testWidgets('offers to turn it off when a factor is already enrolled',
      (tester) async {
    // Enrolling again would collide on the friendly name and dead-end at a
    // generic "could not start" error, which is what someone tapping the
    // Account entry a second time used to get.
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);
    stubEnroll();

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('is on'), findsOneWidget);
    expect(find.text('Turn off'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    verifyNever(() => mfa.enrollTotp(friendlyName: any(named: 'friendlyName')));
  });

  testWidgets('turning it off unenrols the factor', (tester) async {
    // The lockout escape hatch stops needing a manager in the Supabase
    // dashboard: removeFactor was written and tested but reachable from
    // nowhere in the app.
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);
    when(() => mfa.removeFactor(any())).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Turn off'));
    await tester.pumpAndSettle();

    verify(() => mfa.removeFactor('factor-1')).called(1);
    expect(completed, 1);
    expect(lastEnabled, isFalse);
  });

  testWidgets('a cancelled turn-off leaves the factor alone', (tester) async {
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => mfa.removeFactor(any()));
    expect(completed, 0);
  });

  testWidgets('reports a turn-off that failed instead of closing',
      (tester) async {
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);
    when(() => mfa.removeFactor(any()))
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Closing on failure would tell the user two-factor is off while it is
    // still very much on.
    expect(completed, 0);
    expect(find.textContaining('Could not turn'), findsOneWidget);
  });

  testWidgets('keeps the form usable after a wrong code', (tester) async {
    stubEnroll();
    when(() => mfa.submitCode(
            factorId: any(named: 'factorId'), code: any(named: 'code')))
        .thenThrow(AuthFailure('Invalid TOTP code entered'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    // A mistyped code is the common case, not an exceptional one — the codes
    // rotate every 30s, so the retry has to stay right there.
    expect(find.textContaining('did not match'), findsOneWidget);
    expect(completed, 0);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('does not blame the code when it was the network that failed',
      (tester) async {
    stubEnroll();
    when(() => mfa.submitCode(
            factorId: any(named: 'factorId'), code: any(named: 'code')))
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    expect(find.textContaining('did not match'), findsNothing);
    expect(find.textContaining('Could not reach the server'), findsOneWidget);
    expect(completed, 0);
  });

  testWidgets('locks the button while verifying', (tester) async {
    stubEnroll();
    final pending = Completer<void>();
    when(() => mfa.submitCode(
        factorId: any(named: 'factorId'),
        code: any(named: 'code'))).thenAnswer((_) => pending.future);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Activate'));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    pending.complete();
    await tester.pumpAndSettle();
    verify(() => mfa.submitCode(
        factorId: any(named: 'factorId'), code: any(named: 'code'))).called(1);
  });

  testWidgets('hands over the recovery codes before reporting success',
      (tester) async {
    // Enrolling without codes creates exactly the lockout this feature exists
    // to prevent, so completion waits until the user has them.
    stubEnroll();
    when(() => mfa.submitCode(
        factorId: any(named: 'factorId'),
        code: any(named: 'code'))).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    expect(find.byType(RecoveryCodesScreen), findsOneWidget);
    expect(completed, 0, reason: 'not done until the codes are acknowledged');

    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(lastEnabled, isTrue);
  });
}
