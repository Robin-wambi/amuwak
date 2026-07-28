import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/pricing/pricing_settings_repository.dart';

void main() {
  group('PricingSettingsRepository', () {
    test('throws a clear error when no settings row exists', () async {
      final repo = PricingSettingsRepository.forTest(fetchRows: () async => []);
      expect(repo.fetch, throwsA(isA<StateError>()));
    });

    test('returns the first row when present', () async {
      final repo = PricingSettingsRepository.forTest(fetchRows: () async => [
            {
              'id': 'p1',
              'default_rate_per_kg_ugx': 5000,
              'updated_at': '2026-06-06T10:00:00Z',
              'updated_by': null,
            }
          ]);
      final s = await repo.fetch();
      expect(s.defaultRatePerKgUgx, 5000);
    });

    List<Map<String, dynamic>> singletonRow() => [
          {
            'id': 'p1',
            'default_rate_per_kg_ugx': 5000,
            'updated_at': '2026-06-06T10:00:00Z',
            'updated_by': null,
          }
        ];

    test('updateSettings writes rate, delivery fee, express, actor and time',
        () async {
      String? updatedId;
      Map<String, dynamic>? values;
      final repo = PricingSettingsRepository.forTest(
        fetchRows: () async => singletonRow(),
        updateRow: (id, v) async {
          updatedId = id;
          values = v;
        },
      );
      await repo.updateSettings(
        ratePerKgUgx: 6000,
        deliveryFeeUgx: 3000,
        expressFlatUgx: 2000,
        expressPct: 30,
        actorStaffId: 'staff-9',
      );
      expect(updatedId, 'p1');
      expect(values!['default_rate_per_kg_ugx'], 6000);
      expect(values!['delivery_fee_ugx'], 3000);
      expect(values!['express_surcharge_flat_ugx'], 2000);
      expect(values!['express_surcharge_pct'], 30);
      expect(values!['updated_by'], 'staff-9');
      expect(values!.containsKey('updated_at'), isTrue);
    });

    test('updateSettings reuses the cached id and does not re-read', () async {
      var fetchCalls = 0;
      final repo = PricingSettingsRepository.forTest(
        fetchRows: () async {
          fetchCalls++;
          return singletonRow();
        },
        updateRow: (_, __) async {},
      );
      // The settings screen always loads before saving — prime the cache.
      await repo.fetch();
      expect(fetchCalls, 1);
      await repo.updateSettings(
          ratePerKgUgx: 6000,
          deliveryFeeUgx: 0,
          expressFlatUgx: 0,
          expressPct: 0,
          actorStaffId: 'staff-9');
      await repo.updateSettings(
          ratePerKgUgx: 7000,
          deliveryFeeUgx: 0,
          expressFlatUgx: 0,
          expressPct: 0,
          actorStaffId: 'staff-9');
      // No extra SELECT for the singleton id on either save.
      expect(fetchCalls, 1);
    });

    test('updateSettings fetches once for the id when nothing is cached',
        () async {
      var fetchCalls = 0;
      String? updatedId;
      final repo = PricingSettingsRepository.forTest(
        fetchRows: () async {
          fetchCalls++;
          return singletonRow();
        },
        updateRow: (id, _) async => updatedId = id,
      );
      await repo.updateSettings(
          ratePerKgUgx: 6000,
          deliveryFeeUgx: 0,
          expressFlatUgx: 0,
          expressPct: 0,
          actorStaffId: 'staff-9');
      expect(fetchCalls, 1);
      expect(updatedId, 'p1');
    });
  });
}
