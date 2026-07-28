import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/expenses/expense.dart';

void main() {
  group('ExpenseCategory', () {
    test('toDbString returns the Postgres value for each category', () {
      expect(ExpenseCategory.detergent.toDbString(), 'detergent');
      expect(ExpenseCategory.packaging.toDbString(), 'packaging');
      expect(ExpenseCategory.fuel.toDbString(), 'fuel');
      expect(ExpenseCategory.airtimeMisc.toDbString(), 'airtime_misc');
    });

    test('fromDbString maps every known value back to its category', () {
      expect(ExpenseCategory.fromDbString('detergent'),
          ExpenseCategory.detergent);
      expect(ExpenseCategory.fromDbString('packaging'),
          ExpenseCategory.packaging);
      expect(ExpenseCategory.fromDbString('fuel'), ExpenseCategory.fuel);
      expect(ExpenseCategory.fromDbString('airtime_misc'),
          ExpenseCategory.airtimeMisc);
    });

    test('db round-trips for every value', () {
      for (final c in ExpenseCategory.values) {
        expect(ExpenseCategory.fromDbString(c.toDbString()), c);
      }
    });

    test('fromDbString degrades an unknown value to airtimeMisc (catch-all)',
        () {
      expect(ExpenseCategory.fromDbString('cryptocurrency'),
          ExpenseCategory.airtimeMisc);
    });
  });

  group('Expense.fromSupabase', () {
    test('reads all columns', () {
      final e = Expense.fromSupabase({
        'id': 'e1',
        'category': 'detergent',
        'amount_ugx': 8000,
        'note': 'OMO 5kg',
        'spent_at': '2026-06-17T08:00:00Z',
        'recorded_by': 'staff-1',
      });
      expect(e.id, 'e1');
      expect(e.category, ExpenseCategory.detergent);
      expect(e.amountUgx, 8000);
      expect(e.note, 'OMO 5kg');
      expect(e.spentAt, DateTime.utc(2026, 6, 17, 8));
      expect(e.recordedBy, 'staff-1');
    });

    test('a null note reads as an empty string', () {
      final e = Expense.fromSupabase({
        'id': 'e2',
        'category': 'fuel',
        'amount_ugx': 12000,
        'note': null,
        'spent_at': '2026-06-17T09:00:00Z',
        'recorded_by': null,
      });
      expect(e.note, '');
      expect(e.recordedBy, isNull);
    });
  });
}
