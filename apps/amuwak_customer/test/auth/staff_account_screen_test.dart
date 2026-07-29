import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/auth/staff_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

Widget _harness(AuthService auth) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: MaterialApp(
          theme: buildAmuwakTheme(), home: const StaffAccountScreen()),
    );

void main() {
  testWidgets('tells a staff account why this app has nothing for them',
      (tester) async {
    await tester.pumpWidget(_harness(_MockAuthService()));
    await tester.pumpAndSettle();

    expect(find.text('This is a staff account'), findsOneWidget);
    // The whole point of the screen: name the other app, rather than leaving
    // them on a customer home that silently renders empty.
    expect(find.textContaining('staff app'), findsWidgets);
    // And offer the way out for a rider who genuinely wants to send laundry.
    expect(find.textContaining('personal email address'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('tapping sign out calls AuthService.signOut', (tester) async {
    final auth = _MockAuthService();
    when(() => auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(_harness(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
