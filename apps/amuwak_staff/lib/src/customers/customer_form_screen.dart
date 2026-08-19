import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart' show Customer;

typedef SaveCustomerFn = Future<void> Function(Customer customer);

/// Add / edit a single customer. Save is injected (the dashboard wires it to
/// [CustomersRepository.upsertCustomer]) so the screen is testable without
/// Riverpod, mirroring [ExpenseEntryScreen]. Pass [existing] to edit; pass
/// [existingCustomers] so a new record can be rejected when its phone number
/// duplicates one already on file (normalized to the national number).
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    required this.save,
    this.existing,
    this.existingCustomers = const [],
    this.idGenerator = defaultUuidV7,
    this.clock = _defaultClock,
    this.canEditRate = false,
    this.defaultRatePerKgUgx = 0,
    this.minRatePctOfDefault = 0,
  });

  final SaveCustomerFn save;
  final Customer? existing;
  final List<Customer> existingCustomers;
  final String Function() idGenerator;
  final DateTime Function() clock;

  /// Whether this user may set the customer's standing per-kg rate. Manager-only
  /// — narrower than the {in_shop, manager} gate on creating customers at all,
  /// because this is a pricing decision rather than a CRM one. Defaults to
  /// false so a caller that doesn't pass it can never widen access by accident.
  final bool canEditRate;

  /// The global default, shown in the field's label when no override is set.
  final double defaultRatePerKgUgx;

  /// Floor as a whole percentage of [defaultRatePerKgUgx]; 0 disables it.
  final int minRatePctOfDefault;

  static DateTime _defaultClock() => DateTime.now();

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _phoneController =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final _addressController =
      TextEditingController(text: widget.existing?.address ?? '');
  late final _notesController =
      TextEditingController(text: widget.existing?.notes ?? '');
  late final _rateController = TextEditingController(
    text: widget.existing?.customRatePerKgUgx?.round().toString() ?? '',
  );
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Enter the customer name.');
      return;
    }
    final phone = _phoneController.text.trim();
    // Same validity rule the New Pickup form uses: a Ugandan national number is
    // exactly 9 digits once the country code / leading zero is stripped.
    final national = ugandaNationalDigits(phone);
    if (national.length != 9) {
      _showError('Enter a valid phone number.');
      return;
    }
    // Reject a phone that already belongs to another customer (compared on the
    // normalized national number, so +256/0 formatting differences still match).
    final duplicate = widget.existingCustomers.any((c) =>
        c.id != widget.existing?.id && ugandaNationalDigits(c.phone) == national);
    if (duplicate) {
      _showError('A customer with this phone already exists.');
      return;
    }

    // An emptied field clears the override; a filled one is rounded to whole
    // shillings, matching how New Pickup and the settings screen persist rates.
    double? rate = widget.existing?.customRatePerKgUgx;
    if (widget.canEditRate) {
      final raw = _rateController.text.trim();
      if (raw.isEmpty) {
        rate = null;
      } else {
        final parsed = double.tryParse(raw)?.roundToDouble();
        if (parsed == null || parsed <= 0) {
          _showError(
              'Enter a rate greater than 0, or clear it to use the default.');
          return;
        }
        final floor = rateFloorUgx(
          defaultRateUgx: widget.defaultRatePerKgUgx,
          minRatePct: widget.minRatePctOfDefault,
        );
        // isManager: false — this form is only reachable by a manager, so the
        // floor it shows is the one riders will be held to. A manager who needs
        // to go lower changes the floor, which is an auditable settings change
        // rather than a silent per-customer exception.
        if (!isRateAllowed(rateUgx: parsed, floorUgx: floor, isManager: false)) {
          _showError('That is below the minimum of ${formatUgx(floor)}/kg.');
          return;
        }
        rate = parsed;
      }
    }

    final now = widget.clock();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();
    final customer = Customer(
      id: widget.existing?.id ?? widget.idGenerator(),
      name: name,
      phone: phone,
      address: address.isEmpty ? null : address,
      notes: notes.isEmpty ? null : notes,
      // A manager may set or clear the standing rate here; anyone else leaves it
      // exactly as found. Before migration 0059 this was pinned, which meant a
      // rate set at customer creation could never be changed again.
      customRatePerKgUgx: rate,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
      deletedAt: null,
    );

    setState(() => _saving = true);
    try {
      await widget.save(customer);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Customer updated.' : 'Customer added.'),
        ));
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not save — please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit customer' : 'Add customer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _Field(
              label: 'Name',
              controller: _nameController,
              fieldKey: const Key('customer_name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Field(
              label: 'Phone',
              controller: _phoneController,
              fieldKey: const Key('customer_phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Field(
              label: 'Address (optional)',
              controller: _addressController,
              fieldKey: const Key('customer_address'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Field(
              label: 'Notes (optional)',
              controller: _notesController,
              fieldKey: const Key('customer_notes'),
              maxLines: 2,
            ),
            if (widget.canEditRate) ...[
              const SizedBox(height: AppSpacing.lg),
              _Field(
                label: 'Standing rate (USh/kg) — blank uses the default'
                    '${widget.defaultRatePerKgUgx > 0 ? ' of ${formatUgx(widget.defaultRatePerKgUgx.round())}' : ''}',
                controller: _rateController,
                fieldKey: const Key('customer_rate'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const Key('customer_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.fieldKey,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final Key fieldKey;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}
