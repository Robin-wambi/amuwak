import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/auth/customer_session.dart';
import 'package:amuwak_customer/src/home/home_screen.dart';
import 'package:amuwak_customer/src/pricing/pricing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PricingSettings _settings({double rate = 3000}) => PricingSettings(
      id: 's',
      defaultRatePerKgUgx: rate,
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _harness({PricingSettings? settings, Customer? customer}) =>
    ProviderScope(
      overrides: [
        pricingSettingsProvider.overrideWith((ref) => settings ?? _settings()),
        currentCustomerProvider.overrideWith((ref) => Stream.value(customer)),
      ],
      child: MaterialApp(theme: buildAmuwakTheme(), home: const HomeScreen()),
    );

// The Discover header's gradient sheen animates forever, so pumpAndSettle would
// hang. Pump a build frame + one past the async provider resolution instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('renders a tile per service with the live per-kg rate',
      (tester) async {
    await tester.pumpWidget(_harness(settings: _settings(rate: 3000)));
    await _settle(tester);

    expect(find.text('Wash & Iron'), findsOneWidget);
    expect(find.text('Dry cleaning'), findsOneWidget);
    expect(find.text('Iron only'), findsOneWidget);
    expect(find.text('Wash only'), findsOneWidget);
    // One rate hint per tile.
    expect(find.text('from USh 3,000/kg'), findsNWidgets(4));
  });

  testWidgets('greets the customer by name when the profile is loaded',
      (tester) async {
    await tester.pumpWidget(_harness(
      customer: const Customer(id: 'c1', name: 'Ada', phone: '0700'),
    ));
    await _settle(tester);

    expect(find.text('Hi, Ada'), findsOneWidget);
  });

  testWidgets('falls back to a neutral rate hint when pricing is unavailable',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pricingSettingsProvider
              .overrideWith((ref) => Future<PricingSettings>.error('nope')),
          currentCustomerProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child:
            MaterialApp(theme: buildAmuwakTheme(), home: const HomeScreen()),
      ),
    );
    await _settle(tester);

    expect(find.text('Tap to get an estimate'), findsNWidgets(4));
  });
}
