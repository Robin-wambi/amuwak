import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/main.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator_provider.dart';

void main() {
  // The app root is now AuthGate, which reads the auth state to choose a screen.
  // Override the auth seams to "no session" so it renders LoginScreen without
  // touching the uninitialised Supabase.instance. syncLifecycleProvider is a
  // no-op override for the same safety reason (it would build a real
  // SyncOrchestrator against Supabase.instance.client).
  final bootstrapOverrides = <Override>[
    syncLifecycleProvider.overrideWith((ref) {}),
    currentUserIdProvider.overrideWithValue(null),
    currentAuthEventProvider.overrideWithValue(null),
  ];

  testWidgets('App opens to login screen first', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: bootstrapOverrides,
        child: const AmuwakStaffApp(),
      ),
    );

    // The login subtitle is unique to the login screen, so use it as the anchor.
    expect(find.text('Login to manage laundry orders'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  // Form validation, the success path, and the failure path are covered by
  // test/auth/login_screen_test.dart. This file is now scoped to the
  // bootstrap path only (the test above), which AmuwakStaffApp's
  // syncLifecycleProvider override is wired for.
}
