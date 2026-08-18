import 'dart:convert';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:drift/drift.dart' show Value;

import '../data/app_database.dart';
import '../orders/order.dart';
import 'outbox_repository.dart';
import 'supabase_payloads.dart';

/// Read/write repository for orders — OFFLINE-FIRST mode.
///
/// Reads stream from the local Drift `orders` table (hydrated with the joined
/// `proof_events` rows). Writes go to Drift immediately and enqueue a mutation
/// on the outbox for the SyncOrchestrator to dispatch to Supabase in the
/// background — so a rider on a poor or absent network still saves instantly and
/// the change syncs when connectivity returns.
///
/// Order creation is special: [createPickup] cannot insert `orders`/`customers`
/// directly under rider RLS, so it enqueues a `create_pickup` **RPC** outbox row
/// (the SECURITY DEFINER function mints the real `order_code` server-side). The
/// local row carries a placeholder code (its `orderId`) until the puller pulls
/// the synced server row back and replaces it. See [OutboxWorker.supabaseDispatcher].
class OrdersRepository {
  OrdersRepository(
    this._db, {
    OutboxRepository? outbox,
    DateTime Function()? clock,
  })  : _outbox = outbox,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository? _outbox;
  final DateTime Function() _clock;

  OutboxRepository _requireOutbox() {
    final o = _outbox;
    if (o == null) {
      throw StateError('OrdersRepository was constructed without an '
          'OutboxRepository; write methods are unavailable.');
    }
    return o;
  }

  // ----- READ -----

  /// Non-deleted orders, each hydrated with its proof events. Live via Drift's
  /// `.watch()`, so a locally-written order appears synchronously — no network
  /// round-trip. Soft-deleted rows (`deleted_at != null`) are filtered out.
  Stream<List<LaundryOrder>> watchAll() {
    return (_db.select(_db.orders)..where((t) => t.deletedAt.isNull()))
        .watch()
        .asyncMap((rows) async {
      if (rows.isEmpty) return const <LaundryOrder>[];
      final ids = rows.map((r) => r.id).toList();
      final events = await (_db.select(_db.proofEvents)
            ..where((t) => t.orderId.isIn(ids)))
          .get();
      final grouped = <String, List<ProofEvent>>{};
      for (final e in events) {
        grouped.putIfAbsent(e.orderId, () => <ProofEvent>[]).add(e);
      }
      return rows
          .map((r) => LaundryOrderDriftX.fromDriftRow(r, grouped[r.id] ?? const []))
          .toList(growable: false);
    });
  }

  /// A single order (with its proof events), or null if missing/soft-deleted.
  Stream<LaundryOrder?> watchById(String orderId) {
    return (_db.select(_db.orders)
          ..where((t) => t.id.equals(orderId))
          ..where((t) => t.deletedAt.isNull()))
        .watchSingleOrNull()
        .asyncMap((row) async {
      if (row == null) return null;
      final events = await (_db.select(_db.proofEvents)
            ..where((t) => t.orderId.equals(orderId)))
          .get();
      return LaundryOrderDriftX.fromDriftRow(row, events);
    });
  }

  /// One-shot read of all non-deleted orders (the New Pickup address-suggestion
  /// seed). Mirrors [watchAll] but returns a Future, not a stream.
  Future<List<LaundryOrder>> getAll() async {
    final rows =
        await (_db.select(_db.orders)..where((t) => t.deletedAt.isNull())).get();
    if (rows.isEmpty) return const <LaundryOrder>[];
    final ids = rows.map((r) => r.id).toList();
    final events = await (_db.select(_db.proofEvents)
          ..where((t) => t.orderId.isIn(ids)))
        .get();
    final grouped = <String, List<ProofEvent>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.orderId, () => <ProofEvent>[]).add(e);
    }
    return rows
        .map((r) => LaundryOrderDriftX.fromDriftRow(r, grouped[r.id] ?? const []))
        .toList(growable: false);
  }

  // ----- WRITE -----

  /// Returns a copy of [order] with `totalUgx` recomputed from its pricing
  /// inputs. The single chokepoint that keeps the stored total honest — a
  /// caller can never persist a total that disagrees with the weights/rate/
  /// line-items/adjustment.
  static LaundryOrder recomputeOrderTotal(LaundryOrder order) {
    final t = recomputeTotal(PricingInputs(
      ratePerKgUgx: order.ratePerKgSnapshotUgx,
      estimatedWeightKg: order.estimatedWeightKg,
      finalWeightKg: order.finalWeightKg,
      lineItems: order.lineItems,
      manualAdjustmentUgx: order.manualAdjustmentUgx,
      deliveryFeeUgx: order.deliveryFeeSnapshotUgx,
      isExpress: order.isExpress,
      expressFlatUgx: order.expressFlatSnapshotUgx,
      expressPct: order.expressPctSnapshot,
    ));
    return order.copyWith(totalUgx: t.total);
  }

  /// Resolves the rate to freeze into a new order: the customer's override if
  /// set, otherwise the global default.
  static double resolveRatePerKg({
    required double? customRate,
    required double defaultRate,
  }) =>
      customRate ?? defaultRate;

  /// Creates an order locally and enqueues its `create_pickup` RPC on the
  /// outbox. The local row carries a placeholder `order_code` (its id) until the
  /// puller pulls the synced server row back with the real minted code.
  ///
  /// Idempotent three ways: the local upsert is keyed on the (client-generated)
  /// order id; the outbox dedup key (`create_pickup:rpc:<orderId>`, no `extra`)
  /// makes a re-tap a SQL no-op; and the RPC itself returns the existing code on
  /// a retry with the same order id.
  Future<({String orderId, String orderCode})> createPickup(
    LaundryOrder order,
    Customer customer, {
    required String actorStaffId,
  }) async {
    final outbox = _requireOutbox();
    final now = _clock();
    final priced = recomputeOrderTotal(order);
    await _db.transaction(() async {
      await _db
          .into(_db.customers)
          .insertOnConflictUpdate(_customerCompanion(customer, now));
      await _db
          .into(_db.orders)
          .insertOnConflictUpdate(_toCompanion(priced, actorStaffId, now: now));
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'create_pickup', op: 'rpc', rowId: priced.orderId),
        forTable: 'create_pickup',
        op: 'rpc',
        rowId: priced.orderId,
        payload: <String, dynamic>{
          'p_customer': customerUpsertPayload(customer, now: now),
          'p_order':
              orderUpsertPayload(priced, actorStaffId: actorStaffId, now: now),
        },
      );
    });
    return (orderId: priced.orderId, orderCode: priced.orderCode);
  }

  /// Creates an order via a direct `orders` insert + outbox insert. Legacy path
  /// (the rider create flow now goes through [createPickup]); a plain insert
  /// only satisfies RLS for manager/in_shop roles. Retained for the pre-RPC
  /// callers and tests.
  Future<void> upsertOrder(LaundryOrder order,
      {required String actorStaffId}) async {
    final outbox = _requireOutbox();
    final now = _clock();
    final priced = recomputeOrderTotal(order);
    await _db.transaction(() async {
      await _db
          .into(_db.orders)
          .insertOnConflictUpdate(_toCompanion(priced, actorStaffId, now: now));
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'orders',
            op: 'insert',
            rowId: priced.orderId,
            extra: now.toUtc().toIso8601String()),
        forTable: 'orders',
        op: 'insert',
        rowId: priced.orderId,
        payload: orderUpsertPayload(priced, actorStaffId: actorStaffId, now: now),
      );
    });
  }

  /// Updates only the pricing columns (+ updated_at), recomputing total_ugx.
  Future<void> updatePricing(LaundryOrder order,
      {required String actorStaffId}) async {
    final outbox = _requireOutbox();
    final now = _clock();
    final priced = recomputeOrderTotal(order);
    final payload = <String, dynamic>{
      'estimated_weight_kg': priced.estimatedWeightKg,
      'final_weight_kg': priced.finalWeightKg,
      'line_items': priced.lineItems.map((i) => i.toJson()).toList(),
      'manual_adjustment_ugx': priced.manualAdjustmentUgx,
      'delivery_fee_snapshot_ugx': priced.deliveryFeeSnapshotUgx,
      'is_express': priced.isExpress,
      'express_flat_snapshot_ugx': priced.expressFlatSnapshotUgx,
      'express_pct_snapshot': priced.expressPctSnapshot,
      'total_ugx': priced.totalUgx,
      'updated_by': actorStaffId,
      'updated_at': now.toUtc().toIso8601String(),
    };
    await _db.transaction(() async {
      final affected = await (_db.update(_db.orders)
            ..where((t) => t.id.equals(priced.orderId)))
          .write(OrdersCompanion(
            estimatedWeightKg: Value(priced.estimatedWeightKg),
            finalWeightKg: Value(priced.finalWeightKg),
            lineItems: Value(
                jsonEncode(priced.lineItems.map((i) => i.toJson()).toList())),
            manualAdjustmentUgx: Value(priced.manualAdjustmentUgx),
            deliveryFeeSnapshotUgx: Value(priced.deliveryFeeSnapshotUgx),
            isExpress: Value(priced.isExpress),
            expressFlatSnapshotUgx: Value(priced.expressFlatSnapshotUgx),
            expressPctSnapshot: Value(priced.expressPctSnapshot),
            totalUgx: Value(priced.totalUgx),
            updatedBy: Value(actorStaffId),
            updatedAt: Value(now),
          ));
      if (affected == 0) {
        throw StateError('updatePricing: no order with id "${priced.orderId}"');
      }
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'orders',
            op: 'update',
            rowId: priced.orderId,
            extra: 'pricing:${now.toUtc().toIso8601String()}'),
        forTable: 'orders',
        op: 'update',
        rowId: priced.orderId,
        payload: payload,
      );
    });
  }

  /// Updates only the descriptive columns (+ updated_at) — customer details,
  /// service, item count, notes, schedule. Never touches created_at/created_by,
  /// pricing snapshots, or status.
  Future<void> updateOrderDetails(LaundryOrder order,
      {required String actorStaffId}) async {
    final outbox = _requireOutbox();
    final now = _clock();
    await _db.transaction(() async {
      final affected = await (_db.update(_db.orders)
            ..where((t) => t.id.equals(order.orderId)))
          .write(OrdersCompanion(
            customerName: Value(order.customerName),
            phone: Value(order.phone),
            address: Value(order.address),
            serviceType: Value(order.serviceType.toDbString()),
            itemCount: Value(order.itemCount),
            notes: Value(order.notes),
            scheduledFor: Value(order.scheduledFor),
            expectedCollectionAt: Value(order.expectedCollectionAt),
            updatedBy: Value(actorStaffId),
            updatedAt: Value(now),
          ));
      if (affected == 0) {
        throw StateError(
            'updateOrderDetails: no order with id "${order.orderId}"');
      }
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'orders',
            op: 'update',
            rowId: order.orderId,
            extra: 'details:${now.toUtc().toIso8601String()}'),
        forTable: 'orders',
        op: 'update',
        rowId: order.orderId,
        payload: orderDetailsUpdatePayload(order,
            actorStaffId: actorStaffId, now: now),
      );
    });
  }

  /// Soft-deletes an order (back-office tombstone) so it drops off the rider's
  /// lists — [watchAll] filters `deleted_at != null`. Enqueued as an `update`
  /// (setting `deleted_at`), not a `delete`.
  Future<void> softDelete(String orderId,
      {required String actorStaffId}) async {
    final outbox = _requireOutbox();
    final now = _clock();
    await _db.transaction(() async {
      final affected = await (_db.update(_db.orders)
            ..where((t) => t.id.equals(orderId)))
          .write(OrdersCompanion(
            deletedAt: Value(now),
            deletedBy: Value(actorStaffId),
            updatedAt: Value(now),
          ));
      if (affected == 0) {
        throw StateError('softDelete: no order with id "$orderId"');
      }
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'orders',
            op: 'update',
            rowId: orderId,
            extra: 'delete:${now.toUtc().toIso8601String()}'),
        forTable: 'orders',
        op: 'update',
        rowId: orderId,
        payload: orderSoftDeletePayload(actorStaffId: actorStaffId, now: now),
      );
    });
  }

  /// Updates only the payment amount (+ updated_at), so the finance report can
  /// net collected payments. Local Drift write + outbox enqueue.
  Future<void> updatePayment(String orderId, int amountUgx,
      {required String actorStaffId}) async {
    final outbox = _requireOutbox();
    final now = _clock();
    await _db.transaction(() async {
      final affected = await (_db.update(_db.orders)
            ..where((t) => t.id.equals(orderId)))
          .write(OrdersCompanion(
            paymentAmountUgx: Value(amountUgx),
            updatedBy: Value(actorStaffId),
            updatedAt: Value(now),
          ));
      if (affected == 0) {
        throw StateError('updatePayment: no order with id "$orderId"');
      }
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'orders',
            op: 'update',
            rowId: orderId,
            extra: 'payment:${now.toUtc().toIso8601String()}'),
        forTable: 'orders',
        op: 'update',
        rowId: orderId,
        payload: orderPaymentUpdatePayload(amountUgx,
            actorStaffId: actorStaffId, now: now),
      );
    });
  }

  /// Updates an order's status. [updatedAt] stabilises the outbox dedup key so
  /// a capture-screen retry with the same status + timestamp is a no-op.
  Future<void> updateStatus(
    String orderId,
    OrderStatus newStatus, {
    required String actorStaffId,
    DateTime? updatedAt,
  }) async {
    final outbox = _requireOutbox();
    final now = updatedAt ?? _clock();
    final dbStatus = newStatus.toDbString();
    await _db.transaction(() async {
      final affected = await (_db.update(_db.orders)
            ..where((t) => t.id.equals(orderId)))
          .write(OrdersCompanion(
            status: Value(dbStatus),
            updatedBy: Value(actorStaffId),
            updatedAt: Value(now),
          ));
      if (affected == 0) {
        throw StateError('updateStatus: no order with id "$orderId"');
      }
      await outbox.enqueue(
        id: OutboxRepository.dedupKeyFor(
            forTable: 'orders',
            op: 'update',
            rowId: orderId,
            extra: '$dbStatus:${now.toUtc().toIso8601String()}'),
        forTable: 'orders',
        op: 'update',
        rowId: orderId,
        payload:
            orderStatusUpdatePayload(newStatus, actorStaffId: actorStaffId, now: now),
      );
    });
  }

  CustomersCompanion _customerCompanion(Customer customer, DateTime now) {
    return CustomersCompanion(
      id: Value(customer.id),
      name: Value(customer.name),
      phone: Value(customer.phone),
      address: Value(customer.address),
      notes: Value(customer.notes),
      customRatePerKgUgx: Value(customer.customRatePerKgUgx),
      createdAt: Value(customer.createdAt),
      updatedAt: Value(now),
    );
  }

  OrdersCompanion _toCompanion(LaundryOrder order, String actorStaffId,
      {required DateTime now}) {
    return OrdersCompanion(
      id: Value(order.orderId),
      orderCode: Value(order.orderCode),
      customerId: Value(order.customerId),
      customerName: Value(order.customerName),
      phone: Value(order.phone),
      address: Value(order.address),
      serviceType: Value(order.serviceType.toDbString()),
      status: Value(order.status.toDbString()),
      intakeMethod: Value(order.intakeMethod),
      fulfillmentMethod: Value(order.fulfillmentMethod),
      itemCount: Value(order.itemCount),
      notes: Value(order.notes),
      scheduledFor: Value(order.scheduledFor),
      expectedCollectionAt: Value(order.expectedCollectionAt),
      intakeRecordedBy: Value(actorStaffId),
      createdBy: Value(actorStaffId),
      createdAt: Value(now),
      updatedAt: Value(now),
      ratePerKgSnapshotUgx: Value(order.ratePerKgSnapshotUgx),
      // Carried onto the local row, not only into the outbox payload: the
      // screens read Drift, so an audit that lived only in the queued RPC would
      // be invisible on this device until the puller brought it back.
      rateOverrideReason: Value(order.rateOverrideReason),
      rateOverrideFromUgx: Value(order.rateOverrideFromUgx),
      estimatedWeightKg: Value(order.estimatedWeightKg),
      finalWeightKg: Value(order.finalWeightKg),
      lineItems:
          Value(jsonEncode(order.lineItems.map((i) => i.toJson()).toList())),
      manualAdjustmentUgx: Value(order.manualAdjustmentUgx),
      totalUgx: Value(order.totalUgx),
      deliveryFeeSnapshotUgx: Value(order.deliveryFeeSnapshotUgx),
      isExpress: Value(order.isExpress),
      expressFlatSnapshotUgx: Value(order.expressFlatSnapshotUgx),
      expressPctSnapshot: Value(order.expressPctSnapshot),
    );
  }
}
