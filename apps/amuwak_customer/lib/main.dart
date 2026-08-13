import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/customer_app.dart';
import 'src/bootstrap/customer_bootstrap.dart';

Future<void> main() async {
  final recoveryIntent = await CustomerBootstrap.initialize();
  runApp(ProviderScope(
    // The default store forgets on reload, which would let a half-finished
    // password reset be skipped by refreshing the tab. Only the real app has
    // somewhere to persist it, so only the real app overrides this.
    overrides: [
      recoveryIntentStoreProvider.overrideWithValue(recoveryIntent),
    ],
    child: const CustomerApp(),
  ));
}
