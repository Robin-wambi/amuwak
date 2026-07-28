import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/staff/invite_staff_screen.dart';
import 'package:amuwak_staff/src/staff/invite_staff_service.dart';

class _Captured {
  String? email;
  String? displayName;
  String? username;
  String? role;
  int calls = 0;
}

Future<void> _pump(
  WidgetTester tester, {
  required InviteStaffFn invite,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: InviteStaffScreen(invite: invite)),
  );
}

void main() {
  testWidgets('empty fields show validation and do not invite', (tester) async {
    var called = false;
    await _pump(tester, invite: ({
      required email,
      required displayName,
      required username,
      required role,
    }) async {
      called = true;
    });

    await tester.tap(find.widgetWithText(ElevatedButton, 'Send invite'));
    await tester.pump();

    expect(find.text('Enter an email'), findsOneWidget);
    expect(find.text('Enter a display name'), findsOneWidget);
    expect(find.text('Enter a username'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('valid form invites with normalised values and defaults to driver',
      (tester) async {
    final captured = _Captured();
    await _pump(tester, invite: ({
      required email,
      required displayName,
      required username,
      required role,
    }) async {
      captured.calls++;
      captured.email = email;
      captured.displayName = displayName;
      captured.username = username;
      captured.role = role;
    });

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), '  NewRider@Amuwak.CO ');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'), '  Jane Doe ');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), '  JaneD ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send invite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(captured.calls, 1);
    expect(captured.email, 'newrider@amuwak.co');
    expect(captured.displayName, 'Jane Doe');
    expect(captured.username, 'janed');
    expect(captured.role, 'driver');
    expect(find.textContaining('Invitation sent'), findsOneWidget);
  });

  testWidgets('a non-InviteFailure error shows a generic message', (tester) async {
    await _pump(tester, invite: ({
      required email,
      required displayName,
      required username,
      required role,
    }) async {
      throw Exception('SocketException: connection failed');
    });

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'), 'A B');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'ab');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send invite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Could not send the invite. Please try again.'),
        findsOneWidget);
  });

  testWidgets('does not setState after dispose when the invite fails late',
      (tester) async {
    // The screen can be popped while the Edge Function call is in flight; an
    // InviteFailure arriving after teardown must not setState on a disposed
    // State.
    final completer = Completer<void>();
    await _pump(tester, invite: ({
      required email,
      required displayName,
      required username,
      required role,
    }) async {
      await completer.future;
      throw InviteFailure('Username already taken');
    });

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'), 'A B');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'ab');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send invite'));
    await tester.pump();

    // Tear the screen down while the invite is still pending, then let it fail.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    completer.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('InviteFailure shows the error message', (tester) async {
    await _pump(tester, invite: ({
      required email,
      required displayName,
      required username,
      required role,
    }) async {
      throw InviteFailure('Username already taken');
    });

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.co');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'), 'A B');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'ab');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send invite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Username already taken'), findsOneWidget);
  });
}
