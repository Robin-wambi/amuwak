import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/pricing/pricing_settings.dart';

void main() {
  group('PricingSettings', () {
    test('fromSupabase reads the singleton row', () {
      final s = PricingSettings.fromSupabase({
        'id': 'p1',
        'default_rate_per_kg_ugx': 5000,
        'updated_at': '2026-06-06T10:00:00Z',
        'updated_by': 'staff-1',
      });
      expect(s.id, 'p1');
      expect(s.defaultRatePerKgUgx, 5000);
    });

    test('reads an integer-typed rate as double', () {
      final s = PricingSettings.fromSupabase({
        'id': 'p1',
        'default_rate_per_kg_ugx': 4500,
        'updated_at': '2026-06-06T10:00:00Z',
        'updated_by': null,
      });
      expect(s.defaultRatePerKgUgx, 4500.0);
    });

    test('reads delivery fee and express surcharge fields', () {
      final s = PricingSettings.fromSupabase({
        'id': 'p1',
        'default_rate_per_kg_ugx': 5000,
        'updated_at': '2026-06-06T10:00:00Z',
        'updated_by': null,
        'delivery_fee_ugx': 3000,
        'express_surcharge_flat_ugx': 2000,
        'express_surcharge_pct': 30,
      });
      expect(s.deliveryFeeUgx, 3000);
      expect(s.expressFlatUgx, 2000);
      expect(s.expressPct, 30.0);
    });

    test('degrades missing delivery/express columns to zero', () {
      final s = PricingSettings.fromSupabase({
        'id': 'p1',
        'default_rate_per_kg_ugx': 5000,
        'updated_at': '2026-06-06T10:00:00Z',
        'updated_by': null,
      });
      expect(s.deliveryFeeUgx, 0);
      expect(s.expressFlatUgx, 0);
      expect(s.expressPct, 0);
    });

    test('copyWith overrides only the given fields', () {
      final s = PricingSettings.fromSupabase({
        'id': 'p1',
        'default_rate_per_kg_ugx': 5000,
        'updated_at': '2026-06-06T10:00:00Z',
        'updated_by': null,
        'delivery_fee_ugx': 3000,
        'express_surcharge_flat_ugx': 2000,
        'express_surcharge_pct': 30,
      }).copyWith(deliveryFeeUgx: 4000);
      expect(s.deliveryFeeUgx, 4000);
      expect(s.expressFlatUgx, 2000);
      expect(s.defaultRatePerKgUgx, 5000);
    });

    test('copyWith preserves id, updatedAt and updatedBy', () {
      final original = PricingSettings.fromSupabase({
        'id': 'p1',
        'default_rate_per_kg_ugx': 5000,
        'updated_at': '2026-06-06T10:00:00Z',
        'updated_by': 'staff-7',
      });
      final s = original.copyWith(expressPct: 25);
      expect(s.id, 'p1');
      expect(s.updatedAt, original.updatedAt);
      expect(s.updatedBy, 'staff-7');
      expect(s.expressPct, 25.0);
      expect(s.defaultRatePerKgUgx, 5000);
    });
  });
}
