import 'package:flutter/material.dart';

import 'package:amuwak_core/amuwak_core.dart';
import '../order.dart';
import 'order_card.dart';

/// A standalone, scrollable list of tappable [OrderCard]s with consistent
/// spacing. Shared by the orders tab and the order search results so the
/// card-list rendering (separator, padding, tap wiring) lives in one place.
///
/// Callers that want a section title render their own header above this in a
/// `Column` + `Expanded`, keeping their exact heading style — this widget owns
/// only the list itself, so there is no header/index bookkeeping here.
class OrderCardList extends StatelessWidget {
  const OrderCardList({
    super.key,
    required this.orders,
    required this.onOrderTap,
    this.onEditOrder,
    this.onDeleteOrder,
    this.onAdvanceOrderStatus,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final List<LaundryOrder> orders;
  final void Function(LaundryOrder order) onOrderTap;

  /// Optional per-card CRUD actions, forwarded to each [OrderCard]. Null leaves
  /// the cards tap-only (the actions menu and swipe-to-delete stay hidden).
  final void Function(LaundryOrder order)? onEditOrder;
  final void Function(LaundryOrder order)? onDeleteOrder;
  final void Function(LaundryOrder order)? onAdvanceOrderStatus;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          onTap: () => onOrderTap(order),
          onEdit: onEditOrder == null ? null : () => onEditOrder!(order),
          onDelete: onDeleteOrder == null ? null : () => onDeleteOrder!(order),
          onAdvanceStatus: onAdvanceOrderStatus == null
              ? null
              : () => onAdvanceOrderStatus!(order),
        );
      },
    );
  }
}
