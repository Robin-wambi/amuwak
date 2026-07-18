import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Root of the customer app. Uses the shared [buildAmuwakTheme] so it renders
/// with the same brand look as the staff app, and drives navigation with
/// go_router.
///
/// The router is a single placeholder route for now; Task 4 replaces it with
/// the auth-redirecting router (login/signup/home/…).
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Amuwak',
      debugShowCheckedModeBanner: false,
      theme: buildAmuwakTheme(),
      routerConfig: _placeholderRouter,
    );
  }
}

final _placeholderRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const _PlaceholderHome(),
    ),
  ],
);

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_laundry_service_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Amuwak', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
