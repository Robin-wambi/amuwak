import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
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

  Widget buildScreen({double defaultRatePerKgUgx = 5000}) {
    return MaterialApp(
      home: NewPickupScreen(
        customersRepo: customersRepo,
        ordersRepo: ordersRepo,
        actorStaffId: 'staff-1',
        clock: () => DateTime(2026, 5, 25, 10),
        orderIdGenerator: () => 'uuid-order-1',
        customerIdGenerator: () => 'uuid-cust-1',
        geolocate: () async => null,
        reverseGeocode: (_) async => null,
        defaultRatePerKgUgx: defaultRatePerKgUgx,
      ),
    );
  }

  /// A tall viewport so the whole form (incl. the required item-count field that
  /// now sits in the main column) fits without the lazy ListView disposing the
  /// Create button.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The item count is a required field now (the DB rejects item_count = 0), so
  /// every submit must set it first.
  Future<void> setCount(WidgetTester tester, int n) async {
    await tester.enterText(find.byKey(const Key('np_count_field')), '$n');
    await tester.pump();
  }

  testWidgets('shows the default rate when no customer is matched',
      (tester) async {
    await tester.pumpWidget(buildScreen(defaultRatePerKgUgx: 5000));
    expect(find.text('Rate: USh 5,000/kg'), findsOneWidget);
  });

  testWidgets('shows a different default rate value correctly', (tester) async {
    await tester.pumpWidget(buildScreen(defaultRatePerKgUgx: 8000));
    expect(find.text('Rate: USh 8,000/kg'), findsOneWidget);
  });

  testWidgets(
      'switches to customer custom rate when a customer with override is matched',
      (tester) async {
    when(() => customersRepo.getAll()).thenAnswer((_) async => [
          _customer(
            id: 'cust-custom',
            name: 'VIP Client',
            phone: '+256 700 111 222',
            address: 'Kololo, Kampala',
            customRatePerKgUgx: 4000,
          ),
        ]);

    await tester.pumpWidget(buildScreen(defaultRatePerKgUgx: 5000));

    // Default rate is shown before match
    expect(find.text('Rate: USh 5,000/kg'), findsOneWidget);

    // Type a matching phone and blur to trigger the match sheet
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.tap(find.byKey(const Key('np_name')));
    await tester.pumpAndSettle();

    // Match sheet appears — use the customer
    expect(find.text('Use this customer'), findsOneWidget);
    await tester.tap(find.text('Use this customer'));
    await tester.pumpAndSettle();

    // Rate should now show the customer's custom rate
    expect(find.text('Rate: USh 4,000/kg'), findsOneWidget);
    expect(find.text('Rate: USh 5,000/kg'), findsNothing);
  });

  testWidgets(
      'resets to default rate when phone is edited after a customer match',
      (tester) async {
    when(() => customersRepo.getAll()).thenAnswer((_) async => [
          _customer(
            id: 'cust-custom',
            name: 'VIP Client',
            phone: '+256 700 111 222',
            address: 'Kololo, Kampala',
            customRatePerKgUgx: 4000,
          ),
        ]);

    await tester.pumpWidget(buildScreen(defaultRatePerKgUgx: 5000));

    // Match a customer with a custom rate
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.tap(find.byKey(const Key('np_name')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this customer'));
    await tester.pumpAndSettle();
    expect(find.text('Rate: USh 4,000/kg'), findsOneWidget);

    // Edit the phone field — should reset rate to default
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 702 999 999');
    await tester.pump();
    expect(find.text('Rate: USh 5,000/kg'), findsOneWidget);
    expect(find.text('Rate: USh 4,000/kg'), findsNothing);
  });

  testWidgets('rate label live-updates as a custom rate is typed',
      (tester) async {
    // A tall viewport so the whole form (and the optional custom-rate field) is
    // visible without scroll gymnastics — matches the sibling tests and is
    // robust to the form's height changing as validation errors appear/clear.
    useTallViewport(tester);
    await tester.pumpWidget(buildScreen(defaultRatePerKgUgx: 5000));
    expect(find.text('Rate: USh 5,000/kg'), findsOneWidget);

    // Expand optional details and enter a custom rate.
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '4500');
    await tester.pump();

    expect(find.text('Rate: USh 4,500/kg'), findsOneWidget);
    expect(find.text('Rate: USh 5,000/kg'), findsNothing);
  });

  testWidgets(
      'snapshot uses the default rate for an order with no customer override',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildScreen(defaultRatePerKgUgx: 5000));

    await tester.enterText(find.byKey(const Key('np_name')), 'New Customer');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(find.byKey(const Key('np_address')), 'Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final captured = verify(() => ordersRepo.createPickup(
          captureAny(),
          any(),
          actorStaffId: any(named: 'actorStaffId'),
        )).captured.single as LaundryOrder;
    expect(captured.ratePerKgSnapshotUgx, 5000.0);
  });

  testWidgets('snapshot uses the customer custom rate when matched',
      (tester) async {
    when(() => customersRepo.getAll()).thenAnswer((_) async => [
          _customer(
            id: 'cust-custom-snap',
            name: 'VIP Client',
            phone: '+256 700 111 222',
            address: 'Kololo',
            customRatePerKgUgx: 4000,
          ),
        ]);

    useTallViewport(tester);
    await tester.pumpWidget(buildScreen(defaultRatePerKgUgx: 5000));

    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.tap(find.byKey(const Key('np_name')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this customer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final captured = verify(() => ordersRepo.createPickup(
          captureAny(),
          any(),
          actorStaffId: any(named: 'actorStaffId'),
        )).captured.single as LaundryOrder;
    expect(captured.ratePerKgSnapshotUgx, 4000.0);
  });
}
