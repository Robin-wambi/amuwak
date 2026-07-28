import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/pricing/catalog_item.dart';

void main() {
  group('CatalogItem', () {
    test('fromSupabase reads a row', () {
      final c = CatalogItem.fromSupabase({
        'id': 'c1',
        'name': 'Blanket',
        'amount_ugx': 8000,
        'active': true,
        'sort_order': 2,
      });
      expect(c.id, 'c1');
      expect(c.name, 'Blanket');
      expect(c.amountUgx, 8000);
      expect(c.active, isTrue);
      expect(c.sortOrder, 2);
    });

    test('degrades missing active/sort_order to defaults', () {
      final c = CatalogItem.fromSupabase({
        'id': 'c1',
        'name': 'Duvet',
        'amount_ugx': 10000,
      });
      expect(c.active, isTrue);
      expect(c.sortOrder, 0);
    });

    test('toSupabase round-trips', () {
      final c = CatalogItem(
        id: 'c1',
        name: 'Jacket',
        amountUgx: 5000,
        active: false,
        sortOrder: 3,
      );
      final back = CatalogItem.fromSupabase(c.toSupabase());
      expect(back, c);
    });

    test('trims the name and rejects an empty one', () {
      expect(CatalogItem(id: 'c1', name: '  Shirt  ', amountUgx: 1000).name,
          'Shirt');
      expect(() => CatalogItem(id: 'c1', name: '   ', amountUgx: 1000),
          throwsArgumentError);
    });

    test('rejects a negative amount', () {
      expect(() => CatalogItem(id: 'c1', name: 'Shirt', amountUgx: -1),
          throwsArgumentError);
    });

    test('copyWith overrides only the given fields', () {
      final c = CatalogItem(id: 'c1', name: 'Shirt', amountUgx: 1000)
          .copyWith(active: false);
      expect(c.active, isFalse);
      expect(c.name, 'Shirt');
      expect(c.amountUgx, 1000);
    });

    test('reads and writes category', () {
      final c = CatalogItem(
          id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning');
      expect(c.category, 'Dry Cleaning');
      expect(c.toSupabase()['category'], 'Dry Cleaning');
      expect(CatalogItem.fromSupabase(c.toSupabase()), c);
    });

    test('category degrades to null when absent', () {
      final c = CatalogItem.fromSupabase({
        'id': 'c1',
        'name': 'Duvet',
        'amount_ugx': 10000,
      });
      expect(c.category, isNull);
    });

    test('category reads as null when the key is present but null', () {
      // A real Supabase row for an item saved before categories existed has
      // the column present with a null value (not a missing key).
      final c = CatalogItem.fromSupabase({
        'id': 'c1',
        'name': 'Duvet',
        'amount_ugx': 10000,
        'category': null,
      });
      expect(c.category, isNull);
    });

    test('blank category normalizes to null and trims', () {
      expect(CatalogItem(id: 'c1', name: 'X', amountUgx: 1, category: '   ')
          .category, isNull);
      expect(CatalogItem(id: 'c1', name: 'X', amountUgx: 1, category: ' Wash ')
          .category, 'Wash');
    });

    test('copyWith can set and clear category', () {
      final base = CatalogItem(id: 'c1', name: 'X', amountUgx: 1);
      expect(base.copyWith(category: 'Ironing').category, 'Ironing');
      final tagged = CatalogItem(
          id: 'c1', name: 'X', amountUgx: 1, category: 'Ironing');
      expect(tagged.copyWith(category: null).category, isNull);
      expect(tagged.copyWith(name: 'Y').category, 'Ironing'); // untouched
    });
  });
}
