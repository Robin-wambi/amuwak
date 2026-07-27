import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

/// Root of the customer app. Uses the shared [buildAmuwakTheme] so it renders
/// with the same brand look as the staff app, and drives navigation with the
/// auth-redirecting go_router from [routerProvider].
class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Amuwak',
      debugShowCheckedModeBanner: false,
      theme: buildAmuwakTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
