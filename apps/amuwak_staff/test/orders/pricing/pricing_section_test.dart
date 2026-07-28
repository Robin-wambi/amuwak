import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/pricing/pricing_section.dart';
import 'package:amuwak_staff/src/pricing/catalog_item.dart';

void main() {
  testWidgets('LineItemsEditor shows items and fires onRemove', (tester) async {
    var removed = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineItemsEditor(
          items: [LineItem(name: 'Blanket', amountUgx: 8000)],
          onAdd: () {},
          onRemove: (i) => removed = i,
        ),
      ),
    ));
    expect(find.text('Blanket'), findsOneWidget);
    expect(find.text('USh 8,000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove_line_item_0')));
    expect(removed, 0);
  });

  testWidgets('TotalCard renders the total and a Provisional badge', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TotalCard(totalUgx: 23000, isProvisional: true),
      ),
    ));
    expect(find.text('USh 23,000'), findsOneWidget);
    expect(find.text('Provisional'), findsOneWidget);
  });

  testWidgets(
      'showAddLineItemSheet keeps the sheet open and shows an error on invalid amount',
      (tester) async {
    LineItem? result;
    var returned = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showAddLineItemSheet(context);
              returned = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('line_item_name')), 'Blanket');
    await tester.enterText(find.byKey(const Key('line_item_amount')), 'abc');
    await tester.tap(find.byKey(const Key('line_item_save')));
    await tester.pumpAndSettle();

    // Sheet stays open with a validation message; nothing returned yet.
    expect(returned, isFalse);
    expect(find.byKey(const Key('line_item_amount')), findsOneWidget);
    expect(find.text('Enter a valid amount'), findsOneWidget);

    // Correcting the amount and saving returns the item.
    await tester.enterText(find.byKey(const Key('line_item_amount')), '8000');
    await tester.tap(find.byKey(const Key('line_item_save')));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isNotNull);
    expect(result!.name, 'Blanket');
    expect(result!.amountUgx, 8000);
  });

  testWidgets('filters picker items by category chip', (tester) async {
    final catalog = [
      CatalogItem(
          id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
      CatalogItem(id: 'c2', name: 'Blanket', amountUgx: 8000, category: 'Bulky'),
      CatalogItem(id: 'c3', name: 'Plain', amountUgx: 0), // uncategorised
    ];
    LineItem? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                picked = await showPickLineItemSheet(context, catalog),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // All shown by default.
    expect(find.text('Suit'), findsOneWidget);
    expect(find.text('Blanket'), findsOneWidget);
    expect(find.text('Plain'), findsOneWidget);

    // Filter to Dry Cleaning.
    await tester.tap(find.byKey(const Key('pick_category_Dry Cleaning')));
    await tester.pumpAndSettle();
    expect(find.text('Suit'), findsOneWidget);
    expect(find.text('Blanket'), findsNothing);
    expect(find.text('Plain'), findsNothing);

    // Uncategorised via the Other chip.
    await tester.tap(find.byKey(const Key('pick_category_other')));
    await tester.pumpAndSettle();
    expect(find.text('Plain'), findsOneWidget);
    expect(find.text('Suit'), findsNothing);

    // Picking still returns a LineItem with name + amount.
    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();
    expect(picked, isNotNull);
    expect(picked!.name, 'Plain');
    expect(picked!.amountUgx, 0);
  });

  testWidgets('the All chip resets the category filter to show everything',
      (tester) async {
    final catalog = [
      CatalogItem(
          id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
      CatalogItem(id: 'c2', name: 'Blanket', amountUgx: 8000, category: 'Bulky'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPickLineItemSheet(context, catalog),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Narrow to one category, then tap All to restore the full list.
    await tester.tap(find.byKey(const Key('pick_category_Dry Cleaning')));
    await tester.pumpAndSettle();
    expect(find.text('Blanket'), findsNothing);

    await tester.tap(find.byKey(const Key('pick_category_all')));
    await tester.pumpAndSettle();
    expect(find.text('Suit'), findsOneWidget);
    expect(find.text('Blanket'), findsOneWidget);
  });

  testWidgets('Custom item opens the add sheet and returns the entered item',
      (tester) async {
    final catalog = [
      CatalogItem(
          id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
    ];
    LineItem? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                picked = await showPickLineItemSheet(context, catalog),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_custom_item')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('line_item_name')), 'Curtain');
    await tester.enterText(find.byKey(const Key('line_item_amount')), '15000');
    await tester.tap(find.byKey(const Key('line_item_save')));
    await tester.pumpAndSettle();

    // The custom item flows back out through the picker's onTap pop.
    expect(picked, isNotNull);
    expect(picked!.name, 'Curtain');
    expect(picked!.amountUgx, 15000);
  });

  testWidgets('no category chips when nothing is categorised', (tester) async {
    final catalog = [
      CatalogItem(id: 'c1', name: 'Plain', amountUgx: 1000),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPickLineItemSheet(context, catalog),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick_category_all')), findsNothing);
    expect(find.text('Plain'), findsOneWidget);
  });
}
