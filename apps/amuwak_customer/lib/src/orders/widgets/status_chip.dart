import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

/// A small tinted chip showing an order's status, using the shared
/// [StatusColors] theme extension so the color + accessible text color match
/// the staff app exactly.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final pair = Theme.of(context).extension<StatusColors>()!.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: pair.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: pair.onColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
