import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import 'expense.dart';
import 'expense_list_extensions.dart';

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `14 Aug 2026`. A tiny local formatter keeps the ledger free of an `intl`
/// dependency; grouping uses the raw date components so it stays deterministic.
String _dayLabel(DateTime d) => '${d.day} ${_monthAbbr[d.month - 1]} ${d.year}';

/// A small per-category glyph for the row's icon tile. Lives here (not on
/// [ExpenseCategory] itself) so the model stays free of a Flutter dependency.
IconData _categoryIcon(ExpenseCategory c) => switch (c) {
      ExpenseCategory.detergent => Icons.local_laundry_service_outlined,
      ExpenseCategory.packaging => Icons.inventory_2_outlined,
      ExpenseCategory.fuel => Icons.local_gas_station_outlined,
      ExpenseCategory.airtimeMisc => Icons.phone_android_outlined,
    };

/// Standalone Expenses ledger screen. The dashboard embeds [ExpensesListView]
/// directly in its Expenses tab (with its own FAB), mirroring how the Daily
/// Report tab embeds [DailyReportView].
class ExpensesListScreen extends StatelessWidget {
  const ExpensesListScreen({
    super.key,
    required this.expenses,
    this.onAddExpense,
    this.onDelete,
  });

  final List<Expense> expenses;
  final VoidCallback? onAddExpense;
  final void Function(Expense expense)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Expenses',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: onAddExpense == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add),
              label: const Text('Record expense'),
            ),
      body: SafeArea(
        child: ExpensesListView(
          expenses: expenses,
          onAddExpense: onAddExpense,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

/// The expenses ledger body: a running total on top, then rows grouped by the
/// day they were spent (newest first). Stateless and constructor-injected so it
/// renders in both the dashboard tab and tests without Riverpod.
class ExpensesListView extends StatelessWidget {
  const ExpensesListView({
    super.key,
    required this.expenses,
    this.onAddExpense,
    this.onDelete,
  });

  final List<Expense> expenses;

  /// Shown as the empty-state call to action. The non-empty list relies on the
  /// hosting Scaffold's FAB to add, so it isn't repeated here.
  final VoidCallback? onAddExpense;

  /// Deletes (soft-deletes) an expense. Null hides the per-row delete control.
  final void Function(Expense expense)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return _EmptyState(onAddExpense: onAddExpense);
    }

    final theme = Theme.of(context);
    final sorted = [...expenses]..sort((a, b) => b.spentAt.compareTo(a.spentAt));
    final groups = _groupByDay(sorted);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _TotalCard(totalUgx: expenses.totalExpenseUgx),
        const SizedBox(height: AppSpacing.lg),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.sm, bottom: AppSpacing.sm),
            child: Text(
              _dayLabel(group.day),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          for (final e in group.expenses) ...[
            _ExpenseRow(expense: e, onDelete: onDelete),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

typedef _DayGroup = ({DateTime day, List<Expense> expenses});

/// Buckets a date-descending list into consecutive same-day groups.
///
/// [Expense.spentAt] comes back from Supabase as UTC, so it is localized before
/// the day components are read — without that, an expense recorded in the first
/// hours of the local day (the EAT 00:00–03:00 window) lands under the previous
/// day's header. Mirrors the same normalization in `OrderListGrouping.groupByDay`.
List<_DayGroup> _groupByDay(List<Expense> sorted) {
  final out = <_DayGroup>[];
  for (final e in sorted) {
    final local = e.spentAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (out.isNotEmpty && out.last.day == day) {
      out.last.expenses.add(e);
    } else {
      out.add((day: day, expenses: [e]));
    }
  }
  return out;
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalUgx});

  final int totalUgx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total spent', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              formatUgx(totalUgx),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, this.onDelete});

  final Expense expense;
  final void Function(Expense expense)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.field - 2),
            ),
            child: Icon(
              _categoryIcon(expense.category),
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md + 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.category.label, style: theme.textTheme.titleMedium),
                if (expense.note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(expense.note, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatUgx(expense.amountUgx),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (onDelete != null)
                IconButton(
                  key: Key('expense_delete_${expense.id}'),
                  tooltip: 'Delete expense',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete!(expense),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onAddExpense});

  final VoidCallback? onAddExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.lg),
            Text('No expenses yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Every expense you record will appear here.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (onAddExpense != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                key: const Key('expenses_empty_add'),
                onPressed: onAddExpense,
                icon: const Icon(Icons.add),
                label: const Text('Record expense'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
