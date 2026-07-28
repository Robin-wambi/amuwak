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

import '../../helpers/fake_camera_view.dart';

/// Online-only mode: end-to-end pickup → ready → delivery flow driven through
/// OrderDetailsScreen, which passes its (Supabase-backed) repos down to the
/// capture screens. The repos are mocked here — the flow's contract is verified
/// by what the screens call on the repos (two proof inserts + the status
/// transitions) plus the final completed UI state and the persisted photos.
class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockProofEventsRepository extends Mock
    implements ProofEventsRepository {}

/// Invokes the `onPressed` of the `ElevatedButton` that contains [label].
/// Used instead of `tester.tap` because OrderDetailsScreen's primary action
/// sits at the bottom of the viewport and competes for hit-testing with
/// overlay artifacts that linger across the multi-phase flow.
Future<void> _pressButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(ElevatedButton, label);
  final button = tester.widget<ElevatedButton>(finder);
  button.onPressed!();
  await tester.pumpAndSettle();
}

/// Scrolls the collecting ListView until the 'Confirm with customer' button is
/// visible. Task 15 added an estimated-weight field, a line-items editor, and a
/// total card, making the list tall enough for the button to be below the fold
/// in the default test-viewport height.
Future<void> _scrollToConfirm(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('pickup_confirm')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
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
  });

  testWidgets(
      'full pickup -> ready -> delivery flow inserts two proof events and '
      'walks the order through to completed', (tester) async {
    final ordersRepo = _MockOrdersRepository();
    final proofEventsRepo = _MockProofEventsRepository();
    // updateStatus is called with updatedAt (capture screens) and without
    // (the direct advance button) — stub both forms.
    when(() => ordersRepo.updateStatus(any(), any(),
            actorStaffId: any(named: 'actorStaffId'),
            updatedAt: any(named: 'updatedAt')))
        .thenAnswer((_) async {});
    when(() => ordersRepo.updateStatus(any(), any(),
        actorStaffId: any(named: 'actorStaffId'))).thenAnswer((_) async {});
    when(() => proofEventsRepo.insertEvent(any(),
            orderId: any(named: 'orderId'),
            actorStaffId: any(named: 'actorStaffId')))
        .thenAnswer((_) async {});

    final storage = InMemoryProofPhotoStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailsScreen(
          order: const LaundryOrder(
            orderId: 'AMW-0421',
            // Server-minted code, distinct from orderId, so hasServerCode is
            // true and the flow can reach the tag/QR stage. Without this the
            // code defaults to orderId and the order reads as unsynced.
            orderCode: 'AMW-2026-0421',
            customerName: 'Jane',
            serviceType: ServiceType.washOnly,
            status: OrderStatus.pendingPickup,
            timeLabel: 't',
            itemCount: 3,
            phone: 'p',
            address: 'a',
            notes: '',
          ),
          photoStorage: storage,
          pickPhoto: () async => const [1, 2, 3],
          cameraViewBuilder: (ctx, onDetected) {
            return FakeCameraView(
              // The rider scans the tag, which carries the server-minted
              // orderCode — not the internal orderId.
              scannedValue: 'AMW-2026-0421',
              onDetected: onDetected,
            );
          },
          clock: () => DateTime(2026, 5, 12, 9, 42),
          ordersRepo: ordersRepo,
          proofEventsRepo: proofEventsRepo,
          actorStaffId: 's-test',
        ),
      ),
    );

    // Phase 1: Pickup — open capture, enter count + photo, confirm, done.
    await _pressButton(tester, 'Confirm pickup');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('add_photo')));
    await tester.pumpAndSettle();
    await _scrollToConfirm(tester);
    await _pressButton(tester, 'Confirm with customer');
    await _pressButton(tester, 'Done');

    // OrderDetailsScreen optimistically reflects inProgress.
    expect(
      find.widgetWithText(ElevatedButton, 'Move to Ready for delivery'),
      findsOneWidget,
    );

    // Phase 2: inProgress -> readyForDelivery via the direct button.
    await _pressButton(tester, 'Move to Ready for delivery');
    expect(find.widgetWithText(ElevatedButton, 'Deliver'), findsOneWidget);

    // Phase 3: Delivery — scan, add handover photo, mark delivered.
    await _pressButton(tester, 'Deliver');
    await tester.tap(find.text('Simulate scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_handover_photo')));
    await tester.pumpAndSettle();
    await _pressButton(tester, 'Mark delivered');

    // OrderDetailsScreen now shows the disabled completed state.
    expect(
      find.widgetWithText(ElevatedButton, 'Order completed'),
      findsOneWidget,
    );

    // ---- Repo contract: two proof inserts (pickup + delivery) ----
    final events = verify(() => proofEventsRepo.insertEvent(
          captureAny(),
          orderId: 'AMW-0421',
          actorStaffId: 's-test',
        )).captured.cast<ProofEvent>();
    expect(events, hasLength(2));
    expect(events.map((e) => e.type).toSet(),
        {ProofEventType.pickup, ProofEventType.delivery});

    // ---- Status transitions walked through to completed ----
    verify(() => ordersRepo.updateStatus('AMW-0421', OrderStatus.inProgress,
        actorStaffId: 's-test', updatedAt: any(named: 'updatedAt'))).called(1);
    verify(() => ordersRepo.updateStatus(
        'AMW-0421', OrderStatus.readyForDelivery,
        actorStaffId: 's-test')).called(1);
    verify(() => ordersRepo.updateStatus('AMW-0421', OrderStatus.completed,
        actorStaffId: 's-test', updatedAt: any(named: 'updatedAt'))).called(1);

    // ---- Photo storage: one pickup + one delivery ----
    expect(storage.savedPhotos, hasLength(2));
    expect(
      storage.savedPhotos.where((p) => p.path.contains('pickup')).toList(),
      hasLength(1),
    );
    expect(
      storage.savedPhotos.where((p) => p.path.contains('delivery')).toList(),
      hasLength(1),
    );
  });
}
