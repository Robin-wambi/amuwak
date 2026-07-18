import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer.fromSupabase', () {
    test('maps a full customers row', () {
      final c = Customer.fromSupabase({
        'id': 'c1',
        'name': 'Ada',
        'phone': '0700123456',
        'address': '12 Kira Rd',
        'notes': 'gate code 4',
        'email': 'ada@example.com',
        'custom_rate_per_kg_ugx': 4500,
        'auth_user_id': 'auth-1',
      });

      expect(c.id, 'c1');
      expect(c.name, 'Ada');
      expect(c.phone, '0700123456');
      expect(c.address, '12 Kira Rd');
      expect(c.notes, 'gate code 4');
      expect(c.email, 'ada@example.com');
      expect(c.customRatePerKgUgx, 4500);
      expect(c.authUserId, 'auth-1');
    });

    test('tolerates a minimal walk-in row (no email/rate/auth link)', () {
      final c = Customer.fromSupabase({
        'id': 'c2',
        'name': 'Bob',
        'phone': '0701',
        'address': null,
        'notes': null,
      });

      expect(c.email, isNull);
      expect(c.customRatePerKgUgx, isNull);
      expect(c.authUserId, isNull);
      expect(c.address, isNull);
    });

    test('value equality holds by fields', () {
      const a = Customer(id: 'c1', name: 'Ada', phone: '0700');
      const b = Customer(id: 'c1', name: 'Ada', phone: '0700');
      const c = Customer(id: 'c1', name: 'Ada', phone: '0701');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
