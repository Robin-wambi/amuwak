import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/account/profile_screen.dart';
import 'package:amuwak_customer/src/auth/customer_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

Widget _harness(Customer? customer, AuthService auth) => ProviderScope(
      overrides: [
        currentCustomerProvider.overrideWith((ref) => Stream.value(customer)),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(theme: buildAmuwakTheme(), home: const ProfileScreen()),
    );

void main() {
  testWidgets('shows the customer contact details', (tester) async {
    final auth = _MockAuthService();
    await tester.pumpWidget(_harness(
      const Customer(
        id: 'c1',
        name: 'Ada Nakato',
        phone: '+256700000001',
        email: 'ada@example.com',
        address: 'Plot 12, Kololo',
      ),
      auth,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ada Nakato'), findsOneWidget);
    expect(find.text('+256700000001'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Plot 12, Kololo'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('tapping sign out calls AuthService.signOut', (tester) async {
    final auth = _MockAuthService();
    when(() => auth.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(_harness(
      const Customer(id: 'c1', name: 'Ada', phone: '0700'),
      auth,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
