import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/app/router.dart';
import 'package:amuwak_customer/src/auth/complete_profile_screen.dart';
import 'package:amuwak_customer/src/auth/customer_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfiles extends Mock implements CustomerProfileRepository {}

class _MockUser extends Mock implements User {}

/// The screen in a two-route router so the success path — which ends in
/// `context.go('/')` — can be asserted without standing up the real app router
/// (whose redirect keys off a role claim this screen is precisely trying to
/// mint).
Widget _harness(AuthService auth, CustomerProfileRepository profiles) {
  final router = GoRouter(
    initialLocation: kCompleteProfileRoute,
    routes: [
      GoRoute(
        path: kCompleteProfileRoute,
        builder: (_, __) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('customer home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      customerProfileRepositoryProvider.overrideWithValue(profiles),
    ],
    child: MaterialApp.router(routerConfig: router, theme: buildAmuwakTheme()),
  );
}

void main() {
  late _MockAuthService auth;
  late _MockProfiles profiles;

  setUp(() {
    auth = _MockAuthService();
    profiles = _MockProfiles();
    final user = _MockUser();
    when(() => user.email).thenReturn('ada@example.com');
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.refreshSession()).thenAnswer((_) async {});
  });

  void stubLink({String id = 'cust-77'}) {
    when(() => profiles.linkOrCreate(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        )).thenAnswer((_) async => id);
  }

  void verifyNeverLinked() {
    verifyNever(() => profiles.linkOrCreate(
        name: any(named: 'name'),
        phone: any(named: 'phone'),
        email: any(named: 'email')));
  }

  Finder nameField() => find.byType(TextFormField).at(0);
  Finder phoneField() => find.byType(TextFormField).at(1);

  testWidgets('asks for the name and phone that sign-in never collected',
      (tester) async {
    await tester.pumpWidget(_harness(auth, profiles));
    await tester.pumpAndSettle();

    expect(find.text('Finish setting up'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('will not submit without a name', (tester) async {
    stubLink();
    await tester.pumpWidget(_harness(auth, profiles));
    await tester.pumpAndSettle();

    await tester.enterText(phoneField(), '0700123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name'), findsOneWidget);
    verifyNeverLinked();
  });

  testWidgets('will not submit a phone number that is too short',
      (tester) async {
    stubLink();
    await tester.pumpWidget(_harness(auth, profiles));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), 'Ada');
    await tester.enterText(phoneField(), '0700');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number'), findsOneWidget);
    verifyNeverLinked();
  });

  testWidgets('links with the signed-in email, then lets them into the app',
      (tester) async {
    stubLink();
    await tester.pumpWidget(_harness(auth, profiles));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), '  Ada Nakato  ');
    await tester.enterText(phoneField(), '0700123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The email comes from the session, not the form — they already signed up
    // with it, and asking again would be a second chance to get it wrong.
    verify(() => profiles.linkOrCreate(
        name: 'Ada Nakato',
        phone: '0700123456',
        email: 'ada@example.com')).called(1);
    verify(() => auth.refreshSession()).called(1);
    expect(find.text('customer home'), findsOneWidget);
  });

  testWidgets('explains a failed link and keeps them on the screen',
      (tester) async {
    when(() => profiles.linkOrCreate(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        )).thenThrow(Exception('offline'));

    await tester.pumpWidget(_harness(auth, profiles));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), 'Ada');
    await tester.enterText(phoneField(), '0700123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'Could not finish setting up your account. Please try again.'),
        findsOneWidget);
    expect(find.text('customer home'), findsNothing);
    // Refreshing after a failed link would mint a token that still says 'none'.
    verifyNever(() => auth.refreshSession());
    // And the form is usable again for the retry.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('locks the buttons while the link is in flight', (tester) async {
    final pending = Completer<String>();
    when(() => profiles.linkOrCreate(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        )).thenAnswer((_) => pending.future);

    await tester.pumpWidget(_harness(auth, profiles));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), 'Ada');
    await tester.enterText(phoneField(), '0700123456');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Both disabled: a double tap here would fire a second link, and signing
    // out mid-link would strand the account all over again.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);

    pending.complete('cust-77');
    await tester.pumpAndSettle();
    verify(() => profiles.linkOrCreate(
        name: any(named: 'name'),
        phone: any(named: 'phone'),
        email: any(named: 'email'))).called(1);
  });

  testWidgets('offers a way out via sign out', (tester) async {
    when(() => auth.signOut()).thenAnswer((_) async {});
    await tester.pumpWidget(_harness(auth, profiles));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
    verifyNeverLinked();
  });
}
