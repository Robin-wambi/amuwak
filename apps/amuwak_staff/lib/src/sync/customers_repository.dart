import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import 'supabase_mappers.dart';
import 'supabase_payloads.dart';

/// Test seam for the row upsert: given the column map, returns the "selected"
/// rows (empty ⇒ the write did not persist). Lets unit tests exercise
/// [CustomersRepository.upsertCustomer]'s payload + missing-write [StateError]
/// without a live SupabaseClient. Mirrors [OrdersRepository]'s `OrderUpsert`.
typedef CustomerUpsert =
    Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> values);

/// Read + write repository for customers — ONLINE-ONLY mode.
///
/// Reads stream live from Supabase; writes upsert directly. The offline-first
/// implementation (local Drift reads + outbox-queued writes) is preserved in
/// the commented `OFFLINE` block at the bottom of this file. Mirrors
/// [OrdersRepository]'s shape.
class CustomersRepository {
  CustomersRepository(
    SupabaseClient supabase, {
    DateTime Function()? clock,
  })  : _supabase = supabase,
        _clock = clock ?? DateTime.now,
        _upsertOverride = null;

  /// Test seam: inject the raw `upsert(...).select('id')` so unit tests can
  /// drive [upsertCustomer] (payload shape + no-write [StateError]) without
  /// mocking SupabaseClient. Mirrors [OrdersRepository.forTest]. Read methods
  /// are unavailable on a forTest instance (they assert the client is present).
  CustomersRepository.forTest({
    required DateTime Function() clock,
    CustomerUpsert? upsertRow,
  })  : _supabase = null,
        _clock = clock,
        _upsertOverride = upsertRow;

  final SupabaseClient? _supabase;
  final DateTime Function() _clock;
  final CustomerUpsert? _upsertOverride;

  Stream<List<Customer>> watchAll() {
    assert(_supabase != null,
        'watchAll is not available on a forTest instance');
    return _supabase!
        .from('customers')
        .stream(primaryKey: ['id'])
        .order('name')
        .map((rows) => rows
            .where((r) => r['deleted_at'] == null)
            .map(customerFromSupabase)
            .toList(growable: false));
  }

  Stream<Customer?> watchById(String id) {
    assert(_supabase != null,
        'watchById is not available on a forTest instance');
    // Filter soft-deleted client-side (same as watchAll) so a back-office
    // tombstone doesn't surface on detail screens. `.stream()` can't express
    // `IS NULL`.
    return _supabase!
        .from('customers')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) {
      final live = rows.where((r) => r['deleted_at'] == null);
      return live.isEmpty ? null : customerFromSupabase(live.first);
    });
  }

  /// One-shot fetch of all non-deleted customers. Used by callers that need
  /// the current snapshot without subscribing (e.g. phone-on-blur dedup in
  /// the New Pickup form).
  Future<List<Customer>> getAll() async {
    assert(_supabase != null, 'getAll is not available on a forTest instance');
    // One-shot select (not a stream) so we can exclude soft-deleted rows
    // server-side rather than fetching them and filtering client-side.
    final rows = await _supabase!
        .from('customers')
        .select()
        .isFilter('deleted_at', null)
        .order('name');
    return rows.map(customerFromSupabase).toList(growable: false);
  }

  /// Dispatches the customer upsert and returns the selected rows so the caller
  /// can detect a write that didn't persist (empty ⇒ nothing written, e.g. an
  /// RLS policy silently dropped it). Routes through the test override when
  /// constructed via [CustomersRepository.forTest], else the live client.
  Future<List<Map<String, dynamic>>> _upsertRow(
      Map<String, dynamic> values) async {
    final override = _upsertOverride;
    if (override != null) return override(values);
    assert(_supabase != null,
        'forTest instance has no upsertRow — '
        'pass one to CustomersRepository.forTest(upsertRow: ...)');
    return _supabase!.from('customers').upsert(values).select('id');
  }

  /// Upserts a customer. Throws a [StateError] when the write wrote no row (e.g.
  /// an RLS policy silently dropped it) so a caller never reports "saved" for a
  /// write that didn't persist — mirroring [OrdersRepository.upsertOrder]. The
  /// `.select('id')` returning empty is the signal.
  Future<void> upsertCustomer(Customer customer) async {
    final now = _clock();
    final written = await _upsertRow(customerUpsertPayload(customer, now: now));
    if (written.isEmpty) {
      throw StateError(
          'upsertCustomer: write did not persist customer "${customer.id}"');
    }
  }
}

/* ============================================================================
 * OFFLINE (Drift local reads + outbox-queued writes) — PRESERVED FOR RE-ENABLE
 * ----------------------------------------------------------------------------
 * import 'package:drift/drift.dart';
 * import '../data/app_database.dart';
 * import 'outbox_repository.dart';
 *
 * class CustomersRepository {
 *   CustomersRepository(this._db, {OutboxRepository? outbox, DateTime Function()? clock})
 *       : _outbox = outbox, _clock = clock ?? DateTime.now;
 *   final AppDatabase _db;
 *   final OutboxRepository? _outbox;
 *   final DateTime Function() _clock;
 *
 *   Stream<List<Customer>> watchAll() {
 *     return (_db.select(_db.customers)
 *           ..where((t) => t.deletedAt.isNull())
 *           ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
 *   }
 *
 *   Stream<Customer?> watchById(String id) {
 *     return (_db.select(_db.customers)..where((t) => t.id.equals(id)))
 *         .watchSingleOrNull();
 *   }
 *
 *   Future<List<Customer>> getAll() {
 *     return (_db.select(_db.customers)
 *           ..where((t) => t.deletedAt.isNull())
 *           ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
 *   }
 *
 *   Future<void> upsertCustomer(Customer customer) async {
 *     final outbox = _requireOutbox();
 *     final now = _clock();
 *     await _db.transaction(() async {
 *       await _db.into(_db.customers).insertOnConflictUpdate(CustomersCompanion(
 *             id: Value(customer.id),
 *             name: Value(customer.name),
 *             phone: Value(customer.phone),
 *             address: Value(customer.address),
 *             notes: Value(customer.notes),
 *             createdAt: Value(customer.createdAt),
 *             updatedAt: Value(now)));
 *       await outbox.enqueue(
 *         id: OutboxRepository.dedupKeyFor(
 *           forTable: 'customers', op: 'insert', rowId: customer.id,
 *           extra: now.toUtc().toIso8601String()),
 *         forTable: 'customers', op: 'insert', rowId: customer.id,
 *         payload: <String, dynamic>{
 *           'id': customer.id, 'name': customer.name, 'phone': customer.phone,
 *           'address': customer.address, 'notes': customer.notes,
 *           'created_at': customer.createdAt.toUtc().toIso8601String(),
 *           'updated_at': now.toUtc().toIso8601String()});
 *     });
 *   }
 *
 *   OutboxRepository _requireOutbox() {
 *     final o = _outbox;
 *     if (o == null) {
 *       throw StateError('CustomersRepository was constructed without an '
 *           'OutboxRepository; upsertCustomer is unavailable.');
 *     }
 *     return o;
 *   }
 * }
 * ========================================================================== */
