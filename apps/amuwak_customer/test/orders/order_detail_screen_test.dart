import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/orders/order_detail_screen.dart';
import 'package:amuwak_customer/src/orders/providers.dart';
import 'package:amuwak_customer/src/orders/widgets/status_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LaundryOrder _order({
  required OrderStatus status,
  double? finalWeightKg,
  int total = 20000,
  int paid = 0,
}) =>
    LaundryOrder(
      orderId: 'ord-1',
      orderCode: 'AMW-2026-0007',
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
      ratePerKgSnapshotUgx: 5000,
      estimatedWeightKg: 4,
      finalWeightKg: finalWeightKg,
      totalUgx: total,
      paymentAmountUgx: paid,
    );

Widget _harness(LaundryOrder order) => ProviderScope(
      overrides: [
        orderDetailProvider('ord-1')
            .overrideWith((ref) => Stream.value(order)),
      ],
      child: MaterialApp(
        theme: buildAmuwakTheme(),
        home: const OrderDetailScreen(orderId: 'ord-1'),
      ),
    );

void main() {
  testWidgets('renders the tracking ladder and an Estimate badge while unweighed',
      (tester) async {
    await tester.pumpWidget(_harness(
        _order(status: OrderStatus.readyForDelivery, finalWeightKg: null)));
    await tester.pumpAndSettle();

    // The four-rung ladder is present.
    expect(find.byType(StatusTimeline), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Order placed — awaiting pickup'), findsOneWidget);

    // Provisional price → "Estimate" badge + disclaimer.
    expect(find.text('Estimate'), findsOneWidget);
    expect(
      find.textContaining('final price is set after we weigh'),
      findsOneWidget,
    );
  });

  testWidgets('shows a Final badge and the amount due once weighed',
      (tester) async {
    await tester.pumpWidget(_harness(_order(
      status: OrderStatus.completed,
      finalWeightKg: 4.2,
      total: 21000,
      paid: 10000,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Estimate'), findsNothing);
    expect(find.text('Due'), findsOneWidget);
    expect(find.text('USh 11,000'), findsOneWidget);
  });

  testWidgets('offers a Message us action', (tester) async {
    await tester.pumpWidget(
        _harness(_order(status: OrderStatus.pendingPickup)));
    await tester.pumpAndSettle();
    expect(find.text('Message us'), findsOneWidget);
  });
}
