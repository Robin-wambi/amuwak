import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/widgets/order_card.dart';
import 'package:amuwak_staff/src/orders/widgets/order_card_list.dart';

LaundryOrder _order(String id, String name) => LaundryOrder(
      orderId: id,
      orderCode: id,
      customerName: name,
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 1,
      phone: '0700123456',
      address: 'addr',
      notes: '',
    );

void main() {
  testWidgets('renders one OrderCard per order', (tester) async {
    final orders = [_order('A', 'Ann'), _order('B', 'Bob'), _order('C', 'Cy')];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OrderCardList(orders: orders, onOrderTap: (_) {}),
      ),
    ));

    expect(find.byType(OrderCard), findsNWidgets(3));
  });

  testWidgets('tapping a card invokes onOrderTap with that order',
      (tester) async {
    final orders = [_order('A', 'Ann'), _order('B', 'Bob')];
    LaundryOrder? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OrderCardList(orders: orders, onOrderTap: (o) => tapped = o),
      ),
    ));

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(tapped, orders[1]);
  });
}
