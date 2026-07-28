import 'package:amuwak_core/amuwak_core.dart';

import 'order.dart';

/// The set of order subsets a dashboard summary card can drill into.
///
/// A single [OrderFilter] is the source of truth for BOTH a summary card's
/// count and the list shown on the screen the card opens, so the number on the
/// card can never disagree with the orders behind it.
enum OrderFilter {
  /// Every assigned order, regardless of status — the "Assigned" card.
  all,
  pendingPickup,
  inProgress,
  readyForDelivery,

  /// Orders *delivered today* (status completed + a delivery proof captured on
  /// the current calendar day). Distinct from an all-time completed count.
  completedToday,

  /// Every completed order, all-time (status completed, no date constraint) —
  /// the daily report's "Completed" card.
  completed,

  /// Every order not yet completed — the daily report's "Pending work" card.
  pendingWork;

  String get label => switch (this) {
        OrderFilter.all => 'Assigned',
        OrderFilter.pendingPickup => OrderStatus.pendingPickup.label,
        OrderFilter.inProgress => OrderStatus.inProgress.label,
        OrderFilter.readyForDelivery => OrderStatus.readyForDelivery.label,
        OrderFilter.completedToday => 'Completed today',
        OrderFilter.completed => 'Completed',
        OrderFilter.pendingWork => 'Pending work',
      };

  /// Completed work (both [completedToday] and [completed]) reads best
  /// most-recent-first; upcoming work reads best soonest-first.
  bool get newestFirst =>
      this == OrderFilter.completedToday || this == OrderFilter.completed;

  bool matches(LaundryOrder o, {required DateTime now}) => switch (this) {
        OrderFilter.all => true,
        OrderFilter.pendingPickup => o.status == OrderStatus.pendingPickup,
        OrderFilter.inProgress => o.status == OrderStatus.inProgress,
        OrderFilter.readyForDelivery =>
          o.status == OrderStatus.readyForDelivery,
        OrderFilter.completedToday => _isCompletedToday(o, now),
        OrderFilter.completed => o.status == OrderStatus.completed,
        OrderFilter.pendingWork => o.status != OrderStatus.completed,
      };

  List<LaundryOrder> apply(
    List<LaundryOrder> orders, {
    DateTime Function()? now,
  }) {
    final reference = (now ?? DateTime.now)();
    return orders
        .where((o) => matches(o, now: reference))
        .toList(growable: false);
  }

  /// How many orders match, without materializing a list — for summary-card
  /// counts, which are read on every dashboard rebuild.
  int count(List<LaundryOrder> orders, {DateTime Function()? now}) {
    final reference = (now ?? DateTime.now)();
    return orders.where((o) => matches(o, now: reference)).length;
  }

  static bool _isCompletedToday(LaundryOrder o, DateTime now) {
    if (o.status != OrderStatus.completed) return false;
    final delivered = o.deliveryProof?.capturedAt;
    if (delivered == null) return false;
    // capturedAt arrives from Supabase as UTC (DateTime.parse of a "...Z"
    // timestamp). Compare calendar days in the same zone as `now` (local),
    // or an order delivered in the 00:00–03:00 EAT window — stored as the
    // previous UTC day — would be mis-dated. toLocal() is a no-op when the
    // value is already local.
    final deliveredLocal = delivered.toLocal();
    final today = now.toLocal();
    return deliveredLocal.year == today.year &&
        deliveredLocal.month == today.month &&
        deliveredLocal.day == today.day;
  }
}
