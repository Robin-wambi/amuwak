import 'package:amuwak_staff/src/data/app_database.dart' show Customer;
import 'package:amuwak_staff/src/sync/supabase_payloads.dart';
import 'package:flutter_test/flutter_test.dart';

/// `customerUpsertPayload` stays in the staff app (it operates on the Drift
/// `Customer` row and preserves its `created_at`). The Drift-free order/proof
/// payload builders moved to `amuwak_core`; their tests live in
/// `packages/amuwak_core/test/sync/supabase_payloads_test.dart`.
void main() {
  group('customerUpsertPayload', () {
    test('maps columns and keeps createdAt while refreshing updatedAt', () {
      final customer = Customer(
        id: 'c1',
        name: 'Ada',
        phone: '0700',
        address: '12 Kira Rd',
        notes: 'gate code 4',
        createdAt: DateTime.utc(2026, 6, 1, 8),
        updatedAt: DateTime.utc(2026, 6, 1, 8),
        deletedAt: null,
      );
      final now = DateTime(2026, 6, 2, 9);

      final p = customerUpsertPayload(customer, now: now);

      expect(p['id'], 'c1');
      expect(p['name'], 'Ada');
      expect(p['phone'], '0700');
      expect(p['address'], '12 Kira Rd');
      expect(p['notes'], 'gate code 4');
      expect(p['created_at'], DateTime.utc(2026, 6, 1, 8).toIso8601String());
      expect(p['updated_at'], now.toUtc().toIso8601String());
    });

    test('passes through null address/notes', () {
      final customer = Customer(
        id: 'c2',
        name: 'Bob',
        phone: '0701',
        address: null,
        notes: null,
        createdAt: DateTime.utc(2026, 6, 1, 8),
        updatedAt: DateTime.utc(2026, 6, 1, 8),
        deletedAt: null,
      );
      final p = customerUpsertPayload(customer, now: DateTime(2026, 6, 2));
      expect(p['address'], isNull);
      expect(p['notes'], isNull);
    });
  });
}
