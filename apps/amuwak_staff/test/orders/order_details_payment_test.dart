import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_details_screen.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';

import '../helpers/fake_camera_view.dart';

class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockProofEventsRepository extends Mock
    implements ProofEventsRepository {}

LaundryOrder _order({
  int totalUgx = 10000,
  int paymentAmountUgx = 0,
  OrderStatus status = OrderStatus.readyForDelivery,
}) =>
    LaundryOrder(
      orderId: 'AMW-0001',
      customerName: 'Alice',
      serviceType: ServiceType.washOnly,
      status: status,
      timeLabel: 't',
      itemCount: 5,
      phone: 'p',
      address: 'a',
      notes: '',
      ratePerKgSnapshotUgx: 5000,
      totalUgx: totalUgx,
      paymentAmountUgx: paymentAmountUgx,
    );

Widget _wrap(LaundryOrder order, {OrdersRepository? ordersRepo}) {
  return MaterialApp(
    theme: buildAmuwakTheme(),
    home: OrderDetailsScreen(
      order: order,
      photoStorage: InMemoryProofPhotoStorage(),
      pickPhoto: () async => const [1, 2, 3],
      cameraViewBuilder: (context, onDetected) => FakeCameraView(
        scannedValue: 'AMW-0001',
        onDetected: onDetected,
      ),
      clock: () => DateTime(2026, 5, 12, 9, 42),
      ordersRepo: ordersRepo ?? _MockOrdersRepository(),
      proofEventsRepo: _MockProofEventsRepository(),
      actorStaffId: 's-test',
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_order());
  });

  testWidgets('Payment section shows collected, outstanding and a partial badge',
      (tester) async {
    await tester.pumpWidget(_wrap(_order(totalUgx: 10000, paymentAmountUgx: 4000)));

    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('USh 4,000'), findsWidgets); // collected
    expect(find.text('USh 6,000'), findsWidgets); // outstanding
    expect(find.text('Partial'), findsOneWidget);
  });

  testWidgets('pendingPickup: Payment section is absent (no price yet)',
      (tester) async {
    await tester
        .pumpWidget(_wrap(_order(status: OrderStatus.pendingPickup)));
    expect(find.text('Payment'), findsNothing);
    expect(find.byKey(const Key('details_record_payment')), findsNothing);
  });

  testWidgets(
      'Record payment opens the sheet and saves the new cumulative collected',
      (tester) async {
    final repo = _MockOrdersRepository();
    when(() => repo.updatePayment(any(), any(),
        actorStaffId: any(named: 'actorStaffId'))).thenAnswer((_) async {});

    await tester.pumpWidget(
        _wrap(_order(totalUgx: 10000, paymentAmountUgx: 4000), ordersRepo: repo));

    await tester.ensureVisible(find.byKey(const Key('details_record_payment')));
    await tester.tap(find.byKey(const Key('details_record_payment')));
    await tester.pumpAndSettle();

    // 6,000 owed; rider receives exactly that.
    await tester.enterText(find.byKey(const Key('cash_tendered')), '6000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('record_payment_confirm')));
    await tester.pumpAndSettle();

    // New cumulative collected = 4,000 already + 6,000 applied = 10,000.
    verify(() => repo.updatePayment('AMW-0001', 10000, actorStaffId: 's-test'))
        .called(1);
  });
}
