import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../orders/order.dart';
import '../sync/repository_providers.dart';
import 'notification_summary.dart';
import 'relative_time.dart';

/// Live summary of new pickup orders and recently-delivered orders (48h),
/// derived from the same orders stream the dashboard watches.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    this.onOrderTap,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Opens Order Details for a tapped row. The dashboard passes its existing
  /// `_openOrderDetails`; null in isolation (e.g. tests that only assert UI).
  final void Function(LaundryOrder order)? onOrderTap;

  final DateTime Function() _clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorRetry(
          onRetry: () => ref.invalidate(ordersStreamProvider),
        ),
        data: (orders) {
          final now = _clock();
          final summary = NotificationSummary.fromOrders(orders, now: now);
          if (summary.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              headline: 'No notifications yet.',
              subtitle:
                  "We'll let you know when something needs your attention.",
            );
          }
          return _SummaryBody(
            summary: summary,
            now: now,
            onOrderTap: onOrderTap,
          );
        },
      ),
    );
  }
}

/// The "delivered/completed" accent, resolved from the theme's [StatusColors]
/// extension so it stays in lockstep with the completed-status pill on order
/// cards instead of a hardcoded hex.
Color _deliveredColor(BuildContext context) =>
    (Theme.of(context).extension<StatusColors>() ?? StatusColors.light)
        .completed
        .color;

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.summary,
    required this.now,
    required this.onOrderTap,
  });

  final NotificationSummary summary;
  final DateTime now;
  final void Function(LaundryOrder order)? onOrderTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: _CountChip(
                count: summary.newPickups.length,
                label: 'New pickups',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _CountChip(
                count: summary.delivered.length,
                label: 'Delivered · 48h',
                color: _deliveredColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Recent', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        // Built eagerly rather than via ListView.builder: the recent feed is
        // intentionally short (single-digit counts), so the simpler children
        // list is preferred. Revisit if the window ever grows large.
        for (final item in summary.recent)
          _NotificationRow(item: item, now: now, onOrderTap: onOrderTap),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.now,
    required this.onOrderTap,
  });

  final NotificationItem item;
  final DateTime now;
  final void Function(LaundryOrder order)? onOrderTap;

  @override
  Widget build(BuildContext context) {
    final isPickup = item.kind == NotificationKind.newPickup;
    final order = item.order;
    // Invariant from NotificationSummary.fromOrders: every `delivered` item has
    // a delivery proof. Assert it so a hand-built NotificationItem (or a future
    // refactor) that breaks the invariant fails loudly in debug instead of a
    // bare null-bang crash below.
    assert(
      isPickup || order.deliveryProof != null,
      'delivered NotificationItem must carry a delivery proof',
    );
    final colorScheme = Theme.of(context).colorScheme;
    final accent =
        isPickup ? colorScheme.primary : _deliveredColor(context);

    final title = isPickup
        ? 'New pickup · ${order.referenceLabel}'
        : 'Delivered · ${order.referenceLabel}';
    final subtitle = isPickup
        ? '${order.customerName} · ${order.timeLabel}'
        : '${order.customerName} · '
            '${relativeTimeLabel(order.deliveryProof!.capturedAt, now: now)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onOrderTap == null ? null : () => onOrderTap!(order),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.field - 2),
              ),
              child: Icon(
                isPickup
                    ? Icons.shopping_bag_outlined
                    : Icons.check_circle_outline,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Couldn't load notifications."),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
