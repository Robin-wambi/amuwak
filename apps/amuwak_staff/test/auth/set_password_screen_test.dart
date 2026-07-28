import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/set_password_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/dashboard/current_staff_provider.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  required AuthService authService,
  required StaffRepository staffRepository,
  required VoidCallback onCompleted,
  StaffData? currentStaff,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        staffRepositoryProvider.overrideWithValue(staffRepository),
        currentStaffProvider.overrideWith((ref) => Stream.value(currentStaff)),
      ],
      child: MaterialApp(
        home: SetPasswordScreen(onCompleted: onCompleted),
      ),
    ),
  );
}

void main() {
  late _MockAuthService auth;
  late _MockStaffRepository staffRepo;

  setUp(() {
    auth = _MockAuthService();
    staffRepo = _MockStaffRepository();
    when(() => staffRepo.setMyDisplayName(any())).thenAnswer((_) async {});
  });

  Future<void> enterBoth(WidgetTester tester, String pw, String confirm) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'), pw);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'), confirm);
  }

  testWidgets('pre-fills the name field from the current staff row',
      (tester) async {
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () {},
      currentStaff: _staff('Existing Name'),
    );
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Existing Name'), findsOneWidget);
  });

  testWidgets('does not overwrite a name the user typed before the staff row '
      'arrives', (tester) async {
    final staffStream = StreamController<StaffData?>();
    addTearDown(staffStream.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          staffRepositoryProvider.overrideWithValue(staffRepo),
          currentStaffProvider.overrideWith((ref) => staffStream.stream),
        ],
        child: MaterialApp(home: SetPasswordScreen(onCompleted: () {})),
      ),
    );
    await tester.pump();

    // User types before the staff row has loaded.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Your name'), 'User Typed');

    // Staff row arrives late.
    staffStream.add(_staff('Manager Entered'));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'User Typed'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Manager Entered'), findsNothing);
  });

  testWidgets('an empty name shows an error and does not save', (tester) async {
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () {},
      currentStaff: null, // nothing to pre-fill -> name stays empty
    );
    await tester.pump();

    await enterBoth(tester, 'longenough1', 'longenough1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();

    expect(find.text('Your name is required'), findsOneWidget);
    verifyNever(() => staffRepo.setMyDisplayName(any()));
    verifyNever(() => auth.updatePassword(any()));
  });

  testWidgets('mismatched passwords show an error and do not save',
      (tester) async {
    var completed = false;
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () => completed = true,
      currentStaff: _staff('Existing Name'),
    );
    await tester.pump();

    await enterBoth(tester, 'longenough1', 'different1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    verifyNever(() => auth.updatePassword(any()));
    expect(completed, isFalse);
  });

  testWidgets('too-short password shows an error and does not save',
      (tester) async {
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () {},
      currentStaff: _staff('Existing Name'),
    );
    await tester.pump();

    await enterBoth(tester, 'short', 'short');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();

    expect(find.text('At least 8 characters'), findsOneWidget);
    verifyNever(() => auth.updatePassword(any()));
  });

  testWidgets('valid input sets the name then the password then completes',
      (tester) async {
    when(() => auth.updatePassword(any())).thenAnswer((_) async {});
    var completed = false;
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () => completed = true,
      currentStaff: _staff('Old Name'),
    );
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Old Name'), 'New Name');
    await enterBoth(tester, 'longenough1', 'longenough1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verifyInOrder([
      () => staffRepo.setMyDisplayName('New Name'),
      () => auth.updatePassword('longenough1'),
    ]);
    expect(completed, isTrue);
  });

  testWidgets('a name-save failure shows an error and does not set the password',
      (tester) async {
    when(() => staffRepo.setMyDisplayName(any()))
        .thenThrow(Exception('network down'));
    var completed = false;
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () => completed = true,
      currentStaff: _staff('Existing Name'),
    );
    await tester.pump();

    await enterBoth(tester, 'longenough1', 'longenough1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('went wrong'), findsOneWidget);
    verifyNever(() => auth.updatePassword(any()));
    expect(completed, isFalse);
  });

  testWidgets(
      'calls onCompleted even if the screen is disposed before the save '
      'request resolves', (tester) async {
    // onCompleted drives the parent (AuthGate), not this screen — so a save that
    // finishes after this widget is torn down must still notify the parent, or
    // the user is stranded on a Set-password screen whose password already saved.
    final completer = Completer<void>();
    when(() => auth.updatePassword(any())).thenAnswer((_) => completer.future);
    var completed = false;
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () => completed = true,
      currentStaff: _staff('Existing Name'),
    );
    await tester.pump();

    await enterBoth(tester, 'longenough1', 'longenough1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();

    // Tear the screen down while updatePassword is still pending.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    completer.complete();
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('AuthFailure shows the message and does not complete',
      (tester) async {
    when(() => auth.updatePassword(any()))
        .thenThrow(AuthFailure('Password is too weak'));
    var completed = false;
    await _pump(
      tester,
      authService: auth,
      staffRepository: staffRepo,
      onCompleted: () => completed = true,
      currentStaff: _staff('Existing Name'),
    );
    await tester.pump();

    await enterBoth(tester, 'longenough1', 'longenough1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Password is too weak'), findsOneWidget);
    expect(completed, isFalse);
  });
}
