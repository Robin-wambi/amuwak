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
