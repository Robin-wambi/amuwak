import 'dart:developer' as developer;

/// A daily operational expense / consumable the staff record against the day's
/// revenue (detergent, packaging, fuel, airtime). Categories are deliberately a
/// small fixed set; [airtimeMisc] doubles as the "other" catch-all.
enum ExpenseCategory {
  detergent(label: 'Detergent & cleaning'),
  packaging(label: 'Packaging'),
  fuel(label: 'Fuel & transport'),
  airtimeMisc(label: 'Airtime & misc');

  const ExpenseCategory({required this.label});

  final String label;

  String toDbString() => switch (this) {
        ExpenseCategory.detergent => 'detergent',
        ExpenseCategory.packaging => 'packaging',
        ExpenseCategory.fuel => 'fuel',
        ExpenseCategory.airtimeMisc => 'airtime_misc',
      };

  /// Maps a Postgres `expenses.category` string to the UI enum.
  ///
  /// An unknown value degrades to [airtimeMisc] (the catch-all bucket) plus a
  /// WARNING log rather than throwing — a category added server-side before
  /// this app is updated must NOT crash the whole expenses stream (which would
  /// blank the report's Expenses card). Mirrors `OrderStatus.fromDbString`.
  static ExpenseCategory fromDbString(String s) => switch (s) {
        'detergent' => ExpenseCategory.detergent,
        'packaging' => ExpenseCategory.packaging,
        'fuel' => ExpenseCategory.fuel,
        'airtime_misc' => ExpenseCategory.airtimeMisc,
        _ => _degradeUnknown(s),
      };

  static ExpenseCategory _degradeUnknown(String s) {
    developer.log(
      'Unrecognized expense category "$s" — counting it under Airtime & misc '
      'so the expenses stream keeps working.',
      name: 'ExpenseCategory',
      level: 900,
    );
    return ExpenseCategory.airtimeMisc;
  }
}

/// A single recorded expense. [spentAt] is the day it counts against on the
/// report; audit columns ([recordedBy]) follow the house style.
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amountUgx,
    required this.note,
    required this.spentAt,
    this.recordedBy,
  });

  final String id;
  final ExpenseCategory category;
  final int amountUgx;
  final String note;
  final DateTime spentAt;
  final String? recordedBy;

  factory Expense.fromSupabase(Map<String, dynamic> r) => Expense(
        id: r['id'] as String,
        category: ExpenseCategory.fromDbString(r['category'] as String),
        amountUgx: (r['amount_ugx'] as num).toInt(),
        note: r['note'] as String? ?? '',
        spentAt: DateTime.parse(r['spent_at'] as String),
        recordedBy: r['recorded_by'] as String?,
      );
}
