import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import 'supabase_mappers.dart';

/// Read-side repository for staff users — ONLINE-ONLY mode. Streams `StaffData`
/// live from Supabase. The offline (local Drift) implementation is preserved in
/// the commented block at the bottom.
class StaffRepository {
  StaffRepository(this._supabase);

  final SupabaseClient _supabase;

  /// All non-deleted staff, sorted by display name.
  Stream<List<StaffData>> watchAll() {
    return _supabase
        .from('staff')
        .stream(primaryKey: ['id'])
        .order('display_name')
        .map((rows) => rows
            .where((r) => r['deleted_at'] == null)
            .map(staffFromSupabase)
            .toList(growable: false));
  }

  Stream<StaffData?> watchById(String id) {
    // Filter soft-deleted client-side (same as watchAll) so a deactivated/
    // tombstoned staff record doesn't surface on detail screens. `.stream()`
    // can't express `IS NULL`.
    return _supabase
        .from('staff')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) {
      final live = rows.where((r) => r['deleted_at'] == null);
      return live.isEmpty ? null : staffFromSupabase(live.first);
    });
  }

  /// Set the signed-in user's own display name. Goes through the
  /// `set_my_display_name` RPC (migration 0028) because RLS only lets managers
  /// write the staff table directly — the function is column-scoped to
  /// display_name on the caller's own row, so non-managers can still rename
  /// themselves during onboarding without being able to change role/active.
  Future<void> setMyDisplayName(String name) {
    return _supabase
        .rpc('set_my_display_name', params: {'new_name': name.trim()});
  }
}

/* ============================================================================
 * OFFLINE (local Drift reads) — PRESERVED FOR RE-ENABLE
 * ----------------------------------------------------------------------------
 * import 'package:drift/drift.dart';
 * import '../data/app_database.dart';
 *
 * class StaffRepository {
 *   StaffRepository(this._db);
 *   final AppDatabase _db;
 *
 *   Stream<List<StaffData>> watchAll() {
 *     return (_db.select(_db.staff)
 *           ..where((t) => t.deletedAt.isNull())
 *           ..orderBy([(t) => OrderingTerm(expression: t.displayName)])).watch();
 *   }
 *
 *   Stream<StaffData?> watchById(String id) {
 *     return (_db.select(_db.staff)..where((t) => t.id.equals(id)))
 *         .watchSingleOrNull();
 *   }
 * }
 * ========================================================================== */
