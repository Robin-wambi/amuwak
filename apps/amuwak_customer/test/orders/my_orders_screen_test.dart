import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/orders/my_orders_screen.dart';
import 'package:amuwak_customer/src/orders/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LaundryOrder _order({
  required String id,
  required String code,
  required OrderStatus status,
  int total = 12000,
  int paid = 0,
}) =>
    LaundryOrder(
      orderId: id,
      orderCode: code,
      customerId: 'cust-1',
      customerName: 'Ada',
      serviceType: ServiceType.washAndIron,
      status: status,
      timeLabel: 'Pickup: now',
      itemCount: 3,
      phone: '0700',
      address: 'a',
      notes: '',
      intakeMethod: 'customer_app',
      totalUgx: total,
      paymentAmountUgx: paid,
    );

Widget _harness(List<LaundryOrder> orders) => ProviderScope(
      overrides: [
        myOrdersProvider.overrideWith((ref) => Stream.value(orders)),
      ],
      child: MaterialApp(
        theme: buildAmuwakTheme(),
        home: const MyOrdersScreen(),
      ),
    );

void main() {
  testWidgets('splits orders into Active and History tabs', (tester) async {
    await tester.pumpWidget(_harness([
      _order(id: 'a1', code: 'AMW-2026-0001', status: OrderStatus.pendingPickup),
      _order(id: 'c1', code: 'AMW-2026-0002', status: OrderStatus.completed),
    ]));
    await tester.pumpAndSettle();

    // Active tab is shown first: the pending order + its status chip.
    expect(find.text('AMW-2026-0001'), findsOneWidget);
    expect(find.text('Pending pickup'), findsOneWidget);
    expect(find.text('AMW-2026-0002'), findsNothing);

    // Switch to History: the completed order.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('AMW-2026-0002'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('AMW-2026-0001'), findsNothing);
  });

  testWidgets('shows an empty state when there are no active orders',
      (tester) async {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('No active orders'), findsOneWidget);
    expect(find.text('New pickup'), findsOneWidget); // the FAB
  });

  testWidgets('shows the outstanding amount due on a partly-paid order',
      (tester) async {
    await tester.pumpWidget(_harness([
      _order(
          id: 'a1',
          code: 'AMW-2026-0003',
          status: OrderStatus.readyForDelivery,
          total: 20000,
          paid: 12000),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Due USh 8,000'), findsOneWidget);
  });
}
