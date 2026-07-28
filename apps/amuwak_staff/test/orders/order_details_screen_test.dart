import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_details_screen.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';

import '../helpers/fake_camera_view.dart';

/// Online-only mode: OrderDetailsScreen takes Supabase-backed repos via its
/// constructor. These tests mock them — the screen only *reads* from the
/// in-memory [LaundryOrder] passed in (no stream subscriptions), and the one
/// status-advance path is verified by capturing the [OrdersRepository.updateStatus]
/// call (replacing the old Drift row + outbox inspection).
class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockProofEventsRepository extends Mock
    implements ProofEventsRepository {}

const _pendingPickup = LaundryOrder(
  orderId: 'AMW-0421',
  customerName: 'Jane',
  serviceType: ServiceType.washOnly,
  status: OrderStatus.pendingPickup,
  timeLabel: 't',
  itemCount: 12,
  phone: 'p',
  address: 'a',
  notes: '',
);

Widget _wrap(
  LaundryOrder order, {
  required InMemoryProofPhotoStorage storage,
  String scannedValue = 'AMW-0421',
  Future<List<int>?> Function()? pickPhoto,
  OrdersRepository? ordersRepo,
  ProofEventsRepository? proofEventsRepo,
  String actorStaffId = 's-test',
}) {
  return MaterialApp(
    theme: buildAmuwakTheme(),
    home: OrderDetailsScreen(
      order: order,
      photoStorage: storage,
      pickPhoto: pickPhoto ?? () async => const [1, 2, 3],
      cameraViewBuilder: (context, onDetected) {
        return FakeCameraView(
          scannedValue: scannedValue,
          onDetected: onDetected,
        );
      },
      clock: () => DateTime(2026, 5, 12, 9, 42),
      ordersRepo: ordersRepo ?? _MockOrdersRepository(),
      proofEventsRepo: proofEventsRepo ?? _MockProofEventsRepository(),
      actorStaffId: actorStaffId,
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(OrderStatus.pendingPickup));

  testWidgets(
      'pendingPickup shows "Confirm pickup" and routes to PickupCaptureScreen',
      (tester) async {
    final storage = InMemoryProofPhotoStorage();
    await tester.pumpWidget(_wrap(_pendingPickup, storage: storage));

    expect(
      find.widgetWithText(ElevatedButton, 'Confirm pickup'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm pickup'));
    await tester.pumpAndSettle();

    expect(find.text('How many items?'), findsOneWidget);
  });

  testWidgets(
      'readyForDelivery shows "Deliver" and routes through scanner to delivery',
      (tester) async {
    final storage = InMemoryProofPhotoStorage();
    // A synced (coded) order — orderCode differs from the UUID orderId — so it
    // routes through the scan path (the uncoded fallback is covered below).
    final readyOrder = _pendingPickup.copyWith(
      orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
      orderCode: 'AMW-2026-0042',
      status: OrderStatus.readyForDelivery,
      proofEvents: [
        ProofEvent(
          id: 'pe-test-1',
          type: ProofEventType.pickup,
          capturedAt: DateTime(2026, 5, 12, 9, 42),
          count: 12,
          photoPaths: const ['memory://AMW-2026-0042/pickup_0'],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(readyOrder, storage: storage, scannedValue: 'AMW-2026-0042'));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Deliver'));
    await tester.pumpAndSettle();

    expect(find.text('Scan order tag'), findsOneWidget);

    await tester.tap(find.text('Simulate scan'));
    await tester.pumpAndSettle();

    expect(find.text('Hand over'), findsOneWidget);
  });

  testWidgets(
      'a still-uncoded order confirms delivery by customer name instead of '
      'scanning a tag that was never printed', (tester) async {
    final storage = InMemoryProofPhotoStorage();
    // Placeholder: orderCode falls back to the UUID orderId (hasServerCode
    // false). No tag was ever printed (pickup gated that) and the UUID is never
    // shown, so there is nothing to scan — fall back to a name confirmation.
    final uncoded = LaundryOrder(
      orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
      customerName: 'Jane',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.readyForDelivery,
      timeLabel: 't',
      itemCount: 12,
      phone: 'p',
      address: 'a',
      notes: '',
      proofEvents: [
        ProofEvent(
          id: 'pe-test-1',
          type: ProofEventType.pickup,
          capturedAt: DateTime(2026, 5, 12, 9, 42),
          count: 12,
          photoPaths: const ['memory://placeholder/pickup_0'],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(uncoded, storage: storage));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Deliver'));
    await tester.pumpAndSettle();

    // No scan step — a customer-name confirmation dialog instead.
    expect(find.text('Scan order tag'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Jane'), findsWidgets);
    expect(find.textContaining('019e9147'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Confirm delivery'));
    await tester.pumpAndSettle();

    expect(find.text('Hand over'), findsOneWidget);
  });

  testWidgets(
      'order details shows the human order code, never the UUID order id',
      (tester) async {
    final storage = InMemoryProofPhotoStorage();
    // Distinct orderId (UUID) and orderCode so the screen can't pass by the two
    // being accidentally equal (as in the shared _pendingPickup fixture).
    final coded = _pendingPickup.copyWith(
      orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
      orderCode: 'AMW-2026-0042',
    );

    await tester.pumpWidget(_wrap(coded, storage: storage));

    // The short code is shown (header + the "Order code" detail row)...
    expect(find.textContaining('AMW-2026-0042'), findsWidgets);
    // ...and the long UUID is never put in front of the rider.
    expect(
      find.textContaining('019e9147-608b-72b7-9e2c-0baa04e85094'),
      findsNothing,
    );
  });

  testWidgets(
      'a placeholder order (no server code yet) shows "Pending sync", not the '
      'raw UUID', (tester) async {
    final storage = InMemoryProofPhotoStorage();
    // Offline order: orderCode is left unset so it falls back to the UUID
    // orderId (hasServerCode false). The header + "Order code" row must not
    // leak that UUID.
    const placeholder = LaundryOrder(
      orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
      customerName: 'Jane',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 12,
      phone: 'p',
      address: 'a',
      notes: '',
    );

    await tester.pumpWidget(_wrap(placeholder, storage: storage));

    expect(find.textContaining('Pending sync'), findsWidgets);
    expect(
      find.textContaining('019e9147-608b-72b7-9e2c-0baa04e85094'),
      findsNothing,
    );
  });

  testWidgets(
      'Deliver verification matches the human order code, not the UUID order id',
      (tester) async {
    final storage = InMemoryProofPhotoStorage();
    // orderId is the internal UUID; the bag tag the rider scans carries the
    // short order CODE. These MUST differ so the scan can only succeed if the
    // screen verifies against orderCode (not orderId).
    final coded = _pendingPickup.copyWith(
      orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
      orderCode: 'AMW-2026-0042',
      status: OrderStatus.readyForDelivery,
      proofEvents: [
        ProofEvent(
          id: 'pe-test-1',
          type: ProofEventType.pickup,
          capturedAt: DateTime(2026, 5, 12, 9, 42),
          count: 12,
          photoPaths: const ['memory://AMW-2026-0042/pickup_0'],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(
      coded,
      storage: storage,
      scannedValue: 'AMW-2026-0042',
    ));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Deliver'));
    await tester.pumpAndSettle();
    expect(find.text('Scan order tag'), findsOneWidget);

    await tester.tap(find.text('Simulate scan'));
    await tester.pumpAndSettle();

    // Scanning the order code satisfied verification and advanced to delivery.
    expect(find.text('Hand over'), findsOneWidget);
  });

  testWidgets(
      'inProgress advances status by writing through OrdersRepository.updateStatus',
      (tester) async {
    final ordersRepo = _MockOrdersRepository();
    when(() => ordersRepo.updateStatus(
          'AMW-0421',
          OrderStatus.readyForDelivery,
          actorStaffId: any(named: 'actorStaffId'),
        )).thenAnswer((_) async {});

    final storage = InMemoryProofPhotoStorage();
    final inProgress = _pendingPickup.copyWith(status: OrderStatus.inProgress);

    await tester.pumpWidget(_wrap(
      inProgress,
      storage: storage,
      ordersRepo: ordersRepo,
    ));

    expect(
      find.widgetWithText(ElevatedButton, 'Move to Ready for delivery'),
      findsOneWidget,
    );

    await tester
        .tap(find.widgetWithText(ElevatedButton, 'Move to Ready for delivery'));
    await tester.pumpAndSettle();

    // The screen advanced inProgress → readyForDelivery through the repo.
    verify(() => ordersRepo.updateStatus(
          'AMW-0421',
          OrderStatus.readyForDelivery,
          actorStaffId: 's-test',
        )).called(1);
  });

  testWidgets(
      'completed order shows a disabled action that cannot update status',
      (tester) async {
    final ordersRepo = _MockOrdersRepository();
    final storage = InMemoryProofPhotoStorage();
    final completed = _pendingPickup.copyWith(status: OrderStatus.completed);

    await tester.pumpWidget(_wrap(
      completed,
      storage: storage,
      ordersRepo: ordersRepo,
    ));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Order completed'),
    );
    // R4: a completed order's primary action is disabled (no onPressed).
    expect(button.enabled, isFalse);

    // Tapping the disabled action must not push the order any further.
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Order completed'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    verifyNever(() => ordersRepo.updateStatus(any(), any(),
        actorStaffId: any(named: 'actorStaffId')));
  });

  testWidgets('order with proofEvents renders a History panel', (tester) async {
    final storage = InMemoryProofPhotoStorage();
    final delivered = _pendingPickup.copyWith(
      status: OrderStatus.completed,
      proofEvents: [
        ProofEvent(
          id: 'pe-test-1',
          type: ProofEventType.pickup,
          capturedAt: DateTime(2026, 5, 12, 9, 42),
          count: 12,
          photoPaths: const ['memory://AMW-0421/pickup_0'],
        ),
        ProofEvent(
          id: 'pe-test-2',
          type: ProofEventType.delivery,
          capturedAt: DateTime(2026, 5, 12, 16, 13),
          count: 12,
          photoPaths: const ['memory://AMW-0421/delivery_0'],
        ),
      ],
    );

    await tester.pumpWidget(_wrap(delivered, storage: storage));

    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('Pickup'), findsWidgets);
    expect(find.textContaining('Delivery'), findsWidgets);
  });

  testWidgets(
    'History row for same-day event shows only HH:mm — no date',
    (tester) async {
      final storage = InMemoryProofPhotoStorage();
      final sameDay = _pendingPickup.copyWith(
        status: OrderStatus.completed,
        proofEvents: [
          ProofEvent(
            id: 'pe-test-1',
            type: ProofEventType.pickup,
            capturedAt: DateTime(2026, 5, 12, 9, 42),
            count: 12,
            photoPaths: const ['memory://AMW-0421/pickup_0'],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(sameDay, storage: storage));

      expect(find.textContaining('09:42'), findsOneWidget);
      expect(find.textContaining('May'), findsNothing);
      expect(find.textContaining('12 May'), findsNothing);
    },
  );

  testWidgets(
    'History row for an event on a different day prepends the date',
    (tester) async {
      final storage = InMemoryProofPhotoStorage();
      final spansMidnight = _pendingPickup.copyWith(
        status: OrderStatus.completed,
        proofEvents: [
          ProofEvent(
            id: 'pe-test-1',
            type: ProofEventType.pickup,
            capturedAt: DateTime(2026, 5, 11, 22, 15),
            count: 12,
            photoPaths: const ['memory://AMW-0421/pickup_0'],
          ),
          ProofEvent(
            id: 'pe-test-2',
            type: ProofEventType.delivery,
            capturedAt: DateTime(2026, 5, 12, 8, 30),
            count: 12,
            photoPaths: const ['memory://AMW-0421/delivery_0'],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(spansMidnight, storage: storage));

      expect(find.textContaining('11 May'), findsOneWidget);
      expect(find.textContaining('22:15'), findsOneWidget);
      expect(find.textContaining('08:30'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the leading back button pops false to the caller',
    (tester) async {
      // Covers _handleBackNavigation: the screen pops bool `false` (not a
      // LaundryOrder) so the dashboard's push<bool> result is well-typed.
      final storage = InMemoryProofPhotoStorage();
      bool? popped;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(
                          order: _pendingPickup,
                          photoStorage: storage,
                          pickPhoto: () async => const [1, 2, 3],
                          cameraViewBuilder: (context, onDetected) =>
                              const SizedBox.shrink(),
                          clock: () => DateTime(2026, 5, 12, 9, 42),
                          ordersRepo: _MockOrdersRepository(),
                          proofEventsRepo: _MockProofEventsRepository(),
                          actorStaffId: 's-test',
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
      expect(find.text('Order details'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Back on the launcher; the awaited push resolved to `false`.
      expect(find.text('Open'), findsOneWidget);
      expect(popped, isFalse);
    },
  );

  testWidgets(
    'a system back gesture is intercepted and pops false (PopScope)',
    (tester) async {
      // Covers PopScope.onPopInvokedWithResult's !didPop branch: canPop is
      // false, so a system back routes through _handleBackNavigation.
      final storage = InMemoryProofPhotoStorage();
      bool? popped;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(
                          order: _pendingPickup,
                          photoStorage: storage,
                          pickPhoto: () async => const [1, 2, 3],
                          cameraViewBuilder: (context, onDetected) =>
                              const SizedBox.shrink(),
                          clock: () => DateTime(2026, 5, 12, 9, 42),
                          ordersRepo: _MockOrdersRepository(),
                          proofEventsRepo: _MockProofEventsRepository(),
                          actorStaffId: 's-test',
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
      expect(find.text('Order details'), findsOneWidget);

      // Simulate the OS back button / predictive-back pop.
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(popped, isFalse);
    },
  );

  testWidgets(
    'removing a line item on the pricing section drops it from the list',
    (tester) async {
      // Covers the details-screen LineItemsEditor.onRemove: a non-pending order
      // shows the Pricing section; an existing line item can be removed.
      final storage = InMemoryProofPhotoStorage();
      final withLineItem = _pendingPickup.copyWith(
        status: OrderStatus.inProgress,
        lineItems: [LineItem(name: 'Duvet', amountUgx: 6000)],
      );

      await tester.pumpWidget(_wrap(withLineItem, storage: storage));

      await tester.scrollUntilVisible(
        find.byKey(const Key('remove_line_item_0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Duvet'), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove_line_item_0')));
      await tester.pumpAndSettle();

      expect(find.text('Duvet'), findsNothing);
    },
  );

  testWidgets(
    'OrderDetailsScreen builds with the default wall-clock when none is '
    'injected',
    (tester) async {
      // Covers the top-level _defaultClock default for `clock`.
      final storage = InMemoryProofPhotoStorage();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAmuwakTheme(),
          home: OrderDetailsScreen(
            order: _pendingPickup,
            photoStorage: storage,
            pickPhoto: () async => const [1, 2, 3],
            cameraViewBuilder: (context, onDetected) =>
                const SizedBox.shrink(),
            ordersRepo: _MockOrdersRepository(),
            proofEventsRepo: _MockProofEventsRepository(),
            actorStaffId: 's-test',
          ),
        ),
      );

      expect(find.text('Order details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
