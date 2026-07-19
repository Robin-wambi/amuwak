import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../orders/providers.dart';

/// A read-only money view over the customer's orders. There is no online
/// payment yet — this surfaces what each order still owes (derived from
/// [LaundryOrder.outstandingUgx]) and what has been settled, with a running
/// total due at the top. Tapping a row opens the order.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  static const _paid = Color(0xFF2F7D32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton.tonal(
              onPressed: () => ref.invalidate(myOrdersProvider),
              child: const Text('Retry'),
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              headline: 'Nothing to pay yet',
              subtitle: 'Amounts due appear here once you place an order.',
            );
          }
          final due =
              list.where((o) => o.outstandingUgx > 0).toList(growable: false);
          final settled = list
              .where((o) => o.outstandingUgx == 0)
              .toList(growable: false);
          final totalDue =
              due.fold<int>(0, (sum, o) => sum + o.outstandingUgx);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _TotalDueCard(totalDue: totalDue),
              if (due.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel('Outstanding'),
                for (final o in due) _PaymentRow(order: o),
              ],
              if (settled.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel('Settled'),
                for (final o in settled) _PaymentRow(order: o),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TotalDueCard extends StatelessWidget {
  const _TotalDueCard({required this.totalDue});

  final int totalDue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL DUE',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            totalDue == 0 ? 'All settled' : formatUgx(totalDue),
            style: theme.textTheme.displayLarge?.copyWith(
              color: totalDue == 0 ? PaymentsScreen._paid : AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Pay your rider on pickup or delivery.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.order});

  final LaundryOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget trailing;
    if (order.outstandingUgx > 0) {
      trailing = Text(
        'Due ${formatUgx(order.outstandingUgx)}',
        style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary),
      );
    } else if (order.totalUgx == 0) {
      trailing = Text('Awaiting price',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppColors.secondaryText));
    } else {
      trailing = Text('Paid',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: PaymentsScreen._paid));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => context.go('/orders/${order.orderId}'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.referenceLabel,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(order.serviceType.label,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondaryText)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            trailing,
          ],
        ),
      ),
    );
  }
}
