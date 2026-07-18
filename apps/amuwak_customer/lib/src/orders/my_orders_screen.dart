import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'widgets/order_card.dart';

/// The customer's home: their orders, split into Active (anything not yet
/// completed) and History (completed). Live via [myOrdersProvider]. A FAB starts
/// a new pickup.
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  static bool _isActive(LaundryOrder o) => o.status != OrderStatus.completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My orders'),
          actions: [
            IconButton(
              tooltip: 'Inbox',
              icon: const Icon(Icons.notifications_none),
              onPressed: () => context.go('/inbox'),
            ),
            IconButton(
              tooltip: 'Account',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.go('/account'),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Active'), Tab(text: 'History')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/orders/new'),
          icon: const Icon(Icons.add),
          label: const Text('New pickup'),
        ),
        body: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(myOrdersProvider)),
          data: (list) {
            final active = list.where(_isActive).toList(growable: false);
            final history = list
                .where((o) => !_isActive(o))
                .toList(growable: false);
            return TabBarView(
              children: [
                _OrdersTab(
                  orders: active,
                  emptyIcon: Icons.local_laundry_service_outlined,
                  emptyTitle: 'No active orders',
                  emptySubtitle:
                      'Tap “New pickup” to schedule your first order.',
                ),
                _OrdersTab(
                  orders: history,
                  emptyIcon: Icons.history,
                  emptyTitle: 'No past orders yet',
                  emptySubtitle: 'Completed orders will appear here.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.orders,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<LaundryOrder> orders;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        headline: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final order = orders[i];
        return CustomerOrderCard(
          order: order,
          onTap: () => context.go('/orders/${order.orderId}'),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: AppSpacing.md),
          const Text("Couldn't load your orders"),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
