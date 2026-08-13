import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/recovery_codes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecovery extends Mock implements RecoveryCodesService {}

const _codes = [
  'AAAAA-BBBBB-CCCCC-DDDDD',
  'EEEEE-FFFFF-00000-11111',
  '22222-33333-44444-55555',
];

void main() {
  late _MockRecovery recovery;
  bool? poppedWith;

  setUp(() {
    recovery = _MockRecovery();
    poppedWith = null;
    when(() => recovery.generate()).thenAnswer((_) async => _codes);
  });

  // A plain host for states that don't need to observe the pop result.
  Widget harness() => ProviderScope(
        overrides: [recoveryCodesServiceProvider.overrideWithValue(recovery)],
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: const RecoveryCodesScreen(),
        ),
      );

  // Mirrors how the screen is actually used: pushed on top of another route,
  // not as the app's sole route. A harness with nothing beneath it on the
  // stack can't reproduce a pop being attempted and refused. Captures the
  // `bool` result RecoveryCodesScreen pops itself with, same as
  // MfaEnrolmentScreen does.
  Widget pushHarness() => ProviderScope(
        overrides: [recoveryCodesServiceProvider.overrideWithValue(recovery)],
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    poppedWith = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const RecoveryCodesScreen(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('shows every code it was given', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    for (final code in _codes) {
      expect(find.text(code), findsOneWidget);
    }
  });

  testWidgets('cannot be dismissed without confirming they are saved',
      (tester) async {
    // These are shown exactly once. Letting the screen close on a stray back
    // gesture hands someone a two-factor account with no way back into it.
    await tester.pumpWidget(pushHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text("I've saved these"), findsOneWidget);

    // Simulate the OS back button / predictive-back pop, exactly as
    // order_details_screen_test.dart does for its own PopScope coverage.
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // Still on the recovery-codes screen: the pop attempt was refused, not
    // just "the counter didn't move for some unrelated reason".
    expect(find.text('Recovery codes'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    expect(poppedWith, isNull);

    // Acknowledging is still the one working way out.
    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();
    expect(poppedWith, isTrue);
  });

  testWidgets(
      'cannot be dismissed while codes are still being minted, even though '
      '_codes is still null there too', (tester) async {
    // Before this fix, canPop checked only `_codes == null` — which is also
    // true WHILE MINTING, not just before it starts. A system-back pop
    // during the very first mint (or a Retry mint) used to be let through
    // while generate() was still running server-side. That call still
    // commits: the previous set of codes (which may already be written down
    // somewhere) gets deleted and replaced with a set nobody ever sees.
    final pending = Completer<List<String>>();
    when(() => recovery.generate()).thenAnswer((_) => pending.future);

    await tester.pumpWidget(pushHarness());
    await tester.tap(find.text('Open'));
    // Two pumps, the second long enough to clear the push transition: a single
    // pump only starts the route animation, so the pushed screen is not yet
    // findable. pumpAndSettle is not an option — the spinner animates forever,
    // so it would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Not pumpAndSettle: the spinner's animation never settles on its own.
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pump();

    // Still minting, still on screen: the pop attempt was refused.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(poppedWith, isNull);

    pending.complete(_codes);
    await tester.pumpAndSettle();
    expect(find.text("I've saved these"), findsOneWidget);
  });

  testWidgets('a rapid double tap only pops once', (tester) async {
    // Acknowledging pops this screen with `true`. Two fast taps before that
    // pop is processed must not both fire — the second Navigator.pop would
    // either throw or pop an unrelated route.
    await tester.pumpWidget(pushHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I've saved these"));
    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(poppedWith, isTrue);
  });

  testWidgets('shows a spinner rather than an empty list while minting',
      (tester) async {
    final pending = Completer<List<String>>();
    when(() => recovery.generate()).thenAnswer((_) => pending.future);

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("I've saved these"), findsNothing);

    pending.complete(_codes);
    await tester.pumpAndSettle();
    expect(find.text("I've saved these"), findsOneWidget);
  });

  testWidgets('offers a retry when minting fails', (tester) async {
    when(() => recovery.generate())
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not create'), findsOneWidget);

    when(() => recovery.generate()).thenAnswer((_) async => _codes);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text(_codes.first), findsOneWidget);
  });

  testWidgets('a rapid double tap on Retry only mints once', (tester) async {
    // Two RPC calls in flight from one double tap race: if the first
    // response lands after the second, a naive setState would show codes
    // the server has already replaced with a newer set (generate deletes
    // the previous set server-side before minting the new one).
    when(() => recovery.generate())
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    final pending = Completer<List<String>>();
    when(() => recovery.generate()).thenAnswer((_) => pending.future);

    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pump();

    // One call from initState's original (failed) mint, plus exactly one
    // more from the double tap — not two.
    verify(() => recovery.generate()).called(2);

    pending.complete(_codes);
    await tester.pumpAndSettle();
  });

  testWidgets('the error state can be left via system back, unlike the '
      'codes-shown state', (tester) async {
    // canPop only protects the state where codes are actually on screen —
    // an error has nothing to protect, so blocking the pop there would trap
    // the user on a screen they cannot satisfy.
    when(() => recovery.generate())
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(pushHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not create'), findsOneWidget);

    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Recovery codes'), findsNothing);
  });

  testWidgets('the error state offers an explicit Close action, and reports '
      'that as not-acknowledged', (tester) async {
    when(() => recovery.generate())
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(pushHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Recovery codes'), findsNothing);
    expect(poppedWith, isFalse);
  });
}
