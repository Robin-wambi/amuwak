import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'widgets/status_chip.dart';
import 'widgets/status_timeline.dart';

/// Live order detail + tracking: the status ladder, the (provisional until
/// weighed) price, and an entry point into the per-order chat.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.orderCode ?? 'Order'),
        actions: [
          if (async.valueOrNull?.status == OrderStatus.pendingPickup)
            IconButton(
              tooltip: 'Edit order',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/orders/$orderId/edit'),
            ),
        ],
      ),
      floatingActionButton: async.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/orders/$orderId/chat'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message us'),
            ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text("Couldn't load this order.")),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.serviceType.label,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  StatusChip(order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(child: StatusTimeline(status: order.status)),
              const SizedBox(height: AppSpacing.lg),
              _PriceCard(order: order),
              if (order.status == OrderStatus.pendingPickup) ...[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, ref, order.orderId),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Confirms then cancels (soft-deletes) a pending order via the repository.
Future<void> _confirmCancel(
    BuildContext context, WidgetRef ref, String orderId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel this order?'),
      content: const Text(
          'This withdraws your pickup request. You can’t undo this.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(customerOrdersRepositoryProvider).cancel(orderId);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Order cancelled')));
      context.go('/');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not cancel. ($e)')));
    }
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.order});

  final LaundryOrder order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final provisional = order.finalWeightKg == null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Price', style: text.titleMedium),
              const SizedBox(width: AppSpacing.sm),
              _Badge(
                label: provisional ? 'Estimate' : 'Final',
                highlight: provisional,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _row(context, 'Total', formatUgx(order.totalUgx), bold: true),
          if (order.paymentAmountUgx > 0)
            _row(context, 'Paid', formatUgx(order.paymentAmountUgx)),
          if (order.outstandingUgx > 0)
            _row(context, 'Due', formatUgx(order.outstandingUgx), bold: true),
          if (provisional) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Estimated — the final price is set after we weigh your laundry.',
              style: text.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = highlight ? colors.tertiaryContainer : colors.surfaceContainerHighest;
    final fg = highlight ? colors.onTertiaryContainer : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
