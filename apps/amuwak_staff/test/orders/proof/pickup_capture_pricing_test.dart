import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof/pickup_capture_screen.dart';
import 'package:amuwak_staff/src/pricing/catalog_item.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';

class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockProofEventsRepository extends Mock
    implements ProofEventsRepository {}

/// Order with ratePerKgSnapshotUgx = 5000 for provisional-total tests.
const _pricedOrder = LaundryOrder(
  orderId: 'AMW-0999',
  customerName: 'Test Customer',
  serviceType: ServiceType.washAndIron,
  status: OrderStatus.pendingPickup,
  timeLabel: 'Today, 09:00',
  itemCount: 5,
  phone: '+256700000000',
  address: '10 Kampala Rd',
  notes: '',
  ratePerKgSnapshotUgx: 5000,
);

_MockOrdersRepository _okOrdersRepo() {
  final repo = _MockOrdersRepository();
  when(() => repo.updateStatus(any(), any(),
          actorStaffId: any(named: 'actorStaffId'),
          updatedAt: any(named: 'updatedAt')))
      .thenAnswer((_) async {});
  when(() => repo.updatePricing(any(),
          actorStaffId: any(named: 'actorStaffId')))
      .thenAnswer((_) async {});
  return repo;
}

_MockProofEventsRepository _okProofRepo() {
  final repo = _MockProofEventsRepository();
  when(() => repo.insertEvent(any(),
          orderId: any(named: 'orderId'),
          actorStaffId: any(named: 'actorStaffId')))
      .thenAnswer((_) async {});
  return repo;
}

void main() {
  setUpAll(() {
    registerFallbackValue(ProofEvent(
      id: 'fb',
      type: ProofEventType.pickup,
      capturedAt: DateTime(2026, 1, 1),
      count: 1,
      photoPaths: const [],
    ));
    registerFallbackValue(OrderStatus.pendingPickup);
    registerFallbackValue(DateTime(2026, 1, 1));
    registerFallbackValue(
      const LaundryOrder(
        orderId: 'fb',
        customerName: 'fallback',
        serviceType: ServiceType.washOnly,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Pickup: now',
        itemCount: 0,
        phone: 'p',
        address: 'a',
        notes: '',
      ),
    );
  });

  testWidgets(
    'Entering estimated weight of 3 shows provisional total of USh 15,000',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PickupCaptureScreen(
            order: _pricedOrder,
            photoStorage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            clock: () => DateTime(2026, 5, 12, 9, 42),
            ordersRepo: _okOrdersRepo(),
            proofEventsRepo: _okProofRepo(),
            actorStaffId: 's-test',
          ),
        ),
      );

      // Enter estimated weight of 3 kg
      await tester.enterText(
        find.byKey(const Key('pickup_estimated_weight')),
        '3',
      );
      await tester.pump();

      // Scroll to TotalCard: 3 kg × 5000 UGX/kg = 15,000 UGX
      await tester.scrollUntilVisible(
        find.text('USh 15,000'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('USh 15,000'), findsOneWidget);
      expect(find.text('Provisional'), findsOneWidget);
    },
  );

  testWidgets(
    'Adding a line item updates the provisional total',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PickupCaptureScreen(
            order: _pricedOrder,
            photoStorage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            clock: () => DateTime(2026, 5, 12, 9, 42),
            ordersRepo: _okOrdersRepo(),
            proofEventsRepo: _okProofRepo(),
            actorStaffId: 's-test',
          ),
        ),
      );

      // Enter 2 kg → 10,000
      await tester.enterText(
        find.byKey(const Key('pickup_estimated_weight')),
        '2',
      );
      await tester.pump();

      // Scroll to the TotalCard to verify initial total
      await tester.scrollUntilVisible(
        find.text('USh 10,000'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('USh 10,000'), findsOneWidget);

      // Scroll to the 'Add item' button
      await tester.scrollUntilVisible(
        find.byKey(const Key('add_line_item')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Tap 'Add item' to open bottom sheet
      await tester.tap(find.byKey(const Key('add_line_item')));
      await tester.pumpAndSettle();

      // Fill in the sheet
      await tester.enterText(find.byKey(const Key('line_item_name')), 'Blanket');
      await tester.enterText(
          find.byKey(const Key('line_item_amount')), '3000');
      await tester.tap(find.byKey(const Key('line_item_save')));
      await tester.pumpAndSettle();

      // Scroll to the TotalCard to verify updated total
      await tester.scrollUntilVisible(
        find.text('USh 13,000'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Total should now be 10,000 + 3,000 = 13,000
      expect(find.text('USh 13,000'), findsOneWidget);
      expect(find.text('Provisional'), findsOneWidget);
    },
  );

  testWidgets(
    'On Done, updatePricing is called with estimatedWeightKg and lineItems',
    (tester) async {
      final ordersRepo = _okOrdersRepo();
      final proofEventsRepo = _okProofRepo();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PickupCaptureScreen(
                      order: _pricedOrder,
                      photoStorage: InMemoryProofPhotoStorage(),
                      pickPhoto: () async => const [1, 2, 3],
                      clock: () => DateTime(2026, 5, 12, 9, 42),
                      ordersRepo: ordersRepo,
                      proofEventsRepo: proofEventsRepo,
                      actorStaffId: 's-test',
                      proofEventIdGenerator: () => 'pe-pricing-test',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter estimated weight
      await tester.enterText(
        find.byKey(const Key('pickup_estimated_weight')),
        '3',
      );
      await tester.pump();

      // Increment count and add photo so Confirm is enabled
      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();

      // Confirm with customer → QR stage (scroll to button first)
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      // updatePricing was called
      final captured = verify(() => ordersRepo.updatePricing(
            captureAny(),
            actorStaffId: 's-test',
          )).captured;
      expect(captured, hasLength(1));
      final updatedOrder = captured.single as LaundryOrder;
      expect(updatedOrder.estimatedWeightKg, 3.0);
      expect(updatedOrder.lineItems, isEmpty);
    },
  );

  testWidgets(
    'On Done, a failed updatePricing surfaces a warning snackbar to the rider',
    (tester) async {
      final ordersRepo = _MockOrdersRepository();
      when(() => ordersRepo.updateStatus(any(), any(),
              actorStaffId: any(named: 'actorStaffId'),
              updatedAt: any(named: 'updatedAt')))
          .thenAnswer((_) async {});
      when(() => ordersRepo.updatePricing(any(),
              actorStaffId: any(named: 'actorStaffId')))
          .thenThrow(Exception('network down'));
      final proofEventsRepo = _okProofRepo();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PickupCaptureScreen(
                      order: _pricedOrder,
                      photoStorage: InMemoryProofPhotoStorage(),
                      pickPhoto: () async => const [1, 2, 3],
                      clock: () => DateTime(2026, 5, 12, 9, 42),
                      ordersRepo: ordersRepo,
                      proofEventsRepo: proofEventsRepo,
                      actorStaffId: 's-test',
                      proofEventIdGenerator: () => 'pe-fail-test',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('pickup_estimated_weight')),
        '3',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("pricing wasn't saved"),
        findsOneWidget,
        reason: 'rider must be told pricing data needs re-entry on the order',
      );
    },
  );

  testWidgets(
    'Add item offers catalog items and adding one updates the total',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PickupCaptureScreen(
            order: _pricedOrder,
            photoStorage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            clock: () => DateTime(2026, 5, 12, 9, 42),
            ordersRepo: _okOrdersRepo(),
            proofEventsRepo: _okProofRepo(),
            actorStaffId: 's-test',
            catalogItems: [
              CatalogItem(id: 'c1', name: 'Blanket', amountUgx: 8000),
            ],
          ),
        ),
      );

      await tester.enterText(
          find.byKey(const Key('pickup_estimated_weight')), '2');
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const Key('add_line_item')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('add_line_item')));
      await tester.pumpAndSettle();

      // The catalog item appears in the picker; tapping it adds the line.
      await tester.tap(find.byKey(const Key('pick_catalog_item_0')));
      await tester.pumpAndSettle();

      // 2 kg × 5000 = 10,000 + Blanket 8,000 = 18,000.
      await tester.scrollUntilVisible(
        find.text('USh 18,000'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('USh 18,000'), findsOneWidget);
    },
  );

  testWidgets(
    'Empty estimated weight field → provisional total is USh 0',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PickupCaptureScreen(
            order: _pricedOrder,
            photoStorage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            clock: () => DateTime(2026, 5, 12, 9, 42),
            ordersRepo: _okOrdersRepo(),
            proofEventsRepo: _okProofRepo(),
            actorStaffId: 's-test',
          ),
        ),
      );

      // Scroll to TotalCard — No weight entered → 0
      await tester.scrollUntilVisible(
        find.text('USh 0'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('USh 0'), findsOneWidget);
      expect(find.text('Provisional'), findsOneWidget);
    },
  );
}
