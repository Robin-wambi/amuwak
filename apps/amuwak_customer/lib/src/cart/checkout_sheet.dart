import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/customer_session.dart';
import '../data/customer_database.dart';
import '../pricing/pricing_providers.dart';
import 'cart_providers.dart';
import 'cart_repository.dart';
import 'checkout_service.dart';

const _paymentMethods = [
  'Cash on handover',
  'MTN Mobile Money',
  'Airtel Money',
  'Flutterwave',
];

/// The "Cart checkout" review sheet: pickup address, delivery/collect, express,
/// and a (display-only) payment method, then places the order through the outbox
/// so checkout survives a poor connection.
Future<void> showCheckoutSheet(BuildContext context, WidgetRef ref) {
  final customer = ref.read(currentCustomerProvider).valueOrNull;
  final settings = ref.read(pricingSettingsProvider).valueOrNull;
  final items = ref.read(cartProvider).valueOrNull ?? const <CartItem>[];
  if (customer == null || settings == null || items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Still loading your details — try again in a moment.')));
    return Future.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _CheckoutForm(
        customer: customer,
        settings: settings,
        items: items,
        controller: ref.read(cartCheckoutControllerProvider),
        onPlaced: () {
          Navigator.of(sheetContext).pop();
          context.go('/orders');
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content:
                  Text('Order placed — it will sync when you are online.'),
            ));
        },
      ),
    ),
  );
}

class _CheckoutForm extends StatefulWidget {
  const _CheckoutForm({
    required this.customer,
    required this.settings,
    required this.items,
    required this.controller,
    required this.onPlaced,
  });

  final Customer customer;
  final PricingSettings settings;
  final List<CartItem> items;
  final CartCheckoutController controller;
  final VoidCallback onPlaced;

  @override
  State<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<_CheckoutForm> {
  late final TextEditingController _address =
      TextEditingController(text: widget.customer.address ?? '');
  String _fulfillment = 'delivery';
  bool _express = false;
  String _payment = _paymentMethods.first;
  bool _placing = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  CartEstimate get _estimate {
    final inputs = cartEstimateInputs(widget.items);
    return composeCartEstimate(
      estimatedWeightKg: inputs.weightKg,
      pieces: inputs.pieces,
      settings: widget.settings,
      customerRatePerKgUgx: widget.customer.customRatePerKgUgx,
      isExpress: _express,
      includeDelivery: _fulfillment == 'delivery',
      freeDeliveryThresholdUgx: widget.settings.freeDeliveryThresholdUgx,
    );
  }

  Future<void> _place() async {
    final address = _address.text.trim();
    if (_fulfillment == 'delivery' && address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a pickup address for delivery.')));
      return;
    }
    setState(() => _placing = true);
    await widget.controller.checkout(
      items: widget.items,
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      phone: widget.customer.phone,
      settings: widget.settings,
      customerRatePerKgUgx: widget.customer.customRatePerKgUgx,
      fulfillmentMethod: _fulfillment,
      address: address,
      isExpress: _express,
      paymentMethod: _payment,
    );
    widget.onPlaced();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estimate = _estimate;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cart checkout', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('${widget.items.length} item(s) · estimated ${formatUgx(estimate.total)}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'delivery', label: Text('Delivery')),
              ButtonSegment(value: 'customer_collect', label: Text('I\'ll drop off')),
            ],
            selected: {_fulfillment},
            onSelectionChanged: (s) => setState(() => _fulfillment = s.first),
          ),
          if (_fulfillment == 'delivery') ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                  labelText: 'Pickup address', prefixIcon: Icon(Icons.place_outlined)),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Express (faster turnaround)'),
            value: _express,
            onChanged: (v) => setState(() => _express = v),
          ),
          DropdownButtonFormField<String>(
            value: _payment,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              for (final m in _paymentMethods)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (m) => setState(() => _payment = m ?? _payment),
          ),
          const SizedBox(height: 4),
          Text('You pay on handover for now — no charge is taken in the app.',
              style: theme.textTheme.bodySmall),
          const Divider(height: AppSpacing.xl),
          _row(context, 'Subtotal', formatUgx(estimate.subtotal)),
          if (estimate.deliveryFee > 0)
            _row(context, 'Delivery', formatUgx(estimate.deliveryFee))
          else if (_fulfillment == 'delivery')
            _row(context, 'Delivery', 'Free'),
          _row(context, 'Estimated total', formatUgx(estimate.total), bold: true),
          const SizedBox(height: 4),
          Text('Final price is set after we weigh your laundry.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _placing ? null : _place,
            child: _placing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Place order'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final theme = Theme.of(context);
    final style = bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
