import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pricing/pricing_providers.dart';
import 'cart_providers.dart';

/// Bottom sheet to add a weight-priced laundry item: service + a size preset
/// (Small ~3kg / Medium ~6kg / Large ~9kg / Custom) that maps to an estimated
/// kg. Weight is provisional — staff weigh at pickup.
Future<void> showAddLaundrySheet(
  BuildContext context,
  WidgetRef ref, {
  ServiceType? initialService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
      ),
      child: _AddLaundryForm(
        initialService: initialService ?? ServiceType.washAndIron,
        onAdd: (service, estKg, note) async {
          await ref
              .read(cartRepositoryProvider)
              .addWeightItem(service: service, estKg: estKg, note: note);
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          if (context.mounted) _added(context);
        },
      ),
    ),
  );
}

/// Bottom sheet to add a piece-priced specialty item from the catalog.
Future<void> showAddSpecialtySheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (consumerContext, sheetRef, _) {
        final catalog = sheetRef.watch(catalogItemsProvider);
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.6,
          child: catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                    "Couldn't load specialty items. Connect to the internet and try again."),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Center(child: Text('No specialty items yet.'))
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text('Add a specialty item',
                          style: Theme.of(sheetContext).textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.md),
                      for (final item in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          subtitle: Text(
                            [
                              formatUgx(item.amountUgx),
                              if (item.category != null) item.category!,
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () async {
                            await ref
                                .read(cartRepositoryProvider)
                                .addPieceItem(item: item);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                            if (context.mounted) _added(context);
                          },
                        ),
                    ],
                  ),
          ),
        );
      },
    ),
  );
}

void _added(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: const Text('Added to cart'),
      action: SnackBarAction(
        label: 'View cart',
        onPressed: () => context.push('/cart'),
      ),
    ));
}

class _AddLaundryForm extends StatefulWidget {
  const _AddLaundryForm({required this.initialService, required this.onAdd});

  final ServiceType initialService;
  final void Function(ServiceType service, double estKg, String? note) onAdd;

  @override
  State<_AddLaundryForm> createState() => _AddLaundryFormState();
}

class _AddLaundryFormState extends State<_AddLaundryForm> {
  static const _presets = {'Small': 3.0, 'Medium': 6.0, 'Large': 9.0};

  late ServiceType _service = widget.initialService;
  String _size = 'Medium';
  final _customKg = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _customKg.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _estKg {
    if (_size == 'Custom') return double.tryParse(_customKg.text.trim());
    return _presets[_size];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add laundry', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<ServiceType>(
            value: _service,
            decoration: const InputDecoration(labelText: 'Service'),
            items: [
              for (final s in ServiceType.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (s) => setState(() => _service = s ?? _service),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Rough size', style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final label in [..._presets.keys, 'Custom'])
                ChoiceChip(
                  label: Text(label == 'Custom'
                      ? 'Custom'
                      : '$label ~${_presets[label]!.toInt()}kg'),
                  selected: _size == label,
                  onSelected: (_) => setState(() => _size = label),
                ),
            ],
          ),
          if (_size == 'Custom')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextField(
                controller: _customKg,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. delicate, stains on collar'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: (_estKg == null || _estKg! <= 0)
                ? null
                : () => widget.onAdd(
                      _service,
                      _estKg!,
                      _note.text.trim().isEmpty ? null : _note.text.trim(),
                    ),
            child: const Text('Add to cart'),
          ),
        ],
      ),
    );
  }
}
