import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/customer_app.dart';
import 'src/auth/recovery_state.dart';
import 'src/bootstrap/customer_bootstrap.dart';

Future<void> main() async {
  final boot = await CustomerBootstrap.initialize();
  runApp(ProviderScope(
    overrides: [
      // The default store forgets on reload, which would let a half-finished
      // password reset be skipped by refreshing the tab. Only the real app has
      // somewhere to persist it, so only the real app overrides this.
      recoveryIntentStoreProvider.overrideWithValue(boot.recoveryIntent),
      // A rejected recovery token never reaches the auth stream, so bootstrap's
      // verdict is the only record that the emailed link was the problem.
      recoveryLinkOutcomeProvider.overrideWithValue(boot.recoveryLink),
    ],
    child: const CustomerApp(),
  ));
}
