import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/orders/new_pickup_result.dart';
import 'package:amuwak_staff/src/orders/new_pickup_screen.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/customers_repository.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';

class _MockCustomersRepository extends Mock implements CustomersRepository {}

class _MockOrdersRepository extends Mock implements OrdersRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(Customer(
      id: 'fb',
      name: 'fb',
      phone: '0',
      address: null,
      notes: null,
      createdAt: DateTime(2026, 5, 20),
      updatedAt: DateTime(2026, 5, 20),
      deletedAt: null,
    ));
    registerFallbackValue(const LaundryOrder(
      orderId: 'fb',
      customerName: 'fb',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.pendingPickup,
      timeLabel: '',
      itemCount: 1,
      phone: '0',
      address: 'a',
      notes: '',
    ));
  });

  late _MockCustomersRepository customersRepo;
  late _MockOrdersRepository ordersRepo;

  setUp(() {
    customersRepo = _MockCustomersRepository();
    ordersRepo = _MockOrdersRepository();
    when(() => customersRepo.getAll()).thenAnswer((_) async => <Customer>[]);
    when(() => ordersRepo.createPickup(any(), any(),
            actorStaffId: any(named: 'actorStaffId')))
        .thenAnswer((_) async =>
            (orderId: 'uuid-order-1', orderCode: 'AMW-2026-0001'));
    when(() => ordersRepo.getAll())
        .thenAnswer((_) async => const <LaundryOrder>[]);
  });

  LaundryOrder capturedOrder() => verify(() => ordersRepo.createPickup(
        captureAny(),
        any(),
        actorStaffId: any(named: 'actorStaffId'),
      )).captured.single as LaundryOrder;

  Future<void> pumpAndOpen(WidgetTester tester) async {
    // A tall viewport so the whole form (now taller with the required item-count
    // field in the main column) fits — otherwise the express toggle sits at the
    // viewport edge and its tap misses.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<NewPickupResult>(
                  MaterialPageRoute(
                    builder: (_) => NewPickupScreen(
                      customersRepo: customersRepo,
                      ordersRepo: ordersRepo,
                      actorStaffId: 'staff-1',
                      clock: () => DateTime(2026, 5, 25, 10),
                      orderIdGenerator: () => 'uuid-order-1',
                      customerIdGenerator: () => 'uuid-cust-1',
                      geolocate: () async => null,
                      reverseGeocode: (_) async => null,
                      defaultRatePerKgUgx: 5000,
                      deliveryFeeUgx: 3000,
                      expressFlatUgx: 2000,
                      expressPct: 30,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    // Item count is required now (the DB rejects item_count = 0). The tall
    // viewport from pumpAndOpen keeps the count box on-screen, so no scroll.
    await tester.enterText(find.byKey(const Key('np_count_field')), '3');
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();
  }

  // The delivery/express toggles live under "Add optional details".
  Future<void> tapToggle(WidgetTester tester, Key key) async {
    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(key),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults: delivery included, not express', (tester) async {
    await pumpAndOpen(tester);
    await fillRequiredFields(tester);
    await submit(tester);

    final order = capturedOrder();
    expect(order.deliveryFeeSnapshotUgx, 3000);
    expect(order.isExpress, isFalse);
    expect(order.expressFlatSnapshotUgx, 0);
    expect(order.expressPctSnapshot, 0);
  });

  testWidgets('turning delivery off freezes a zero delivery fee',
      (tester) async {
    await pumpAndOpen(tester);
    await fillRequiredFields(tester);
    await tapToggle(tester, const Key('np_delivery_toggle'));
    await submit(tester);

    expect(capturedOrder().deliveryFeeSnapshotUgx, 0);
  });

  testWidgets('marking express freezes the flat + percentage snapshots',
      (tester) async {
    await pumpAndOpen(tester);
    await fillRequiredFields(tester);
    await tapToggle(tester, const Key('np_express_toggle'));
    await submit(tester);

    final order = capturedOrder();
    expect(order.isExpress, isTrue);
    expect(order.expressFlatSnapshotUgx, 2000);
    expect(order.expressPctSnapshot, 30);
  });
}
