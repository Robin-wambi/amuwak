import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import '../../pricing/catalog_item.dart';

/// Editable list of free-form line items, with an "Add item" button. Stateless:
/// the parent owns the list and re-renders on change.
class LineItemsEditor extends StatelessWidget {
  const LineItemsEditor({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final List<LineItem> items;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(child: Text(items[i].name)),
                Text(formatUgx(items[i].amountUgx)),
                IconButton(
                  key: Key('remove_line_item_$i'),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          key: const Key('add_line_item'),
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
      ],
    );
  }
}

/// Prominent total display with an optional "Provisional" badge (shown until a
/// final weight is recorded).
class TotalCard extends StatelessWidget {
  const TotalCard({
    super.key,
    required this.totalUgx,
    required this.isProvisional,
  });

  final int totalUgx;
  final bool isProvisional;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: textTheme.bodySmall),
              Text(formatUgx(totalUgx), style: textTheme.headlineMedium),
            ],
          ),
          if (isProvisional)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.secondaryText.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Provisional'),
            ),
        ],
      ),
    );
  }
}

/// Shows the line-item picker: tap a catalog item to add it, or choose "Custom
/// item" for a free-form entry. Falls back straight to the free-form sheet when
/// the catalog is empty. Returns the chosen [LineItem], or null if dismissed.
Future<LineItem?> showPickLineItemSheet(
    BuildContext context, List<CatalogItem> catalog) {
  if (catalog.isEmpty) return showAddLineItemSheet(context);
  return showModalBottomSheet<LineItem>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PickLineItemSheet(catalog: catalog),
  );
}

class _PickLineItemSheet extends StatefulWidget {
  const _PickLineItemSheet({required this.catalog});

  final List<CatalogItem> catalog;

  @override
  State<_PickLineItemSheet> createState() => _PickLineItemSheetState();
}

class _PickLineItemSheetState extends State<_PickLineItemSheet> {
  // Sentinel values that cannot collide with real category names (they start
  // with a space, which is never a valid category name).
  static const String _all = ' all';
  static const String _other = ' other';
  String _selected = _all;

  List<String> get _categories {
    final sorted = widget.catalog
        .map((e) => e.category)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return sorted;
  }

  bool get _hasUncategorised =>
      widget.catalog.any((e) => e.category == null);

  List<CatalogItem> get _filtered {
    if (_selected == _all) return widget.catalog;
    if (_selected == _other) {
      return widget.catalog.where((e) => e.category == null).toList();
    }
    return widget.catalog.where((e) => e.category == _selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final showChips = categories.isNotEmpty;
    final filtered = _filtered;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          if (showChips)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const Key('pick_category_all'),
                    label: const Text('All'),
                    selected: _selected == _all,
                    onSelected: (_) => setState(() => _selected = _all),
                  ),
                  for (final c in categories)
                    ChoiceChip(
                      key: Key('pick_category_$c'),
                      label: Text(c),
                      selected: _selected == c,
                      onSelected: (_) => setState(() => _selected = c),
                    ),
                  if (_hasUncategorised)
                    ChoiceChip(
                      key: const Key('pick_category_other'),
                      label: const Text('Other'),
                      selected: _selected == _other,
                      onSelected: (_) => setState(() => _selected = _other),
                    ),
                ],
              ),
            ),
          for (var i = 0; i < filtered.length; i++)
            ListTile(
              key: Key('pick_catalog_item_$i'),
              title: Text(filtered[i].name),
              trailing: Text(formatUgx(filtered[i].amountUgx)),
              onTap: () => Navigator.pop(
                context,
                LineItem(
                    name: filtered[i].name, amountUgx: filtered[i].amountUgx),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            key: const Key('pick_custom_item'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Custom item'),
            onTap: () async {
              final item = await showAddLineItemSheet(context);
              if (item != null && context.mounted) {
                Navigator.pop(context, item);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Shows a bottom sheet collecting a line-item name + amount. Returns the
/// validated [LineItem], or null if dismissed without saving. Invalid input
/// keeps the sheet open with an inline error rather than silently closing, so
/// the rider can tell a rejected entry from a deliberate cancel.
Future<LineItem?> showAddLineItemSheet(BuildContext context) {
  return showModalBottomSheet<LineItem>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _AddLineItemSheet(),
  );
}

/// Sheet body for [showAddLineItemSheet]. A stateful widget so its controllers
/// are disposed via [State.dispose] once the sheet has fully closed — disposing
/// them when the future completes would free them mid exit-animation while the
/// fields are still mounted.
class _AddLineItemSheet extends StatefulWidget {
  const _AddLineItemSheet();

  @override
  State<_AddLineItemSheet> createState() => _AddLineItemSheetState();
}

class _AddLineItemSheetState extends State<_AddLineItemSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _nameError;
  String? _amountError;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());
    final nextNameError = name.isEmpty ? 'Enter an item name' : null;
    final nextAmountError =
        (amount == null || amount < 0) ? 'Enter a valid amount' : null;
    if (nextNameError != null || nextAmountError != null) {
      setState(() {
        _nameError = nextNameError;
        _amountError = nextAmountError;
      });
      return;
    }
    Navigator.pop(context, LineItem(name: name, amountUgx: amount!));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('line_item_name'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Item (e.g. Blanket)',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('line_item_amount'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (UGX)',
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            key: const Key('line_item_save'),
            onPressed: _submit,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
