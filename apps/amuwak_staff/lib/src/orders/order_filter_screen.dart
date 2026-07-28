import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amuwak_core/amuwak_core.dart';
import '../sync/repository_providers.dart';
import 'order.dart';
import 'order_filter.dart';
import 'order_list_extensions.dart';
import 'widgets/order_card.dart';

/// A read-only list of the orders behind one dashboard summary card.
///
/// Opened by tapping a summary card; the [filter] drives both that card's count
/// and this screen's list, so the two can never disagree. Orders are grouped
/// under date section headers (soonest-first, or most-recent-first for
/// completed work — see [OrderFilter.newestFirst]).
///
/// Watches [ordersStreamProvider] so the list stays live: an order that changes
/// status (or gets delivered) drops out of / moves within the list on the next
/// stream emit, exactly like the order search screen.
///
/// [onOrderTap] is the dashboard's order-details opener (it carries the session
/// check + repository wiring), so this screen never re-implements navigation
/// into the details view.
class OrderFilterScreen extends ConsumerWidget {
  const OrderFilterScreen({
    super.key,
    required this.filter,
    required this.onOrderTap,
    this.onEditOrder,
    this.onDeleteOrder,
    this.onAdvanceOrderStatus,
    this.onNewPickup,
    this.now,
    this.title,
  });

  final OrderFilter filter;
  final void Function(LaundryOrder order) onOrderTap;

  /// Optional per-card CRUD actions (edit / soft-delete / advance status),
  /// wired by the dashboard. Null leaves the cards tap-only.
  final void Function(LaundryOrder order)? onEditOrder;
  final void Function(LaundryOrder order)? onDeleteOrder;
  final void Function(LaundryOrder order)? onAdvanceOrderStatus;

  /// Opens the New Pickup flow from this list's FAB. Null hides the FAB (e.g.
  /// in isolation tests). The dashboard passes its existing `_handleNewPickup`.
  final VoidCallback? onNewPickup;

  /// Overrides the AppBar title. Defaults to [OrderFilter.label] when null —
  /// used so a caller (e.g. the daily report's "Orders" card) can title the
  /// screen to match the card the user tapped, even when it reuses
  /// [OrderFilter.all] (whose own label is "Assigned").
  final String? title;

  /// Injectable clock for tests so the "Completed today" predicate and the
  /// "Today"/"Tomorrow" day-group labels are deterministic. Defaults to the
  /// real clock in production.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title ?? filter.label)),
      floatingActionButton: onNewPickup == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onNewPickup,
              icon: const Icon(Icons.add),
              label: const Text('New pickup'),
            ),
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
    final groups = filter
        .apply(orders, now: now)
        .groupByDay(newestFirst: filter.newestFirst, now: now);

    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        headline: 'Nothing here',
        subtitle: 'No orders to show right now.',
      );
    }

    // Flatten the day groups into a single index model: each group contributes
    // a header row followed by one row per order, so the whole screen scrolls
    // as one list.
    final rows = <_Row>[];
    for (final group in groups) {
      rows.add(_HeaderRow(group.label));
      for (final order in group.orders) {
        rows.add(_OrderRow(order));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is _HeaderRow) {
          // First header hugs the top; later headers get breathing room above.
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        final order = (row as _OrderRow).order;
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

/// A flattened list row — either a date header or an order card.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.label);
  final String label;
}

class _OrderRow extends _Row {
  const _OrderRow(this.order);
  final LaundryOrder order;
}
