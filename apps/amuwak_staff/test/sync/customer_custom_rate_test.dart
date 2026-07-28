import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/supabase_mappers.dart';
import 'package:amuwak_staff/src/sync/supabase_payloads.dart';

void main() {
  test('customerFromSupabase reads custom_rate_per_kg_ugx', () {
    final c = customerFromSupabase({
      'id': 'c1',
      'name': 'Aisha',
      'phone': '+256 700000000',
      'address': 'Kampala',
      'notes': null,
      'custom_rate_per_kg_ugx': 4000,
      'created_at': '2026-06-06T10:00:00Z',
      'updated_at': '2026-06-06T10:00:00Z',
      'deleted_at': null,
    });
    expect(c.customRatePerKgUgx, 4000.0);
  });

  test('customerUpsertPayload writes custom_rate_per_kg_ugx (incl. null)', () {
    final c = Customer(
      id: 'c1',
      name: 'Aisha',
      phone: '+256 700000000',
      address: 'Kampala',
      notes: null,
      customRatePerKgUgx: null,
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
      deletedAt: null,
    );
    final p = customerUpsertPayload(c, now: DateTime.utc(2026, 6, 6));
    expect(p.containsKey('custom_rate_per_kg_ugx'), isTrue);
    expect(p['custom_rate_per_kg_ugx'], isNull);
  });
}
