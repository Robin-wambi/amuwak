import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart' show Customer;

/// Browsable, searchable customer list. Stateless w.r.t. the data (the list is
/// injected — the dashboard feeds it `customersStreamProvider`), holding only
/// the local search query. Add / Import are gated by [canManage] because RLS
/// only lets in-shop/manager roles write the customers table directly.
class CustomersListView extends StatefulWidget {
  const CustomersListView({
    super.key,
    required this.customers,
    this.onAddCustomer,
    this.onImport,
    this.onCustomerTap,
    this.canManage = true,
  });

  final List<Customer> customers;
  final VoidCallback? onAddCustomer;
  final VoidCallback? onImport;
  final void Function(Customer customer)? onCustomerTap;
  final bool canManage;

  @override
  State<CustomersListView> createState() => _CustomersListViewState();
}

class _CustomersListViewState extends State<CustomersListView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Customer c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (c.name.toLowerCase().contains(q)) return true;
    final digits = _digitsOnly(q);
    if (digits.isNotEmpty) {
      if (_digitsOnly(c.phone).contains(digits)) return true;
      if (ugandaNationalDigits(c.phone).contains(digits)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customers.isEmpty) {
      return _EmptyState(
        canManage: widget.canManage,
        onAddCustomer: widget.onAddCustomer,
        onImport: widget.onImport,
      );
    }

    final filtered = widget.customers.where(_matches).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              if (widget.canManage) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('customers_import'),
                        onPressed: widget.onImport,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Import'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('customers_add'),
                        onPressed: widget.onAddCustomer,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                key: const Key('customer_search'),
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name or phone',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matching customers.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CustomerRow(
                        customer: c,
                        onTap: widget.onCustomerTap == null
                            ? null
                            : () => widget.onCustomerTap!(c),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
}

/// Keeps only ASCII digits — used to match a search query against a phone
/// number regardless of `+256`, spaces or leading-zero formatting.
String _digitsOnly(String s) {
  final buffer = StringBuffer();
  for (final unit in s.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) buffer.writeCharCode(unit);
  }
  return buffer.toString();
}

/// A single customer row, reskinned onto [AppCard] to match the rest of the
/// app's lists (e.g. `OrderCard`, the expenses `_ExpenseRow`). Tapping opens
/// the same [CustomerFormScreen] edit flow as before — this widget only
/// changes what the row looks like, not what tapping it does.
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, this.onTap});

  final Customer customer;
  final VoidCallback? onTap;

  bool get _hasAddress =>
      customer.address != null && customer.address!.isNotEmpty;

  /// Whitespace-only notes (e.g. a stray space left after clearing the
  /// field) don't count as "has notes" — matches how the form screen already
  /// treats a trimmed-empty notes field as null on save.
  bool get _hasNotes =>
      customer.notes != null && customer.notes!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = customer.customRatePerKgUgx;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.primary,
            child: Text(_initial(customer.name)),
          ),
          const SizedBox(width: AppSpacing.md + 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  _hasAddress
                      ? '${customer.phone} · ${customer.address}'
                      : customer.phone,
                  style: theme.textTheme.bodySmall,
                ),
                if (rate != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _RateChip(
                    key: Key('customer_rate_chip_${customer.id}'),
                    rateUgx: rate,
                  ),
                ],
              ],
            ),
          ),
          if (_hasNotes) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.sticky_note_2_outlined,
              key: Key('customer_notes_indicator_${customer.id}'),
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

/// The customer's standing per-kg rate override, shown only when one is set.
/// Rounds the same way `customer_form_screen.dart` rounds a rate for display
/// (`.round()`) and reuses [formatUgx] as-is — it already prefixes "USh ", so
/// nothing else here re-adds it.
class _RateChip extends StatelessWidget {
  const _RateChip({super.key, required this.rateUgx});

  final double rateUgx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        '${formatUgx(rateUgx.round())}/kg',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.canManage,
    this.onAddCustomer,
    this.onImport,
  });

  final bool canManage;
  final VoidCallback? onAddCustomer;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.lg),
            Text('Your customer list is empty',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your first customer or import a list to get started.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (canManage) ...[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                key: const Key('customers_empty_import'),
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Import list'),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('customers_empty_add'),
                onPressed: onAddCustomer,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add customer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
