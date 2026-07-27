import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';

/// Builds the customer-app order draft from the form + pricing config and hands
/// it to [CustomerOrdersRepository.placeOrder] (which mints the code, pins the
/// customer_app attribution, and inserts). A plain injectable class so it is
/// unit-testable with a `.forTest()` repository and a fixed id generator.
class PlaceOrderController {
  PlaceOrderController({
    required CustomerOrdersRepository ordersRepository,
    String Function()? idGen,
  })  : _orders = ordersRepository,
        _idGen = idGen ?? defaultUuidV7;

  final CustomerOrdersRepository _orders;
  final String Function() _idGen;

  /// Assembles the draft, freezes the estimated total onto it, and places it.
  /// Returns the new order id. `finalWeightKg` is deliberately null — the price
  /// stays provisional until staff weigh the laundry.
  Future<String> submit({
    required String customerId,
    required String customerName,
    required String phone,
    required PricingSettings settings,
    double? customerRatePerKgUgx,
    required ServiceType serviceType,
    required String fulfillmentMethod, // 'delivery' | 'customer_collect'
    required String address,
    double? estimatedWeightKg,
    int itemCount = 0,
    String notes = '',
    bool isExpress = false,
    DateTime? scheduledFor,
  }) {
    final includeDelivery = fulfillmentMethod == 'delivery';
    final rate = customerRatePerKgUgx ?? settings.defaultRatePerKgUgx;

    var draft = LaundryOrder(
      orderId: _idGen(),
      customerId: customerId,
      customerName: customerName,
      serviceType: serviceType,
      status: OrderStatus.pendingPickup,
      timeLabel: LaundryOrder.computeTimeLabel(scheduledFor: scheduledFor),
      itemCount: itemCount,
      phone: phone,
      address: address,
      notes: notes,
      intakeMethod: 'customer_app',
      fulfillmentMethod: fulfillmentMethod,
      scheduledFor: scheduledFor,
      ratePerKgSnapshotUgx: rate,
      estimatedWeightKg: estimatedWeightKg,
      deliveryFeeSnapshotUgx: includeDelivery ? settings.deliveryFeeUgx : 0,
      isExpress: isExpress,
      expressFlatSnapshotUgx: settings.expressFlatUgx,
      expressPctSnapshot: settings.expressPct,
    );

    // Freeze the (provisional) estimated total onto the row so the list/detail
    // show an amount before staff weigh it.
    final total = recomputeTotal(PricingInputs(
      ratePerKgUgx: draft.ratePerKgSnapshotUgx,
      estimatedWeightKg: draft.estimatedWeightKg,
      finalWeightKg: draft.finalWeightKg,
      lineItems: draft.lineItems,
      manualAdjustmentUgx: draft.manualAdjustmentUgx,
      deliveryFeeUgx: draft.deliveryFeeSnapshotUgx,
      isExpress: draft.isExpress,
      expressFlatUgx: draft.expressFlatSnapshotUgx,
      expressPct: draft.expressPctSnapshot,
    )).total;
    draft = draft.copyWith(totalUgx: total);

    return _orders.placeOrder(draft);
  }
}
