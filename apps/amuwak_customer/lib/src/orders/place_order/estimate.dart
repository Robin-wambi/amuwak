import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';

/// Composes the global [PricingSettings], the customer's optional rate override,
/// and the rough form inputs into an [OrderTotal] via the shared
/// [recomputeTotal]. Always provisional (no final weight yet), so
/// `result.isProvisional` is true — the UI shows the "final price after we
/// weigh" disclaimer.
///
/// A pure function so it is unit-testable and can recompute live as the customer
/// edits the form.
OrderTotal estimateOrderTotal({
  required PricingSettings settings,
  double? customerRatePerKgUgx,
  double? estimatedWeightKg,
  bool includeDelivery = false,
  bool isExpress = false,
}) {
  return recomputeTotal(PricingInputs(
    ratePerKgUgx: customerRatePerKgUgx ?? settings.defaultRatePerKgUgx,
    estimatedWeightKg: estimatedWeightKg,
    finalWeightKg: null,
    deliveryFeeUgx: includeDelivery ? settings.deliveryFeeUgx : 0,
    isExpress: isExpress,
    expressFlatUgx: settings.expressFlatUgx,
    expressPct: settings.expressPct,
  ));
}
