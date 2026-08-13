import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/staff/reset_staff_mfa_service.dart';
import 'package:amuwak_staff/src/staff/staff_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

StaffData _staff(String id, String name, String role) => StaffData(
      id: id,
      username: name.toLowerCase(),
      displayName: name,
      role: role,
      active: true,
      mustChangePin: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  Widget harness({
    required ResetStaffMfaFn onReset,
    String currentStaffId = 'me',
    Stream<List<StaffData>> Function()? staff,
  }) =>
      ProviderScope(
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: StaffListScreen(
            staff: staff ??
                () => Stream.value([
                      _staff('me', 'Manager Me', 'manager'),
                      _staff('rider-1', 'Rider One', 'driver'),
                    ]),
            onReset: onReset,
            currentStaffId: currentStaffId,
          ),
        ),
      );

  testWidgets('lists staff with their role', (tester) async {
    await tester.pumpWidget(harness(onReset: ({required staffId}) async => 0));
    await tester.pumpAndSettle();

    expect(find.text('Rider One'), findsOneWidget);
    expect(find.text('Manager Me'), findsOneWidget);
  });

  testWidgets('confirms before clearing someone else\'s two-factor',
      (tester) async {
    var called = 0;
    await tester.pumpWidget(harness(onReset: ({required staffId}) async {
      called++;
      return 1;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();

    // Naming the person in the dialog matters: the list is tappable rows and
    // resetting the wrong rider silently locks them out of their shift.
    expect(find.textContaining('Rider One'), findsWidgets);
    expect(called, 0);

    await tester.tap(find.text('Reset two-factor'));
    await tester.pumpAndSettle();

    expect(called, 1);
  });

  testWidgets('the row is inert while that reset is still in flight',
      (tester) async {
    // The reset is a network round trip, and this is the one screen used from
    // the shop floor on whatever connection the shop has. Nothing about the
    // list says a reset is running — the dialog is gone, the row looks
    // untouched — so tapping again is the obvious thing to do, and without a
    // guard it starts a second concurrent reset of the same person. That one
    // clears nothing, reports "had no two-factor set up" about the very rider
    // whose factor was just removed, and lands a factors_cleared = 0 row in an
    // audit log whose whole job is to record what actually happened.
    //
    // Note this is deliberately NOT a same-frame double-tap test. Three
    // attempts at one (two tap() calls with no pump, and raw same-frame
    // TestPointer events) all produced exactly one dialog: tap() pumps
    // internally and the pushed route's modal barrier absorbs the second
    // press, so such a test passes with or without the guard. The in-flight
    // window below is the reachable version of the same defect, and it fails
    // without the `_busy` guard.
    final gate = Completer<int>();
    var called = 0;
    await tester.pumpWidget(harness(onReset: ({required staffId}) {
      called++;
      return gate.future;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset two-factor'));
    await tester.pump();
    expect(called, 1);

    await tester.tap(find.text('Rider One'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Reset two-factor'), findsNothing,
        reason: 'a reset is in flight, so the row must not offer another');
    expect(called, 1);

    // And the row works again once the reset lands.
    gate.complete(1);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cleared two-factor'), findsOneWidget);

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();
    expect(find.text('Reset two-factor'), findsOneWidget);
  });

  testWidgets('a reset that lands after the screen is gone does not crash',
      (tester) async {
    // A session expiry or a sign-out swaps the whole tree while the round trip
    // is still open. Capturing the messenger before the await is what keeps
    // this off the `use_build_context_synchronously` lint, but it does not make
    // the call safe: that messenger has no Scaffolds under it any more, and
    // showSnackBar asserts `_scaffolds.isNotEmpty` rather than no-opping.
    // Without the `mounted` re-check this test fails with that assertion,
    // thrown from _runConfirmAndReset itself.
    final gate = Completer<int>();
    await tester.pumpWidget(
      harness(onReset: ({required staffId}) => gate.future),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset two-factor'));
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('signed out'))),
    );
    await tester.pumpAndSettle();

    gate.complete(1);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('signed out'), findsOneWidget);
  });

  testWidgets('says plainly when there was nothing to clear', (tester) async {
    await tester.pumpWidget(harness(onReset: ({required staffId}) async => 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset two-factor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('had no two-factor'), findsOneWidget);
  });

  testWidgets('reports the server\'s reason when a reset is refused',
      (tester) async {
    await tester.pumpWidget(harness(onReset: ({required staffId}) async {
      throw ResetMfaFailure('Complete your own two-factor check first');
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset two-factor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Complete your own two-factor check'),
        findsOneWidget);
  });

  testWidgets('does not offer a reset on your own row', (tester) async {
    // The server refuses self-reset; not offering it avoids walking the manager
    // into a guaranteed error.
    await tester.pumpWidget(harness(onReset: ({required staffId}) async => 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manager Me'));
    await tester.pumpAndSettle();

    expect(find.text('Reset two-factor'), findsNothing);
  });

  testWidgets('explains a failed load instead of spinning forever',
      (tester) async {
    // An RLS rejection or a dropped connection errors the stream. Without an
    // error branch the screen shows a spinner indefinitely, which is the
    // failure a manager on a poor network actually hits.
    await tester.pumpWidget(harness(
      onReset: ({required staffId}) async => 0,
      staff: () => Stream<List<StaffData>>.error(Exception('no connection')),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load staff'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('retry re-subscribes rather than reusing the failed stream',
      (tester) async {
    // A bare Stream cannot be re-listened to once it has errored, so the screen
    // takes a factory. If it took a Stream, this test would throw "Stream has
    // already been listened to" on the retry tap.
    var subscriptions = 0;
    await tester.pumpWidget(harness(
      onReset: ({required staffId}) async => 0,
      staff: () {
        subscriptions++;
        return subscriptions == 1
            ? Stream<List<StaffData>>.error(Exception('no connection'))
            : Stream.value([_staff('rider-1', 'Rider One', 'driver')]);
      },
    ));
    await tester.pumpAndSettle();
    expect(subscriptions, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(subscriptions, 2);
    expect(find.text('Rider One'), findsOneWidget);
  });
}
