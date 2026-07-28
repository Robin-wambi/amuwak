import 'expense.dart';

/// Aggregations over a list of [Expense]s for the Daily Report's Expenses card.
/// Net profit (revenue − expenses) is computed at the call site, mirroring how
/// the report sums revenue from orders — the arithmetic stays out of the widgets.
extension ExpenseListStats on List<Expense> {
  /// Total spent across every expense.
  int get totalExpenseUgx =>
      fold<int>(0, (sum, e) => sum + e.amountUgx);

  /// Spend summed per category. Categories with no expenses are absent from the
  /// map, so the card can render a row per present category only.
  Map<ExpenseCategory, int> get byCategory {
    final totals = <ExpenseCategory, int>{};
    for (final e in this) {
      totals.update(e.category, (v) => v + e.amountUgx,
          ifAbsent: () => e.amountUgx);
    }
    return totals;
  }
}
