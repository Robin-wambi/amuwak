import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';

/// Edit the descriptive details of a still-pending order (service, address,
/// item count, notes, pickup time). Never price, status, or delivery/collect —
/// those are fixed once placed. Backed by the customer_update_order_details RPC,
/// which re-checks ownership + editability server-side.
class EditOrderScreen extends ConsumerStatefulWidget {
  const EditOrderScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends ConsumerState<EditOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _items = TextEditingController();
  final _notes = TextEditingController();
  ServiceType _serviceType = ServiceType.washAndIron;
  DateTime? _scheduledFor;
  bool _initialized = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _items.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _initFrom(LaundryOrder o) {
    _address.text = o.address;
    _items.text = o.itemCount.toString();
    _notes.text = o.notes;
    _serviceType = o.serviceType;
    _scheduledFor = o.scheduledFor;
    _initialized = true;
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledFor ?? now),
    );
    if (time == null || !mounted) return;
    setState(() => _scheduledFor =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save(LaundryOrder order) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final delivery = order.fulfillmentMethod == 'delivery';
    try {
      await ref.read(customerOrdersRepositoryProvider).updateDetails(
            orderId: order.orderId,
            serviceType: _serviceType,
            address: delivery ? _address.text.trim() : '',
            itemCount: (int.tryParse(_items.text.trim()) ?? 1).clamp(1, 100000),
            notes: _notes.text.trim(),
            scheduledFor: _scheduledFor,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Order updated')));
        context.go('/orders/${order.orderId}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save changes. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit order')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load this order.")),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }
          if (order.status != OrderStatus.pendingPickup) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  "This order is already being handled and can no longer be "
                  "edited. Message the shop if you need a change.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!_initialized) _initFrom(order);
          final delivery = order.fulfillmentMethod == 'delivery';
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<ServiceType>(
                      value: _serviceType,
                      decoration: const InputDecoration(labelText: 'Service'),
                      items: ServiceType.values
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _serviceType = v ?? _serviceType),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (delivery)
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                            labelText: 'Pickup / delivery address'),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Enter an address for delivery'
                            : null,
                      ),
                    if (delivery) const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _items,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Number of items'),
                      validator: (v) =>
                          (int.tryParse((v ?? '').trim()) ?? 0) < 1
                              ? 'Enter at least 1 item'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text(_scheduledFor == null
                          ? 'Pickup: as soon as possible'
                          : 'Pickup: ${LaundryOrder.formatScheduled(_scheduledFor!)}'),
                      trailing: Wrap(
                        children: [
                          if (_scheduledFor != null)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _scheduledFor = null),
                            ),
                          TextButton(
                            onPressed: _pickSchedule,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _busy ? null : () => _save(order),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
