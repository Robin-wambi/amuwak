import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fetchActive maps rows to CatalogItems', () async {
    final repo = CatalogRepository.forTest(
      fetchRows: () async => [
        {
          'id': 'c1',
          'name': 'Jacket',
          'amount_ugx': 8000,
          'active': true,
          'sort_order': 1,
          'category': 'Dry Cleaning',
        },
        {
          'id': 'c2',
          'name': 'Blanket',
          'amount_ugx': 12000,
        },
      ],
    );

    final items = await repo.fetchActive();

    expect(items, hasLength(2));
    expect(items.first.name, 'Jacket');
    expect(items.first.amountUgx, 8000);
    expect(items.first.category, 'Dry Cleaning');
    // Missing active/sort_order/category degrade to defaults.
    expect(items[1].active, isTrue);
    expect(items[1].sortOrder, 0);
    expect(items[1].category, isNull);
  });
}
