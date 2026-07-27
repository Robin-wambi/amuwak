import 'dart:async';
import 'dart:convert';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/customer_session.dart';
import '../data/customer_database.dart';
import '../sync/outbox_worker.dart';
import '../sync/sync_providers.dart';
import 'cart_repository.dart';

/// The op-type of a queued order placement in the outbox.
const kPlaceOrderOp = 'place_order';

/// Builds the frozen customer-app order the cart checks out as: one combined
/// pickup priced by [composeCartEstimate] (weight items summed, piece items as
/// line items, free-delivery waiver honoured), tagged with the cart's itemized
/// snapshot. `finalWeightKg` stays null — the price is provisional until staff
/// weigh the laundry.
LaundryOrder buildCartOrderDraft({
  required List<CartItem> items,
  required String customerId,
  required String customerName,
  required String phone,
  required PricingSettings settings,
  double? customerRatePerKgUgx,
  required String fulfillmentMethod, // 'delivery' | 'customer_collect'
  required String address,
  bool isExpress = false,
  DateTime? scheduledFor,
  String notes = '',
  required String Function() newId,
}) {
  final includeDelivery = fulfillmentMethod == 'delivery';
  final rate = customerRatePerKgUgx ?? settings.defaultRatePerKgUgx;
  final inputs = cartEstimateInputs(items);
  final estimate = composeCartEstimate(
    estimatedWeightKg: inputs.weightKg,
    pieces: inputs.pieces,
    settings: settings,
    customerRatePerKgUgx: customerRatePerKgUgx,
    isExpress: isExpress,
    includeDelivery: includeDelivery,
    freeDeliveryThresholdUgx: settings.freeDeliveryThresholdUgx,
  );

  return LaundryOrder(
    orderId: newId(),
    customerId: customerId,
    customerName: customerName,
    serviceType: _primaryService(items),
    status: OrderStatus.pendingPickup,
    timeLabel: LaundryOrder.computeTimeLabel(scheduledFor: scheduledFor),
    itemCount: _itemCount(items),
    phone: phone,
    address: address,
    notes: notes,
    intakeMethod: 'customer_app',
    fulfillmentMethod: fulfillmentMethod,
    scheduledFor: scheduledFor,
    ratePerKgSnapshotUgx: rate,
    estimatedWeightKg: inputs.weightKg == 0 ? null : inputs.weightKg,
    lineItems: estimate.lineItems,
    // Freeze the (post-waiver) delivery fee + estimated total onto the row.
    deliveryFeeSnapshotUgx: estimate.deliveryFee,
    isExpress: isExpress,
    expressFlatSnapshotUgx: settings.expressFlatUgx,
    expressPctSnapshot: settings.expressPct,
    totalUgx: estimate.total,
  );
}

/// The order-row insert payload for the outbox, WITHOUT `order_code` (minted at
/// drain time) and WITH the customer attribution + the cart snapshot.
Map<String, dynamic> buildPlaceOrderPayload({
  required LaundryOrder draft,
  required List<CartItem> items,
  required DateTime now,
}) {
  final payload = orderUpsertPayload(
    draft,
    actorStaffId: kCustomerAppSentinelStaffId,
    now: now,
  )
    ..['placed_by_customer_id'] = draft.customerId
    ..['cart_items'] = cartItemsSnapshot(items)
    ..remove('order_code');
  return payload;
}

/// The outbox handler for [kPlaceOrderOp]: mints the human `order_code`, stamps
/// it onto the queued row, and inserts. A duplicate-key on retry (the row was
/// already inserted but the outbox row wasn't cleared) is treated as success so
/// a placement is idempotent.
Future<void> placeOrderFromPayload(
    SupabaseClient supabase, String payloadJson) async {
  final map = (jsonDecode(payloadJson) as Map)
      .map((k, v) => MapEntry(k as String, v));
  final code = parseOrderCodeRpcResult(await supabase.rpc('next_order_code'));
  map['order_code'] = code;
  try {
    final written = await supabase.from('orders').insert(map).select('id');
    if (written.isEmpty) {
      throw StateError('place_order: no row persisted (RLS?)');
    }
  } on PostgrestException catch (e) {
    if (e.code == '23505') return; // already placed — idempotent retry
    rethrow;
  }
}

ServiceType _primaryService(List<CartItem> items) {
  for (final it in items) {
    if (it.kind == 'weight' && it.serviceType != null) {
      return ServiceType.values.firstWhere(
        (s) => s.name == it.serviceType,
        orElse: () => ServiceType.washAndIron,
      );
    }
  }
  return ServiceType.washAndIron;
}

int _itemCount(List<CartItem> items) {
  var n = 0;
  for (final it in items) {
    n += it.kind == 'piece' ? it.qty : 1;
  }
  return n < 1 ? 1 : n;
}

/// Queues a cart as one order and (best-effort) drains immediately: online it
/// places now, offline it stays queued and syncs on reconnect. Returns the new
/// order id (a local UUID until the server row syncs back with its `AMW` code).
class CartCheckoutController {
  CartCheckoutController({
    required CustomerDatabase db,
    required OutboxWorker outbox,
    DateTime Function()? clock,
    String Function()? newId,
  })  : _db = db,
        _outbox = outbox,
        _clock = clock ?? DateTime.now,
        _newId = newId ?? defaultUuidV7;

  final CustomerDatabase _db;
  final OutboxWorker _outbox;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<String> checkout({
    required List<CartItem> items,
    required String customerId,
    required String customerName,
    required String phone,
    required PricingSettings settings,
    double? customerRatePerKgUgx,
    required String fulfillmentMethod,
    required String address,
    bool isExpress = false,
    DateTime? scheduledFor,
    String? paymentMethod,
  }) async {
    // Payment is display-only for now — record the customer's choice as a note.
    final notes =
        paymentMethod == null ? '' : 'Preferred payment: $paymentMethod';
    final draft = buildCartOrderDraft(
      items: items,
      customerId: customerId,
      customerName: customerName,
      phone: phone,
      settings: settings,
      customerRatePerKgUgx: customerRatePerKgUgx,
      fulfillmentMethod: fulfillmentMethod,
      address: address,
      isExpress: isExpress,
      scheduledFor: scheduledFor,
      notes: notes,
      newId: _newId,
    );
    final payload =
        buildPlaceOrderPayload(draft: draft, items: items, now: _clock());
    await _db.enqueue(
      id: _newId(),
      opType: kPlaceOrderOp,
      payload: jsonEncode(payload),
      now: _clock(),
    );
    await _db.clearCart();
    unawaited(_outbox.drain());
    return draft.orderId;
  }
}

final cartCheckoutControllerProvider = Provider<CartCheckoutController>(
  (ref) => CartCheckoutController(
    db: ref.watch(customerDatabaseProvider),
    outbox: ref.watch(outboxWorkerProvider),
  ),
);

/// Registers the [kPlaceOrderOp] handler on the outbox worker. Watch this from
/// an always-mounted widget (the shell) so an order queued in a previous
/// session drains on launch, before the cart is ever opened.
final placeOrderHandlerProvider = Provider<void>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  ref
      .watch(outboxWorkerProvider)
      .register(kPlaceOrderOp, (p) => placeOrderFromPayload(supabase, p));
});
