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
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(acknowledged, 0);
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
}
