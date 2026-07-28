import 'package:amuwak_staff/src/pricing/catalog_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CatalogItem item({String category = 'Bedding'}) => CatalogItem(
        id: 'c1',
        name: 'Blanket',
        amountUgx: 8000,
        active: true,
        sortOrder: 2,
        category: category,
      );

  test('value equality holds for identical field values', () {
    expect(item(), equals(item()));
    expect(item().hashCode, item().hashCode);
  });

  test('differing fields break equality and (typically) the hashCode', () {
    expect(item(), isNot(equals(item().copyWith(amountUgx: 9000))));
    expect(item(), isNot(equals(item().copyWith(active: false))));
    expect(item(), isNot(equals(item(category: 'Other'))));
    // hashCode folds the same fields, so a changed field changes the hash.
    expect(item().hashCode, isNot(item().copyWith(sortOrder: 99).hashCode));
  });

  test('toString lists the identifying fields', () {
    final s = item().toString();
    expect(s, contains('Blanket'));
    expect(s, contains('8000'));
    expect(s, contains('Bedding'));
  });
}
