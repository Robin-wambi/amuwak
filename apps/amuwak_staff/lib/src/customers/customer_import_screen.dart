import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart' show Customer;
import 'customer_import.dart';

/// Returns the chosen CSV file's contents, or null if the user cancelled. The
/// dashboard supplies the real picker (file_picker); tests inject a fixed
/// string, so this screen never depends on a plugin.
typedef PickCsvTextFn = Future<String?> Function();
typedef LoadCustomersFn = Future<List<Customer>> Function();
typedef ImportCustomersFn = Future<int> Function(List<Customer> customers);

/// Bulk-import customers from a CSV: pick a file, preview how many rows are
/// valid / duplicated / rejected, then write the survivors. All I/O is injected
/// so the flow is testable without file_picker or Supabase.
class CustomerImportScreen extends StatefulWidget {
  const CustomerImportScreen({
    super.key,
    required this.pickCsvText,
    required this.loadExisting,
    required this.importCustomers,
    this.idGenerator = defaultUuidV7,
    this.clock = _defaultClock,
  });

  final PickCsvTextFn pickCsvText;
  final LoadCustomersFn loadExisting;
  final ImportCustomersFn importCustomers;
  final String Function() idGenerator;
  final DateTime Function() clock;

  static DateTime _defaultClock() => DateTime.now();

  @override
  State<CustomerImportScreen> createState() => _CustomerImportScreenState();
}

class _CustomerImportScreenState extends State<CustomerImportScreen> {
  bool _loading = false;
  bool _importing = false;
  CsvParseResult? _result;
  ImportPlan? _plan;

  Future<void> _pickAndParse() async {
    setState(() => _loading = true);
    try {
      final text = await widget.pickCsvText();
      if (text == null) {
        // Cancelled — leave any previous preview untouched.
        if (mounted) setState(() => _loading = false);
        return;
      }
      final parsed = parseCustomersCsv(text);
      final existing = await widget.loadExisting();
      final plan = planCustomerImport(
        parsed.rows,
        existing,
        idGenerator: widget.idGenerator,
        now: widget.clock,
      );
      if (!mounted) return;
      setState(() {
        _result = parsed;
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the file.')),
      );
    }
  }

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null || plan.toImport.isEmpty) return;
    setState(() => _importing = true);
    try {
      final written = await widget.importCustomers(plan.toImport);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content:
              Text('Imported $written customer${written == 1 ? '' : 's'}.'),
        ));
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed — please retry.')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    final result = _result;
    final duplicates =
        plan == null ? 0 : plan.duplicatesInFile + plan.duplicatesExisting;

    return Scaffold(
      appBar: AppBar(title: const Text('Import customers')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Import a CSV with columns: name, phone, address. '
              'The first row may be a header.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              key: const Key('import_choose_file'),
              onPressed: _loading || _importing ? null : _pickAndParse,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Choose CSV file'),
            ),
            if (_loading) ...[
              const SizedBox(height: AppSpacing.lg),
              const Center(child: CircularProgressIndicator()),
            ],
            if (plan != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                '${plan.toImport.length} ready to import',
                style: theme.textTheme.titleLarge,
              ),
              if (duplicates > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('$duplicates duplicate${duplicates == 1 ? '' : 's'} '
                    'skipped'),
              ],
              if (result != null && result.errors.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('${result.errors.length} row'
                    '${result.errors.length == 1 ? '' : 's'} with problems',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final error in result.errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(error,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                  ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (plan.toImport.isEmpty)
                Text('Nothing to import.', style: theme.textTheme.bodyMedium)
              else
                FilledButton.icon(
                  key: const Key('import_confirm'),
                  onPressed: _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done_outlined),
                  label: Text('Import ${plan.toImport.length} '
                      'customer${plan.toImport.length == 1 ? '' : 's'}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
