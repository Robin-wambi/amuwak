import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_details_screen.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof/printable_tag.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/printing/label_printer.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';

import '../helpers/fake_camera_view.dart';
import '../helpers/fake_label_printer.dart';

class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockProofEventsRepository extends Mock
    implements ProofEventsRepository {}

LaundryOrder _order(OrderStatus status) => LaundryOrder(
      orderId: 'uuid-1',
      orderCode: 'AMW-2026-0042',
      customerName: 'Jane Doe',
      serviceType: ServiceType.washOnly,
      status: status,
      timeLabel: 't',
      itemCount: 3,
      phone: 'p',
      address: 'a',
      notes: '',
    );

final _tagBytes = Uint8List.fromList(const [5, 5, 5, 5]);

Widget _wrap(LaundryOrder order, {LabelPrinter? printer}) {
  return MaterialApp(
    theme: buildAmuwakTheme(),
    home: OrderDetailsScreen(
      order: order,
      photoStorage: InMemoryProofPhotoStorage(),
      pickPhoto: () async => const [1, 2, 3],
      cameraViewBuilder: (context, onDetected) =>
          FakeCameraView(scannedValue: 'AMW-2026-0042', onDetected: onDetected),
      clock: () => DateTime(2026, 5, 12, 9, 42),
      ordersRepo: _MockOrdersRepository(),
      proofEventsRepo: _MockProofEventsRepository(),
      actorStaffId: 's-test',
      labelPrinter: printer,
      captureTag: (_) async => _tagBytes,
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(OrderStatus.pendingPickup));

  testWidgets('shows Reprint tag for a ready order when a printer is wired up',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_order(OrderStatus.readyForDelivery), printer: FakeLabelPrinter()),
    );
    expect(find.byKey(const Key('reprint_tag')), findsOneWidget);
  });

  testWidgets('shows Reprint tag while the order is in progress',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_order(OrderStatus.inProgress), printer: FakeLabelPrinter()),
    );
    expect(find.byKey(const Key('reprint_tag')), findsOneWidget);
  });

  testWidgets('hides Reprint tag when no printer is wired up', (tester) async {
    await tester.pumpWidget(_wrap(_order(OrderStatus.readyForDelivery)));
    expect(find.byKey(const Key('reprint_tag')), findsNothing);
  });

  testWidgets('hides Reprint tag before pickup (bag not tagged yet)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_order(OrderStatus.pendingPickup), printer: FakeLabelPrinter()),
    );
    expect(find.byKey(const Key('reprint_tag')), findsNothing);
  });

  testWidgets('Reprint tag opens a sheet with the printable tag',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_order(OrderStatus.readyForDelivery), printer: FakeLabelPrinter()),
    );

    await tester.tap(find.byKey(const Key('reprint_tag')));
    await tester.pumpAndSettle();

    expect(find.text('Reprint bag tag'), findsOneWidget);
    expect(find.byType(PrintableTag), findsOneWidget);
    expect(find.text('AMW-2026-0042'), findsWidgets);
  });

  testWidgets('Reprint sheet prints the tag to a connected printer',
      (tester) async {
    final printer = FakeLabelPrinter(
      connected: const PrinterDevice(id: 'AB:CD', name: 'Munbyn'),
    );
    await tester.pumpWidget(
      _wrap(_order(OrderStatus.readyForDelivery), printer: printer),
    );

    await tester.tap(find.byKey(const Key('reprint_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();

    expect(printer.printed, hasLength(1));
    expect(printer.printed.single, equals(_tagBytes));
  });
}
