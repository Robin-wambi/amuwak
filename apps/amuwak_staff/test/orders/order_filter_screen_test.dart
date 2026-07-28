import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_filter.dart';
import 'package:amuwak_staff/src/orders/order_filter_screen.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/orders/widgets/order_card.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';

LaundryOrder _pending(String name) => LaundryOrder(
      orderId: name,
      orderCode: name,
      customerName: name,
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 'Pickup: now',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
    );

// Fixed reference clock so "Completed today" and date-group labels are
// deterministic (no wall-clock / midnight fragility).
DateTime _fixedNow() => DateTime(2026, 6, 11, 10);

LaundryOrder _completedToday(String name) => LaundryOrder(
      orderId: name,
      orderCode: name,
      customerName: name,
      serviceType: ServiceType.washOnly,
      status: OrderStatus.completed,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
      proofEvents: [
        ProofEvent(
          id: 'd-$name',
          type: ProofEventType.delivery,
          capturedAt: DateTime(2026, 6, 11, 9),
          count: 1,
          photoPaths: const [],
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  required OrderFilter filter,
  required List<LaundryOrder> orders,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ordersStreamProvider.overrideWith(
          (ref) => Stream<List<LaundryOrder>>.value(orders),
        ),
      ],
      child: MaterialApp(
        home: OrderFilterScreen(
          filter: filter,
          onOrderTap: (_) {},
          now: _fixedNow,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app bar shows the filter label', (tester) async {
    await _pump(tester, filter: OrderFilter.pendingPickup, orders: [
      _pending('Jane'),
    ]);
    expect(find.widgetWithText(AppBar, 'Pending pickup'), findsOneWidget);
  });

  testWidgets('title override replaces the filter label in the app bar',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
            (ref) => Stream<List<LaundryOrder>>.value([_pending('Jane')]),
          ),
        ],
        child: MaterialApp(
          home: OrderFilterScreen(
            filter: OrderFilter.all,
            onOrderTap: (_) {},
            now: _fixedNow,
            title: 'Orders',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The override wins; the filter's own label ("Assigned") is not shown.
    expect(find.widgetWithText(AppBar, 'Orders'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Assigned'), findsNothing);
  });

  testWidgets('renders one card per matching order and a "Now" date header',
      (tester) async {
    await _pump(tester, filter: OrderFilter.pendingPickup, orders: [
      _pending('Jane'),
      _pending('Bob'),
      _completedToday('Carol'), // filtered out by pendingPickup
    ]);

    // Count == preview: exactly the two pending orders are shown.
    expect(find.byType(OrderCard), findsNWidgets(2));
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Carol'), findsNothing);
    // Immediate orders group under a "Now" section.
    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets('completedToday lists only orders delivered today',
      (tester) async {
    await _pump(tester, filter: OrderFilter.completedToday, orders: [
      _completedToday('Carol'),
      _pending('Jane'),
    ]);

    expect(find.widgetWithText(AppBar, 'Completed today'), findsOneWidget);
    expect(find.byType(OrderCard), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
  });

  testWidgets('empty result shows the empty state', (tester) async {
    await _pump(tester, filter: OrderFilter.inProgress, orders: [
      _pending('Jane'),
    ]);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byType(OrderCard), findsNothing);
  });

  testWidgets('stream error shows the load-error state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
            (ref) => Stream<List<LaundryOrder>>.error(Exception('boom')),
          ),
        ],
        child: MaterialApp(
          home: OrderFilterScreen(
            filter: OrderFilter.all,
            onOrderTap: (_) {},
            now: _fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load orders"), findsOneWidget);
    expect(find.byType(OrderCard), findsNothing);
  });
}
