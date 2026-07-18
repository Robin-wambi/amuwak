import 'dart:convert';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';

import '../data/app_database.dart' as drift;

export 'package:amuwak_core/models.dart' show LaundryOrder;

/// The Drift read-path hydrator for [LaundryOrder]. It stays in the staff app
/// (not `amuwak_core`) because it depends on the Drift-generated `Order` /
/// `ProofEvent` row classes. The Drift-free Supabase hydrator
/// [LaundryOrder.fromSupabase] lives on the core model and is shared by both
/// apps.
extension LaundryOrderDriftX on LaundryOrder {
  /// Hydrates a [LaundryOrder] from a Drift `orders` row plus its joined
  /// `proof_events` rows. The six-to-four status folding and the unknown-value
  /// degrade live on [OrderStatus.fromDbString] / [ProofEventType.fromDbString].
  ///
  /// Photos are intentionally dropped here — `photoPaths` is always
  /// `const []` because the photo binaries live in Supabase Storage and
  /// aren't pulled to the device until Plan 4.
  static LaundryOrder fromDriftRow(
    drift.Order row,
    List<drift.ProofEvent> events,
  ) {
    return LaundryOrder(
      orderId: row.id,
      orderCode: _blankToNull(row.orderCode),
      customerId: row.customerId,
      customerName: row.customerName,
      serviceType: ServiceType.fromDbString(row.serviceType),
      status: OrderStatus.fromDbString(row.status),
      timeLabel: LaundryOrder.computeTimeLabel(
        scheduledFor: row.scheduledFor,
      ),
      itemCount: row.itemCount,
      phone: row.phone,
      address: row.address,
      notes: row.notes,
      intakeMethod: row.intakeMethod,
      fulfillmentMethod: row.fulfillmentMethod,
      scheduledFor: row.scheduledFor,
      proofEvents: events
          .map((e) => ProofEvent(
                id: e.id,
                type: ProofEventType.fromDbString(e.type),
                capturedAt: e.capturedAt,
                count: e.itemCount,
                photoPaths: const [],
                notes: e.notes,
              ))
          .toList(growable: false),
      ratePerKgSnapshotUgx: row.ratePerKgSnapshotUgx,
      estimatedWeightKg: row.estimatedWeightKg,
      finalWeightKg: row.finalWeightKg,
      lineItems: _parseLineItems(jsonDecode(row.lineItems)),
      manualAdjustmentUgx: row.manualAdjustmentUgx,
      totalUgx: row.totalUgx,
      deliveryFeeSnapshotUgx: row.deliveryFeeSnapshotUgx,
      isExpress: row.isExpress,
      expressFlatSnapshotUgx: row.expressFlatSnapshotUgx,
      expressPctSnapshot: row.expressPctSnapshot,
      paymentAmountUgx: row.paymentAmountUgx,
    );
  }
}

/// Collapses an empty or whitespace-only `order_code` to `null` so the
/// `orderCode ?? orderId` fallback fires (see [LaundryOrder]'s own copy).
String? _blankToNull(String? code) =>
    (code == null || code.trim().isEmpty) ? null : code;

/// Parses a decoded `orders.line_items` jsonb array into typed [LineItem]s.
List<LineItem> _parseLineItems(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => LineItem.fromJson((e as Map).cast<String, dynamic>()))
      .toList(growable: false);
}
