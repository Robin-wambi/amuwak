import 'package:flutter/material.dart';

import 'package:amuwak_core/amuwak_core.dart';
import '../order.dart';

/// A single order summary card: customer name, order code + service type,
/// time/item-count chips, and a status pill. Shared between the dashboard
/// order list and the order search results so both stay visually identical.
///
/// Contextual CRUD is opt-in via the optional [onEdit], [onDelete], and
/// [onAdvanceStatus] callbacks. Supplying any of them surfaces visible action
/// icons (a pencil for Edit in the header, a ⋮ overflow at the bottom-right for
/// the rest) plus a long-press actions menu; Delete lives in that menu, guarded
/// by a confirm dialog. With none supplied the card is the original tap-only
/// summary (keeping its chevron), so existing call sites are unaffected.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAdvanceStatus,
  });

  final LaundryOrder order;
  final VoidCallback onTap;

  /// Opens the edit-details flow for this order. Null hides the menu entry.
  final VoidCallback? onEdit;

  /// Soft-deletes this order. Null hides the Delete entry in the actions menu.
  final VoidCallback? onDelete;

  /// Advances this order to its next status. Only wired for the single
  /// proof-less transition (in progress → ready for delivery); pickup and
  /// delivery steps need proof capture and route through [onTap] instead.
  final VoidCallback? onAdvanceStatus;

  /// The next status reachable inline without proof capture. Only
  /// `inProgress → readyForDelivery` qualifies — pickup and delivery require
  /// photos / a barcode scan, so they are never advanced from the card.
  OrderStatus? get _quickAdvanceTarget => order.status == OrderStatus.inProgress
      ? OrderStatus.readyForDelivery
      : null;

  /// Label for the proof-gated step a pending/ready order must open Details to
  /// complete (null when the order isn't waiting on a proof step).
  String? get _proofStepLabel => switch (order.status) {
        OrderStatus.pendingPickup => 'Confirm pickup',
        OrderStatus.readyForDelivery => 'Confirm delivery',
        _ => null,
      };

  bool get _hasActionsMenu =>
      onEdit != null || onDelete != null || onAdvanceStatus != null;

  /// Actions reachable only through the overflow sheet — everything except the
  /// pencil, which has its own dedicated icon. Drives whether the ⋮ button
  /// appears, so a card with only [onEdit] shows just the pencil rather than a
  /// ⋮ that opens a sheet repeating "Edit details".
  bool get _hasOverflowActions => onDelete != null || onAdvanceStatus != null;

  Future<void> _showActionsSheet(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final quickTarget = _quickAdvanceTarget;
    final proofStep = _proofStepLabel;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit details'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onEdit!();
                },
              ),
            // A proof-less advance is offered directly; a proof-gated step
            // routes to the card tap (which opens Details' capture flow) so an
            // order is never marked picked-up/delivered without its proof.
            if (onAdvanceStatus != null && quickTarget != null)
              ListTile(
                leading: const Icon(Icons.arrow_forward_rounded),
                title: Text('Mark as ${quickTarget.label}'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onAdvanceStatus!();
                },
              )
            else if (onAdvanceStatus != null && proofStep != null)
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: Text(proofStep),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onTap();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text('Delete',
                    style: TextStyle(color: colorScheme.error)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await _confirmDelete(context);
                  // StatelessWidget has no `mounted`; guard the card's context
                  // explicitly in case the list rebuilt away this card while
                  // the confirm dialog was open.
                  if (confirmed && context.mounted) onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Destructive actions always confirm. Returns true when the rider confirms.
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete order?'),
        content: Text(
          order.hasServerCode
              ? 'Delete order ${order.orderCode}? This hides it from the rider.'
              : 'Delete this pending order for ${order.customerName}? '
                  'This hides it from the rider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    Widget card = _buildCard(context);

    if (_hasActionsMenu) {
      card = GestureDetector(
        onLongPress: () => _showActionsSheet(context),
        child: card,
      );
    }

    return card;
  }

  /// A compact icon button sized so it doesn't grow the row it sits in. Used by
  /// the header pencil and the bottom-row ⋮ overflow; each wins the gesture
  /// arena on its own hit-box, so a tap fires its action while a tap elsewhere
  /// on the card still triggers the card's onTap.
  Widget _compactActionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) =>
      IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        color: Theme.of(context).colorScheme.primary,
      );

  /// The header's trailing slot. A plain tap-only card keeps its chevron; an
  /// actions card surfaces the common Edit as a visible pencil here. The ⋮
  /// overflow lives in the bottom row (beside the status pill), not here.
  Widget _buildTrailing(BuildContext context) {
    if (!_hasActionsMenu) {
      return const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.secondaryText,
      );
    }
    if (onEdit == null) return const SizedBox.shrink();
    return _compactActionButton(
      context,
      icon: Icons.edit_outlined,
      tooltip: 'Edit order',
      onPressed: onEdit!,
    );
  }

  Widget _buildCard(BuildContext context) {
    final statusPair = (Theme.of(context).extension<StatusColors>() ??
            StatusColors.light)
        .of(order.status);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.field - 2),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md + 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: textTheme.titleMedium,
                    ),
                    // Attribution for a self-service order the customer placed
                    // from the customer app (intake_method='customer_app'), so
                    // staff know it wasn't taken by a rider/in-shop.
                    if (order.intakeMethod == 'customer_app') ...[
                      const SizedBox(height: AppSpacing.xs / 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smartphone,
                              size: 12, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Placed via app',
                            style: textTheme.labelSmall
                                ?.copyWith(color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      // Offline orders have no server-minted AMW code yet, so
                      // show only the service (the "Pending sync" chip below
                      // signals the missing code) rather than a raw UUID.
                      order.hasServerCode
                          ? '${order.orderCode} - ${order.serviceType.label}'
                          : order.serviceType.label,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _buildTrailing(context),
            ],
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          Row(
            children: [
              // Surfaces an offline order still awaiting its server-minted AMW
              // code — the rider should identify it by customer name until sync.
              if (!order.hasServerCode) ...[
                _OrderInfoChip(
                  icon: Icons.sync_rounded,
                  label: order.referenceLabel,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _OrderInfoChip(
                icon: Icons.access_time_rounded,
                label: order.timeLabel,
              ),
              const SizedBox(width: AppSpacing.sm),
              _OrderInfoChip(
                icon: Icons.inventory_2_outlined,
                label: '${order.itemCount} items',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusPair.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    color: statusPair.onColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              // The ⋮ overflow sits opposite the status pill, filling the
              // bottom-right and keeping the header to the pencil + identity.
              if (_hasOverflowActions) ...[
                const Spacer(),
                _compactActionButton(
                  context,
                  icon: Icons.more_vert,
                  tooltip: 'More actions',
                  onPressed: () => _showActionsSheet(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderInfoChip extends StatelessWidget {
  const _OrderInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
