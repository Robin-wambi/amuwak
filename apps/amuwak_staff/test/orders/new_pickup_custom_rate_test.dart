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

Customer _customer({
  required String id,
  required String name,
  required String phone,
  String? address,
  double? customRatePerKgUgx,
}) =>
    Customer(
      id: id,
      name: name,
      phone: phone,
      address: address,
      notes: null,
      createdAt: DateTime(2026, 5, 20, 9),
      updatedAt: DateTime(2026, 5, 20, 9),
      deletedAt: null,
      customRatePerKgUgx: customRatePerKgUgx,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_customer(id: 'fb', name: 'fb', phone: '0'));
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
    // initState loads address suggestions from customers + orders.
    when(() => ordersRepo.getAll())
        .thenAnswer((_) async => const <LaundryOrder>[]);
  });

  /// Captures the (order, customer) passed to [OrdersRepository.createPickup] in
  /// a single verify. mocktail marks a call verified once captured, so two
  /// separate verifies of the same call would fail — capture both at once.
  ({LaundryOrder order, Customer customer}) capturedPickup() {
    final args = verify(() => ordersRepo.createPickup(
          captureAny(),
          captureAny(),
          actorStaffId: any(named: 'actorStaffId'),
        )).captured;
    return (order: args[0] as LaundryOrder, customer: args[1] as Customer);
  }

  Future<_FormHandle> pumpFormAndOpen(WidgetTester tester) async {
    final handle = _FormHandle();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  handle.popped =
                      await Navigator.of(context).push<NewPickupResult>(
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
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return handle;
  }

  /// The item count is a required field now (the DB rejects item_count = 0), so
  /// every submit must set it. Scrolls the count box into view, then types.
  Future<void> setCount(WidgetTester tester, int n) async {
    await tester.dragUntilVisible(
      find.byKey(const Key('np_count_field')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_count_field')), '$n');
    await tester.pump();
  }

  testWidgets('blank custom rate saves a null override', (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    // Leave custom rate blank (do not expand optional details or leave field empty).
    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final customer = capturedPickup().customer;
    expect(customer.customRatePerKgUgx, isNull,
        reason: 'blank custom rate field should save null override');
  });

  testWidgets(
      'returning customer with stored rate: blank custom-rate field preserves '
      'their existing rate (does not erase it with null)', (tester) async {
    // Arrange: a returning customer with a negotiated custom rate of 4000.
    when(() => customersRepo.getAll()).thenAnswer((_) async => [
          _customer(
            id: 'returning-cust-1',
            name: 'VIP Returner',
            phone: '+256 700 555 666',
            address: 'Ntinda, Kampala',
            customRatePerKgUgx: 4000,
          ),
        ]);
    await pumpFormAndOpen(tester);

    // Trigger the phone-blur match lookup.
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 555 666');
    await tester.tap(find.byKey(const Key('np_name')));
    await tester.pumpAndSettle();

    // Accept the matched customer ("Use this customer").
    expect(find.text('Use this customer'), findsOneWidget);
    await tester.tap(find.text('Use this customer'));
    await tester.pumpAndSettle();

    // Select service type to enable submit.
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    // Leave the custom-rate field blank (do not expand optional details).
    // Submit.
    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    // The customer's stored rate must be preserved — NOT erased to null.
    final customer = capturedPickup().customer;
    expect(
      customer.customRatePerKgUgx,
      4000.0,
      reason:
          'blank custom-rate field should fall back to the matched customer\'s '
          'stored rate (4000), not erase it with null',
    );
  });

  testWidgets(
      'returning customer + typed custom rate: the rate is a one-off — it bills '
      'this order but does NOT overwrite the customer stored rate',
      (tester) async {
    // Arrange: a returning customer with a negotiated standing rate of 4000.
    when(() => customersRepo.getAll()).thenAnswer((_) async => [
          _customer(
            id: 'returning-cust-1',
            name: 'VIP Returner',
            phone: '+256 700 555 666',
            address: 'Ntinda, Kampala',
            customRatePerKgUgx: 4000,
          ),
        ]);
    await pumpFormAndOpen(tester);

    // Match and accept the returning customer.
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 555 666');
    await tester.tap(find.byKey(const Key('np_name')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this customer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    // Type a one-off custom rate of 6000 for this order only.
    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('np_custom_rate')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '6000');

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final pickup = capturedPickup();
    // The order is billed at the typed one-off rate...
    expect(pickup.order.ratePerKgSnapshotUgx, 6000.0,
        reason: 'the order snapshot should use the typed one-off rate');
    // ...but the matched customer's standing rate is left untouched.
    expect(pickup.customer.customRatePerKgUgx, 4000.0,
        reason: 'a one-off custom rate must not overwrite the returning '
            'customer\'s stored standing rate');
  });

  testWidgets('a positive custom rate is saved on the customer and order',
      (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    // Expand optional details and enter a custom rate.
    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('np_custom_rate')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '4000');

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final pickup = capturedPickup();
    expect(pickup.customer.customRatePerKgUgx, 4000.0,
        reason: 'custom rate should be saved on the customer');
    expect(pickup.order.ratePerKgSnapshotUgx, 4000.0,
        reason: 'order snapshot should use the typed custom rate');
  });

  testWidgets('a fractional custom rate is rounded before saving',
      (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('np_custom_rate')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '4000.7');

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    // 4000.7 must be persisted as the rounded whole UGX it is displayed as,
    // consistent with the settings-screen rate handling.
    final pickup = capturedPickup();
    expect(pickup.customer.customRatePerKgUgx, 4001.0,
        reason: 'custom rate should be rounded on the customer');
    expect(pickup.order.ratePerKgSnapshotUgx, 4001.0,
        reason: 'order snapshot should use the rounded custom rate');
  });
}

class _FormHandle {
  NewPickupResult? popped;
}
