import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../orders/order.dart';
import '../orders/order_list_extensions.dart';
import '../orders/widgets/order_card.dart';
import '../sync/repository_providers.dart';

/// A read-only breakdown of how the day's items are distributed across orders.
///
/// Opened by tapping the "Items" card on the daily report. Items is a count,
/// not an order subset, so this page can't reuse [OrderFilterScreen]; instead it
/// lists the orders that carry items, most-items-first, under a running total.
///
/// Watches [ordersStreamProvider] so the list stays live, and delegates row
/// taps to [onOrderTap] (the dashboard's order-details opener, which carries the
/// session check + repository wiring).
class ItemsBreakdownScreen extends ConsumerWidget {
  const ItemsBreakdownScreen({
    super.key,
    required this.onOrderTap,
    this.onEditOrder,
    this.onDeleteOrder,
    this.onAdvanceOrderStatus,
  });

  final void Function(LaundryOrder order) onOrderTap;

  /// Optional per-card CRUD actions, wired by the dashboard. Null = tap-only.
  final void Function(LaundryOrder order)? onEditOrder;
  final void Function(LaundryOrder order)? onDeleteOrder;
  final void Function(LaundryOrder order)? onAdvanceOrderStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Items')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          headline: "Couldn't load orders",
          subtitle: 'Please try again.',
        ),
        data: (orders) => _buildBody(context, orders),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<LaundryOrder> orders) {
    // Only orders that actually carry items, most-items-first. Ties break on
    // orderCode so the order of equal-count rows is stable.
    final withItems = orders.where((o) => o.itemCount > 0).toList()
      ..sort((a, b) {
        final byCount = b.itemCount.compareTo(a.itemCount);
        return byCount != 0 ? byCount : a.orderCode.compareTo(b.orderCode);
      });

    if (withItems.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        headline: 'No items yet',
        subtitle: 'No orders have items to show right now.',
      );
    }

    // Sum over the FULL list (not just withItems) so this header equals the
    // daily report's "Items" card count that opened this screen — orders with
    // zero items contribute nothing, so the two always agree.
    final totalItems = orders.totalItems;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      // +1 for the total-items header row at index 0.
      itemCount: withItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Total items handled today: $totalItems',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        final order = withItems[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: OrderCard(
            order: order,
            onTap: () => onOrderTap(order),
            onEdit: onEditOrder == null ? null : () => onEditOrder!(order),
            onDelete:
                onDeleteOrder == null ? null : () => onDeleteOrder!(order),
            onAdvanceStatus: onAdvanceOrderStatus == null
                ? null
                : () => onAdvanceOrderStatus!(order),
          ),
        );
      },
    );
  }
}
