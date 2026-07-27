import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/customer_photo_url.dart';
import 'package:amuwak_staff/src/orders/widgets/customer_items_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _weightLine = CartSnapshotItem(
  kind: 'weight',
  name: 'Wash & Iron',
  serviceType: ServiceType.washAndIron,
  estKg: 6,
  note: 'delicate',
);

const _flaggedLine = CartSnapshotItem(
  kind: 'piece',
  name: 'Jacket',
  unitUgx: 8000,
  qty: 2,
  photoKey: 'customer/c1/cart/p1.jpg',
);

Widget _harness({
  required List<CartSnapshotItem> items,
  CustomerPhotoUrlResolver? photoUrl,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomerItemsSection(items: items, photoUrl: photoUrl),
        ),
      ),
    );

void main() {
  testWidgets('lists what the customer declared, with quantities and notes',
      (tester) async {
    await tester.pumpWidget(_harness(items: const [_weightLine, _flaggedLine]));
    await tester.pumpAndSettle();

    expect(find.text('What the customer sent'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Wash & Iron'), findsOneWidget);
    expect(find.text('~6 kg'), findsOneWidget);
    expect(find.text('Note: delicate'), findsOneWidget);
    expect(find.text('Jacket'), findsOneWidget);
    expect(find.text('× 2'), findsOneWidget);
  });

  testWidgets('warns about flagged damage before the load is washed',
      (tester) async {
    await tester.pumpWidget(_harness(items: const [_weightLine, _flaggedLine]));
    await tester.pumpAndSettle();

    expect(
      find.text('Customer flagged 1 item as damaged — check before washing.'),
      findsOneWidget,
    );
  });

  testWidgets('says nothing about damage when no item is flagged',
      (tester) async {
    await tester.pumpWidget(_harness(items: const [_weightLine]));
    await tester.pumpAndSettle();

    expect(find.textContaining('flagged'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('renders nothing at all for a rider order', (tester) async {
    await tester.pumpWidget(_harness(items: const []));
    await tester.pumpAndSettle();

    expect(find.text('What the customer sent'), findsNothing);
  });

  testWidgets('signs a URL per flagged photo and shows the thumbnail',
      (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(_harness(
      items: const [_flaggedLine],
      photoUrl: (key) async {
        asked.add(key);
        return 'https://example.test/signed/$key';
      },
    ));
    await tester.pump(); // resolve the signing future
    await tester.pump();

    expect(asked, ['customer/c1/cart/p1.jpg']);
    expect(find.byType(Image), findsOneWidget);
    // A test harness can't actually fetch the URL; the load error is expected
    // and handled by the widget's errorBuilder.
    tester.takeException();
  });

  testWidgets('an unresolvable photo falls back to a placeholder, not an error',
      (tester) async {
    // Offline: the resolver returns null rather than throwing.
    await tester.pumpWidget(
        _harness(items: const [_flaggedLine], photoUrl: (key) async => null));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    // The declared item is still readable — the point of the section.
    expect(find.text('Jacket'), findsOneWidget);
  });

  testWidgets('with no resolver at all it still lists the items',
      (tester) async {
    await tester.pumpWidget(_harness(items: const [_flaggedLine]));
    await tester.pumpAndSettle();

    expect(find.text('Jacket'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
