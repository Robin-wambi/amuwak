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
  int acknowledged = 0;

  setUp(() {
    recovery = _MockRecovery();
    acknowledged = 0;
    when(() => recovery.generate()).thenAnswer((_) async => _codes);
  });

  Widget harness() => ProviderScope(
        overrides: [recoveryCodesServiceProvider.overrideWithValue(recovery)],
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: RecoveryCodesScreen(onAcknowledged: () => acknowledged++),
        ),
      );

  // Mirrors how the screen is actually used: pushed on top of another route,
  // not as the app's sole route. A harness with nothing beneath it on the
  // stack can't reproduce a pop being attempted and refused.
  Widget dismissHarness() => ProviderScope(
        overrides: [recoveryCodesServiceProvider.overrideWithValue(recovery)],
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecoveryCodesScreen(
                        onAcknowledged: () => acknowledged++,
                      ),
                    ),
                  ),
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
    await tester.pumpWidget(dismissHarness());
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
    expect(acknowledged, 0);

    // Acknowledging is still the one working way out.
    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();
    expect(acknowledged, 1);
  });

  testWidgets('a rapid double tap only acknowledges once', (tester) async {
    // onAcknowledged is wired (by the caller) to a pop plus provider
    // invalidation. Two fast taps before that unmounts this screen must not
    // fire it twice.
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text("I've saved these"));
    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();

    expect(acknowledged, 1);
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
    expect(acknowledged, 0);

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

    await tester.pumpWidget(dismissHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not create'), findsOneWidget);

    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Recovery codes'), findsNothing);
  });

  testWidgets('the error state offers an explicit Close action',
      (tester) async {
    when(() => recovery.generate())
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(dismissHarness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Recovery codes'), findsNothing);
  });
}
