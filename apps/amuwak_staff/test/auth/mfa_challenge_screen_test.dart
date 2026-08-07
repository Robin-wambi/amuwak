import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/mfa_challenge_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator_provider.dart';
import 'package:amuwak_staff/src/sync/sync_status.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockMfa extends Mock implements MfaService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockOrchestrator extends Mock implements SyncOrchestrator {}

class _MockRecovery extends Mock implements RecoveryCodesService {}

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
  late AppDatabase db;
  late _MockOrchestrator orchestrator;
  late _MockRecovery recovery;

  setUp(() {
    mfa = _MockMfa();
    auth = _MockAuthService();
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);
    // Sign-out goes through signOutAndReset, which stops the sync engine and
    // truncates the local cache — so every harness needs both, not just auth.
    db = AppDatabase.forTesting(NativeDatabase.memory());
    orchestrator = _MockOrchestrator();
    when(() => orchestrator.stop()).thenAnswer((_) async {});
    recovery = _MockRecovery();
  });

  tearDown(() async => db.close());

  Widget harness() => ProviderScope(
        overrides: [
          mfaServiceProvider.overrideWithValue(mfa),
          authServiceProvider.overrideWithValue(auth),
          appDatabaseProvider.overrideWithValue(db),
          syncOrchestratorProvider.overrideWithValue(orchestrator),
          recoveryCodesServiceProvider.overrideWithValue(recovery),
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
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sign out').last);
    await tester.pumpAndSettle();

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

  testWidgets('does not blame the code when it was the network that failed',
      (tester) async {
    // Telling a rider on a dropped connection that their code "did not match"
    // sends them back to an authenticator that was right all along.
    when(() => mfa.submitCode(
            factorId: any(named: 'factorId'), code: any(named: 'code')))
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.textContaining('did not match'), findsNothing);
    expect(find.textContaining('Could not reach the server'), findsOneWidget);
  });

  testWidgets('waits for the factor rather than offering a dead Verify button',
      (tester) async {
    // verifiedFactors() refreshes the session first, so on a rider's network
    // this window is seconds long. Rendering the form during it would let
    // someone type a code and tap Verify to no effect at all.
    final pending = Completer<List<Factor>>();
    when(() => mfa.verifiedFactors()).thenAnswer((_) => pending.future);

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Verify'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);

    pending.complete([_verified('factor-1')]);
    await tester.pumpAndSettle();

    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('offers a retry when the factor list cannot be loaded',
      (tester) async {
    when(() => mfa.verifiedFactors())
        .thenThrow(AuthFailure('network is unreachable'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not reach the server'), findsOneWidget);
    expect(find.text('Verify'), findsNothing);

    // Recovering must not mean force-quitting the app: the screen tells the
    // user to retry, so it has to give them something that retries.
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Verify'), findsOneWidget);
    expect(find.textContaining('Could not reach the server'), findsNothing);
  });

  testWidgets('explains itself when no verified factor is registered',
      (tester) async {
    // A manager unenrolling the factor is the documented lockout recovery, and
    // it can land while this screen is up. An inert Verify button would strand
    // the user on a screen they have no way to satisfy.
    when(() => mfa.verifiedFactors()).thenAnswer((_) async => <Factor>[]);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('No authenticator'), findsOneWidget);
    expect(find.text('Verify'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('confirms before signing out, because it wipes local work',
      (tester) async {
    // Sign-out here runs the full signOutAndReset: it truncates the outbox
    // along with everything else, so a stray tap destroys unsynced work. The
    // dashboard confirms for exactly that reason and this does the same
    // teardown, so it asks too.
    when(() => auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => auth.signOut());
    verifyNever(() => orchestrator.stop());
    expect(find.byType(MfaChallengeScreen), findsOneWidget);
  });

  testWidgets('sign out tears down the local cache, not just the session',
      (tester) async {
    // signOutAndReset's contract: stop the sync engine and truncate every
    // cached table BEFORE revoking the session. The sync engine has been
    // pulling since sign-in (syncLifecycleProvider starts on any live session,
    // aal1 included), so a raw signOut() here would leave the last rider's
    // orders and customer PII on what is often a shared device.
    final now = DateTime.utc(2026, 1, 1);
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: 'c-1',
          name: 'Sarah',
          phone: '+256700000000',
          createdAt: now,
          updatedAt: now,
        ));
    when(() => auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sign out').last);
    await tester.pumpAndSettle();

    verify(() => orchestrator.stop()).called(1);
    verify(() => auth.signOut()).called(1);
    expect(await db.select(db.customers).get(), isEmpty);
  });

  testWidgets('reports a sign-out that fails instead of looking stuck',
      (tester) async {
    // This is the lockout escape hatch. Dropping the Future meant a failure
    // here was completely silent — the user taps and nothing whatsoever
    // happens, on the one control they need most.
    when(() => auth.signOut()).thenThrow(AuthFailure('network is unreachable'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sign out').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not sign out'), findsOneWidget);
  });

  testWidgets('a recovery code gets a locked-out user back in', (tester) async {
    // The whole point: no manager, no Supabase dashboard.
    when(() => recovery.redeem(any())).thenAnswer((_) async {});
    when(() => auth.refreshSession()).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'AAAAA-BBBBB-CCCCC-DDDDD');
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();

    verify(() => recovery.redeem('AAAAA-BBBBB-CCCCC-DDDDD')).called(1);
    // Without the refresh the gate never notices: the assurance level is read
    // from factors cached on the session user.
    verify(() => auth.refreshSession()).called(1);
  });

  testWidgets('a rejected recovery code keeps the field usable',
      (tester) async {
    when(() => recovery.redeem(any()))
        .thenThrow(AuthFailure('That recovery code is not valid.'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'NOPE1-NOPE2-NOPE3-NOPE4');
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not valid'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('can go back to the authenticator code', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    expect(find.text('Verify'), findsNothing);

    await tester.tap(find.text('Use my authenticator instead'));
    await tester.pumpAndSettle();
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets(
      'a successful redeem is never reported as a failure, even if the '
      'refresh afterward fails', (tester) async {
    // The code is already burned server-side by the time redeem() resolves.
    // Telling the user it failed here would be false, and leaving the spent
    // code in the field would invite a resubmit the server will now reject.
    when(() => recovery.redeem(any())).thenAnswer((_) async {});
    when(() => auth.refreshSession())
        .thenThrow(AuthFailure('network is unreachable', retryable: true));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'AAAAA-BBBBB-CCCCC-DDDDD');
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();

    verify(() => recovery.redeem('AAAAA-BBBBB-CCCCC-DDDDD')).called(1);
    verify(() => auth.refreshSession()).called(1);
    expect(find.textContaining('Could not use'), findsNothing);
    expect(find.textContaining('not valid'), findsNothing);
    expect(find.textContaining('accepted'), findsOneWidget);
    // The spent code must not sit in the field inviting a resubmit.
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets(
      'switching to a recovery code clears a stale authenticator '
      'validation error', (tester) async {
    // Both forms share the same Form key/position, so Flutter reconciles
    // the field in place rather than recreating it: without an explicit
    // reset, the old inline error survives the mode switch.
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6-digit code'), findsOneWidget);

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the 6-digit code'), findsNothing);
  });

  testWidgets(
      'the recovery-code field does not offer to autocorrect or autofill it',
      (tester) async {
    // This field carries a one-time credential. Without these settings,
    // Android's soft keyboard learns the typed groups into its personalised
    // dictionary — handing a secret to a third-party IME process.
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.autofillHints, isEmpty);
  });

  testWidgets(
      'a redeem that resolves after the screen is gone does not throw',
      (tester) async {
    // Reproduces disposal mid-flight: redeem() is still in flight when the
    // screen is torn down (e.g. the gate navigates away), then the Future
    // resolves into an already-disposed State. _code.clear() sits between
    // the two try blocks in _useRecoveryCode and must not touch the
    // disposed controller.
    final pending = Completer<void>();
    when(() => recovery.redeem(any())).thenAnswer((_) => pending.future);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'AAAAA-BBBBB-CCCCC-DDDDD');
    await tester.tap(find.text('Use code'));
    await tester.pump();

    // Replace the whole tree while redeem() is still pending: this unmounts
    // MfaChallengeScreen's State and disposes its TextEditingController.
    await tester.pumpWidget(const SizedBox());

    pending.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
