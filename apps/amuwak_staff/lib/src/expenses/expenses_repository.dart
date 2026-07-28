import 'package:supabase_flutter/supabase_flutter.dart';

import 'expense.dart';

typedef InsertRow = Future<void> Function(Map<String, dynamic> values);
typedef UpdateRowById = Future<void> Function(
    String id, Map<String, dynamic> values);

/// Read/write repository for daily expenses — ONLINE-ONLY mode, mirroring
/// [OrdersRepository]. Reads stream live from Supabase; writes go straight there.
/// Soft-deleted rows are filtered client-side ([expensesFromRows]) since
/// `.stream()` can't express `IS NULL`, matching the orders read path.
class ExpensesRepository {
  ExpensesRepository(this._supabase, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _insertOverride = null,
        _updateOverride = null;

  /// Test seam: inject the raw insert/update so unit tests don't mock
  /// SupabaseClient. Mirrors [PricingSettingsRepository.forTest].
  ExpensesRepository.forTest({
    required DateTime Function() clock,
    InsertRow? insertRow,
    UpdateRowById? updateRow,
  })  : _supabase = null,
        _clock = clock,
        _insertOverride = insertRow,
        _updateOverride = updateRow;

  final SupabaseClient? _supabase;
  final DateTime Function() _clock;
  final InsertRow? _insertOverride;
  final UpdateRowById? _updateOverride;

  // ----- READ -----

  /// Live stream of non-deleted expenses, most relevant by `spent_at`.
  Stream<List<Expense>> watchAll() {
    return _supabase!
        .from('expenses')
        .stream(primaryKey: ['id'])
        .order('spent_at')
        .map(expensesFromRows);
  }

  // ----- WRITE -----

  /// Records a new expense. Stamps `recorded_by` with the actor and
  /// `created_at`/`updated_at` from the injected clock.
  Future<void> addExpense(Expense expense,
      {required String actorStaffId}) async {
    final now = _clock();
    final values = <String, dynamic>{
      'id': expense.id,
      'category': expense.category.toDbString(),
      'amount_ugx': expense.amountUgx,
      'note': expense.note,
      'spent_at': expense.spentAt.toUtc().toIso8601String(),
      'recorded_by': actorStaffId,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };
    final override = _insertOverride;
    if (override != null) {
      await override(values);
      return;
    }
    await _supabase!.from('expenses').insert(values);
  }

  /// Soft-deletes an expense (back-office tombstone) so it drops off the report.
  Future<void> softDelete(String id) async {
    final now = _clock();
    final values = <String, dynamic>{
      'deleted_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };
    final override = _updateOverride;
    if (override != null) {
      await override(id, values);
      return;
    }
    await _supabase!.from('expenses').update(values).eq('id', id);
  }
}

/// Folds raw `expenses` rows into the list shown on the report. Soft-deleted
/// rows (`deleted_at != null`) are dropped; the rest map via [Expense.fromSupabase].
/// Pure so the stream filter is unit-testable without mocking Supabase.
List<Expense> expensesFromRows(List<Map<String, dynamic>> rows) => rows
    .where((r) => r['deleted_at'] == null)
    .map(Expense.fromSupabase)
    .toList(growable: false);
