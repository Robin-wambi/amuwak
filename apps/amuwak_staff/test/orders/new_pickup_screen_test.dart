import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/orders/geo_services.dart';
import 'package:amuwak_staff/src/orders/new_pickup_result.dart';
import 'package:amuwak_staff/src/orders/new_pickup_screen.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/customers_repository.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';

/// Online-only mode: NewPickupScreen takes [CustomersRepository] /
/// [OrdersRepository] (now Supabase-backed) via its constructor. These tests
/// mock those repos so they exercise the screen's UI behaviour without a
/// database — `getAll()` is stubbed for phone-match lookups, and writes are
/// verified by capturing the [Customer] / [LaundryOrder] passed to the repo
/// (replacing the old in-memory-Drift row inspection).
class _MockCustomersRepository extends Mock implements CustomersRepository {}

class _MockOrdersRepository extends Mock implements OrdersRepository {}

Customer _customer({
  required String id,
  required String name,
  required String phone,
  String? address,
}) => Customer(
  id: id,
  name: name,
  phone: phone,
  address: address,
  notes: null,
  createdAt: DateTime(2026, 5, 20, 9),
  updatedAt: DateTime(2026, 5, 20, 9),
  deletedAt: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_customer(id: 'fb', name: 'fb', phone: '0'));
    registerFallbackValue(
      const LaundryOrder(
        orderId: 'fb',
        customerName: 'fb',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: '',
        itemCount: 1,
        phone: '0',
        address: 'a',
        notes: '',
      ),
    );
  });

  late _MockCustomersRepository customersRepo;
  late _MockOrdersRepository ordersRepo;

  setUp(() {
    customersRepo = _MockCustomersRepository();
    ordersRepo = _MockOrdersRepository();
    // Default: no existing customers (phone-match lookup finds nothing) and
    // writes succeed.
    when(() => customersRepo.getAll()).thenAnswer((_) async => <Customer>[]);
    when(
      () => ordersRepo.createPickup(
        any(),
        any(),
        actorStaffId: any(named: 'actorStaffId'),
      ),
    ).thenAnswer(
      (_) async => (orderId: 'uuid-order-1', orderCode: 'AMW-2026-0001'),
    );
    // initState loads address suggestions from customers + orders.
    when(
      () => ordersRepo.getAll(),
    ).thenAnswer((_) async => const <LaundryOrder>[]);
  });

  /// Captures the (order, customer) passed to [OrdersRepository.createPickup] in
  /// a single verify. mocktail marks a call verified once captured, so two
  /// separate verifies of the same call would fail — capture both at once.
  ({LaundryOrder order, Customer customer}) capturedPickup() {
    final args = verify(
      () => ordersRepo.createPickup(
        captureAny(),
        captureAny(),
        actorStaffId: any(named: 'actorStaffId'),
      ),
    ).captured;
    return (order: args[0] as LaundryOrder, customer: args[1] as Customer);
  }

  /// Captures the [LaundryOrder] passed to [OrdersRepository.createPickup].
  LaundryOrder capturedOrder() =>
      verify(
            () => ordersRepo.createPickup(
              captureAny(),
              any(),
              actorStaffId: any(named: 'actorStaffId'),
            ),
          ).captured.single
          as LaundryOrder;

  Future<_FormHandle> pumpFormAndOpen(
    WidgetTester tester, {
    GeolocateFn? geolocate,
    ReverseGeocodeFn? reverseGeocode,
  }) async {
    // A tall viewport so the whole form (summary hint + any inline field errors
    // + the action row) fits without scrolling — otherwise the lazy ListView
    // disposes off-screen children and finders/taps on the buttons fail.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final handle = _FormHandle();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  handle.popped = await Navigator.of(context)
                      .push<NewPickupResult>(
                        MaterialPageRoute(
                          builder: (_) => NewPickupScreen(
                            customersRepo: customersRepo,
                            ordersRepo: ordersRepo,
                            actorStaffId: 'staff-1',
                            clock: () => DateTime(2026, 5, 25, 10),
                            orderIdGenerator: () => 'uuid-order-1',
                            customerIdGenerator: () => 'uuid-cust-1',
                            geolocate: geolocate ?? () async => null,
                            reverseGeocode: reverseGeocode ?? (_) async => null,
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

  /// The item count is now a required field (the DB rejects item_count = 0), so
  /// every happy-path submit must set it before Create enables. Types the value
  /// straight into the always-visible count box.
  Future<void> setCount(WidgetTester tester, int n) async {
    await tester.enterText(find.byKey(const Key('np_count_field')), '$n');
    await tester.pump();
  }

  testWidgets(
    'scheduling: quick chips and the custom date/time picker set a pickup time',
    (tester) async {
      await pumpFormAndOpen(tester);

      // Switch to scheduled mode → the quick chips appear.
      await tester.tap(find.text('Schedule for later'));
      await tester.pumpAndSettle();

      // Each quick chip sets a concrete schedule (the "Scheduled for:" label).
      await tester.tap(find.text('In 1 hour'));
      await tester.pump();
      expect(find.textContaining('Scheduled for:'), findsOneWidget);
      await tester.tap(find.text('Tomorrow morning'));
      await tester.pump();
      await tester.tap(find.text('Tomorrow afternoon'));
      await tester.pump();
      expect(find.textContaining('Scheduled for:'), findsOneWidget);

      // Custom… opens the date then the time picker; confirming both (the
      // clock is 10:00, so the default 10:00 today is not in the past) sets it.
      await tester.tap(find.text('Custom…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // confirm date
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // confirm time
      await tester.pumpAndSettle();
      expect(find.textContaining('Scheduled for:'), findsOneWidget);

      // Switching back to "Pickup now" clears the schedule.
      await tester.tap(find.text('Pickup now'));
      await tester.pump();
      expect(find.textContaining('Scheduled for:'), findsNothing);
    },
  );

  testWidgets('Create button is disabled until required fields are valid', (
    tester,
  ) async {
    await pumpFormAndOpen(tester);
    final create = find.widgetWithText(ElevatedButton, 'Create pickup');
    expect(tester.widget<ElevatedButton>(create).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(
      find.byKey(const Key('np_address')),
      'Kikoni, Kampala',
    );
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    expect(tester.widget<ElevatedButton>(create).onPressed, isNotNull);
  });

  testWidgets('Create stays disabled until item count is at least 1', (
    tester,
  ) async {
    await pumpFormAndOpen(tester);
    final create = find.widgetWithText(ElevatedButton, 'Create pickup');

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(
      find.byKey(const Key('np_address')),
      'Kikoni, Kampala',
    );
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();

    // Everything else is valid, but the item count is still 0 → Create stays
    // disabled and the "Still needed" hint names it. (The DB rejects an order
    // with item_count = 0, so the form must not let one through.)
    expect(tester.widget<ElevatedButton>(create).onPressed, isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('np_missing_hint'))).data!,
      contains('Number of items'),
    );

    // Stepping the count up to 1 satisfies the last requirement.
    await tester.tap(find.byKey(const Key('np_count_inc')));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(create).onPressed, isNotNull);
    expect(find.byKey(const Key('np_missing_hint')), findsNothing);
  });

  testWidgets('the item count box flags 0 only after the rider touches it', (
    tester,
  ) async {
    await pumpFormAndOpen(tester);

    // A freshly opened form does not pre-flag the count box — no red on a form
    // the rider hasn't interacted with yet.
    expect(find.text('Add at least 1 item'), findsNothing);

    // Interact and land back on 0: now the requirement is flagged.
    await tester.tap(find.byKey(const Key('np_count_inc')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('np_count_dec')));
    await tester.pump();
    expect(find.text('Add at least 1 item'), findsOneWidget);

    // Clears again once there is at least one item.
    await tester.tap(find.byKey(const Key('np_count_inc')));
    await tester.pump();
    expect(find.text('Add at least 1 item'), findsNothing);
  });

  testWidgets('required field errors stay hidden until the rider interacts', (
    tester,
  ) async {
    await pumpFormAndOpen(tester);

    // onUserInteraction: a fresh form shows no red errors — the rider isn't
    // greeted by a wall of "internal errors" before typing anything. The bottom
    // "Still needed" hint (tested separately) names what's outstanding instead.
    expect(find.text("Enter the customer's name"), findsNothing);
    expect(find.text('Enter the 9-digit number after +256'), findsNothing);
    expect(find.text('Enter or detect the pickup address'), findsNothing);
    expect(find.text('Choose a service type'), findsNothing);

    // Touching the name field and leaving it empty surfaces its error.
    await tester.enterText(find.byKey(const Key('np_name')), 'x');
    await tester.enterText(find.byKey(const Key('np_name')), '');
    await tester.pump();
    expect(find.text("Enter the customer's name"), findsOneWidget);
  });

  testWidgets(
    'while Create is disabled, a hint names the required fields still missing',
    (tester) async {
      await pumpFormAndOpen(tester);
      final hint = find.byKey(const Key('np_missing_hint'));

      // Nothing filled yet: every required field is listed so a greyed-out
      // Create button is never a silent dead-end.
      expect(hint, findsOneWidget);
      final initial = tester.widget<Text>(hint).data!;
      expect(initial, contains('Customer name'));
      expect(initial, contains('Phone'));
      expect(initial, contains('Address'));
      expect(initial, contains('Service type'));
      expect(initial, contains('Number of items'));

      // Fill everything except the service type and item count — those remain.
      await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
      await tester.enterText(
        find.byKey(const Key('np_phone')),
        '+256 700 111 222',
      );
      await tester.enterText(
        find.byKey(const Key('np_address')),
        'Kikoni, Kampala',
      );
      await tester.pump();
      final partial = tester.widget<Text>(hint).data!;
      expect(partial, isNot(contains('Customer name')));
      expect(partial, isNot(contains('Address')));
      expect(partial, contains('Service type'));
      expect(partial, contains('Number of items'));

      // Pick the service type and set a count: the hint disappears and Create
      // enables.
      await tester.tap(find.byKey(const Key('np_service_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceType.washAndIron.label).last);
      await tester.pumpAndSettle();
      await setCount(tester, 3);
      expect(find.byKey(const Key('np_missing_hint')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Create pickup'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'phone field shows an inline error until it holds 9 national digits',
    (tester) async {
      await pumpFormAndOpen(tester);
      const message = 'Enter the 9-digit number after +256';

      // onUserInteraction: not flagged up front, before the rider edits it.
      expect(find.text(message), findsNothing);

      // Once edited and still too short, the error appears.
      await tester.enterText(find.byKey(const Key('np_phone')), '+256 700');
      await tester.pump();
      expect(find.text(message), findsOneWidget);

      // Completing the number clears it.
      await tester.enterText(
        find.byKey(const Key('np_phone')),
        '+256 700111222',
      );
      await tester.pump();
      expect(find.text(message), findsNothing);
    },
  );

  testWidgets(
    'Create stays disabled when the phone has fewer than 9 digits even '
    'though the formatted text is 9+ characters',
    (tester) async {
      await pumpFormAndOpen(tester);

      await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
      // '+256 1234' is 9 raw characters but only 7 digits — a raw-length check
      // would wrongly enable Create; a digit-count check must keep it disabled.
      await tester.enterText(find.byKey(const Key('np_phone')), '+256 1234');
      await tester.enterText(
        find.byKey(const Key('np_address')),
        'Kikoni, Kampala',
      );
      await tester.tap(find.byKey(const Key('np_service_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceType.washAndIron.label).last);
      await tester.pumpAndSettle();

      final create = find.widgetWithText(ElevatedButton, 'Create pickup');
      expect(tester.widget<ElevatedButton>(create).onPressed, isNull);
    },
  );

  testWidgets('phone field caps the national number at 9 digits (blocks the '
      '10th)', (tester) async {
    await pumpFormAndOpen(tester);
    final phone = find.byKey(const Key('np_phone'));

    // A full 9-digit national number is accepted.
    await tester.enterText(phone, '+256 700123456');
    await tester.pump();
    expect(
      ugandaNationalDigits(
        tester.widget<TextFormField>(phone).controller!.text,
      ).length,
      9,
    );

    // Attempting a 10th national digit is rejected — the field stays at 9.
    await tester.enterText(phone, '+256 7001234567');
    await tester.pump();
    expect(
      ugandaNationalDigits(
        tester.widget<TextFormField>(phone).controller!.text,
      ).length,
      9,
    );
  });

  testWidgets('Submit happy path writes customer + order, pops with '
      'startPickupNow=true (default schedule)', (tester) async {
    final handle = await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(
      find.byKey(const Key('np_address')),
      'Kikoni, Kampala',
    );
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    expect(handle.popped, isNotNull);
    expect(handle.popped!.orderId, 'uuid-order-1');
    expect(handle.popped!.startPickupNow, isTrue);

    final pickup = capturedPickup();
    final customer = pickup.customer;
    expect(customer.id, 'uuid-cust-1');
    expect(customer.name, 'Jane Doe');

    final order = pickup.order;
    expect(order.orderId, 'uuid-order-1');
    expect(order.customerId, 'uuid-cust-1');
    expect(order.customerName, 'Jane Doe');
    expect(order.serviceType, ServiceType.washAndIron);
    expect(order.status, OrderStatus.pendingPickup);
    expect(order.scheduledFor, isNull);
  });

  testWidgets(
    'a failed create_pickup surfaces a friendly error and pops nothing; '
    'a retry then succeeds',
    (tester) async {
      var calls = 0;
      when(
        () => ordersRepo.createPickup(
          any(),
          any(),
          actorStaffId: any(named: 'actorStaffId'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw Exception(
            'PostgrestException(message: could not connect to server, '
            'code: 08006, details: network)',
          );
        }
        return (orderId: 'uuid-order-1', orderCode: 'AMW-2026-0042');
      });

      final handle = await pumpFormAndOpen(tester);

      await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
      await tester.enterText(
        find.byKey(const Key('np_phone')),
        '+256 700 111 222',
      );
      await tester.enterText(
        find.byKey(const Key('np_address')),
        'Kikoni, Kampala',
      );
      await tester.tap(find.byKey(const Key('np_service_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceType.washAndIron.label).last);
      await tester.pumpAndSettle();
      await setCount(tester, 3);

      // First attempt: the RPC throws. The form stays open with an error.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
      await tester.pump();
      expect(find.textContaining('Could not save the pickup'), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(handle.popped, isNull);

      // Second attempt: the RPC succeeds and the form pops. The cached
      // customer/order ids make the retry idempotent server-side.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
      await tester.pumpAndSettle();
      expect(handle.popped, isNotNull);
      expect(calls, 2);
    },
  );

  testWidgets(
    'a failed create_pickup shows friendly copy, not raw Postgres details',
    (tester) async {
      when(
        () => ordersRepo.createPickup(
          any(),
          any(),
          actorStaffId: any(named: 'actorStaffId'),
        ),
      ).thenThrow(
        Exception(
          'PostgrestException(message: new row violates row-level security '
          'policy for table "orders", code: 42501, details: hidden)',
        ),
      );
      final handle = await pumpFormAndOpen(tester);

      await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
      await tester.enterText(
        find.byKey(const Key('np_phone')),
        '+256 700 111 222',
      );
      await tester.enterText(
        find.byKey(const Key('np_address')),
        'Kikoni, Kampala',
      );
      await tester.tap(find.byKey(const Key('np_service_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceType.washAndIron.label).last);
      await tester.pumpAndSettle();
      await setCount(tester, 3);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
      await tester.pump();

      // The rider sees actionable copy, while raw Postgres/Supabase details
      // stay in developer logs. (Offline-first: createPickup throws only on a
      // local write failure; a server-side RLS/validation rejection of the
      // queued create_pickup RPC surfaces asynchronously via the sync-status UX,
      // not on this screen.)
      expect(
        find.textContaining('Could not save the pickup on this device.'),
        findsOneWidget,
      );
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);
      expect(find.textContaining('row-level security'), findsNothing);
      expect(handle.popped, isNull);
    },
  );

  testWidgets('Cancel returns null and writes nothing', (tester) async {
    final handle = await pumpFormAndOpen(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(handle.popped, isNull);
    verifyNever(
      () => ordersRepo.createPickup(
        any(),
        any(),
        actorStaffId: any(named: 'actorStaffId'),
      ),
    );
  });

  testWidgets('Phone-on-blur with a matching customer shows the bottom sheet; '
      'tapping "Use this customer" pre-fills name + address', (tester) async {
    when(() => customersRepo.getAll()).thenAnswer(
      (_) async => [
        _customer(
          id: 'existing-cust-1',
          name: 'Jane Existing',
          phone: '+256 700 111 222',
          address: 'Old address, Kampala',
        ),
      ],
    );
    await pumpFormAndOpen(tester);

    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.tap(find.byKey(const Key('np_name')));
    await tester.pumpAndSettle();

    expect(find.text('Use this customer'), findsOneWidget);
    expect(find.text('Jane Existing'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Use this customer'));
    await tester.pumpAndSettle();

    expect(
      (tester.widget<TextFormField>(
        find.byKey(const Key('np_name')),
      )).controller!.text,
      'Jane Existing',
    );
    expect(
      (tester.widget<TextFormField>(
        find.byKey(const Key('np_address')),
      )).controller!.text,
      'Old address, Kampala',
    );
  });

  testWidgets('Submit with a matched existing customer reuses customer id', (
    tester,
  ) async {
    when(() => customersRepo.getAll()).thenAnswer(
      (_) async => [
        _customer(
          id: 'existing-cust-2',
          name: 'Bob Returning',
          phone: '+256 701 222 333',
          address: 'Wandegeya',
        ),
      ],
    );
    await pumpFormAndOpen(tester);

    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 701 222 333',
    );
    await tester.tap(find.byKey(const Key('np_name')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.dryCleaning.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final pickup = capturedPickup();
    expect(pickup.customer.id, 'existing-cust-2');
    expect(pickup.order.customerId, 'existing-cust-2');
  });

  testWidgets(
    'Editing the phone field after accepting a customer match drops the '
    'cached customer id so submit creates a fresh customer row',
    (tester) async {
      when(() => customersRepo.getAll()).thenAnswer(
        (_) async => [
          _customer(
            id: 'existing-cust-edited',
            name: 'Carol Original',
            phone: '+256 702 333 444',
            address: 'Original address',
          ),
        ],
      );
      await pumpFormAndOpen(tester);

      await tester.enterText(
        find.byKey(const Key('np_phone')),
        '+256 702 333 444',
      );
      await tester.tap(find.byKey(const Key('np_name')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this customer'));
      await tester.pumpAndSettle();
      // Rider realises the wrong customer was matched and edits the phone.
      await tester.enterText(
        find.byKey(const Key('np_phone')),
        '+256 702 999 999',
      );
      await tester.tap(find.byKey(const Key('np_service_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceType.washAndIron.label).last);
      await tester.pumpAndSettle();
      await setCount(tester, 3);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
      await tester.pumpAndSettle();

      // Cached match id was dropped → a fresh customer id is used, and the order
      // points at the new row (NOT the originally matched 'existing-cust-edited').
      final pickup = capturedPickup();
      expect(pickup.customer.id, 'uuid-cust-1');
      expect(pickup.customer.id, isNot('existing-cust-edited'));
      expect(pickup.order.customerId, 'uuid-cust-1');
    },
  );

  testWidgets(
    'Use my location chip fills address from stubbed reverseGeocode',
    (tester) async {
      final handle = await pumpFormAndOpen(
        tester,
        geolocate: () async =>
            const GeoLocation(latitude: 0.3163, longitude: 32.5822),
        reverseGeocode: (_) async => 'Detected address, Kampala',
      );

      await tester.tap(find.widgetWithText(ActionChip, 'Use my location'));
      await tester.pumpAndSettle();

      expect(
        (tester.widget<TextFormField>(
          find.byKey(const Key('np_address')),
        )).controller!.text,
        'Detected address, Kampala',
      );
      expect(handle.popped, isNull);
    },
  );

  testWidgets(
    'Use my location chip shows a SnackBar when geolocation is unavailable '
    '(permission denied / GPS off) and leaves the address blank',
    (tester) async {
      // geolocate returns null — no fix available.
      await pumpFormAndOpen(tester, geolocate: () async => null);

      await tester.tap(find.widgetWithText(ActionChip, 'Use my location'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't get your location"), findsOneWidget);
      expect(
        (tester.widget<TextFormField>(
          find.byKey(const Key('np_address')),
        )).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'Use my location chip shows a SnackBar when reverseGeocode returns '
    'null after a successful geolocate, and leaves the address blank',
    (tester) async {
      await pumpFormAndOpen(
        tester,
        geolocate: () async =>
            const GeoLocation(latitude: 0.3163, longitude: 32.5822),
        reverseGeocode: (_) async => null,
      );

      await tester.tap(find.widgetWithText(ActionChip, 'Use my location'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not determine address — please type it manually.'),
        findsOneWidget,
      );
      expect(
        (tester.widget<TextFormField>(
          find.byKey(const Key('np_address')),
        )).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('Schedule for later → Tomorrow morning sets scheduledFor to '
      '9 AM next day and pops with startPickupNow=false', (tester) async {
    final handle = await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(find.byKey(const Key('np_address')), 'Kikoni');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.tap(find.text('Schedule for later'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow morning'));
    await tester.pumpAndSettle();

    final tomorrowMorningChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Tomorrow morning'),
    );
    expect(tomorrowMorningChip.selected, isTrue);
    final inOneHourChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'In 1 hour'),
    );
    expect(inOneHourChip.selected, isFalse);
    expect(find.text('Scheduled for: Tomorrow, 9:00 AM'), findsOneWidget);

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    expect(handle.popped, isNotNull);
    expect(handle.popped!.startPickupNow, isFalse);
    expect(capturedOrder().scheduledFor, DateTime(2026, 5, 26, 9));
  });

  testWidgets('Schedule for later with no time chosen keeps Create disabled '
      'until a time is picked', (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(find.byKey(const Key('np_address')), 'Kikoni');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    // All required fields filled — in "Pickup now" mode Create is enabled.
    final create = find.widgetWithText(ElevatedButton, 'Create pickup');
    expect(tester.widget<ElevatedButton>(create).onPressed, isNotNull);

    // Switching to "Schedule for later" without choosing a time must disable
    // Create — otherwise the order silently submits as an immediate pickup.
    await tester.tap(find.text('Schedule for later'));
    await tester.pumpAndSettle();
    // The schedule controls grow the form; bring Create back into view (the
    // lazy ListView disposes off-screen children) before reading its state.
    await tester.dragUntilVisible(
      create,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(create).onPressed, isNull);

    // Choosing a time re-enables it — scroll the chip back into view to tap it.
    await tester.dragUntilVisible(
      find.widgetWithText(ChoiceChip, 'Tomorrow morning'),
      find.byType(ListView),
      const Offset(0, 200),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow morning'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      create,
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(tester.widget<ElevatedButton>(create).onPressed, isNotNull);
  });

  testWidgets('item-count stepper sets the count; notes (optional) are '
      'persisted in the order row', (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(find.byKey(const Key('np_address')), 'Kikoni');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();

    // The count is a main field now — step it up before reaching the optional
    // section (notes still live under "Add optional details").
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('np_count_inc')));
      await tester.pump();
    }
    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('np_notes')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(
      find.byKey(const Key('np_notes')),
      'Gate locked after 6',
    );

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final order = capturedOrder();
    expect(order.itemCount, 4);
    expect(order.notes, 'Gate locked after 6');
  });

  testWidgets('Item count: stepper caps at 99', (tester) async {
    await pumpFormAndOpen(tester);

    // Tap well past the cap; the count must not exceed 99 (no four-digit counts).
    for (var i = 0; i < 105; i++) {
      await tester.tap(find.byKey(const Key('np_count_inc')));
      await tester.pump();
    }

    expect(find.text('99'), findsOneWidget);
    expect(find.text('100'), findsNothing);
    final incButton = tester.widget<IconButton>(
      find.byKey(const Key('np_count_inc')),
    );
    expect(
      incButton.onPressed,
      isNull,
      reason: 'increment is disabled once the cap is reached',
    );
  });

  testWidgets('Item count: the count is labelled and carries its unit', (
    tester,
  ) async {
    await pumpFormAndOpen(tester);

    // The count is a main required field now (not under "Add optional details"),
    // so it is visible immediately with its label and unit.
    expect(find.text('Number of items'), findsOneWidget);
    expect(find.byKey(const Key('np_count_field')), findsOneWidget);
    expect(find.text('items'), findsOneWidget);
  });

  testWidgets('Item count: typing a count sets itemCount (tap-to-edit)', (
    tester,
  ) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(find.byKey(const Key('np_address')), 'Kikoni');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();

    // Type the count directly instead of tapping + thirty times.
    await tester.enterText(find.byKey(const Key('np_count_field')), '30');
    await tester.pump();

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    expect(capturedOrder().itemCount, 30);
  });

  testWidgets('Item count: a typed count over 99 is clamped to 99', (
    tester,
  ) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(find.byKey(const Key('np_address')), 'Kikoni');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('np_count_field')), '150');
    await tester.pump();

    // The field self-corrects to the cap and the persisted count never exceeds it.
    expect(find.text('99'), findsOneWidget);
    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    expect(capturedOrder().itemCount, 99);
  });

  testWidgets('Create pickup shows a spinner while the submit is in flight', (
    tester,
  ) async {
    // Gate the create_pickup RPC so the submit stays in flight while we assert,
    // then release it to let the form finish.
    final gate = Completer<({String orderId, String orderCode})>();
    when(
      () => ordersRepo.createPickup(
        any(),
        any(),
        actorStaffId: any(named: 'actorStaffId'),
      ),
    ).thenAnswer((_) => gate.future);
    final handle = await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
      find.byKey(const Key('np_phone')),
      '+256 700 111 222',
    );
    await tester.enterText(
      find.byKey(const Key('np_address')),
      'Kikoni, Kampala',
    );
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pump(); // kick off the async submit; _saving is now true

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Create pickup'), findsNothing);

    // Let the submit complete so the widget isn't torn down mid-flight.
    gate.complete((orderId: 'uuid-order-1', orderCode: 'AMW-2026-0001'));
    await tester.pumpAndSettle();
    expect(handle.popped, isNotNull);
  });

  group('Address auto-suggest', () {
    testWidgets('suggests a previously-used address and fills it on tap', (
      tester,
    ) async {
      when(() => customersRepo.getAll()).thenAnswer(
        (_) async => [
          _customer(
            id: 'c1',
            name: 'Ann',
            phone: '+256 700 000 001',
            address: 'Kololo, Kampala',
          ),
        ],
      );
      await pumpFormAndOpen(tester);
      await tester.pumpAndSettle(); // let the initState suggestion load finish

      await tester.enterText(find.byKey(const Key('np_address')), 'kol');
      await tester.pumpAndSettle();

      // The matching previous address is offered in the overlay.
      expect(find.text('Kololo, Kampala'), findsOneWidget);

      await tester.tap(find.text('Kololo, Kampala'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('np_address')))
            .controller!
            .text,
        'Kololo, Kampala',
      );
    });

    testWidgets('orders suggestions by how commonly the address is used', (
      tester,
    ) async {
      when(() => customersRepo.getAll()).thenAnswer(
        (_) async => [
          _customer(
            id: 'a',
            name: 'A',
            phone: '+256 700 000 001',
            address: 'Plot 1, Kampala',
          ),
          _customer(
            id: 'b',
            name: 'B',
            phone: '+256 700 000 002',
            address: 'Plot 2, Kampala',
          ),
          _customer(
            id: 'c',
            name: 'C',
            phone: '+256 700 000 003',
            address: 'Plot 2, Kampala',
          ),
        ],
      );
      await pumpFormAndOpen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('np_address')), 'kampala');
      await tester.pumpAndSettle();

      // "Plot 2, Kampala" (used twice) ranks above "Plot 1, Kampala" (used once).
      expect(
        tester.getTopLeft(find.text('Plot 2, Kampala')).dy <
            tester.getTopLeft(find.text('Plot 1, Kampala')).dy,
        isTrue,
      );
    });

    testWidgets(
      'includes addresses from past orders and ranks by combined use',
      (tester) async {
        when(() => customersRepo.getAll()).thenAnswer(
          (_) async => [
            _customer(
              id: 'c1',
              name: 'Ann',
              phone: '+256 700 000 001',
              address: 'Bugolobi, Kampala',
            ),
          ],
        );
        LaundryOrder order(String id, String address) => LaundryOrder(
          orderId: id,
          customerName: 'X',
          serviceType: ServiceType.washAndIron,
          status: OrderStatus.pendingPickup,
          timeLabel: '',
          itemCount: 0,
          phone: '0',
          address: address,
          notes: '',
        );
        when(() => ordersRepo.getAll()).thenAnswer(
          (_) async => [
            order('o1', 'Ntinda, Kampala'),
            order('o2', 'Ntinda, Kampala'),
          ],
        );
        await pumpFormAndOpen(tester);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('np_address')), 'kampala');
        await tester.pumpAndSettle();

        // The order-only address is offered, and (used twice across orders) it
        // ranks above the customer address that was used only once.
        expect(find.text('Ntinda, Kampala'), findsOneWidget);
        expect(find.text('Bugolobi, Kampala'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Ntinda, Kampala')).dy <
              tester.getTopLeft(find.text('Bugolobi, Kampala')).dy,
          isTrue,
        );
      },
    );

    testWidgets('shows no suggestion when nothing matches', (tester) async {
      when(() => customersRepo.getAll()).thenAnswer(
        (_) async => [
          _customer(
            id: 'c1',
            name: 'Ann',
            phone: '+256 700 000 001',
            address: 'Kololo, Kampala',
          ),
        ],
      );
      await pumpFormAndOpen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('np_address')), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Kololo, Kampala'), findsNothing);
    });
  });

  group('scheduledTimeIsInPast', () {
    final now = DateTime(2026, 5, 25, 14, 30, 45);

    test('a time earlier today is in the past', () {
      expect(scheduledTimeIsInPast(DateTime(2026, 5, 25, 14, 0), now), isTrue);
    });

    test('a time one minute earlier is in the past', () {
      expect(scheduledTimeIsInPast(DateTime(2026, 5, 25, 14, 29), now), isTrue);
    });

    test(
      'the current minute is NOT in the past (now\'s seconds are ignored)',
      () {
        // The time picker yields 14:30:00 for "this minute"; comparing against
        // now=14:30:45 at second precision would wrongly reject it.
        expect(
          scheduledTimeIsInPast(DateTime(2026, 5, 25, 14, 30), now),
          isFalse,
        );
      },
    );

    test('a future time is not in the past', () {
      expect(scheduledTimeIsInPast(DateTime(2026, 5, 25, 15, 0), now), isFalse);
    });
  });
}

/// Mutable holder so tests can read the value the form pops with AFTER the
/// pop has actually happened (i.e. after Cancel or Create pickup).
class _FormHandle {
  NewPickupResult? popped;
}
