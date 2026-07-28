import 'package:amuwak_core/amuwak_core.dart';
import 'order.dart';

extension OrderListStats on List<LaundryOrder> {
  int countByStatus(OrderStatus status) =>
      where((order) => order.status == status).length;

  int get totalItems =>
      fold<int>(0, (sum, order) => sum + order.itemCount);

  /// Revenue already earned: the sum of [LaundryOrder.totalUgx] across
  /// completed (delivered) orders. Accrual basis — revenue is recognised once
  /// the order is delivered.
  int get earnedRevenueUgx => where((o) => o.status == OrderStatus.completed)
      .fold<int>(0, (sum, o) => sum + o.totalUgx);

  /// Revenue still outstanding: the sum of [LaundryOrder.totalUgx] across
  /// orders that are not yet completed (their totals may be provisional when
  /// the final weight isn't in yet).
  int get expectedRevenueUgx => where((o) => o.status != OrderStatus.completed)
      .fold<int>(0, (sum, o) => sum + o.totalUgx);

  /// Total booked revenue across every order — equal to
  /// [earnedRevenueUgx] + [expectedRevenueUgx].
  int get totalRevenueUgx =>
      fold<int>(0, (sum, o) => sum + o.totalUgx);

  /// Cash actually collected across all orders — the real top line.
  int get collectedUgx =>
      fold<int>(0, (sum, o) => sum + o.paymentAmountUgx);

  /// Money still owed across all orders (receivables) — each order's balance
  /// is clamped at 0 so an over-collection can't net off another's debt.
  int get outstandingUgx =>
      fold<int>(0, (sum, o) => sum + o.outstandingUgx);

  /// Total charged across all orders (an alias of [totalRevenueUgx] read through
  /// the finance lens). Equals [collectedUgx] + [outstandingUgx] in normal
  /// operation; the two can exceed billed only if an order was *over-collected*
  /// (its `total_ugx` revised down after cash was taken), in which case the
  /// surplus is money owed back to the customer, not extra revenue.
  int get billedUgx => totalRevenueUgx;

  /// Average value of a *priced* order — billed revenue divided by the count of
  /// orders that actually have a bill (`total_ugx > 0`). Pending/unpriced orders
  /// are excluded from the denominator so they don't depress the average during
  /// normal operation. 0 when nothing is priced yet (no divide-by-zero).
  int get avgOrderValueUgx {
    final pricedCount = where((o) => o.totalUgx > 0).length;
    return pricedCount == 0 ? 0 : (billedUgx / pricedCount).round();
  }

  /// Money given away in the period: the absolute sum of the *negative* manual
  /// adjustments (discounts). Positive adjustments (surcharges) are excluded —
  /// see [RevenueBreakdown.surchargesUgx].
  int get discountsUgx => fold<int>(
      0, (sum, o) => sum + (o.manualAdjustmentUgx < 0 ? -o.manualAdjustmentUgx : 0));

  /// Revenue billed on an estimated weight only (not yet confirmed) — "at risk"
  /// of changing once the final weight is recorded.
  int get provisionalRevenueUgx => where((o) => o.finalWeightKg == null)
      .fold<int>(0, (sum, o) => sum + o.totalUgx);

  /// Revenue billed on a confirmed final weight.
  int get finalRevenueUgx => where((o) => o.finalWeightKg != null)
      .fold<int>(0, (sum, o) => sum + o.totalUgx);

  /// The net-sales waterfall over the period: gross charges (weight, line items,
  /// express, delivery) split out, plus discounts/surcharges, reusing the same
  /// pricing calculator that stamps `total_ugx` so the breakdown can never
  /// disagree with the billed total.
  RevenueBreakdown get revenueBreakdown {
    var weight = 0, lineItems = 0, express = 0, delivery = 0;
    var discounts = 0, surcharges = 0;
    for (final o in this) {
      final t = recomputeTotal(PricingInputs(
        ratePerKgUgx: o.ratePerKgSnapshotUgx,
        estimatedWeightKg: o.estimatedWeightKg,
        finalWeightKg: o.finalWeightKg,
        lineItems: o.lineItems,
        manualAdjustmentUgx: o.manualAdjustmentUgx,
        deliveryFeeUgx: o.deliveryFeeSnapshotUgx,
        isExpress: o.isExpress,
        expressFlatUgx: o.expressFlatSnapshotUgx,
        expressPct: o.expressPctSnapshot,
      ));
      weight += t.weightCharge;
      lineItems += t.lineItemsSum;
      express += t.expressSurcharge;
      delivery += t.deliveryFee;
      if (o.manualAdjustmentUgx < 0) {
        discounts += -o.manualAdjustmentUgx;
      } else {
        surcharges += o.manualAdjustmentUgx;
      }
    }
    return RevenueBreakdown(
      weightChargeUgx: weight,
      lineItemsUgx: lineItems,
      expressUgx: express,
      deliveryUgx: delivery,
      discountsUgx: discounts,
      surchargesUgx: surcharges,
    );
  }
}

/// The period's revenue split into its charge components plus discounts and
/// surcharges — the Loyverse/Square "gross → discounts → net" waterfall.
/// [netSalesUgx] reconciles to the list's billed total by construction.
class RevenueBreakdown {
  const RevenueBreakdown({
    required this.weightChargeUgx,
    required this.lineItemsUgx,
    required this.expressUgx,
    required this.deliveryUgx,
    required this.discountsUgx,
    required this.surchargesUgx,
  });

  final int weightChargeUgx;
  final int lineItemsUgx;
  final int expressUgx;
  final int deliveryUgx;
  final int discountsUgx;
  final int surchargesUgx;

  /// Gross charges before any adjustment: weight + line items + express +
  /// delivery.
  int get grossChargesUgx =>
      weightChargeUgx + lineItemsUgx + expressUgx + deliveryUgx;

  /// Net sales after adjustments: gross − discounts + surcharges. Reconciles to
  /// the billed total (Σ total_ugx) for every order whose stored total was
  /// stamped by the current pricing calculator (the write-path chokepoint, i.e.
  /// all live orders). A legacy row whose stored total predates the current
  /// formula could diverge; none exist in practice.
  int get netSalesUgx => grossChargesUgx - discountsUgx + surchargesUgx;
}

/// A run of orders that share a calendar day, with a ready-to-render header
/// label. [day] is null for the "Now" group (immediate orders with no
/// [LaundryOrder.relevantDate]).
class OrderDayGroup {
  const OrderDayGroup({
    required this.day,
    required this.label,
    required this.orders,
  });

  final DateTime? day;
  final String label;
  final List<LaundryOrder> orders;
}

extension OrderListGrouping on List<LaundryOrder> {
  /// Groups orders into day sections for a list screen, keyed on
  /// [LaundryOrder.relevantDate]'s calendar day.
  ///
  /// The "Now" group (orders with no relevant date — immediate pickups) always
  /// comes first. Dated groups, and the orders within every group, are ordered
  /// soonest-first by default, or most-recent-first when [newestFirst] is set
  /// (completed work). Ties break on [LaundryOrder.orderCode] so the order is
  /// stable.
  List<OrderDayGroup> groupByDay({
    required bool newestFirst,
    DateTime Function()? now,
  }) {
    final reference = now ?? DateTime.now;
    final dated = <DateTime, List<LaundryOrder>>{};
    final nowBucket = <LaundryOrder>[];
    for (final order in this) {
      final date = order.relevantDate;
      if (date == null) {
        nowBucket.add(order);
      } else {
        // relevantDate (capturedAt/scheduledFor) is UTC when sourced from
        // Supabase; bucket by the LOCAL calendar day so a late-night order
        // doesn't land under the previous day's header. toLocal() is a no-op
        // when the value is already local.
        final local = date.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        (dated[day] ??= <LaundryOrder>[]).add(order);
      }
    }

    int compare(LaundryOrder a, LaundryOrder b) {
      final da = a.relevantDate;
      final db = b.relevantDate;
      final byDate = (da == null || db == null) ? 0 : da.compareTo(db);
      final directed = newestFirst ? -byDate : byDate;
      return directed != 0 ? directed : a.orderCode.compareTo(b.orderCode);
    }

    final days = dated.keys.toList()
      ..sort((a, b) => newestFirst ? b.compareTo(a) : a.compareTo(b));

    return [
      if (nowBucket.isNotEmpty)
        OrderDayGroup(
          day: null,
          label: 'Now',
          orders: nowBucket..sort(compare),
        ),
      for (final day in days)
        OrderDayGroup(
          day: day,
          label: LaundryOrder.formatDay(day, now: reference),
          orders: dated[day]!..sort(compare),
        ),
    ];
  }
}

extension OrderListSearch on List<LaundryOrder> {
  /// Case-insensitive partial-match filter for the order search screen.
  /// Matches the query against the fields a rider would read off a bag/ticket:
  /// order code, customer name, phone, and address. An empty (or whitespace)
  /// query returns the list unchanged so callers can use this for the
  /// zero-state list as well.
  ///
  /// Phone is matched on the Ugandan national significant number
  /// ([ugandaNationalDigits]) so a local query (`0700123456`) still matches an
  /// internationally-stored number (`+256 700 123 456`) and vice versa,
  /// regardless of spacing.
  ///
  /// A bare-number query (e.g. `4` or `0042`) is treated as an order number and
  /// matched against the code's [orderCodeNumber] *exactly*, so a rider can type
  /// just the number off a bag instead of the full `AMW-2026-0042` — and typing
  /// `4` finds order #4 only, not every code that happens to contain a 4. A bare
  /// number only ever matches an order code or a phone (a typed phone number is
  /// digits too); it deliberately does NOT match names or addresses, so the
  /// digit in "4th Avenue" can't surface unrelated orders.
  List<LaundryOrder> searchBy(String query) {
    final raw = query.trim();
    if (raw.isEmpty) return this;
    final q = raw.toLowerCase();
    final queryDigits = ugandaNationalDigits(q);
    bool phoneMatches(LaundryOrder o) =>
        queryDigits.isNotEmpty &&
        ugandaNationalDigits(o.phone).contains(queryDigits);
    final queryNumber = isBareOrderNumber(raw) ? int.tryParse(raw) : null;
    return where((o) {
      if (queryNumber != null) {
        return orderCodeNumber(o.orderCode) == queryNumber || phoneMatches(o);
      }
      return o.orderCode.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.address.toLowerCase().contains(q) ||
          phoneMatches(o);
    }).toList(growable: false);
  }
}
