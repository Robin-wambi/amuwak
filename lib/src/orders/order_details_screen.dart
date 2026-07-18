import 'package:flutter/material.dart';

import 'package:amuwak_core/amuwak_core.dart';
import '../pricing/catalog_item.dart';
import '../printing/label_printer.dart';
import '../printing/printer_store.dart';
import '../sync/orders_repository.dart';
import '../sync/proof_events_repository.dart';
import 'chat/order_chat_screen.dart';
import 'order.dart';
import 'payment/record_payment_sheet.dart';
import 'pricing/pricing_section.dart';
import 'proof_event.dart';
import 'proof/barcode_reader.dart';
import 'proof/delivery_capture_screen.dart';
import 'proof/pickup_capture_screen.dart';
import 'proof/printable_tag.dart';
import 'proof/proof_photo_storage.dart';
import 'proof/scanner_screen.dart';
import 'proof/tag_print_view.dart';

DateTime _defaultClock() => DateTime.now();

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.photoStorage,
    required this.pickPhoto,
    required this.cameraViewBuilder,
    required this.ordersRepo,
    required this.proofEventsRepo,
    required this.actorStaffId,
    this.clock = _defaultClock,
    this.labelPrinter,
    this.printerStore,
    this.captureTag = captureTagPng,
    this.catalogItems = const [],
  });

  final LaundryOrder order;
  final ProofPhotoStorage photoStorage;
  final PickPhotoFn pickPhoto;
  final CameraViewBuilder cameraViewBuilder;
  final OrdersRepository ordersRepo;
  final ProofEventsRepository proofEventsRepo;
  final String actorStaffId;
  final DateTime Function() clock;

  /// Label printer for bag tags, threaded through to pickup capture and the
  /// reprint sheet. Null at a printerless site (the print action doesn't appear).
  final LabelPrinter? labelPrinter;

  /// Remembers the last printer so the rider needn't re-pick it each shift.
  final PrinterStore? printerStore;

  /// Rasterises the printable tag. Injectable so tests skip real PNG encoding.
  final TagCapturer captureTag;

  /// Active catalog items offered in the "Add item" picker. Empty falls back to
  /// the free-form entry sheet.
  final List<CatalogItem> catalogItems;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late LaundryOrder _order;
  late final TextEditingController _finalWeightController;
  late final TextEditingController _manualAdjustmentController;
  late List<LineItem> _lineItems;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _finalWeightController = TextEditingController(
        text: _order.finalWeightKg == null
            ? ''
            : (_order.finalWeightKg! % 1 == 0
                ? _order.finalWeightKg!.toInt().toString()
                : _order.finalWeightKg!.toString()));
    _manualAdjustmentController = TextEditingController(
        text: _order.manualAdjustmentUgx == 0
            ? ''
            : _order.manualAdjustmentUgx.toString());
    _lineItems = [..._order.lineItems];
  }

  @override
  void dispose() {
    _finalWeightController.dispose();
    _manualAdjustmentController.dispose();
    super.dispose();
  }

  OrderTotal get _pricingTotal => recomputeTotal(PricingInputs(
        ratePerKgUgx: _order.ratePerKgSnapshotUgx,
        estimatedWeightKg: _order.estimatedWeightKg,
        finalWeightKg: double.tryParse(_finalWeightController.text.trim()),
        lineItems: _lineItems,
        manualAdjustmentUgx:
            int.tryParse(_manualAdjustmentController.text.trim()) ?? 0,
        deliveryFeeUgx: _order.deliveryFeeSnapshotUgx,
        isExpress: _order.isExpress,
        expressFlatUgx: _order.expressFlatSnapshotUgx,
        expressPct: _order.expressPctSnapshot,
      ));

  Future<void> _savePricing() async {
    final updated = _order.copyWith(
      finalWeightKg: double.tryParse(_finalWeightController.text.trim()),
      clearFinalWeight: _finalWeightController.text.trim().isEmpty,
      lineItems: _lineItems,
      manualAdjustmentUgx:
          int.tryParse(_manualAdjustmentController.text.trim()) ?? 0,
    );
    try {
      await widget.ordersRepo
          .updatePricing(updated, actorStaffId: widget.actorStaffId);
      if (!mounted) return;
      setState(() => _order = OrdersRepository.recomputeOrderTotal(updated));
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Pricing saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save pricing — please retry.')),
      );
    }
  }

  /// Derived payment state label — paid/partial/unpaid is never stored, it's
  /// read off collected vs total (see [LaundryOrder.isFullyPaid]).
  String get _paymentLabel {
    if (_order.isFullyPaid) return 'Paid';
    if (_order.paymentAmountUgx == 0) return 'Unpaid';
    return 'Partial';
  }

  /// Opens the change calculator to record cash against this order. The applied
  /// amount is added to the current collected total and persisted as the new
  /// absolute value, then optimistically reflected locally (this screen isn't
  /// subscribed to the orders stream).
  Future<void> _recordPayment() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: RecordPaymentSheet(
          amountDueUgx: _order.outstandingUgx,
          onConfirm: (applied) async {
            final newCollected = _order.paymentAmountUgx + applied;
            await widget.ordersRepo.updatePayment(
              _order.orderId,
              newCollected,
              actorStaffId: widget.actorStaffId,
            );
            if (mounted) {
              setState(() =>
                  _order = _order.copyWith(paymentAmountUgx: newCollected));
            }
          },
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Payment recorded.')));
    }
  }

  Future<void> _advanceStatusDirectly() async {
    final nextStatus = _order.status.nextStatus;
    if (nextStatus == null) return;
    try {
      await widget.ordersRepo.updateStatus(
        _order.orderId,
        nextStatus,
        actorStaffId: widget.actorStaffId,
      );
      if (!mounted) return;
      // Optimistic local update — the orders stream will reconcile this screen
      // is plain StatefulWidget and not subscribed to the stream itself.
      setState(() {
        _order = _order.copyWith(status: nextStatus);
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Order moved to ${nextStatus.label}.')),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save status change — please retry.'),
        ),
      );
    }
  }


  Future<void> _confirmPickup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PickupCaptureScreen(
          order: _order,
          photoStorage: widget.photoStorage,
          pickPhoto: widget.pickPhoto,
          clock: widget.clock,
          ordersRepo: widget.ordersRepo,
          proofEventsRepo: widget.proofEventsRepo,
          actorStaffId: widget.actorStaffId,
          labelPrinter: widget.labelPrinter,
          catalogItems: widget.catalogItems,
        ),
      ),
    );
    if (result == true && mounted) {
      // Optimistic local update; the orders stream is the source of truth on
      // the dashboard. History panel won't show the new proof event until a
      // refetch, which is acceptable for Task 11.
      setState(() {
        _order = _order.copyWith(status: OrderStatus.inProgress);
      });
    }
  }

  Future<void> _confirmDelivery() async {
    // A never-synced order still carries its UUID placeholder as order_code, so
    // no tag was ever printed and the code is never shown to the rider — there
    // is nothing to scan. Fall back to a customer-name confirmation (mirrors the
    // offline pickup-capture gating). A coded order keeps the tag scan.
    final bool proceed;
    if (_order.hasServerCode) {
      final scanOk = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ScannerScreen(
            expectedOrderCode: _order.orderCode,
            cameraViewBuilder: widget.cameraViewBuilder,
          ),
        ),
      );
      proceed = scanOk == true;
    } else {
      proceed = await _confirmUncodedDelivery();
    }
    if (!proceed || !mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeliveryCaptureScreen(
          order: _order,
          photoStorage: widget.photoStorage,
          pickPhoto: widget.pickPhoto,
          clock: widget.clock,
          ordersRepo: widget.ordersRepo,
          proofEventsRepo: widget.proofEventsRepo,
          actorStaffId: widget.actorStaffId,
        ),
      ),
    );
    if (result == true && mounted) {
      // Optimistic local update; the orders stream is the source of truth on
      // the dashboard. Delivery proof event won't show in the history panel
      // until a refetch, which is acceptable for Task 12.
      setState(() {
        _order = _order.copyWith(status: OrderStatus.completed);
      });
    }
  }

  /// Delivery confirmation for an order whose code hasn't synced yet: there is
  /// no printed tag to scan, so the rider verifies the handover by customer
  /// name instead. Returns true when they confirm.
  Future<bool> _confirmUncodedDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm delivery'),
        content: Text(
          "This order's code hasn't synced yet, so there's no tag to scan. "
          'Confirm you are handing over ${_order.customerName}\'s order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm delivery'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// The bag is tagged once it's cleaned, then scanned at delivery. Offer a
  /// reprint while it's in the depot (in progress / ready) so a missing or
  /// damaged tag can be replaced — but only when a printer is wired up.
  bool get _canReprintTag =>
      widget.labelPrinter != null &&
      (_order.status == OrderStatus.inProgress ||
          _order.status == OrderStatus.readyForDelivery);

  Future<void> _reprintTag() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reprint bag tag',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TagPrintView(
                orderCode: _order.orderCode,
                customerName: _order.customerName,
                labelPrinter: widget.labelPrinter,
                printerStore: widget.printerStore,
                captureTag: widget.captureTag,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    // Dashboard pushes this route as `push<bool>`; popping a LaundryOrder
    // here would mismatch the route's result type and silently coerce to
    // null. Pop `false` so the awaited result is well-typed for the caller.
    Navigator.pop<bool>(context, false);
  }

  Widget _buildPrimaryAction() {
    switch (_order.status) {
      case OrderStatus.pendingPickup:
        return ElevatedButton(
          onPressed: _confirmPickup,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded),
              SizedBox(width: AppSpacing.sm),
              Text('Confirm pickup'),
            ],
          ),
        );
      case OrderStatus.inProgress:
        return ElevatedButton(
          onPressed: () => _advanceStatusDirectly(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.update_rounded),
              SizedBox(width: AppSpacing.sm),
              Text('Move to Ready for delivery'),
            ],
          ),
        );
      case OrderStatus.readyForDelivery:
        return ElevatedButton(
          onPressed: _confirmDelivery,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delivery_dining_rounded),
              SizedBox(width: AppSpacing.sm),
              Text('Deliver'),
            ],
          ),
        );
      case OrderStatus.completed:
        return ElevatedButton(
          onPressed: null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded),
              SizedBox(width: AppSpacing.sm),
              Text('Order completed'),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusPair = (Theme.of(context).extension<StatusColors>() ??
            StatusColors.light)
        .of(_order.status);

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          title: const Text(
            'Order details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBackNavigation,
          ),
          actions: [
            // Chat is only meaningful for an order a customer placed from the
            // app (they have the app to receive the reply).
            if (widget.order.intakeMethod == 'customer_app')
              IconButton(
                tooltip: 'Chat with customer',
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OrderChatScreen(orderId: widget.order.orderId),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OrderHeader(order: _order),
                      const SizedBox(height: AppSpacing.xl),
                      _StatusChip(
                        color: statusPair.color,
                        onColor: statusPair.onColor,
                        label: _order.status.label,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _DetailsSection(
                        title: 'Customer',
                        children: [
                          _DetailRow(
                            icon: Icons.person_outline,
                            label: 'Name',
                            value: _order.customerName,
                          ),
                          _DetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: _order.phone,
                          ),
                          _DetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Address',
                            value: _order.address,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DetailsSection(
                        title: 'Laundry details',
                        children: [
                          _DetailRow(
                            icon: Icons.receipt_long_outlined,
                            label: 'Order code',
                            // "Pending sync" until the server-minted AMW code
                            // backfills — never the raw UUID placeholder.
                            value: _order.referenceLabel,
                          ),
                          _DetailRow(
                            icon: Icons.checkroom_outlined,
                            label: 'Service',
                            value: _order.serviceType.label,
                          ),
                          _DetailRow(
                            icon: Icons.inventory_2_outlined,
                            label: 'Items',
                            value: '${_order.itemCount} items',
                          ),
                          _DetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Time',
                            value: _order.timeLabel,
                          ),
                        ],
                      ),
                      if (_order.status != OrderStatus.pendingPickup) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DetailsSection(
                          title: 'Pricing',
                          children: [
                            _DetailRow(
                              icon: Icons.scale_outlined,
                              label: 'Rate',
                              value:
                                  '${formatUgx(_order.ratePerKgSnapshotUgx.round())}/kg',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              key: const Key('details_final_weight'),
                              controller: _finalWeightController,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Final weight (kg)'),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            LineItemsEditor(
                              items: _lineItems,
                              onAdd: () async {
                                final item = await showPickLineItemSheet(
                                    context, widget.catalogItems);
                                if (item != null) {
                                  setState(() => _lineItems = [..._lineItems, item]);
                                }
                              },
                              onRemove: (i) => setState(() {
                                _lineItems = [..._lineItems]..removeAt(i);
                              }),
                            ),
                            TextFormField(
                              key: const Key('details_manual_adjustment'),
                              controller: _manualAdjustmentController,
                              keyboardType: const TextInputType
                                  .numberWithOptions(signed: true),
                              decoration: const InputDecoration(
                                  labelText: 'Manual adjustment (UGX, +/-)'),
                              onChanged: (_) => setState(() {}),
                            ),
                            if (_order.isExpress &&
                                _pricingTotal.expressSurcharge > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _DetailRow(
                                icon: Icons.bolt_outlined,
                                label: 'Express',
                                value:
                                    formatUgx(_pricingTotal.expressSurcharge),
                              ),
                            ],
                            if (_pricingTotal.deliveryFee > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _DetailRow(
                                icon: Icons.local_shipping_outlined,
                                label: 'Delivery',
                                value: formatUgx(_pricingTotal.deliveryFee),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            TotalCard(
                              totalUgx: _pricingTotal.total,
                              isProvisional: _pricingTotal.isProvisional,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ElevatedButton(
                              key: const Key('details_save_pricing'),
                              onPressed: _savePricing,
                              child: const Text('Save pricing'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _DetailsSection(
                          title: 'Payment',
                          children: [
                            _DetailRow(
                              icon: Icons.payments_outlined,
                              label: 'Collected',
                              value: formatUgx(_order.paymentAmountUgx),
                            ),
                            _DetailRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Outstanding',
                              value: formatUgx(_order.outstandingUgx),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _PaymentBadge(label: _paymentLabel),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                key: const Key('details_record_payment'),
                                onPressed: _order.outstandingUgx == 0
                                    ? null
                                    : _recordPayment,
                                icon: const Icon(Icons.point_of_sale_outlined),
                                label: const Text('Record payment'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _DetailsSection(
                        title: 'Notes',
                        children: [
                          Builder(
                            builder: (context) => Text(
                              _order.notes.isEmpty ? '—' : _order.notes,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_order.proofEvents.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DetailsSection(
                          title: 'History',
                          children: [
                            for (final event in _order.proofEvents)
                              _ProofEventRow(event: event, now: widget.clock()),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_canReprintTag) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('reprint_tag'),
                          onPressed: _reprintTag,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Reprint tag'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _buildPrimaryAction(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});
  final LaundryOrder order;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: Icon(
              Icons.local_laundry_service_rounded,
              color: colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.referenceLabel,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  order.customerName,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  order.serviceType.label,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.color,
    required this.onColor,
    required this.label,
  });
  final Color color;
  final Color onColor;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(color: onColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Paid → primary, Partial → tertiary/secondary, Unpaid → error, all tinted.
    final color = switch (label) {
      'Paid' => colorScheme.primary,
      'Unpaid' => colorScheme.error,
      _ => colorScheme.tertiary,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 21),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofEventRow extends StatelessWidget {
  const _ProofEventRow({required this.event, required this.now});
  final ProofEvent event;
  final DateTime now;

  static const _monthAbbreviations = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _label =>
      event.type == ProofEventType.pickup ? 'Pickup' : 'Delivery';

  String get _timestampText {
    final dt = event.capturedAt;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) return '$hh:$mm';
    return '${dt.day} ${_monthAbbreviations[dt.month - 1]} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(
            event.type == ProofEventType.pickup
                ? Icons.qr_code_2_rounded
                : Icons.delivery_dining_rounded,
            color: colorScheme.primary,
            size: 21,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$_label · $_timestampText · ${event.count} items · '
              '${event.photoPaths.length} photo(s)',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
