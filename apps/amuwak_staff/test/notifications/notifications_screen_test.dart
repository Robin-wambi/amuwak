import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/notifications/notifications_screen.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';

final _now = DateTime.utc(2026, 6, 5, 12, 0);

LaundryOrder _order({
  required String code,
  required OrderStatus status,
  DateTime? deliveredAt,
}) {
  return LaundryOrder(
    orderId: 'id-$code',
    orderCode: code,
    customerName: 'Cust $code',
    serviceType: ServiceType.washAndIron,
    status: status,
    timeLabel: 'Today',
    itemCount: 1,
    phone: '0700000000',
    address: 'Somewhere',
    notes: '',
    proofEvents: [
      if (deliveredAt != null)
        ProofEvent(
          id: 'pe-$code',
          type: ProofEventType.delivery,
          capturedAt: deliveredAt,
          count: 1,
          photoPaths: const [],
        ),
    ],
  );
}

Widget _harness(
  List<LaundryOrder> orders, {
  void Function(LaundryOrder)? onOrderTap,
}) {
  return ProviderScope(
    overrides: [
      ordersStreamProvider.overrideWith((ref) => Stream.value(orders)),
    ],
    child: MaterialApp(
      home: NotificationsScreen(
        onOrderTap: onOrderTap,
        clock: () => _now,
      ),
    ),
  );
}

void main() {
  testWidgets('shows the empty state when nothing to summarize', (tester) async {
    await tester.pumpWidget(_harness([
      _order(code: 'I1', status: OrderStatus.inProgress),
    ]));
    await tester.pump();

    expect(find.text('No notifications yet.'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
  });

  testWidgets('renders count chips and feed rows', (tester) async {
    await tester.pumpWidget(_harness([
      _order(code: 'P1', status: OrderStatus.pendingPickup),
      _order(
        code: 'D1',
        status: OrderStatus.completed,
        deliveredAt: _now.subtract(const Duration(minutes: 5)),
      ),
    ]));
    await tester.pump();

    expect(find.text('New pickup · P1'), findsOneWidget);
    expect(find.text('Delivered · D1'), findsOneWidget);
    expect(find.textContaining('5 min ago'), findsOneWidget);
  });

  testWidgets(
      'a placeholder pickup shows "Pending sync", never the raw UUID',
      (tester) async {
    // Offline order: orderCode unset so it falls back to the UUID orderId.
    const placeholder = LaundryOrder(
      orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
      customerName: 'Cust',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.pendingPickup,
      timeLabel: 'Today',
      itemCount: 1,
      phone: '0700000000',
      address: 'Somewhere',
      notes: '',
    );
    await tester.pumpWidget(_harness([placeholder]));
    await tester.pump();

    expect(find.text('New pickup · Pending sync'), findsOneWidget);
    expect(find.textContaining('019e9147'), findsNothing);
  });

  testWidgets('tapping a row invokes onOrderTap with that order', (tester) async {
    LaundryOrder? tapped;
    await tester.pumpWidget(_harness(
      [_order(code: 'P1', status: OrderStatus.pendingPickup)],
      onOrderTap: (o) => tapped = o,
    ));
    await tester.pump();

    await tester.tap(find.text('New pickup · P1'));
    await tester.pump();

    expect(tapped?.orderCode, 'P1');
  });

  testWidgets('tapping a delivered row invokes onOrderTap with that order',
      (tester) async {
    LaundryOrder? tapped;
    await tester.pumpWidget(_harness(
      [
        _order(
          code: 'D1',
          status: OrderStatus.completed,
          deliveredAt: _now.subtract(const Duration(minutes: 5)),
        ),
      ],
      onOrderTap: (o) => tapped = o,
    ));
    await tester.pump();

    await tester.tap(find.text('Delivered · D1'));
    await tester.pump();

    expect(tapped?.orderCode, 'D1');
  });

  testWidgets('shows a spinner while the orders stream is loading',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A stream that never emits keeps the provider in the loading state.
          ordersStreamProvider.overrideWith(
            (ref) => Stream<List<LaundryOrder>>.fromFuture(
              Completer<List<LaundryOrder>>().future,
            ),
          ),
        ],
        child: MaterialApp(
          home: NotificationsScreen(clock: () => _now),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a retry affordance when the orders stream errors',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider
              .overrideWith((ref) => Stream.error(Exception('boom'))),
        ],
        child: MaterialApp(
          home: NotificationsScreen(clock: () => _now),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry re-subscribes and renders content',
      (tester) async {
    var attempt = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // First subscription errors; the invalidate behind Retry re-runs this
          // override, which then yields data.
          ordersStreamProvider.overrideWith((ref) {
            attempt++;
            if (attempt == 1) {
              return Stream<List<LaundryOrder>>.error(Exception('boom'));
            }
            return Stream.value([
              _order(code: 'P1', status: OrderStatus.pendingPickup),
            ]);
          }),
        ],
        child: MaterialApp(
          home: NotificationsScreen(clock: () => _now),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump(); // invalidate → re-subscribe
    await tester.pump(); // second stream emits data

    expect(find.text('New pickup · P1'), findsOneWidget);
    expect(attempt, 2);
  });
}
