import 'cart_snapshot_item.dart';
import 'order_status.dart';
import 'proof_event.dart';
import 'service_type.dart';
import 'pricing/line_item.dart';

class LaundryOrder {
  const LaundryOrder({
    required this.orderId,
    String? orderCode,
    this.customerId,
    required this.customerName,
    required this.serviceType,
    required this.status,
    required this.timeLabel,
    required this.itemCount,
    required this.phone,
    required this.address,
    required this.notes,
    this.intakeMethod = 'driver_pickup',
    this.fulfillmentMethod = 'delivery',
    this.scheduledFor,
    this.expectedCollectionAt,
    this.proofEvents = const [],
    this.ratePerKgSnapshotUgx = 0,
    this.estimatedWeightKg,
    this.finalWeightKg,
    this.lineItems = const [],
    this.manualAdjustmentUgx = 0,
    this.totalUgx = 0,
    this.deliveryFeeSnapshotUgx = 0,
    this.isExpress = false,
    this.expressFlatSnapshotUgx = 0,
    this.expressPctSnapshot = 0,
    this.paymentAmountUgx = 0,
    this.cartItems = const [],
  }) : orderCode = orderCode ?? orderId;

  final String orderId;
  final String orderCode;
  final String? customerId;
  final String customerName;
  final ServiceType serviceType;
  final OrderStatus status;
  final String timeLabel;
  final int itemCount;
  final String phone;
  final String address;
  final String notes;
  final String intakeMethod;
  final String fulfillmentMethod;
  final DateTime? scheduledFor;

  /// The date staff promised the order would be ready for collection/delivery.
  /// Nullable: rider intake may leave it unset. Distinct from [scheduledFor]
  /// (the promised *pickup* time). See Supabase migration 0058.
  final DateTime? expectedCollectionAt;
  final List<ProofEvent> proofEvents;
  final double ratePerKgSnapshotUgx;
  final double? estimatedWeightKg;
  final double? finalWeightKg;
  final List<LineItem> lineItems;
  final int manualAdjustmentUgx;
  final int totalUgx;

  /// Flat delivery fee frozen onto the order (0 when delivery not included).
  final int deliveryFeeSnapshotUgx;

  /// Whether the express surcharge applies to this order.
  final bool isExpress;

  /// Express flat add-on and percentage frozen at creation, so the surcharge
  /// recomputes correctly once the final weight is recorded.
  final int expressFlatSnapshotUgx;
  final double expressPctSnapshot;

  /// Cumulative cash collected against this order. The single stored source of
  /// truth for payment; paid/partial/unpaid is *derived* (see [outstandingUgx]
  /// and [isFullyPaid]), never stored, so it can't drift from a later total
  /// change. See Supabase migration 0031.
  final int paymentAmountUgx;

  /// The itemized cart a customer-app order was checked out from
  /// (`orders.cart_items`, migration `0050`) — empty for orders a rider or the
  /// shop took. READ-ONLY on the staff side: it records what the customer said
  /// they were sending (and which garments they flagged with a photo), while
  /// staff still weigh and price the pickup with their own tools. Deliberately
  /// absent from [orderUpsertPayload] so a staff write can never clobber it.
  final List<CartSnapshotItem> cartItems;

  /// Damage photos the customer attached to their cart lines, in order.
  List<CartSnapshotItem> get flaggedCartItems =>
      cartItems.where((i) => i.hasPhoto).toList(growable: false);

  /// Money still owed: [totalUgx] minus what's been collected, clamped so an
  /// over-collection (change handed back in cash) never reads as negative.
  int get outstandingUgx => (totalUgx - paymentAmountUgx).clamp(0, totalUgx);

  /// Whether the order is settled — collected covers a non-zero total. A
  /// zero-total order is never "paid" (there's nothing to pay).
  bool get isFullyPaid => totalUgx > 0 && paymentAmountUgx >= totalUgx;

  /// Whether the human `AMW-YYYY-NNNN` code has been assigned by the server yet.
  ///
  /// An order created offline carries its UUID [orderId] as a placeholder
  /// [orderCode] (see the `orderCode ?? orderId` default) until the SyncPuller
  /// pulls the synced server row back with the real minted code. While the two
  /// are equal the code is a placeholder — never surface it as an order number
  /// or print it on a bag tag (it isn't a valid, scannable `AMW` code).
  bool get hasServerCode => orderCode != orderId;

  /// The reference to show a human: the real `AMW` code once assigned, or a
  /// clear "Pending sync" placeholder while an offline order awaits its code.
  String get referenceLabel => hasServerCode ? orderCode : 'Pending sync';

  ProofEvent? get pickupProof => _firstOfType(ProofEventType.pickup);
  ProofEvent? get deliveryProof => _firstOfType(ProofEventType.delivery);
  bool get hasPickupProof => pickupProof != null;
  bool get hasDeliveryProof => deliveryProof != null;

  /// The single date this order should be grouped/sorted by on a list screen.
  ///
  /// - Completed orders are anchored to when they were *delivered*
  ///   ([deliveryProof] capturedAt), falling back to [scheduledFor] if a
  ///   completed order is missing its proof (the non-atomic proof-vs-status
  ///   write).
  /// - Everything else is anchored to its upcoming [scheduledFor], falling
  ///   back to when it was *picked up* once it's in the shop.
  ///
  /// Immediate orders with neither a schedule nor any proof have no meaningful
  /// date and return `null` — callers group these under a "Now" section.
  DateTime? get relevantDate => status == OrderStatus.completed
      ? (deliveryProof?.capturedAt ?? scheduledFor)
      : (scheduledFor ?? pickupProof?.capturedAt);

  ProofEvent? _firstOfType(ProofEventType type) {
    for (final event in proofEvents) {
      if (event.type == type) return event;
    }
    return null;
  }

  /// Hydrates a [LaundryOrder] from a Supabase `orders` row (snake_case JSON)
  /// plus its joined `proof_events` rows. The online read path's hydrator —
  /// same status/service folding and the "photos live in Storage, drop them
  /// here" rule (`photoPaths` is `const []`). Soft-deleted proof rows
  /// (`deleted_at != null`) are dropped so they don't surface to the rider.
  ///
  /// The Drift read path's counterpart, `fromDriftRow`, stays in the staff app
  /// as an extension (it depends on the Drift row classes); this Drift-free
  /// hydrator is shared by both the staff and customer apps.
  factory LaundryOrder.fromSupabase(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> proofRows,
  ) {
    final scheduledFor = row['scheduled_for'] == null
        ? null
        : DateTime.parse(row['scheduled_for'] as String);
    final expectedCollectionAt = row['expected_collection_at'] == null
        ? null
        : DateTime.parse(row['expected_collection_at'] as String);
    return LaundryOrder(
      orderId: row['id'] as String,
      orderCode: _blankToNull(row['order_code'] as String?),
      customerId: row['customer_id'] as String?,
      customerName: row['customer_name'] as String,
      serviceType: ServiceType.fromDbString(row['service_type'] as String),
      status: OrderStatus.fromDbString(row['status'] as String),
      timeLabel: computeTimeLabel(
        scheduledFor: scheduledFor,
      ),
      itemCount: row['item_count'] as int,
      phone: row['phone'] as String,
      address: row['address'] as String,
      notes: (row['notes'] as String?) ?? '',
      intakeMethod: (row['intake_method'] as String?) ?? 'driver_pickup',
      fulfillmentMethod: (row['fulfillment_method'] as String?) ?? 'delivery',
      scheduledFor: scheduledFor,
      expectedCollectionAt: expectedCollectionAt,
      proofEvents: proofRows
          .where((e) => e['deleted_at'] == null)
          .map((e) => ProofEvent(
                id: e['id'] as String,
                type: ProofEventType.fromDbString(e['type'] as String),
                capturedAt: DateTime.parse(e['captured_at'] as String),
                count: e['item_count'] as int,
                photoPaths: const [],
                notes: e['notes'] as String?,
              ))
          .toList(growable: false),
      // Invariant: a missing or null rate snapshot must never error the whole
      // orders stream — degrade the row to 0. (Can occur for a row that predates
      // the pricing columns being added/backfilled.)
      ratePerKgSnapshotUgx:
          (row['rate_per_kg_snapshot_ugx'] as num?)?.toDouble() ?? 0,
      estimatedWeightKg: (row['estimated_weight_kg'] as num?)?.toDouble(),
      finalWeightKg: (row['final_weight_kg'] as num?)?.toDouble(),
      lineItems: _parseLineItems(row['line_items']),
      manualAdjustmentUgx: (row['manual_adjustment_ugx'] as num?)?.toInt() ?? 0,
      totalUgx: (row['total_ugx'] as num?)?.toInt() ?? 0,
      // Like the rate snapshot: a row predating these columns degrades to
      // 0/false (no delivery, not express) rather than erroring the stream.
      deliveryFeeSnapshotUgx:
          (row['delivery_fee_snapshot_ugx'] as num?)?.toInt() ?? 0,
      isExpress: (row['is_express'] as bool?) ?? false,
      expressFlatSnapshotUgx:
          (row['express_flat_snapshot_ugx'] as num?)?.toInt() ?? 0,
      expressPctSnapshot:
          (row['express_pct_snapshot'] as num?)?.toDouble() ?? 0,
      // Same degrade-to-0 rule: a row predating the payment column reads as
      // "nothing collected yet" rather than erroring the stream.
      paymentAmountUgx: (row['payment_amount_ugx'] as num?)?.toInt() ?? 0,
      // Empty for a rider/in-shop order, and for any row predating 0050.
      cartItems: parseCartSnapshot(row['cart_items']),
    );
  }

  /// Collapses an empty or whitespace-only `order_code` to `null` so the
  /// `orderCode ?? orderId` fallback fires. A blank (not null) code from a
  /// legacy row, manual DB edit, or server-side defect would otherwise leak
  /// through as the human-facing code. See #42.
  static String? _blankToNull(String? code) =>
      (code == null || code.trim().isEmpty) ? null : code;

  /// Parses `orders.line_items` (a jsonb array from Supabase, already decoded to
  /// `List`, or `null`) into typed [LineItem]s. Drops nothing — validation lives
  /// in [LineItem]'s constructor.
  static List<LineItem> _parseLineItems(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => LineItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  static String _formatTime(DateTime t) {
    final hour12 = switch (t.hour) {
      0 => 12,
      final h when h > 12 => h - 12,
      final h => h,
    };
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $ampm';
  }

  static const _weekdayShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Date-only label for a day relative to "now".
  /// Examples: `'Today'`, `'Tomorrow'`, `'Yesterday'`, `'Mon 1 Jun'`.
  /// The reference "now" is injectable for tests; defaults to [DateTime.now].
  static String formatDay(DateTime when, {DateTime Function()? now}) {
    final today = (now ?? DateTime.now)();
    final whenDay = DateTime(when.year, when.month, when.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final dayDelta = whenDay.difference(todayDay).inDays;
    if (dayDelta == 0) return 'Today';
    if (dayDelta == 1) return 'Tomorrow';
    if (dayDelta == -1) return 'Yesterday';
    final weekday = _weekdayShort[when.weekday - 1];
    final month = _monthShort[when.month - 1];
    return '$weekday ${when.day} $month';
  }

  /// Human-readable label for a scheduled pickup/delivery time.
  /// Examples: `'Today, 2:15 PM'`, `'Tomorrow, 9:00 AM'`, `'Mon 1 Jun, 9:00 AM'`.
  /// The reference "now" is injectable for tests; defaults to [DateTime.now].
  static String formatScheduled(DateTime when, {DateTime Function()? now}) =>
      '${formatDay(when, now: now)}, ${_formatTime(when)}';

  /// Single source of truth for the `timeLabel` shown on the dashboard order
  /// card. Both [LaundryOrder.fromSupabase] (when the stream re-emits an
  /// order after sync) and the New Pickup form (when it builds the in-memory
  /// `LaundryOrder` to pass to `upsertOrder`) call this so the displayed
  /// label can't drift between the in-memory and post-roundtrip values.
  ///
  /// - Scheduled orders → `'Today, 2:15 PM'` etc. via [formatScheduled].
  /// - Immediate orders → `'Pickup: now'` (a stable label that tells the
  ///   rider this order doesn't have a future schedule, distinct from the
  ///   creation timestamp which is shown elsewhere on the card).
  static String computeTimeLabel({
    required DateTime? scheduledFor,
    DateTime Function()? now,
  }) {
    if (scheduledFor != null) return formatScheduled(scheduledFor, now: now);
    return 'Pickup: now';
  }

  LaundryOrder copyWith({
    String? orderId,
    String? orderCode,
    String? customerId,
    String? customerName,
    ServiceType? serviceType,
    OrderStatus? status,
    String? timeLabel,
    int? itemCount,
    String? phone,
    String? address,
    String? notes,
    String? intakeMethod,
    String? fulfillmentMethod,
    DateTime? scheduledFor,
    DateTime? expectedCollectionAt,
    bool clearCustomerId = false,
    bool clearScheduledFor = false,
    bool clearExpectedCollectionAt = false,
    List<ProofEvent>? proofEvents,
    double? ratePerKgSnapshotUgx,
    double? estimatedWeightKg,
    double? finalWeightKg,
    List<LineItem>? lineItems,
    int? manualAdjustmentUgx,
    int? totalUgx,
    int? deliveryFeeSnapshotUgx,
    bool? isExpress,
    int? expressFlatSnapshotUgx,
    double? expressPctSnapshot,
    int? paymentAmountUgx,
    List<CartSnapshotItem>? cartItems,
    bool clearEstimatedWeight = false,
    bool clearFinalWeight = false,
  }) {
    return LaundryOrder(
      orderId: orderId ?? this.orderId,
      orderCode: _blankToNull(orderCode) ?? this.orderCode,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      customerName: customerName ?? this.customerName,
      serviceType: serviceType ?? this.serviceType,
      status: status ?? this.status,
      timeLabel: timeLabel ?? this.timeLabel,
      itemCount: itemCount ?? this.itemCount,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      intakeMethod: intakeMethod ?? this.intakeMethod,
      fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
      scheduledFor:
          clearScheduledFor ? null : (scheduledFor ?? this.scheduledFor),
      expectedCollectionAt: clearExpectedCollectionAt
          ? null
          : (expectedCollectionAt ?? this.expectedCollectionAt),
      proofEvents: proofEvents ?? this.proofEvents,
      ratePerKgSnapshotUgx: ratePerKgSnapshotUgx ?? this.ratePerKgSnapshotUgx,
      estimatedWeightKg: clearEstimatedWeight
          ? null
          : (estimatedWeightKg ?? this.estimatedWeightKg),
      finalWeightKg:
          clearFinalWeight ? null : (finalWeightKg ?? this.finalWeightKg),
      lineItems: lineItems ?? this.lineItems,
      manualAdjustmentUgx: manualAdjustmentUgx ?? this.manualAdjustmentUgx,
      totalUgx: totalUgx ?? this.totalUgx,
      deliveryFeeSnapshotUgx:
          deliveryFeeSnapshotUgx ?? this.deliveryFeeSnapshotUgx,
      isExpress: isExpress ?? this.isExpress,
      expressFlatSnapshotUgx:
          expressFlatSnapshotUgx ?? this.expressFlatSnapshotUgx,
      expressPctSnapshot: expressPctSnapshot ?? this.expressPctSnapshot,
      paymentAmountUgx: paymentAmountUgx ?? this.paymentAmountUgx,
      cartItems: cartItems ?? this.cartItems,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LaundryOrder) return false;
    if (other.orderId != orderId ||
        other.orderCode != orderCode ||
        other.customerId != customerId ||
        other.customerName != customerName ||
        other.serviceType != serviceType ||
        other.status != status ||
        other.timeLabel != timeLabel ||
        other.itemCount != itemCount ||
        other.phone != phone ||
        other.address != address ||
        other.notes != notes ||
        other.intakeMethod != intakeMethod ||
        other.fulfillmentMethod != fulfillmentMethod ||
        other.scheduledFor != scheduledFor ||
        other.expectedCollectionAt != expectedCollectionAt ||
        other.ratePerKgSnapshotUgx != ratePerKgSnapshotUgx ||
        other.estimatedWeightKg != estimatedWeightKg ||
        other.finalWeightKg != finalWeightKg ||
        other.manualAdjustmentUgx != manualAdjustmentUgx ||
        other.totalUgx != totalUgx ||
        other.deliveryFeeSnapshotUgx != deliveryFeeSnapshotUgx ||
        other.isExpress != isExpress ||
        other.expressFlatSnapshotUgx != expressFlatSnapshotUgx ||
        other.expressPctSnapshot != expressPctSnapshot ||
        other.paymentAmountUgx != paymentAmountUgx) {
      return false;
    }
    if (lineItems.length != other.lineItems.length) return false;
    for (var i = 0; i < lineItems.length; i++) {
      if (lineItems[i] != other.lineItems[i]) return false;
    }
    if (proofEvents.length != other.proofEvents.length) return false;
    for (var i = 0; i < proofEvents.length; i++) {
      if (proofEvents[i] != other.proofEvents[i]) return false;
    }
    if (cartItems.length != other.cartItems.length) return false;
    for (var i = 0; i < cartItems.length; i++) {
      if (cartItems[i] != other.cartItems[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        orderId,
        orderCode,
        customerId,
        customerName,
        serviceType,
        status,
        timeLabel,
        itemCount,
        phone,
        address,
        notes,
        intakeMethod,
        fulfillmentMethod,
        scheduledFor,
        expectedCollectionAt,
        Object.hashAll(proofEvents),
        // Pricing fields grouped into a nested hash to stay within Object.hash's
        // 20-argument limit.
        Object.hash(
          ratePerKgSnapshotUgx,
          estimatedWeightKg,
          finalWeightKg,
          Object.hashAll(lineItems),
          manualAdjustmentUgx,
          totalUgx,
          deliveryFeeSnapshotUgx,
          isExpress,
          expressFlatSnapshotUgx,
          expressPctSnapshot,
          paymentAmountUgx,
          Object.hashAll(cartItems),
        ),
      );
}
