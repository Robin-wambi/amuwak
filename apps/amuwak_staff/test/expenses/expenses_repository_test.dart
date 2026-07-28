import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/expenses/expense.dart';
import 'package:amuwak_staff/src/expenses/expenses_repository.dart';

void main() {
  final clock = DateTime.utc(2026, 6, 17, 10, 30);

  Expense newExpense() => Expense(
        id: 'e1',
        category: ExpenseCategory.detergent,
        amountUgx: 8000,
        note: 'OMO 5kg',
        spentAt: DateTime.utc(2026, 6, 17, 8),
      );

  group('ExpensesRepository.addExpense', () {
    test('inserts the expense with category, amount, note and audit columns',
        () async {
      Map<String, dynamic>? inserted;
      final repo = ExpensesRepository.forTest(
        clock: () => clock,
        insertRow: (values) async => inserted = values,
      );

      await repo.addExpense(newExpense(), actorStaffId: 'staff-7');

      expect(inserted!['id'], 'e1');
      expect(inserted!['category'], 'detergent');
      expect(inserted!['amount_ugx'], 8000);
      expect(inserted!['note'], 'OMO 5kg');
      expect(inserted!['spent_at'], '2026-06-17T08:00:00.000Z');
      expect(inserted!['recorded_by'], 'staff-7');
      expect(inserted!['created_at'], '2026-06-17T10:30:00.000Z');
      expect(inserted!['updated_at'], '2026-06-17T10:30:00.000Z');
    });
  });

  group('ExpensesRepository.softDelete', () {
    test('stamps deleted_at and updated_at for the id', () async {
      String? deletedId;
      Map<String, dynamic>? values;
      final repo = ExpensesRepository.forTest(
        clock: () => clock,
        insertRow: (_) async {},
        updateRow: (id, v) async {
          deletedId = id;
          values = v;
        },
      );

      await repo.softDelete('e1');

      expect(deletedId, 'e1');
      expect(values!['deleted_at'], '2026-06-17T10:30:00.000Z');
      expect(values!['updated_at'], '2026-06-17T10:30:00.000Z');
    });
  });

  group('expensesFromRows', () {
    test('drops soft-deleted rows and maps the rest', () {
      final result = expensesFromRows([
        {
          'id': 'a',
          'category': 'fuel',
          'amount_ugx': 12000,
          'note': '',
          'spent_at': '2026-06-17T08:00:00Z',
          'recorded_by': 's1',
          'deleted_at': null,
        },
        {
          'id': 'b',
          'category': 'packaging',
          'amount_ugx': 3000,
          'note': '',
          'spent_at': '2026-06-17T09:00:00Z',
          'recorded_by': 's1',
          'deleted_at': '2026-06-17T09:30:00Z',
        },
      ]);

      expect(result.map((e) => e.id), ['a']);
      expect(result.single.category, ExpenseCategory.fuel);
    });
  });
}
