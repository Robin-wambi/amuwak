import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/auth/auth_gate.dart';
import 'src/auth/recovery_link_state.dart';
import 'src/bootstrap/app_bootstrap.dart';
import 'src/printing/printing_providers.dart';
import 'src/sync/sync_orchestrator_provider.dart';

Future<void> main() async {
  final recoveryLink = await AppBootstrap.initialize();
  // Resolved once here so screens can read PrinterStore synchronously.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // The default store forgets on relaunch, which would let a rider skip
        // a forced password reset by reopening the app.
        recoveryIntentStoreProvider
            .overrideWithValue(PersistentRecoveryIntentStore(prefs)),
        // A rejected recovery token never reaches the auth stream, so
        // bootstrap's verdict is the only record that the emailed link was the
        // problem — without it the rider lands on a plain sign-in screen.
        recoveryLinkOutcomeProvider.overrideWithValue(recoveryLink),
      ],
      child: const AmuwakStaffApp(),
    ),
  );
}

class AmuwakStaffApp extends ConsumerWidget {
  const AmuwakStaffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly resolve `syncLifecycleProvider` so its auth-state listener starts
    // the SyncOrchestrator on sign-in (and stops + truncates on sign-out). This
    // is what makes the offline engine run: the outbox worker drains queued
    // writes and the puller fills the local Drift DB in the background.
    ref.watch(syncLifecycleProvider);

    return MaterialApp(
      title: 'Amuwak Staff',
      debugShowCheckedModeBanner: false,
      theme: buildAmuwakTheme(),
      // AuthGate routes between login, set-password (invite/reset), and the
      // dashboard from the persisted auth state — so a returning, already
      // signed-in staff member lands straight on the dashboard.
      home: const AuthGate(),
    );
  }
}
