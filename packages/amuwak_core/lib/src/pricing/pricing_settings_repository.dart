import 'package:supabase_flutter/supabase_flutter.dart';

import 'pricing_settings.dart';

typedef FetchRows = Future<List<Map<String, dynamic>>> Function();
typedef UpdateRow = Future<void> Function(
    String id, Map<String, dynamic> values);

/// Reads and updates the singleton `pricing_settings` row.
///
/// Reads are one-shot (the row is a singleton; no realtime needed). The settings
/// table is intentionally not in the realtime publication — see migration 0019.
class PricingSettingsRepository {
  PricingSettingsRepository(this._supabase, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _fetchRowsOverride = null,
        _updateRowOverride = null;

  /// Test seam: inject the raw row fetch/update so unit tests don't mock
  /// SupabaseClient.
  PricingSettingsRepository.forTest({
    required FetchRows fetchRows,
    UpdateRow? updateRow,
  })  : _supabase = null,
        _clock = DateTime.now,
        _fetchRowsOverride = fetchRows,
        _updateRowOverride = updateRow;

  final SupabaseClient? _supabase;
  final DateTime Function() _clock;
  final FetchRows? _fetchRowsOverride;
  final UpdateRow? _updateRowOverride;

  /// The singleton row's id, cached after the first read. It never changes, so
  /// once known a save can skip the extra SELECT that fetched it.
  String? _cachedId;

  Future<List<Map<String, dynamic>>> _fetchRows() {
    final override = _fetchRowsOverride;
    if (override != null) return override();
    return _supabase!
        .from('pricing_settings')
        .select()
        .limit(1)
        .then((rows) => rows.cast<Map<String, dynamic>>());
  }

  /// Fetches the singleton settings. Throws [StateError] if the row is missing
  /// (corrupted state the singleton index should prevent) so the UI can show
  /// "Pricing settings missing — contact admin." rather than silently defaulting.
  Future<PricingSettings> fetch() async {
    final rows = await _fetchRows();
    if (rows.isEmpty) {
      throw StateError('pricing_settings has no row');
    }
    final settings = PricingSettings.fromSupabase(rows.first);
    _cachedId = settings.id;
    return settings;
  }

  /// Updates the full pricing configuration on the singleton row: the default
  /// rate plus the delivery fee and express surcharge (flat + percentage).
  /// Reuses the cached id when known (the settings screen always reads before it
  /// can save), so a save doesn't pay for an extra SELECT for the singleton id.
  Future<void> updateSettings({
    required double ratePerKgUgx,
    required int deliveryFeeUgx,
    required int expressFlatUgx,
    required double expressPct,
    required String actorStaffId,
  }) async {
    final id = _cachedId ?? (await fetch()).id;
    final values = {
      'default_rate_per_kg_ugx': ratePerKgUgx,
      'delivery_fee_ugx': deliveryFeeUgx,
      'express_surcharge_flat_ugx': expressFlatUgx,
      'express_surcharge_pct': expressPct,
      'updated_at': _clock().toUtc().toIso8601String(),
      'updated_by': actorStaffId,
    };
    final override = _updateRowOverride;
    if (override != null) {
      await override(id, values);
      return;
    }
    await _supabase!.from('pricing_settings').update(values).eq('id', id);
  }
}
