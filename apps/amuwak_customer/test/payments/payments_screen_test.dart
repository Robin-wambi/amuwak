import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/orders/providers.dart';
import 'package:amuwak_customer/src/payments/payments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LaundryOrder _order({
  required String id,
  required String code,
  int total = 0,
  int paid = 0,
  OrderStatus status = OrderStatus.readyForDelivery,
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
        home: const PaymentsScreen(),
      ),
    );

void main() {
  testWidgets('groups outstanding vs settled and totals the amount due',
      (tester) async {
    await tester.pumpWidget(_harness([
      _order(id: 'a', code: 'AMW-1', total: 20000, paid: 12000), // due 8,000
      _order(id: 'b', code: 'AMW-2', total: 10000, paid: 10000), // paid
      _order(id: 'c', code: 'AMW-3', total: 0, paid: 0), // awaiting price
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Due USh 8,000'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Awaiting price'), findsOneWidget);
    // Total-due card sums only the outstanding balances.
    expect(find.text('USh 8,000'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no orders', (tester) async {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to pay yet'), findsOneWidget);
  });
}
