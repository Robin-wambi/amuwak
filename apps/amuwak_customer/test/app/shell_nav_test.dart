import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/app/customer_app.dart';
import 'package:amuwak_customer/src/auth/customer_session.dart';
import 'package:amuwak_customer/src/cart/cart_photo.dart';
import 'package:amuwak_customer/src/cart/checkout_service.dart';
import 'package:amuwak_customer/src/orders/providers.dart';
import 'package:amuwak_customer/src/pricing/pricing_providers.dart';
import 'package:amuwak_customer/src/sync/sync_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Overrides the providers the shell's SyncBanner reads, so it renders without
/// opening a real Drift DB (path_provider), hitting connectivity_plus, reaching
/// Supabase, or leaving a stream timer pending at teardown.
List<Override> offlineTestOverrides() => [
      onlineProvider.overrideWith((ref) => Stream.value(true)),
      pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
      outboxDriverProvider.overrideWith((ref) {}),
      placeOrderHandlerProvider.overrideWith((ref) {}),
      photoUploadHandlerProvider.overrideWith((ref) {}),
    ];

/// Drives the real router/shell with every Supabase-touching provider overridden
/// so the four bottom-nav tabs render without a live backend.
///
/// The Discover header animates forever, so pumpAndSettle would hang; pump a
/// build frame plus one past async provider/route resolution instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  Widget app() => ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<AuthState>.empty()),
          currentUserIdProvider.overrideWithValue('user-1'),
          // Stubbed for the same reason as the id: the redirect reads the role
          // too, and it falls back to the restored session — a real AuthService
          // — when the auth stream has not emitted.
          currentRoleProvider.overrideWithValue('customer'),
          pricingSettingsProvider.overrideWith(
            (ref) => PricingSettings(
              id: 's',
              defaultRatePerKgUgx: 3000,
              updatedAt: DateTime(2026, 1, 1),
            ),
          ),
          currentCustomerProvider.overrideWith(
            (ref) => Stream.value(
              const Customer(id: 'c1', name: 'Ada', phone: '0700'),
            ),
          ),
          myOrdersProvider.overrideWith((ref) => Stream.value(const [])),
          ...offlineTestOverrides(),
        ],
        child: const CustomerApp(),
      );

  testWidgets('the bottom nav switches between the four dashboard tabs',
      (tester) async {
    await tester.pumpWidget(app());
    await _settle(tester);

    // Starts on Home (Discover).
    expect(find.text('Wash & Iron'), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await _settle(tester);
    expect(find.text('My orders'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await _settle(tester);
    expect(find.text('Nothing to pay yet'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await _settle(tester);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
