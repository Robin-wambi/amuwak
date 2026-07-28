import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/expenses/expense.dart';
import 'package:amuwak_staff/src/expenses/expense_list_extensions.dart';

Expense _expense(ExpenseCategory category, int amountUgx) => Expense(
      id: '$category-$amountUgx',
      category: category,
      amountUgx: amountUgx,
      note: '',
      spentAt: DateTime.utc(2026, 6, 17, 8),
    );

void main() {
  group('ExpenseListStats', () {
    test('totalExpenseUgx sums every expense amount', () {
      final expenses = [
        _expense(ExpenseCategory.detergent, 8000),
        _expense(ExpenseCategory.packaging, 3000),
        _expense(ExpenseCategory.fuel, 12000),
      ];
      expect(expenses.totalExpenseUgx, 23000);
    });

    test('totalExpenseUgx is zero for an empty list', () {
      expect(<Expense>[].totalExpenseUgx, 0);
    });

    test('byCategory sums amounts grouped by category', () {
      final expenses = [
        _expense(ExpenseCategory.detergent, 8000),
        _expense(ExpenseCategory.detergent, 2000),
        _expense(ExpenseCategory.fuel, 12000),
      ];
      expect(expenses.byCategory, {
        ExpenseCategory.detergent: 10000,
        ExpenseCategory.fuel: 12000,
      });
    });

    test('byCategory omits categories with no expenses', () {
      final expenses = [_expense(ExpenseCategory.packaging, 3000)];
      expect(expenses.byCategory.containsKey(ExpenseCategory.detergent),
          isFalse);
      expect(expenses.byCategory[ExpenseCategory.packaging], 3000);
    });
  });
}
