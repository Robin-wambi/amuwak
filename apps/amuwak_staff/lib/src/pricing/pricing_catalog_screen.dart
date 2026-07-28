import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'catalog_item.dart';

typedef LoadCatalogFn = Future<List<CatalogItem>> Function();
typedef SaveCatalogItemFn = Future<void> Function(CatalogItem item);

/// Manages the service item catalog: list every item (active + retired), add a
/// new one, edit an existing one, or retire/restore it. The pickup/billing
/// picker only ever sees active items.
class PricingCatalogScreen extends StatefulWidget {
  const PricingCatalogScreen({
    super.key,
    required this.load,
    required this.save,
    required this.idGenerator,
  });

  final LoadCatalogFn load;
  final SaveCatalogItemFn save;
  final String Function() idGenerator;

  @override
  State<PricingCatalogScreen> createState() => _PricingCatalogScreenState();
}

class _PricingCatalogScreenState extends State<PricingCatalogScreen> {
  List<CatalogItem> _items = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _saveAndReload(CatalogItem item) async {
    try {
      await widget.save(item);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — please retry.')),
      );
    }
  }

  Future<void> _addItem() async {
    final result = await _showItemSheet();
    if (result == null) return;
    final nextSort =
        _items.fold<int>(0, (m, e) => math.max(m, e.sortOrder)) + 1;
    await _saveAndReload(CatalogItem(
      id: widget.idGenerator(),
      name: result.name,
      amountUgx: result.amountUgx,
      sortOrder: nextSort,
      category: result.category,
    ));
  }

  Future<void> _editItem(CatalogItem item) async {
    final result = await _showItemSheet(existing: item);
    if (result == null) return;
    await _saveAndReload(item.copyWith(
      name: result.name,
      amountUgx: result.amountUgx,
      active: result.active,
      category: result.category,
    ));
  }

  Future<_SheetResult?> _showItemSheet({CatalogItem? existing}) {
    final categories = _items
        .map((e) => e.category)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _CatalogItemSheet(existing: existing, categories: categories),
    );
  }

  Widget? _subtitle(CatalogItem item) {
    final parts = <String>[
      if (item.category != null) item.category!,
      if (!item.active) 'Retired',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service items')),
      floatingActionButton: _loading || _error
          ? null
          : FloatingActionButton.extended(
              key: const Key('catalog_add'),
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? const Center(
                    child: Text('Could not load the catalog — please retry.'))
                : _items.isEmpty
                    ? const Center(child: Text('No service items yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          return ListTile(
                            key: Key('catalog_item_$i'),
                            title: Text(item.name),
                            subtitle: _subtitle(item),
                            trailing: Text(formatUgx(item.amountUgx)),
                            enabled: true,
                            onTap: () => _editItem(item),
                          );
                        },
                      ),
      ),
    );
  }
}

/// The validated values a catalog sheet returns.
class _SheetResult {
  const _SheetResult(this.name, this.amountUgx, this.active, this.category);
  final String name;
  final int amountUgx;
  final bool active;
  final String? category;
}

class _CatalogItemSheet extends StatefulWidget {
  const _CatalogItemSheet({this.existing, this.categories = const []});
  final CatalogItem? existing;
  final List<String> categories;

  @override
  State<_CatalogItemSheet> createState() => _CatalogItemSheetState();
}

class _CatalogItemSheetState extends State<_CatalogItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late bool _active;
  String? _nameError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _amountController = TextEditingController(
        text: widget.existing == null
            ? ''
            : widget.existing!.amountUgx.toString());
    _categoryController =
        TextEditingController(text: widget.existing?.category ?? '');
    _active = widget.existing?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
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
    final category = _categoryController.text.trim();
    Navigator.pop(
      context,
      _SheetResult(name, amount!, _active, category.isEmpty ? null : category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('catalog_name'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Item (e.g. Blanket)',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('catalog_amount'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (UGX)',
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('catalog_category'),
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Category (optional, e.g. Dry Cleaning)',
            ),
          ),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final c in widget.categories)
                  ActionChip(
                    key: Key('catalog_category_suggestion_$c'),
                    label: Text(c),
                    onPressed: () => _categoryController.text = c,
                  ),
              ],
            ),
          ],
          if (isEdit) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              key: const Key('catalog_active'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Off retires it from the picker'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            key: const Key('catalog_save'),
            onPressed: _submit,
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }
}
