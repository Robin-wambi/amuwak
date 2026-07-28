import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_staff/src/auth/auth_gate.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/login_screen.dart';
import 'package:amuwak_staff/src/auth/set_password_screen.dart';
import 'package:amuwak_staff/src/dashboard/current_staff_provider.dart';
import 'package:amuwak_staff/src/dashboard/staff_dashboard_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';
import 'package:amuwak_staff/src/sync/staff_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockStaffRepository extends Mock implements StaffRepository {}

StaffData _staff(String displayName) => StaffData(
      id: 'u1',
      username: 'user1',
      displayName: displayName,
      role: 'driver',
      active: true,
      mustChangePin: false,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

/// Controllable event source so a test can change the auth event mid-render.
final _testEventProvider =
    StateProvider<AuthChangeEvent?>((_) => AuthChangeEvent.passwordRecovery);

/// Controllable signed-in user id so a test can simulate sign-out mid-render.
final _testUserIdProvider = StateProvider<String?>((_) => 'u1');

/// Overrides that let the heavy dashboard build without touching Supabase.
List<Override> _dashboardStubs() => [
      currentRoleProvider.overrideWithValue(null),
      currentStaffProvider.overrideWith((ref) => Stream<StaffData?>.value(null)),
      ordersStreamProvider
          .overrideWith((ref) => Stream<List<LaundryOrder>>.value(const [])),
    ];

Future<void> _pumpGate(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: AuthGate()),
    ),
  );
}

void main() {
  testWidgets('shows LoginScreen when nobody is signed in', (tester) async {
    await _pumpGate(tester, overrides: [
      currentUserIdProvider.overrideWithValue(null),
      currentAuthEventProvider.overrideWithValue(null),
    ]);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(StaffDashboardScreen), findsNothing);
  });

  testWidgets('shows SetPasswordScreen after a passwordRecovery event',
      (tester) async {
    await _pumpGate(tester, overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      currentAuthEventProvider
          .overrideWithValue(AuthChangeEvent.passwordRecovery),
      authServiceProvider.overrideWithValue(_MockAuthService()),
    ]);

    expect(find.byType(SetPasswordScreen), findsOneWidget);
    expect(find.byType(StaffDashboardScreen), findsNothing);
  });

  testWidgets('shows the dashboard when signed in normally', (tester) async {
    await _pumpGate(tester, overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      currentAuthEventProvider.overrideWithValue(AuthChangeEvent.signedIn),
      authServiceProvider.overrideWithValue(_MockAuthService()),
      ..._dashboardStubs(),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(StaffDashboardScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('leaves SetPassword for the dashboard once the password is set',
      (tester) async {
    final auth = _MockAuthService();
    when(() => auth.updatePassword(any())).thenAnswer((_) async {});
    final staffRepo = _MockStaffRepository();
    when(() => staffRepo.setMyDisplayName(any())).thenAnswer((_) async {});

    // SetPasswordScreen now also collects a name (pre-filled from the staff row)
    // and writes it via the staff repo, so this submit path needs both stubs.
    await _pumpGate(tester, overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      currentAuthEventProvider
          .overrideWithValue(AuthChangeEvent.passwordRecovery),
      authServiceProvider.overrideWithValue(auth),
      staffRepositoryProvider.overrideWithValue(staffRepo),
      currentRoleProvider.overrideWithValue(null),
      currentStaffProvider
          .overrideWith((ref) => Stream<StaffData?>.value(_staff('Existing'))),
      ordersStreamProvider
          .overrideWith((ref) => Stream<List<LaundryOrder>>.value(const [])),
    ]);

    expect(find.byType(SetPasswordScreen), findsOneWidget);
    await tester.pump(); // let currentStaff emit so the name field seeds

    await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'), 'longenough1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'), 'longenough1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SetPasswordScreen), findsNothing);
    expect(find.byType(StaffDashboardScreen), findsOneWidget);
  });

  testWidgets(
      'a token refresh during recovery keeps the user on SetPassword',
      (tester) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      currentAuthEventProvider.overrideWith((ref) => ref.watch(_testEventProvider)),
      authServiceProvider.overrideWithValue(_MockAuthService()),
      ..._dashboardStubs(),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AuthGate()),
    ));

    expect(find.byType(SetPasswordScreen), findsOneWidget);

    // Supabase can fire tokenRefreshed during the recovery window; the sticky
    // _recovering flag must keep the user on the password form, not route them
    // to the dashboard.
    container.read(_testEventProvider.notifier).state =
        AuthChangeEvent.tokenRefreshed;
    await tester.pump();

    expect(find.byType(SetPasswordScreen), findsOneWidget);
    expect(find.byType(StaffDashboardScreen), findsNothing);
  });

  testWidgets(
      'a passwordRecovery event after mount routes to SetPassword',
      (tester) async {
    // Start signed-in (not recovering), then a recovery event arrives at
    // runtime via ref.listen — the gate must flip into the recovery state.
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      currentAuthEventProvider.overrideWith((ref) => ref.watch(_testEventProvider)),
      authServiceProvider.overrideWithValue(_MockAuthService()),
      ..._dashboardStubs(),
    ]);
    addTearDown(container.dispose);
    // Seed the event source to signedIn so initState does NOT pre-set recovery.
    container.read(_testEventProvider.notifier).state = AuthChangeEvent.signedIn;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(StaffDashboardScreen), findsOneWidget);

    container.read(_testEventProvider.notifier).state =
        AuthChangeEvent.passwordRecovery;
    await tester.pump();

    expect(find.byType(SetPasswordScreen), findsOneWidget);
    expect(find.byType(StaffDashboardScreen), findsNothing);
  });

  testWidgets(
      'a signedOut event during recovery clears the sticky recovery flag',
      (tester) async {
    // Start in recovery; a signedOut event must drop _recovering back to false.
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_testUserIdProvider)),
      currentAuthEventProvider.overrideWith((ref) => ref.watch(_testEventProvider)),
      authServiceProvider.overrideWithValue(_MockAuthService()),
      ..._dashboardStubs(),
    ]);
    addTearDown(container.dispose);
    container.read(_testEventProvider.notifier).state =
        AuthChangeEvent.passwordRecovery;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AuthGate()),
    ));
    expect(find.byType(SetPasswordScreen), findsOneWidget);

    // Sign out: event flips to signedOut and the user id clears.
    container.read(_testEventProvider.notifier).state =
        AuthChangeEvent.signedOut;
    container.read(_testUserIdProvider.notifier).state = null;
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SetPasswordScreen), findsNothing);
  });

  testWidgets('routes back to LoginScreen when the session ends (sign-out)',
      (tester) async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_testUserIdProvider)),
      currentAuthEventProvider.overrideWithValue(AuthChangeEvent.signedIn),
      authServiceProvider.overrideWithValue(_MockAuthService()),
      ..._dashboardStubs(),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(StaffDashboardScreen), findsOneWidget);

    // Sign out: the session id clears. AuthGate must show the login screen so a
    // subsequent sign-in routes forward again (the dashboard no longer does this
    // itself).
    container.read(_testUserIdProvider.notifier).state = null;
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(StaffDashboardScreen), findsNothing);
  });
}
