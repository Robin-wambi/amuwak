import 'package:supabase_flutter/supabase_flutter.dart';

import '../customers/customer.dart';

/// Test seam for the `link_or_create_customer` RPC.
typedef LinkOrCreateRpc = Future<Object?> Function(Map<String, dynamic> params);

/// The signed-in customer's own profile — ONLINE-ONLY. `watchMe` streams the
/// single row RLS (`customers_self_read`) exposes; `linkOrCreate` runs the
/// signup RPC that links the auth user to a customers row (or creates one).
class CustomerProfileRepository {
  CustomerProfileRepository(SupabaseClient supabase)
      : _supabase = supabase,
        _linkOverride = null;

  /// Test seam: drive [linkOrCreate] without a live SupabaseClient. `watchMe`
  /// asserts the client is present.
  CustomerProfileRepository.forTest({LinkOrCreateRpc? linkOrCreate})
      : _supabase = null,
        _linkOverride = linkOrCreate;

  final SupabaseClient? _supabase;
  final LinkOrCreateRpc? _linkOverride;

  /// The caller's own customer row, or null if not yet linked. RLS scopes the
  /// stream to the single self row, so no explicit filter is needed; a
  /// soft-deleted row is treated as absent.
  Stream<Customer?> watchMe() {
    assert(_supabase != null, 'watchMe is not available on a forTest instance');
    return _supabase!.from('customers').stream(primaryKey: ['id']).map((rows) {
      final live = rows.where((r) => r['deleted_at'] == null);
      return live.isEmpty ? null : Customer.fromSupabase(live.first);
    });
  }

  /// Links the authenticated auth user to a customers row (creating one if
  /// needed) via the `link_or_create_customer` RPC and returns the customers.id.
  /// Idempotent server-side (returns the existing link on a repeat call).
  Future<String> linkOrCreate({
    required String name,
    required String phone,
    required String email,
  }) async {
    final params = <String, dynamic>{
      'p_name': name,
      'p_phone': phone,
      'p_email': email,
    };
    final override = _linkOverride;
    final result = override != null
        ? await override(params)
        : await _supabase!.rpc('link_or_create_customer', params: params);
    if (result is! String || result.trim().isEmpty) {
      throw StateError(
          'link_or_create_customer returned an unexpected result: $result');
    }
    return result;
  }
}
