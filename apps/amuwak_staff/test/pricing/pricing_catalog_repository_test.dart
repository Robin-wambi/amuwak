import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/pricing/catalog_item.dart';
import 'package:amuwak_staff/src/pricing/pricing_catalog_repository.dart';

void main() {
  group('PricingCatalogRepository', () {
    List<Map<String, dynamic>> rows() => [
          {
            'id': 'c1',
            'name': 'Blanket',
            'amount_ugx': 8000,
            'active': true,
            'sort_order': 1,
          },
          {
            'id': 'c2',
            'name': 'Old item',
            'amount_ugx': 5000,
            'active': false,
            'sort_order': 2,
          },
        ];

    test('fetchActive requests active-only and maps rows', () async {
      bool? askedActiveOnly;
      final repo = PricingCatalogRepository.forTest(
        fetchRows: ({required bool activeOnly}) async {
          askedActiveOnly = activeOnly;
          return rows().where((r) => r['active'] == true).toList();
        },
      );
      final items = await repo.fetchActive();
      expect(askedActiveOnly, isTrue);
      expect(items, hasLength(1));
      expect(items.single, isA<CatalogItem>());
      expect(items.single.name, 'Blanket');
    });

    test('fetchAll requests every row including inactive', () async {
      bool? askedActiveOnly;
      final repo = PricingCatalogRepository.forTest(
        fetchRows: ({required bool activeOnly}) async {
          askedActiveOnly = activeOnly;
          return rows();
        },
      );
      final items = await repo.fetchAll();
      expect(askedActiveOnly, isFalse);
      expect(items, hasLength(2));
    });

    test('upsertItem writes the serialized item', () async {
      Map<String, dynamic>? written;
      final repo = PricingCatalogRepository.forTest(
        fetchRows: ({required bool activeOnly}) async => [],
        upsertRow: (values) async => written = values,
      );
      await repo
          .upsertItem(CatalogItem(id: 'c3', name: 'Duvet', amountUgx: 10000));
      expect(written!['id'], 'c3');
      expect(written!['name'], 'Duvet');
      expect(written!['amount_ugx'], 10000);
      expect(written!['active'], true);
    });

    test('deactivating is an upsert of a copy with active false', () async {
      Map<String, dynamic>? written;
      final repo = PricingCatalogRepository.forTest(
        fetchRows: ({required bool activeOnly}) async => [],
        upsertRow: (values) async => written = values,
      );
      final item = CatalogItem(id: 'c1', name: 'Blanket', amountUgx: 8000);
      await repo.upsertItem(item.copyWith(active: false));
      expect(written!['active'], false);
    });
  });
}
