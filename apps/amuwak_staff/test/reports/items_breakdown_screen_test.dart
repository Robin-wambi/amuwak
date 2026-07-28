import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/widgets/order_card.dart';
import 'package:amuwak_staff/src/reports/items_breakdown_screen.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';

LaundryOrder _order(String id, int itemCount) => LaundryOrder(
      orderId: id,
      orderCode: id,
      customerName: 'Cust $id',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.inProgress,
      timeLabel: 't',
      itemCount: itemCount,
      phone: 'p',
      address: 'a',
      notes: '',
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<LaundryOrder> orders,
  void Function(LaundryOrder)? onOrderTap,
  void Function(LaundryOrder)? onAdvanceOrderStatus,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ordersStreamProvider.overrideWith(
          (ref) => Stream<List<LaundryOrder>>.value(orders),
        ),
      ],
      child: MaterialApp(
        home: ItemsBreakdownScreen(
          onOrderTap: onOrderTap ?? (_) {},
          onAdvanceOrderStatus: onAdvanceOrderStatus,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app bar shows the Items title and the total-items header',
      (tester) async {
    await _pump(tester, orders: [_order('A', 3), _order('B', 2)]);

    expect(find.widgetWithText(AppBar, 'Items'), findsOneWidget);
    expect(find.text('Total items handled today: 5'), findsOneWidget);
  });

  testWidgets('lists orders that carry items, most-items-first', (tester) async {
    await _pump(tester, orders: [
      _order('low', 1),
      _order('high', 9),
      _order('mid', 4),
      _order('none', 0), // excluded: no items
    ]);

    expect(find.byType(OrderCard), findsNWidgets(3));

    // Ordered high -> mid -> low by vertical position.
    final highY = tester.getTopLeft(find.text('Cust high')).dy;
    final midY = tester.getTopLeft(find.text('Cust mid')).dy;
    final lowY = tester.getTopLeft(find.text('Cust low')).dy;
    expect(highY, lessThan(midY));
    expect(midY, lessThan(lowY));
    expect(find.text('Cust none'), findsNothing);
  });

  testWidgets('orders with equal item counts are ordered by orderCode',
      (tester) async {
    await _pump(tester, orders: [
      _order('zebra', 5),
      _order('apple', 5),
      _order('mango', 5),
    ]);

    // Same itemCount, so the ascending orderCode tiebreak decides: apple < mango < zebra.
    final appleY = tester.getTopLeft(find.text('Cust apple')).dy;
    final mangoY = tester.getTopLeft(find.text('Cust mango')).dy;
    final zebraY = tester.getTopLeft(find.text('Cust zebra')).dy;
    expect(appleY, lessThan(mangoY));
    expect(mangoY, lessThan(zebraY));
  });

  testWidgets('tapping a row invokes onOrderTap with that order', (tester) async {
    LaundryOrder? tapped;
    await _pump(
      tester,
      orders: [_order('A', 3)],
      onOrderTap: (o) => tapped = o,
    );

    await tester.tap(find.text('Cust A'));
    await tester.pumpAndSettle();

    expect(tapped?.orderId, 'A');
  });

  testWidgets('shows the empty state when no order has items', (tester) async {
    await _pump(tester, orders: [_order('A', 0)]);

    expect(find.text('No items yet'), findsOneWidget);
    expect(find.byType(OrderCard), findsNothing);
  });

  testWidgets('shows the error state when the orders stream errors',
      (tester) async {
    // Covers ordersAsync.error → EmptyState("Couldn't load orders").
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
            (ref) => Stream<List<LaundryOrder>>.error(
              StateError('stream blew up'),
            ),
          ),
        ],
        child: MaterialApp(
          home: ItemsBreakdownScreen(onOrderTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load orders"), findsOneWidget);
    expect(find.text('Please try again.'), findsOneWidget);
    expect(find.byType(OrderCard), findsNothing);
  });

  testWidgets(
      'an order card forwards its advance-status action to onAdvanceOrderStatus',
      (tester) async {
    // Covers the onAdvanceStatus closure wired onto each OrderCard (line 107):
    // an inProgress order offers a proof-less "Mark as ..." action whose tap
    // invokes the callback with that order.
    LaundryOrder? advanced;
    await _pump(
      tester,
      orders: [_order('A', 3)], // _order builds inProgress orders
      onAdvanceOrderStatus: (o) => advanced = o,
    );

    // Open the card's overflow actions sheet via long-press.
    await tester.longPress(find.byType(OrderCard));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Mark as'));
    await tester.pumpAndSettle();

    expect(advanced?.orderId, 'A');
  });
}
