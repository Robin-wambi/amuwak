import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/expenses/expense.dart';
import 'package:amuwak_staff/src/expenses/expenses_list_screen.dart';

Expense _expense({
  required String id,
  ExpenseCategory category = ExpenseCategory.detergent,
  int amountUgx = 5000,
  String note = '',
  required DateTime spentAt,
}) =>
    Expense(
      id: id,
      category: category,
      amountUgx: amountUgx,
      note: note,
      spentAt: spentAt,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders the total spent across all expenses', (tester) async {
    await tester.pumpWidget(_host(ExpensesListView(expenses: [
      _expense(id: 'a', amountUgx: 8000, spentAt: DateTime.utc(2026, 8, 14)),
      _expense(id: 'b', amountUgx: 2000, spentAt: DateTime.utc(2026, 8, 14)),
    ])));

    // Both expenses share a category+day, so 10,000 is unambiguously the total.
    expect(find.text('USh 10,000'), findsOneWidget);
  });

  testWidgets('groups expenses under a per-day header, newest day first',
      (tester) async {
    await tester.pumpWidget(_host(ExpensesListView(expenses: [
      _expense(id: 'a', amountUgx: 3000, spentAt: DateTime.utc(2026, 8, 13, 9)),
      _expense(id: 'b', amountUgx: 4000, spentAt: DateTime.utc(2026, 8, 14, 9)),
    ])));

    expect(find.text('14 Aug 2026'), findsOneWidget);
    expect(find.text('13 Aug 2026'), findsOneWidget);
    // Newest day header sits above the older one.
    final newest = tester.getTopLeft(find.text('14 Aug 2026')).dy;
    final oldest = tester.getTopLeft(find.text('13 Aug 2026')).dy;
    expect(newest, lessThan(oldest));
  });

  testWidgets('day header follows the local calendar day, not the UTC one',
      (tester) async {
    // spentAt arrives from Supabase as UTC; the same instant expressed as UTC
    // vs local must land under one shared day header. Without toLocal() the two
    // diverge for an instant whose UTC and local calendar days differ (the EAT
    // 00:00–03:00 window) — this fails on any non-UTC machine if the
    // normalization regresses, and never false-fails on a UTC machine.
    final instantUtc = DateTime.utc(2026, 8, 13, 21, 30); // 00:30 EAT, 14 Aug

    await tester.pumpWidget(_host(ExpensesListView(expenses: [
      _expense(id: 'utc', spentAt: instantUtc),
      _expense(id: 'local', spentAt: instantUtc.toLocal()),
    ])));

    // One instant, one bucket — two headers means the UTC day leaked through.
    expect(find.textContaining('Aug 2026'), findsOneWidget);
  });

  testWidgets('renders each expense category label, note and amount',
      (tester) async {
    await tester.pumpWidget(_host(ExpensesListView(expenses: [
      _expense(
        id: 'a',
        category: ExpenseCategory.fuel,
        amountUgx: 15000,
        note: 'boda to depot',
        spentAt: DateTime.utc(2026, 8, 14),
      ),
    ])));

    expect(find.text(ExpenseCategory.fuel.label), findsOneWidget);
    expect(find.text('boda to depot'), findsOneWidget);
    // Appears twice: once as the total, once as the single row.
    expect(find.text('USh 15,000'), findsWidgets);
  });

  testWidgets('empty state invites recording the first expense',
      (tester) async {
    var addCalls = 0;
    await tester.pumpWidget(_host(ExpensesListView(
      expenses: const [],
      onAddExpense: () => addCalls++,
    )));

    expect(find.text('No expenses yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('expenses_empty_add')));
    await tester.pump();
    expect(addCalls, 1);
  });

  testWidgets('delete affordance reports the tapped expense', (tester) async {
    Expense? deleted;
    final e =
        _expense(id: 'a', amountUgx: 5000, spentAt: DateTime.utc(2026, 8, 14));
    await tester.pumpWidget(_host(ExpensesListView(
      expenses: [e],
      onDelete: (x) => deleted = x,
    )));

    await tester.tap(find.byKey(const Key('expense_delete_a')));
    await tester.pump();
    expect(deleted, isNotNull);
    expect(deleted!.id, 'a');
  });
}
