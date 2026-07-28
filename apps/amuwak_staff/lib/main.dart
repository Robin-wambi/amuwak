import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/auth/auth_gate.dart';
import 'src/bootstrap/app_bootstrap.dart';
import 'src/printing/printing_providers.dart';
import 'src/sync/sync_orchestrator_provider.dart';

Future<void> main() async {
  await AppBootstrap.initialize();
  // Resolved once here so screens can read PrinterStore synchronously.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
