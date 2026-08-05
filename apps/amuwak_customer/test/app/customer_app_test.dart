import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/app/customer_app.dart';
import 'package:amuwak_customer/src/auth/recovery_state.dart';
import 'package:amuwak_customer/src/cart/cart_photo.dart';
import 'package:amuwak_customer/src/cart/checkout_service.dart';
import 'package:amuwak_customer/src/sync/sync_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A recovery flag the test drives directly, standing in for the auth-event
/// latch so the router can be observed reacting to it.
class _TestRecovering extends RecoveringNotifier {
  _TestRecovering(this.initial);
  final bool initial;

  @override
  bool build() => initial;

  void set(bool value) => state = value;
}

/// Drives the real router with auth overridden so it never touches Supabase.
/// Proves the redirect wiring: signed-out lands on login, signed-in on home.
void main() {
  Widget app({
    required String? userId,
    bool recovering = false,
    bool recoveryLinkFailed = false,
    String? role,
  }) =>
      ProviderScope(
        overrides: [
          // Empty stream so routerProvider's listen never builds AuthService.
          authStateProvider.overrideWith((ref) => Stream<AuthState>.empty()),
          currentUserIdProvider.overrideWithValue(userId),
          // The redirect reads the role alongside the id, and both fall back to
          // the restored session when the stream has not emitted — which would
          // build a real AuthService. Stub it for the same reason as the id.
          currentRoleProvider.overrideWithValue(role),
          recoveringProvider.overrideWith(() => _TestRecovering(recovering)),
          recoveryLinkFailedProvider.overrideWithValue(recoveryLinkFailed),
          // The signed-in route reaches the shell's SyncBanner — keep it off a
          // real Drift DB / connectivity_plus (and any pending stream timer).
          onlineProvider.overrideWith((ref) => Stream.value(true)),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          outboxDriverProvider.overrideWith((ref) {}),
          placeOrderHandlerProvider.overrideWith((ref) {}),
          photoUploadHandlerProvider.overrideWith((ref) {}),
        ],
        child: const CustomerApp(),
      );

  testWidgets('signed-out visitor is routed to the login screen',
      (tester) async {
    await tester.pumpWidget(app(userId: null));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signed-in customer lands on the Discover dashboard',
      (tester) async {
    await tester.pumpWidget(app(userId: 'user-1', role: 'customer'));
    // The Discover header's sheen animates forever, so pumpAndSettle would hang.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Home tab: a service tile and the dashboard's bottom-nav destinations.
    expect(find.text('Wash & Iron'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
  });

  testWidgets('a recovery in progress holds a signed-in user on the reset screen',
      (tester) async {
    // The recovery link signs the user in, so without this they would land on
    // the dashboard and never be asked for a new password.
    await tester.pumpWidget(app(userId: 'user-1', recovering: true));
    await tester.pumpAndSettle();

    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.text('Wash & Iron'), findsNothing);
  });

  testWidgets('a recovery link that produced no session explains itself',
      (tester) async {
    // The failure looks identical to an ordinary signed-out visit, so without
    // the router consulting it the user lands on /login and is left to request
    // more links that cannot work either.
    await tester.pumpWidget(app(userId: null, recoveryLinkFailed: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('same browser'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('ending recovery re-routes without any other auth event',
      (tester) async {
    // Recovery begins and ends without the auth state changing shape, so the
    // router needs its own listener on the flag. Without it the user would sit
    // here until something unrelated bumped the refresh listenable.
    //
    // Routed through a staff account on purpose: it proves the re-route while
    // landing on a screen that opens no Drift database and runs no endless
    // animation, so this test stays hermetic.
    await tester
        .pumpWidget(app(userId: 'user-1', role: 'manager', recovering: true));
    await tester.pumpAndSettle();
    expect(find.text('Set a new password'), findsOneWidget);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(CustomerApp)));
    (container.read(recoveringProvider.notifier) as _TestRecovering).set(false);
    await tester.pumpAndSettle();

    expect(find.text('Set a new password'), findsNothing);
    expect(find.text('This is a staff account'), findsOneWidget);
  });
}
