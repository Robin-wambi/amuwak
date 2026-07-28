import 'package:amuwak_staff/src/orders/edit_order_screen.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The edit form changes only an order's descriptive fields and hands the
/// updated order back through the injected `save` callback (the dashboard wires
/// that to OrdersRepository.updateOrderDetails). Pricing and status are
/// deliberately out of scope here — they live on the details screen.
LaundryOrder _order() => LaundryOrder(
      orderId: 'o1',
      orderCode: 'AMW-1',
      customerName: 'Ada',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.inProgress,
      timeLabel: 'Today',
      itemCount: 3,
      phone: '0700',
      address: 'Kira',
      notes: 'gate code 4',
      // Pricing snapshot that must survive untouched through copyWith.
      ratePerKgSnapshotUgx: 5000,
      totalUgx: 19500,
    );

void main() {
  // A tall surface so the whole scrolling form lays out (the Notes field and
  // Save button sit below the default 800x600 viewport).
  Future<void> pumpTall(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: child));
  }

  testWidgets('prefills the form from the order', (tester) async {
    await pumpTall(
      tester,
      EditOrderScreen(order: _order(), save: (_) async {}),
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('0700'), findsOneWidget);
    expect(find.text('Kira'), findsOneWidget);
    expect(find.text('gate code 4'), findsOneWidget);
  });

  testWidgets('save passes an order with the edited fields, pricing intact',
      (tester) async {
    LaundryOrder? saved;
    await pumpTall(
      tester,
      EditOrderScreen(order: _order(), save: (o) async => saved = o),
    );

    await tester.enterText(find.byKey(const Key('edit_customer_name')), 'Bola');
    await tester.enterText(find.byKey(const Key('edit_phone')), '0800');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.orderId, 'o1');
    expect(saved!.customerName, 'Bola');
    expect(saved!.phone, '0800');
    // Edits must not disturb the frozen pricing snapshot.
    expect(saved!.ratePerKgSnapshotUgx, 5000);
    expect(saved!.totalUgx, 19500);
    // Nor the status.
    expect(saved!.status, OrderStatus.inProgress);
  });

  testWidgets('a blank customer name is rejected before save', (tester) async {
    var saveCalled = false;
    await pumpTall(
      tester,
      EditOrderScreen(order: _order(), save: (_) async => saveCalled = true),
    );

    await tester.enterText(find.byKey(const Key('edit_customer_name')), '   ');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(saveCalled, isFalse);
  });

  testWidgets('an empty item count is rejected before save', (tester) async {
    // The field is digitsOnly, so a literal "-1" can't be typed; the reachable
    // invalid path is an empty/non-numeric count, where int.tryParse returns
    // null and the same guard (itemCount == null || itemCount < 1) fires.
    var saveCalled = false;
    await pumpTall(
      tester,
      EditOrderScreen(order: _order(), save: (_) async => saveCalled = true),
    );

    await tester.enterText(find.byKey(const Key('edit_item_count')), '');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(saveCalled, isFalse);
    expect(find.text('Enter an item count of at least 1.'), findsOneWidget);
  });

  testWidgets('an item count of 0 is rejected before save', (tester) async {
    // The DB enforces CHECK (item_count > 0); a 0 here would otherwise pass the
    // client and only fail at the server with an opaque error (the same class of
    // bug fixed in the New Pickup form). Must be caught before save.
    var saveCalled = false;
    await pumpTall(
      tester,
      EditOrderScreen(order: _order(), save: (_) async => saveCalled = true),
    );

    await tester.enterText(find.byKey(const Key('edit_item_count')), '0');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(saveCalled, isFalse);
    expect(find.text('Enter an item count of at least 1.'), findsOneWidget);
  });

  testWidgets('a failed save surfaces a retry SnackBar and clears saving',
      (tester) async {
    await pumpTall(
      tester,
      EditOrderScreen(
        order: _order(),
        save: (_) async => throw Exception('network down'),
      ),
    );

    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(find.text('Could not save — please retry.'), findsOneWidget);
    // The button is interactive again (not stuck in the saving spinner).
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('changing the service chip is carried into the saved order',
      (tester) async {
    LaundryOrder? saved;
    await pumpTall(
      tester,
      EditOrderScreen(order: _order(), save: (o) async => saved = o),
    );

    // _order() starts as washAndIron; pick a different service.
    await tester.tap(find.text(ServiceType.washOnly.label));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(saved!.serviceType, ServiceType.washOnly);
  });

  testWidgets(
      'picking a date and time sets a concrete schedule on the saved order',
      (tester) async {
    LaundryOrder? saved;
    await pumpTall(
      tester,
      EditOrderScreen(order: _order(), save: (o) async => saved = o),
    );

    await tester.tap(find.byKey(const Key('edit_pick_schedule')));
    await tester.pumpAndSettle();
    // Confirm the date picker's initial date.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // Confirm the time picker's initial time.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(saved!.scheduledFor, isNotNull);
  });

  testWidgets(
      'an order with a schedule shows it and can be cleared back to immediate',
      (tester) async {
    LaundryOrder? saved;
    final scheduled =
        _order().copyWith(scheduledFor: DateTime(2026, 7, 1, 14, 30));
    await pumpTall(
      tester,
      EditOrderScreen(order: scheduled, save: (o) async => saved = o),
    );

    // The scheduled label renders and the Clear affordance is offered.
    expect(find.text(LaundryOrder.formatScheduled(scheduled.scheduledFor!)),
        findsOneWidget);
    final clear = find.byKey(const Key('edit_clear_schedule'));
    expect(clear, findsOneWidget);

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('Immediate (pickup now)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();
    expect(saved!.scheduledFor, isNull);
  });
}
