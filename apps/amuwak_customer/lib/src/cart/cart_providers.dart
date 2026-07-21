import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/customer_session.dart';
import '../data/customer_database.dart';
import '../pricing/pricing_providers.dart';
import '../sync/sync_providers.dart';
import 'cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(customerDatabaseProvider)),
);

/// The cart's lines, live from the local Drift table (works offline).
final cartProvider = StreamProvider<List<CartItem>>(
  (ref) => ref.watch(cartRepositoryProvider).watch(),
);

/// Number of lines in the cart (drives the Home cart badge).
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).valueOrNull?.length ?? 0,
);

/// The running price breakdown shown on the cart screen: delivery included and
/// not-express by default (the checkout sheet re-computes once the customer
/// picks fulfilment + express). Null until pricing settings load.
final cartEstimateProvider = Provider<CartEstimate?>((ref) {
  final settings = ref.watch(pricingSettingsProvider).valueOrNull;
  if (settings == null) return null;
  final items = ref.watch(cartProvider).valueOrNull ?? const <CartItem>[];
  final customer = ref.watch(currentCustomerProvider).valueOrNull;
  final inputs = cartEstimateInputs(items);
  return composeCartEstimate(
    estimatedWeightKg: inputs.weightKg,
    pieces: inputs.pieces,
    settings: settings,
    customerRatePerKgUgx: customer?.customRatePerKgUgx?.toDouble(),
    isExpress: false,
    includeDelivery: true,
    freeDeliveryThresholdUgx: settings.freeDeliveryThresholdUgx,
  );
});
