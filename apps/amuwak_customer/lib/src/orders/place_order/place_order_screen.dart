import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/customer_session.dart';
import '../../pricing/pricing_providers.dart';
import '../providers.dart';
import 'estimate.dart';
import 'place_order_controller.dart';

/// Two-step wizard: enter pickup details, then review the (provisional) price
/// estimate and place the order.
class PlaceOrderScreen extends ConsumerStatefulWidget {
  const PlaceOrderScreen({
    super.key,
    this.initialService,
    this.initialExpress = false,
  });

  /// Pre-selected service when opened from a Discover tile; defaults to
  /// [ServiceType.washAndIron] when null.
  final ServiceType? initialService;

  /// Pre-tick the express toggle (from the "Express clean" quick action).
  final bool initialExpress;

  @override
  ConsumerState<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends ConsumerState<PlaceOrderScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _address = TextEditingController();
  // Pre-filled to 1: the orders table requires item_count > 0, and staff
  // re-count the actual items at intake anyway.
  final _items = TextEditingController(text: '1');
  final _notes = TextEditingController();

  late ServiceType _serviceType;
  String _fulfillment = 'delivery';
  late bool _express;
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serviceType = widget.initialService ?? ServiceType.washAndIron;
    _express = widget.initialExpress;
  }

  @override
  void dispose() {
    _weight.dispose();
    _address.dispose();
    _items.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? get _estWeight => double.tryParse(_weight.text.trim());
  bool get _includeDelivery => _fulfillment == 'delivery';

  Future<void> _place(PricingSettings settings, Customer customer) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = PlaceOrderController(
        ordersRepository: ref.read(customerOrdersRepositoryProvider),
      );
      final id = await controller.submit(
        customerId: customer.id,
        customerName: customer.name,
        phone: customer.phone,
        settings: settings,
        customerRatePerKgUgx: customer.customRatePerKgUgx,
        serviceType: _serviceType,
        fulfillmentMethod: _fulfillment,
        address: _includeDelivery ? _address.text.trim() : '',
        estimatedWeightKg: _estWeight,
        // Guaranteed >= 1 by the field validator; guard anyway so a stray 0
        // can't trip the orders_item_count_check DB constraint.
        itemCount: (int.tryParse(_items.text.trim()) ?? 1).clamp(1, 100000),
        notes: _notes.text.trim(),
        isExpress: _express,
      );
      if (mounted) context.go('/orders/$id');
    } catch (e) {
      // TODO: map known backend errors to friendly copy before release; for now
      // surface the cause so failures are diagnosable rather than opaque.
      if (mounted) {
        setState(() => _error = 'Could not place your order. ($e)');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(pricingSettingsProvider);
    final customer = ref.watch(currentCustomerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('New pickup')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text("Couldn't load pricing. Please try again later."),
          ),
        ),
        data: (settings) {
          if (customer == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stepper(
            currentStep: _step,
            onStepContinue: _onContinue,
            onStepCancel: _step == 0 ? null : () => setState(() => _step -= 1),
            controlsBuilder: (context, details) =>
                _controls(details, settings, customer),
            steps: [
              Step(
                title: const Text('Pickup details'),
                isActive: _step >= 0,
                content: _detailsForm(),
              ),
              Step(
                title: const Text('Review & place'),
                isActive: _step >= 1,
                content: _review(settings, customer),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onContinue() {
    if (_step == 0) {
      if (_detailsKey.currentState!.validate()) setState(() => _step = 1);
    }
  }

  Widget _controls(
      ControlsDetails details, PricingSettings settings, Customer customer) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          if (_step == 0)
            FilledButton(
              onPressed: details.onStepContinue,
              child: const Text('Review'),
            )
          else
            FilledButton(
              onPressed: _busy ? null : () => _place(settings, customer),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Place order'),
            ),
          const SizedBox(width: AppSpacing.sm),
          if (_step == 1)
            TextButton(
              onPressed: _busy ? null : details.onStepCancel,
              child: const Text('Back'),
            ),
        ],
      ),
    );
  }

  Widget _detailsForm() {
    return Form(
      key: _detailsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ServiceType>(
            value: _serviceType,
            decoration: const InputDecoration(labelText: 'Service'),
            items: ServiceType.values
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _serviceType = v ?? _serviceType),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'delivery', label: Text('Delivery')),
              ButtonSegment(
                  value: 'customer_collect', label: Text('I\'ll collect')),
            ],
            selected: {_fulfillment},
            onSelectionChanged: (s) => setState(() => _fulfillment = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_includeDelivery)
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Pickup / delivery address',
              ),
              validator: (v) => _includeDelivery && (v ?? '').trim().isEmpty
                  ? 'Enter an address for delivery'
                  : null,
            ),
          if (_includeDelivery) const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _weight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Rough weight (kg, optional)',
              helperText: 'Just an estimate — we weigh it at the shop.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _items,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Number of items',
              helperText: 'A rough count — we confirm it at the shop.',
            ),
            validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) < 1
                ? 'Enter at least 1 item'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Express (faster turnaround)'),
            value: _express,
            onChanged: (v) => setState(() => _express = v),
          ),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration:
                const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _review(PricingSettings settings, Customer customer) {
    final estimate = estimateOrderTotal(
      settings: settings,
      customerRatePerKgUgx: customer.customRatePerKgUgx,
      estimatedWeightKg: _estWeight,
      includeDelivery: _includeDelivery,
      isExpress: _express,
    );
    final rate = customer.customRatePerKgUgx ?? settings.defaultRatePerKgUgx;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            children: [
              _line('Rate per kg', '${formatUgx(rate.round())} / kg'),
              _line(
                _estWeight == null
                    ? 'Weight charge (est.)'
                    : 'Weight charge (${_estWeight!.toStringAsFixed(1)} kg)',
                formatUgx(estimate.weightCharge),
              ),
              if (estimate.deliveryFee > 0)
                _line('Delivery fee', formatUgx(estimate.deliveryFee)),
              if (estimate.expressSurcharge > 0)
                _line('Express surcharge', formatUgx(estimate.expressSurcharge)),
              const Divider(),
              _line(
                'Estimated total',
                formatUgx(estimate.total),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 18, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'This is an estimate. The final price is set after we weigh '
                'your laundry at the shop.',
                style: text.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
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
