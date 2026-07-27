import '../orders/pricing/line_item.dart';
import '../orders/pricing/pricing_calculator.dart';
import '../orders/pricing/pricing_inputs.dart';
import 'pricing_settings.dart';

/// One piece-priced line in a cart (e.g. "Jacket" at a fixed catalog price,
/// quantity 2). Weight-priced items are folded into a single `estimatedWeightKg`
/// by the caller, since the rate/kg is service-independent.
class CartPieceLine {
  const CartPieceLine({
    required this.name,
    required this.unitUgx,
    this.qty = 1,
  });

  final String name;
  final int unitUgx;
  final int qty;

  /// The `LineItem` this piece contributes to the order (amount = unit × qty).
  /// Quantity is surfaced in the name because `LineItem` has no qty field and
  /// the staff pricing screen renders line-item names verbatim.
  LineItem toLineItem() => LineItem(
        name: qty > 1 ? '$name ×$qty' : name,
        amountUgx: unitUgx * qty,
      );
}

/// The full, provisional price breakdown for a cart — the numbers the cart
/// screen shows before checkout. Everything is an estimate until staff weigh the
/// pickup, so [isProvisional] is always true here.
class CartEstimate {
  const CartEstimate({
    required this.weightCharge,
    required this.pieceCharge,
    required this.expressSurcharge,
    required this.subtotal,
    required this.deliveryFee,
    required this.deliveryDiscount,
    required this.freeDeliveryApplied,
    required this.amountToFreeDeliveryUgx,
    required this.freeDeliveryThresholdUgx,
    required this.total,
    required this.isProvisional,
    required this.estimatedWeightKg,
    required this.lineItems,
  });

  final int weightCharge;
  final int pieceCharge;
  final int expressSurcharge;

  /// Everything except delivery: weight + pieces + express. This is the amount
  /// the free-delivery threshold is measured against.
  final int subtotal;

  /// Delivery actually charged (0 when waived or not a delivery order).
  final int deliveryFee;

  /// The delivery fee that was waived by hitting the free-delivery threshold
  /// (shown as a discount line); 0 otherwise.
  final int deliveryDiscount;

  final bool freeDeliveryApplied;

  /// How much more (in UGX) the customer must add to unlock free delivery; 0 if
  /// already free, not a delivery order, or the threshold is disabled.
  final int amountToFreeDeliveryUgx;

  final int freeDeliveryThresholdUgx;
  final int total;
  final bool isProvisional;
  final double estimatedWeightKg;
  final List<LineItem> lineItems;
}

/// Composes a [CartEstimate] from the cart's aggregate weight + its piece lines,
/// reusing [recomputeTotal] for the weight/pieces/express math (single source of
/// truth for rounding + the express formula), then applying the free-delivery
/// waiver on top.
///
/// - [estimatedWeightKg]: Σ of all weight-priced items' kg (0 if none).
/// - [pieces]: piece-priced items (catalog price × qty).
/// - [customerRatePerKgUgx]: per-customer rate override, else the shop default.
/// - [includeDelivery]: false for customer-collect orders.
/// - [freeDeliveryThresholdUgx]: subtotal at/above which delivery is free; 0
///   disables the feature. (Sourced from pricing settings once the column lands.)
CartEstimate composeCartEstimate({
  required double estimatedWeightKg,
  required List<CartPieceLine> pieces,
  required PricingSettings settings,
  double? customerRatePerKgUgx,
  required bool isExpress,
  required bool includeDelivery,
  int freeDeliveryThresholdUgx = 0,
}) {
  final rate = customerRatePerKgUgx ?? settings.defaultRatePerKgUgx;
  final lineItems = pieces.map((p) => p.toLineItem()).toList(growable: false);

  // Compute weight + pieces + express with delivery excluded, so `subtotal` is
  // the amount the threshold measures against.
  final base = recomputeTotal(PricingInputs(
    ratePerKgUgx: rate,
    estimatedWeightKg: estimatedWeightKg,
    lineItems: lineItems,
    isExpress: isExpress,
    expressFlatUgx: settings.expressFlatUgx,
    expressPct: settings.expressPct,
    deliveryFeeUgx: 0,
  ));

  final subtotal =
      base.weightCharge + base.lineItemsSum + base.expressSurcharge;

  // No delivery on an empty cart or a collect order.
  final wouldChargeDelivery =
      (includeDelivery && subtotal > 0) ? settings.deliveryFeeUgx : 0;
  final thresholdActive = wouldChargeDelivery > 0 && freeDeliveryThresholdUgx > 0;
  final freeDelivery = thresholdActive && subtotal >= freeDeliveryThresholdUgx;

  final deliveryFee = freeDelivery ? 0 : wouldChargeDelivery;
  final deliveryDiscount = freeDelivery ? wouldChargeDelivery : 0;
  final amountToFree = (thresholdActive && !freeDelivery)
      ? freeDeliveryThresholdUgx - subtotal
      : 0;

  return CartEstimate(
    weightCharge: base.weightCharge,
    pieceCharge: base.lineItemsSum,
    expressSurcharge: base.expressSurcharge,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    deliveryDiscount: deliveryDiscount,
    freeDeliveryApplied: freeDelivery,
    amountToFreeDeliveryUgx: amountToFree,
    freeDeliveryThresholdUgx: freeDeliveryThresholdUgx,
    total: subtotal + deliveryFee,
    isProvisional: true,
    estimatedWeightKg: estimatedWeightKg,
    lineItems: lineItems,
  );
}
