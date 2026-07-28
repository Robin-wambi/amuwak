import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'expense.dart';

typedef SaveExpenseFn = Future<void> Function(Expense expense);

/// Fast "record an expense" form: pick a category, type an amount, optional
/// note. Save is injected (the dashboard wires it to [ExpensesRepository]) so
/// the screen is testable without Riverpod, mirroring [PricingSettingsScreen].
class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({
    super.key,
    required this.save,
    this.idGenerator = defaultUuidV7,
    this.clock = _defaultClock,
  });

  final SaveExpenseFn save;
  final String Function() idGenerator;
  final DateTime Function() clock;

  static DateTime _defaultClock() => DateTime.now();

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.values.first;
  bool _saving = false;

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0.')),
      );
      return;
    }
    final expense = Expense(
      id: widget.idGenerator(),
      category: _category,
      amountUgx: amount,
      note: _noteController.text.trim(),
      spentAt: widget.clock(),
    );
    setState(() => _saving = true);
    try {
      await widget.save(expense);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Recorded ${_category.label} expense.')),
        );
      // Pop back to the report when pushed onto a navigator; in the standalone
      // test harness there's nothing to pop, so guard it.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — please retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record expense')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final category in ExpenseCategory.values)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Amount (UGX)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('expense_amount'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              // TextInputType.number is advisory on Android; the formatter keeps
              // out pasted non-digits (e.g. "1,500", "15k") so the rejection
              // happens inline rather than as a SnackBar on save.
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Note (optional)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('expense_note'),
              controller: _noteController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              key: const Key('expense_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
