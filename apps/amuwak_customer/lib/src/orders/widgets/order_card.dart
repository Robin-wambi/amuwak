import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';

import 'status_chip.dart';

/// One order row on the customer's list: code + status, a date line, and the
/// amount (with what's still due when partly/unpaid).
class CustomerOrderCard extends StatelessWidget {
  const CustomerOrderCard({required this.order, this.onTap, super.key});

  final LaundryOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = order.relevantDate;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.orderCode,
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              StatusChip(order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            date == null ? order.serviceType.label
                : '${order.serviceType.label} · ${LaundryOrder.formatDay(date)}',
            style: text.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatUgx(order.totalUgx),
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (order.outstandingUgx > 0)
                Text('Due ${formatUgx(order.outstandingUgx)}',
                    style: text.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600))
              else if (order.isFullyPaid)
                Text('Paid',
                    style: text.labelMedium?.copyWith(
                        color: Theme.of(context)
                            .extension<StatusColors>()!
                            .completed
                            .onColor,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
