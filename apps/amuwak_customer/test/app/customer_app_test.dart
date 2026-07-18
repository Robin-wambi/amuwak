import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/app/customer_app.dart';
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

  testWidgets('signed-in customer lands on the home (my orders) route',
      (tester) async {
    await tester.pumpWidget(app(userId: 'user-1'));
    await tester.pumpAndSettle();

    expect(find.text('My orders'), findsOneWidget);
  });
}
