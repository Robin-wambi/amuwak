import 'package:supabase_flutter/supabase_flutter.dart';

import '../orders/order.dart';
import '../orders/order_status.dart';
import '../orders/service_type.dart';
import '../shared/order_code.dart';
import 'supabase_payloads.dart';

/// The system sentinel staff row that owns customer-placed orders' NOT-NULL
/// `created_by`/`intake_recorded_by` columns (migration 0044). The real
/// originator is `placed_by_customer_id` (+ `customer_id`). The customer-insert
/// RLS policy (0046) requires both staff columns to equal exactly this id.
const kCustomerAppSentinelStaffId = '00000000-0000-0000-0000-00000000a001';

/// Test seam for a row insert: given the column map, returns the "selected"
/// rows (empty ⇒ the write did not persist, e.g. an RLS policy dropped it).
typedef OrderInsert =
    Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> values);

/// Test seam for the `next_order_code` RPC.
typedef OrderCodeRpc = Future<Object?> Function();

/// Test seam for the edit/cancel RPCs (`customer_update_order_details`,
/// `customer_cancel_order`): given the function name + params, stands in for the
/// live `SupabaseClient.rpc` call.
typedef CustomerOrderRpc = Future<void> Function(
    String fn, Map<String, dynamic> params);

/// Read + place repository for a customer's OWN orders — ONLINE-ONLY (Supabase
/// realtime `.stream()` reads; a direct RLS-gated insert to place an order).
///
/// A customer never advances status or edits price (no update path here; RLS
/// forbids it too). Placing an order mints the human `order_code` via the
/// `next_order_code` RPC, pins the intake/status/attribution the RLS insert
/// policy requires, and inserts directly.
class CustomerOrdersRepository {
  CustomerOrdersRepository(
    SupabaseClient supabase, {
    DateTime Function()? clock,
  })  : _supabase = supabase,
        _clock = clock ?? DateTime.now,
        _insertOverride = null,
        _rpcOverride = null,
        _editOverride = null;

  /// Test seam: drive [placeOrder] (RPC → payload shape → no-write [StateError])
  /// without a live SupabaseClient. Read methods assert the client is present.
  CustomerOrdersRepository.forTest({
    required DateTime Function() clock,
    OrderInsert? insertRow,
    OrderCodeRpc? nextOrderCode,
    CustomerOrderRpc? rpc,
  })  : _supabase = null,
        _clock = clock,
        _insertOverride = insertRow,
        _rpcOverride = nextOrderCode,
        _editOverride = rpc;

  final SupabaseClient? _supabase;
  final DateTime Function() _clock;
  final OrderInsert? _insertOverride;
  final OrderCodeRpc? _rpcOverride;
  final CustomerOrderRpc? _editOverride;

  /// Live list of the customer's own orders, newest activity first via
  /// `created_at`. RLS (`orders_customer_read`) already scopes to this customer,
  /// so the `.eq('customer_id', …)` is defence-in-depth + an index hint.
  Stream<List<LaundryOrder>> watchMine(String customerId) {
    assert(_supabase != null,
        'watchMine is not available on a forTest instance');
    return _supabase!
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at')
        .asyncMap((rows) => _hydrate(rows));
  }

  /// One order (with its proof events), or null if missing/not visible.
  Stream<LaundryOrder?> watchById(String orderId) {
    assert(_supabase != null,
        'watchById is not available on a forTest instance');
    return _supabase!
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .asyncMap((rows) async {
      final orders = await _hydrate(rows);
      return orders.isEmpty ? null : orders.first;
    });
  }

  /// Folds streamed `orders` rows + a follow-up `proof_events` fetch into
  /// [LaundryOrder]s. Drops soft-deleted orders; proofs are grouped by order id.
  Future<List<LaundryOrder>> _hydrate(List<Map<String, dynamic>> orderRows) async {
    final live =
        orderRows.where((r) => r['deleted_at'] == null).toList(growable: false);
    if (live.isEmpty) return const <LaundryOrder>[];
    final ids = live.map((r) => r['id'] as String).toList();
    final proofRows = await _supabase!
        .from('proof_events')
        .select()
        .inFilter('order_id', ids);
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in proofRows) {
      (grouped[p['order_id'] as String] ??= <Map<String, dynamic>>[]).add(p);
    }
    return live
        .map((r) =>
            LaundryOrder.fromSupabase(r, grouped[r['id'] as String] ?? const []))
        .toList(growable: false);
  }

  Future<Object?> _nextOrderCode() async {
    final override = _rpcOverride;
    if (override != null) return override();
    assert(_supabase != null,
        'forTest instance has no nextOrderCode — '
        'pass one to CustomerOrdersRepository.forTest(nextOrderCode: ...)');
    return _supabase!.rpc('next_order_code');
  }

  Future<List<Map<String, dynamic>>> _insertRow(
      Map<String, dynamic> values) async {
    final override = _insertOverride;
    if (override != null) return override(values);
    assert(_supabase != null,
        'forTest instance has no insertRow — '
        'pass one to CustomerOrdersRepository.forTest(insertRow: ...)');
    return _supabase!.from('orders').insert(values).select('id');
  }

  /// Places [draft] as a customer-app order: mints the real `order_code`, pins
  /// `intake_method='customer_app'` + `status='pending_pickup'` and the sentinel
  /// staff attribution the RLS insert policy requires, self-attributes via
  /// `placed_by_customer_id`, and inserts. Returns the new order id.
  ///
  /// The caller builds [draft] with a fresh `orderId`, the customer's
  /// `customerId`, and the chosen service/fulfilment/address/schedule/pricing
  /// snapshots. Throws [StateError] if the insert persisted no row (RLS drop).
  Future<String> placeOrder(LaundryOrder draft) async {
    final now = _clock();
    final code = parseOrderCodeRpcResult(await _nextOrderCode());
    final order = draft.copyWith(
      orderCode: code,
      intakeMethod: 'customer_app',
      status: OrderStatus.pendingPickup,
    );
    final payload = orderUpsertPayload(
      order,
      actorStaffId: kCustomerAppSentinelStaffId,
      now: now,
    )..['placed_by_customer_id'] = order.customerId;

    final written = await _insertRow(payload);
    if (written.isEmpty) {
      throw StateError(
          'placeOrder: order "${order.orderId}" did not persist (RLS?)');
    }
    return order.orderId;
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params) async {
    final override = _editOverride;
    if (override != null) return override(fn, params);
    assert(_supabase != null,
        'forTest instance has no rpc — pass one to '
        'CustomerOrdersRepository.forTest(rpc: ...)');
    await _supabase!.rpc(fn, params: params);
  }

  /// Amends the descriptive details of the customer's own order via the
  /// `customer_update_order_details` RPC. Server-side the RPC rejects anything
  /// but the caller's own still-pending order and touches only these fields —
  /// never price, status, or fulfilment. Throws if the order isn't editable.
  Future<void> updateDetails({
    required String orderId,
    required ServiceType serviceType,
    required String address,
    required int itemCount,
    String notes = '',
    DateTime? scheduledFor,
  }) =>
      _rpc('customer_update_order_details', {
        'p_order_id': orderId,
        'p_service_type': serviceType.toDbString(),
        'p_address': address,
        'p_item_count': itemCount,
        'p_notes': notes,
        'p_scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      });

  /// Cancels (soft-deletes) the customer's own order via the
  /// `customer_cancel_order` RPC. Only a still-pending order the caller owns can
  /// be cancelled; throws otherwise.
  Future<void> cancel(String orderId) =>
      _rpc('customer_cancel_order', {'p_order_id': orderId});
}
