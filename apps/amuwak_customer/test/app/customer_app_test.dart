import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/app/customer_app.dart';
import 'package:amuwak_customer/src/cart/cart_photo.dart';
import 'package:amuwak_customer/src/cart/checkout_service.dart';
import 'package:amuwak_customer/src/sync/sync_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drives the real router with auth overridden so it never touches Supabase.
/// Proves the redirect wiring: signed-out lands on login, signed-in on home.
void main() {
  Widget app({required String? userId}) => ProviderScope(
        overrides: [
          // Empty stream so routerProvider's listen never builds AuthService.
          authStateProvider.overrideWith((ref) => Stream<AuthState>.empty()),
          currentUserIdProvider.overrideWithValue(userId),
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
    await tester.pumpWidget(app(userId: 'user-1'));
    // The Discover header's sheen animates forever, so pumpAndSettle would hang.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Home tab: a service tile and the dashboard's bottom-nav destinations.
    expect(find.text('Wash & Iron'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
  });
}
