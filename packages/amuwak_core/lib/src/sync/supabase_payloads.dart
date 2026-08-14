import '../orders/order.dart';
import '../orders/order_status.dart';
import '../orders/proof_event.dart';

/// Pure builders for the ONLINE write path: domain model → snake_case Supabase
/// row map. Drift-free, so both the staff and customer apps share them.
///
/// Extracted from the repositories so the payload shapes (column names, casing,
/// UTC ISO timestamps) are unit-testable without mocking the Supabase client.
/// Keep the keys in sync with the table definitions under
/// `supabase/migrations/` and the staff app's `lib/src/data/tables/`.
///
/// The customer-row builder (`customerUpsertPayload`) stays in the staff app: it
/// operates on the Drift `Customer` row (with `created_at`), a staff-write
/// concern the customer app does not use (customers link via the
/// `link_or_create_customer` RPC).

Map<String, dynamic> orderUpsertPayload(
  LaundryOrder order, {
  required String actorStaffId,
  required DateTime now,
}) =>
    {
      'id': order.orderId,
      'order_code': order.orderCode,
      'customer_id': order.customerId,
      'customer_name': order.customerName,
      'phone': order.phone,
      'address': order.address,
      'service_type': order.serviceType.toDbString(),
      'status': order.status.toDbString(),
      'intake_method': order.intakeMethod,
      'fulfillment_method': order.fulfillmentMethod,
      'item_count': order.itemCount,
      'notes': order.notes,
      'scheduled_for': order.scheduledFor?.toUtc().toIso8601String(),
      'expected_collection_at':
          order.expectedCollectionAt?.toUtc().toIso8601String(),
      'rate_per_kg_snapshot_ugx': order.ratePerKgSnapshotUgx,
      'estimated_weight_kg': order.estimatedWeightKg,
      'final_weight_kg': order.finalWeightKg,
      'line_items': order.lineItems.map((i) => i.toJson()).toList(),
      'manual_adjustment_ugx': order.manualAdjustmentUgx,
      'delivery_fee_snapshot_ugx': order.deliveryFeeSnapshotUgx,
      'is_express': order.isExpress,
      'express_flat_snapshot_ugx': order.expressFlatSnapshotUgx,
      'express_pct_snapshot': order.expressPctSnapshot,
      'total_ugx': order.totalUgx,
      'payment_amount_ugx': order.paymentAmountUgx,
      'intake_recorded_by': actorStaffId,
      'created_by': actorStaffId,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };

Map<String, dynamic> orderStatusUpdatePayload(
  OrderStatus status, {
  required String actorStaffId,
  required DateTime now,
}) =>
    {
      'status': status.toDbString(),
      'updated_by': actorStaffId,
      'updated_at': now.toUtc().toIso8601String(),
    };

/// The cash-collected column for an order, as an ABSOLUTE cumulative total (not
/// a delta) — the caller computes the new collected amount from the current
/// order plus what's just been tendered and passes it whole, mirroring how
/// [orderStatusUpdatePayload] carries an absolute status. Narrow shape: only
/// `payment_amount_ugx` (+ updated_by/updated_at), so it can't clobber pricing,
/// status, or creation columns. [actorStaffId] is recorded as `updated_by`.
Map<String, dynamic> orderPaymentUpdatePayload(
  int amountUgx, {
  required String actorStaffId,
  required DateTime now,
}) =>
    {
      'payment_amount_ugx': amountUgx,
      'updated_by': actorStaffId,
      'updated_at': now.toUtc().toIso8601String(),
    };

/// The descriptive columns an edit can change after creation — customer
/// details, service, item count, notes, and schedule (+ updated_by/updated_at).
/// Mirrors [orderStatusUpdatePayload]'s narrow shape: it deliberately omits
/// `created_at`/`created_by`, `status`, and every pricing snapshot so an edit
/// can never clobber creation metadata or the frozen pricing (those flow
/// through `upsertOrder` / `updatePricing` / `updateStatus` instead).
/// [actorStaffId] is recorded as `updated_by` (the staff who made the edit).
Map<String, dynamic> orderDetailsUpdatePayload(
  LaundryOrder order, {
  required String actorStaffId,
  required DateTime now,
}) =>
    {
      'customer_name': order.customerName,
      'phone': order.phone,
      'address': order.address,
      'service_type': order.serviceType.toDbString(),
      'item_count': order.itemCount,
      'notes': order.notes,
      'scheduled_for': order.scheduledFor?.toUtc().toIso8601String(),
      'expected_collection_at':
          order.expectedCollectionAt?.toUtc().toIso8601String(),
      'updated_by': actorStaffId,
      'updated_at': now.toUtc().toIso8601String(),
    };

/// Soft-deletes an order — a back-office tombstone that drops it off the
/// rider's lists (`watchAll` filters `deleted_at != null` client-side). Mirrors
/// `ExpensesRepository.softDelete`. [actorStaffId] is recorded as `deleted_by`
/// for the destructive-action audit trail.
Map<String, dynamic> orderSoftDeletePayload({
  required String actorStaffId,
  required DateTime now,
}) =>
    {
      'deleted_at': now.toUtc().toIso8601String(),
      'deleted_by': actorStaffId,
      'updated_at': now.toUtc().toIso8601String(),
    };

Map<String, dynamic> proofEventUpsertPayload(
  ProofEvent event, {
  required String orderId,
  required String actorStaffId,
  required DateTime now,
}) =>
    {
      'id': event.id,
      'order_id': orderId,
      'type': event.type.name,
      'captured_at': event.capturedAt.toUtc().toIso8601String(),
      'item_count': event.count,
      'notes': event.notes,
      'captured_by': actorStaffId,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };
