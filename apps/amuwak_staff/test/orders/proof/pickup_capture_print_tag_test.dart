import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof/pickup_capture_screen.dart';
import 'package:amuwak_staff/src/orders/proof/printable_tag.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/printing/label_printer.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';

import '../../helpers/fake_label_printer.dart';

class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockProofEventsRepository extends Mock
    implements ProofEventsRepository {}

class _StubPhotoStorage implements ProofPhotoStorage {
  @override
  Future<String> save({
    required String orderId,
    required ProofEventType type,
    required int index,
    required List<int> bytes,
  }) async =>
      'path-$index';
}

// A synced order: the UUID orderId differs from the server-minted orderCode, so
// hasServerCode is true and the tag/QR stage renders. Keep them distinct — when
// they match, the order reads as an unsynced placeholder and the tag is hidden.
const _order = LaundryOrder(
  orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
  orderCode: 'AMW-2026-0042',
  customerName: 'Jane Doe',
  serviceType: ServiceType.washAndIron,
  status: OrderStatus.pendingPickup,
  timeLabel: 'Today, 09:00',
  itemCount: 3,
  phone: '+256700000000',
  address: '5 Yaba',
  notes: '',
);

final _tagBytes = Uint8List.fromList(const [9, 9, 9, 9]);

/// Pump the pickup screen with [printer] injected and advance to the QR/tag
/// stage where the "Print tag" button lives.
Future<void> _pumpToTagStage(
  WidgetTester tester, {
  required FakeLabelPrinter printer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PickupCaptureScreen(
        order: _order,
        photoStorage: _StubPhotoStorage(),
        pickPhoto: () async => const [1, 2, 3, 4],
        ordersRepo: _MockOrdersRepository(),
        proofEventsRepo: _MockProofEventsRepository(),
        actorStaffId: 's-test',
        labelPrinter: printer,
        captureTag: (_) async => _tagBytes,
      ),
    ),
  );

  // Count must be > 0 and at least one photo present to confirm.
  await tester.tap(find.byKey(const Key('count_increment')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('add_photo')));
  await tester.pumpAndSettle();

  // The confirm button sits below the fold in the default test viewport.
  await tester.scrollUntilVisible(
    find.byKey(const Key('pickup_confirm')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byKey(const Key('pickup_confirm')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pickup_confirm')));
  await tester.pumpAndSettle();

  // We should now be on the tag stage with a printable preview.
  expect(find.byType(PrintableTag), findsOneWidget);
}

void main() {
  testWidgets('prints the tag bitmap when a printer is already connected',
      (tester) async {
    final printer = FakeLabelPrinter(
      connected: const PrinterDevice(id: 'AB:CD', name: 'Munbyn'),
    );
    await _pumpToTagStage(tester, printer: printer);

    await tester.ensureVisible(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();

    expect(printer.printed, hasLength(1));
    expect(printer.printed.single, equals(_tagBytes));
  });

  testWidgets('offers a printer to pick when none is connected, then prints',
      (tester) async {
    final printer = FakeLabelPrinter(
      devices: const [PrinterDevice(id: 'AB:CD', name: 'Phomemo M2')],
    );
    await _pumpToTagStage(tester, printer: printer);

    await tester.ensureVisible(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();

    // A picker listing the discovered printer appears.
    expect(printer.discoverCalls, equals(1));
    expect(find.text('Phomemo M2'), findsOneWidget);

    await tester.tap(find.text('Phomemo M2'));
    await tester.pumpAndSettle();

    expect(printer.connectCalls, hasLength(1));
    expect(printer.printed, hasLength(1));
  });

  testWidgets('guides the rider when no printer is paired', (tester) async {
    final printer = FakeLabelPrinter(); // discover() returns []
    await _pumpToTagStage(tester, printer: printer);

    await tester.ensureVisible(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();

    expect(printer.printed, isEmpty);
    expect(find.textContaining('No paired printer'), findsOneWidget);
  });

  testWidgets('surfaces an error and re-enables the button when connect fails',
      (tester) async {
    final printer = FakeLabelPrinter(
      devices: const [PrinterDevice(id: 'AB:CD', name: 'Phomemo M2')],
      connectThrows: true,
    );
    await _pumpToTagStage(tester, printer: printer);

    await tester.ensureVisible(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phomemo M2'));
    await tester.pumpAndSettle();

    expect(printer.printed, isEmpty);
    // A connection failure reads as such, not as a generic print failure.
    expect(find.textContaining('Could not connect to'), findsOneWidget);
    // The button is enabled again so the rider can retry.
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('pickup_print_tag')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('surfaces an error when the printer rejects the tag',
      (tester) async {
    final printer = FakeLabelPrinter(
      connected: const PrinterDevice(id: 'AB:CD', name: 'Munbyn'),
      printThrows: Exception('printer offline'),
    );
    await _pumpToTagStage(tester, printer: printer);

    await tester.ensureVisible(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickup_print_tag')));
    await tester.pumpAndSettle();

    expect(printer.printed, isEmpty);
    expect(find.textContaining('Could not print the tag'), findsOneWidget);
  });
}
