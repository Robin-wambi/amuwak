import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import '../chat/order_chat_screen.dart';
import '../inbox/inbox_screen.dart';
import '../orders/my_orders_screen.dart';
import '../orders/order_detail_screen.dart';
import '../orders/place_order/place_order_screen.dart';

/// Pure redirect policy for the customer app, extracted so it is unit-testable
/// without pumping a live router. Returns the path to redirect to, or null to
/// stay put.
///
/// - Signed-out visitors are sent to `/login` (but may sit on `/login` or
///   `/signup`).
/// - Signed-in customers are bounced off the auth pages back to `/`.
String? customerAuthRedirect({
  required bool signedIn,
  required String location,
}) {
  final onAuthPage = location == '/login' || location == '/signup';
  if (!signedIn) return onAuthPage ? null : '/login';
  if (onAuthPage) return '/';
  return null;
}

/// The app router. Rebuilds its redirect on every auth-state change (a
/// [Listenable] bumped from [authStateProvider]) so signing in/out re-routes
/// immediately.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => customerAuthRedirect(
      signedIn: ref.read(currentUserIdProvider) != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/',
        builder: (_, __) => const MyOrdersScreen(),
      ),
      GoRoute(
        path: '/orders/new',
        builder: (_, __) => const PlaceOrderScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/:id/chat',
        builder: (_, state) =>
            OrderChatScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/inbox', builder: (_, __) => const InboxScreen()),
      GoRoute(
        path: '/account',
        builder: (_, __) => const _Stub(title: 'Account'),
      ),
    ],
  );
});

/// Placeholder for a route whose screen is built in a later Stage-2 task.
class _Stub extends StatelessWidget {
  const _Stub({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title — coming soon',
            style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
