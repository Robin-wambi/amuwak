import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

/// A vertical tracking ladder over the four order statuses. Steps before the
/// current one read as done (filled + check), the current one is highlighted,
/// and later ones are muted — so a customer sees where their order is and what's
/// left. Driven purely by the order's current [status], which the detail stream
/// keeps live as staff advance it.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({required this.status, super.key});

  final OrderStatus status;

  /// Customer-facing wording for each rung (friendlier than the staff labels).
  static const _labels = {
    OrderStatus.pendingPickup: 'Order placed — awaiting pickup',
    OrderStatus.inProgress: 'Picked up — being cleaned',
    OrderStatus.readyForDelivery: 'Ready',
    OrderStatus.completed: 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.values;
    final currentIndex = status.index;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _Rung(
            label: _labels[steps[i]]!,
            state: i < currentIndex
                ? _RungState.done
                : i == currentIndex
                    ? _RungState.current
                    : _RungState.upcoming,
            isLast: i == steps.length - 1,
            colors: colors,
          ),
      ],
    );
  }
}

enum _RungState { done, current, upcoming }

class _Rung extends StatelessWidget {
  const _Rung({
    required this.label,
    required this.state,
    required this.isLast,
    required this.colors,
  });

  final String label;
  final _RungState state;
  final bool isLast;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final active = state != _RungState.upcoming;
    final dotColor = active ? colors.primary : colors.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _RungState.done ? colors.primary : null,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: state == _RungState.done
                    ? Icon(Icons.check, size: 12, color: colors.onPrimary)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: dotColor),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: state == _RungState.current
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: active
                        ? colors.onSurface
                        : colors.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
