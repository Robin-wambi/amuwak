import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/repository_providers.dart';
import 'catalog_item.dart';
import 'pricing_catalog_repository.dart';
import 'pricing_settings.dart';
import 'pricing_settings_repository.dart';

final pricingSettingsRepositoryProvider =
    Provider<PricingSettingsRepository>(
  (ref) => PricingSettingsRepository(ref.watch(supabaseClientProvider)),
);

/// The full singleton pricing config (rate + delivery fee + express surcharge).
/// Re-read on invalidation (e.g. after the settings screen saves). The dashboard
/// reads this to seed the new-pickup screen with the rate + fee config.
final pricingSettingsProvider = FutureProvider<PricingSettings>(
  (ref) async => ref.watch(pricingSettingsRepositoryProvider).fetch(),
);

final pricingCatalogRepositoryProvider = Provider<PricingCatalogRepository>(
  (ref) => PricingCatalogRepository(ref.watch(supabaseClientProvider)),
);

/// Active catalog items for the pickup/billing picker. Invalidated after the
/// catalog manager saves.
final pricingCatalogProvider = FutureProvider<List<CatalogItem>>(
  (ref) async => ref.watch(pricingCatalogRepositoryProvider).fetchActive(),
);
