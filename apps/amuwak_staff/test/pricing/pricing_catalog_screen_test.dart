import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/pricing/catalog_item.dart';
import 'package:amuwak_staff/src/pricing/pricing_catalog_screen.dart';

void main() {
  Widget screen({
    required List<CatalogItem> items,
    required void Function(CatalogItem) onSave,
    String newId = 'new-id',
  }) {
    // Reload returns the same list; tests assert on the saved item, not reload.
    return MaterialApp(
      home: PricingCatalogScreen(
        load: () async => items,
        save: (item) async => onSave(item),
        idGenerator: () => newId,
      ),
    );
  }

  testWidgets('lists items and marks retired ones', (tester) async {
    await tester.pumpWidget(screen(
      items: [
        CatalogItem(id: 'c1', name: 'Blanket', amountUgx: 8000),
        CatalogItem(id: 'c2', name: 'Old', amountUgx: 5000, active: false),
      ],
      onSave: (_) {},
    ));
    await tester.pumpAndSettle();
    expect(find.text('Blanket'), findsOneWidget);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('Retired'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no items', (tester) async {
    await tester.pumpWidget(screen(items: const [], onSave: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text('No service items yet.'), findsOneWidget);
  });

  testWidgets('shows an error state when the load fails', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PricingCatalogScreen(
        load: () async => throw Exception('boom'),
        save: (_) async {},
        idGenerator: () => 'x',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Could not load the catalog — please retry.'),
        findsOneWidget);
    // The add FAB is hidden in the error state.
    expect(find.byKey(const Key('catalog_add')), findsNothing);
  });

  testWidgets('adds a new active item with a generated id', (tester) async {
    CatalogItem? saved;
    await tester.pumpWidget(screen(
      items: const [],
      onSave: (item) => saved = item,
      newId: 'gen-1',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catalog_name')), 'Duvet');
    await tester.enterText(find.byKey(const Key('catalog_amount')), '10000');
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.id, 'gen-1');
    expect(saved!.name, 'Duvet');
    expect(saved!.amountUgx, 10000);
    expect(saved!.active, isTrue);
  });

  testWidgets('editing an item can retire it', (tester) async {
    CatalogItem? saved;
    await tester.pumpWidget(screen(
      items: [CatalogItem(id: 'c1', name: 'Blanket', amountUgx: 8000)],
      onSave: (item) => saved = item,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_item_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_active'))); // turn off
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.id, 'c1');
    expect(saved!.active, isFalse);
  });

  testWidgets('rejects a blank name', (tester) async {
    CatalogItem? saved;
    await tester.pumpWidget(screen(items: const [], onSave: (i) => saved = i));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catalog_amount')), '5000');
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Enter an item name'), findsOneWidget);
  });

  testWidgets('shows category in the list subtitle', (tester) async {
    await tester.pumpWidget(screen(
      items: [
        CatalogItem(
            id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
      ],
      onSave: (_) {},
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dry Cleaning'), findsOneWidget);
  });

  testWidgets('adds an item with a category', (tester) async {
    CatalogItem? saved;
    await tester.pumpWidget(screen(
      items: const [],
      onSave: (item) => saved = item,
      newId: 'gen-1',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catalog_name')), 'Suit');
    await tester.enterText(find.byKey(const Key('catalog_amount')), '12000');
    await tester.enterText(
        find.byKey(const Key('catalog_category')), 'Dry Cleaning');
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.category, 'Dry Cleaning');
  });

  testWidgets('a failing save surfaces a retry SnackBar', (tester) async {
    // Covers _saveAndReload's catch block: when save throws, the screen shows
    // rider-friendly copy instead of swallowing the error.
    await tester.pumpWidget(MaterialApp(
      home: PricingCatalogScreen(
        load: () async => const [],
        save: (_) async => throw Exception('network down'),
        idGenerator: () => 'gen-fail',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catalog_name')), 'Duvet');
    await tester.enterText(find.byKey(const Key('catalog_amount')), '10000');
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Could not save — please retry.'), findsOneWidget);
    expect(find.textContaining('network down'), findsNothing);
  });

  testWidgets('tapping a suggestion fills the category field', (tester) async {
    CatalogItem? saved;
    await tester.pumpWidget(screen(
      items: [
        CatalogItem(
            id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
      ],
      onSave: (item) => saved = item,
      newId: 'gen-2',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catalog_name')), 'Coat');
    await tester.enterText(find.byKey(const Key('catalog_amount')), '9000');
    await tester.tap(find
        .byKey(const Key('catalog_category_suggestion_Dry Cleaning')));
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pumpAndSettle();
    expect(saved!.category, 'Dry Cleaning');
  });
}
