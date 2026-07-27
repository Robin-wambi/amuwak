import 'package:amuwak_core/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/customer_session.dart';

final pricingSettingsRepositoryProvider = Provider<PricingSettingsRepository>(
  (ref) => PricingSettingsRepository(ref.watch(supabaseClientProvider)),
);

/// The singleton global pricing configuration. One-shot (the row is a
/// singleton, not realtime); the customer reads it under the
/// `pricing_settings_customer_read` RLS policy to compute an estimate.
final pricingSettingsProvider = FutureProvider<PricingSettings>(
  (ref) => ref.watch(pricingSettingsRepositoryProvider).fetch(),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseClientProvider)),
);

/// Active catalog items (fixed per-piece prices) for the cart's specialty-item
/// picker. One-shot read under `pricing_catalog_items_customer_read`. Requires
/// connectivity; piece items can't be added offline until the catalog is cached
/// (a later addition) — weight items always work offline.
final catalogItemsProvider = FutureProvider<List<CatalogItem>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchActive(),
);
