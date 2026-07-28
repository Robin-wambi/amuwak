import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'order.dart';

typedef SaveOrderFn = Future<void> Function(LaundryOrder updated);

/// Edits an existing order's **descriptive** fields — customer details,
/// service, item count, notes, and schedule. Pricing and status are out of
/// scope (they live on [OrderDetailsScreen]); this screen never touches the
/// frozen pricing snapshots or the workflow status.
///
/// [save] is injected (the dashboard wires it to
/// `OrdersRepository.updateOrderDetails`) so the screen is testable without
/// Riverpod, mirroring [ExpenseEntryScreen] / [PricingSettingsScreen].
class EditOrderScreen extends StatefulWidget {
  const EditOrderScreen({super.key, required this.order, required this.save});

  final LaundryOrder order;
  final SaveOrderFn save;

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _itemCountController;
  late final TextEditingController _notesController;
  late ServiceType _serviceType;
  DateTime? _scheduledFor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _nameController = TextEditingController(text: o.customerName);
    _phoneController = TextEditingController(text: o.phone);
    _addressController = TextEditingController(text: o.address);
    _itemCountController = TextEditingController(text: o.itemCount.toString());
    _notesController = TextEditingController(text: o.notes);
    _serviceType = o.serviceType;
    _scheduledFor = o.scheduledFor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _itemCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final base = _scheduledFor ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledFor =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a customer name.')),
      );
      return;
    }
    final itemCount = int.tryParse(_itemCountController.text.trim());
    // The DB enforces CHECK (item_count > 0), so 0 must be rejected here rather
    // than failing server-side with an opaque error.
    if (itemCount == null || itemCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an item count of at least 1.')),
      );
      return;
    }
    final updated = widget.order.copyWith(
      customerName: name,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      serviceType: _serviceType,
      itemCount: itemCount,
      notes: _notesController.text.trim(),
      scheduledFor: _scheduledFor,
      clearScheduledFor: _scheduledFor == null,
      // Keep the derived label in step with the (possibly changed) schedule so
      // the in-memory order is self-consistent before the stream re-hydrates it.
      timeLabel: LaundryOrder.computeTimeLabel(scheduledFor: _scheduledFor),
    );
    setState(() => _saving = true);
    try {
      await widget.save(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Order updated.')));
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } catch (e, st) {
      developer.log('Order save failed.',
          name: 'EditOrderScreen', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — please retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit order')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Customer', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('edit_customer_name'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('edit_phone'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('edit_address'),
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Service', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final service in ServiceType.values)
                  ChoiceChip(
                    label: Text(service.label),
                    selected: _serviceType == service,
                    onSelected: (_) => setState(() => _serviceType = service),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Items', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('edit_item_count'),
              controller: _itemCountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Item count',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Schedule', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _scheduledFor == null
                        ? 'Immediate (pickup now)'
                        : LaundryOrder.formatScheduled(_scheduledFor!),
                  ),
                ),
                TextButton(
                  key: const Key('edit_pick_schedule'),
                  onPressed: _pickSchedule,
                  child: const Text('Change'),
                ),
                if (_scheduledFor != null)
                  TextButton(
                    key: const Key('edit_clear_schedule'),
                    onPressed: () => setState(() => _scheduledFor = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Notes', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('edit_notes'),
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              key: const Key('edit_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
