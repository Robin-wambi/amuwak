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

/// The expenses ledger body: a search field and category filter chips, a
/// running total below them, then rows grouped by the day they were spent
/// (newest first). Constructor-injected data so it renders in both the
/// dashboard tab and tests without Riverpod; holds only the local
/// search/filter selection as state, mirroring `CustomersListView` and the
/// Orders tab's `_OrdersBody`.
class ExpensesListView extends StatefulWidget {
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
  State<ExpensesListView> createState() => _ExpensesListViewState();
}

class _ExpensesListViewState extends State<ExpensesListView> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Null means the 'All' chip — no category narrowing.
  ExpenseCategory? _category;

  // 'All' (null) plus one chip per category, in the enum's declared order —
  // same list the summary card iterates, so chip order and breakdown order
  // agree.
  static const List<ExpenseCategory?> _filters = [
    null,
    ...ExpenseCategory.values,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Expense e) {
    if (_category != null && e.category != _category) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (e.note.toLowerCase().contains(q)) return true;
    if (e.category.label.toLowerCase().contains(q)) return true;
    return false;
  }

  /// How many of the full, unfiltered expense list fall under [category]
  /// (or the whole list, for the 'All' chip). Always counts against
  /// `widget.expenses`, never the search-narrowed list, so a chip's own
  /// count doesn't shift as the user types — mirrors `OrderFilter.count` in
  /// `_OrdersBody`. This also keeps each chip's label text distinct from the
  /// bare category label shown elsewhere (summary card, row), so a
  /// `find.text(category.label)` lookup in tests can't accidentally match
  /// the chip too.
  int _categoryCount(ExpenseCategory? category) => category == null
      ? widget.expenses.length
      : widget.expenses.where((e) => e.category == category).length;

  @override
  Widget build(BuildContext context) {
    if (widget.expenses.isEmpty) {
      return _EmptyState(onAddExpense: widget.onAddExpense);
    }

    final theme = Theme.of(context);
    final visible = widget.expenses.where(_matches).toList();
    final sorted = [...visible]..sort((a, b) => b.spentAt.compareTo(a.spentAt));
    final groups = _groupByDay(sorted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: TextField(
            key: const Key('expenses_search'),
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search expenses by note or category',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final category = _filters[i];
              final label = category?.label ?? 'All';
              return Center(
                child: FilterChip(
                  key: Key('expenses_chip_${category?.name ?? 'all'}'),
                  label: Text('$label (${_categoryCount(category)})'),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              // Always aggregates the full, unfiltered expense list — the
              // search/category filter only narrows the day-grouped rows
              // below, so "Total spent" never appears to change mid-filter.
              _ExpensesSummaryCard(
                byCategory: widget.expenses.byCategory,
                totalUgx: widget.expenses.totalExpenseUgx,
              ),
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
                  _ExpenseRow(expense: e, onDelete: widget.onDelete),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ],
          ),
        ),
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

/// The ledger's summary card: a row per category that has spend so far (icon,
/// label, subtotal — in the enum's declared order, skipping absent
/// categories), a divider, then the emphasized grand total. Mirrors the shape
/// of `daily_report_screen.dart`'s `_ExpensesCard`, minus the net-profit/
/// margin rows below the total, which need revenue data this tab doesn't have.
class _ExpensesSummaryCard extends StatelessWidget {
  const _ExpensesSummaryCard({
    required this.byCategory,
    required this.totalUgx,
  });

  final Map<ExpenseCategory, int> byCategory;
  final int totalUgx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Iterate the enum so categories always render in a stable, defined
    // order; skip any with no spend.
    final rows = <Widget>[];
    for (final category in ExpenseCategory.values) {
      final amount = byCategory[category];
      if (amount == null) continue;
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.lg - 2));
      }
      rows.add(_CategoryBreakdownRow(category: category, amountUgx: amount));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text('Total spent', style: theme.textTheme.labelLarge),
              ),
              Text(
                formatUgx(totalUgx),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of the summary card's per-category breakdown: the category's icon,
/// label, and its spend so far.
class _CategoryBreakdownRow extends StatelessWidget {
  const _CategoryBreakdownRow({
    required this.category,
    required this.amountUgx,
  });

  final ExpenseCategory category;
  final int amountUgx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(_categoryIcon(category),
            size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(category.label, style: theme.textTheme.bodyMedium),
        ),
        Text(
          formatUgx(amountUgx),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
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
