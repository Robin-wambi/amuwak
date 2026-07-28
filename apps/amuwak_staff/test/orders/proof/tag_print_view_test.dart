import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amuwak_staff/src/orders/proof/printable_tag.dart';
import 'package:amuwak_staff/src/orders/proof/tag_print_view.dart';
import 'package:amuwak_staff/src/printing/label_printer.dart';
import 'package:amuwak_staff/src/printing/printer_store.dart';

import '../../helpers/fake_label_printer.dart';

final _tagBytes = Uint8List.fromList(const [7, 7, 7, 7]);

Future<void> _pump(
  WidgetTester tester, {
  required LabelPrinter? printer,
  PrinterStore? printerStore,
  BluetoothPermissionRequester? requestPermission,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TagPrintView(
          orderCode: 'AMW-2026-0042',
          customerName: 'Jane Doe',
          labelPrinter: printer,
          printerStore: printerStore,
          captureTag: (_) async => _tagBytes,
          requestBluetoothPermission:
              requestPermission ?? () async => true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('always shows the tag preview', (tester) async {
    await _pump(tester, printer: null);
    expect(find.byType(PrintableTag), findsOneWidget);
    expect(find.text('AMW-2026-0042'), findsOneWidget);
  });

  testWidgets('hides the print button when no printer is wired up',
      (tester) async {
    await _pump(tester, printer: null);
    expect(find.byKey(const Key('print_tag')), findsNothing);
  });

  testWidgets('prints when a printer is already connected', (tester) async {
    final printer = FakeLabelPrinter(
      connected: const PrinterDevice(id: 'AB:CD', name: 'Munbyn'),
    );
    await _pump(tester, printer: printer);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();

    expect(printer.printed, hasLength(1));
    expect(printer.printed.single, equals(_tagBytes));
  });

  testWidgets('picks a printer when none is connected, then prints',
      (tester) async {
    final printer = FakeLabelPrinter(
      devices: const [PrinterDevice(id: 'AB:CD', name: 'Phomemo M2')],
    );
    await _pump(tester, printer: printer);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();
    expect(find.text('Phomemo M2'), findsOneWidget);

    await tester.tap(find.text('Phomemo M2'));
    await tester.pumpAndSettle();

    expect(printer.connectCalls, hasLength(1));
    expect(printer.printed, hasLength(1));
  });

  testWidgets('guides the rider when no printer is paired', (tester) async {
    final printer = FakeLabelPrinter();
    await _pump(tester, printer: printer);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();

    expect(printer.printed, isEmpty);
    expect(find.textContaining('No paired printer'), findsOneWidget);
  });

  testWidgets('surfaces an error and re-enables the button on print failure',
      (tester) async {
    final printer = FakeLabelPrinter(
      connected: const PrinterDevice(id: 'AB:CD', name: 'Munbyn'),
      printThrows: Exception('offline'),
    );
    await _pump(tester, printer: printer);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();

    expect(printer.printed, isEmpty);
    expect(find.textContaining('Could not print the tag'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('print_tag')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('stops with guidance when Bluetooth permission is denied',
      (tester) async {
    final printer = FakeLabelPrinter(
      devices: const [PrinterDevice(id: 'AB:CD', name: 'Phomemo M2')],
    );
    await _pump(tester, printer: printer, requestPermission: () async => false);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();

    expect(printer.discoverCalls, equals(0));
    expect(printer.printed, isEmpty);
    expect(find.textContaining('Bluetooth permission'), findsOneWidget);
  });

  testWidgets('connects to the remembered printer without showing the picker',
      (tester) async {
    const remembered = PrinterDevice(id: 'AB:CD', name: 'Munbyn M2');
    SharedPreferences.setMockInitialValues({});
    final store = PrinterStore(await SharedPreferences.getInstance());
    await store.save(remembered);

    final printer = FakeLabelPrinter(
      devices: const [PrinterDevice(id: 'ZZ:99', name: 'Other')],
    );
    await _pump(tester, printer: printer, printerStore: store);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a printer'), findsNothing);
    expect(printer.connectCalls, equals(const [remembered]));
    expect(printer.printed, hasLength(1));
  });

  testWidgets('falls back to the picker when the remembered printer is gone',
      (tester) async {
    const remembered = PrinterDevice(id: 'GONE:01', name: 'Old Printer');
    SharedPreferences.setMockInitialValues({});
    final store = PrinterStore(await SharedPreferences.getInstance());
    await store.save(remembered);

    const replacement = PrinterDevice(id: 'AB:CD', name: 'Phomemo M2');
    final printer = FakeLabelPrinter(
      devices: const [replacement],
      connectFailingIds: {remembered.id},
    );
    await _pump(tester, printer: printer, printerStore: store);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();

    // Remembered connect was attempted and failed, so the picker is shown.
    expect(printer.connectCalls.first, equals(remembered));
    expect(find.text('Phomemo M2'), findsOneWidget);

    await tester.tap(find.text('Phomemo M2'));
    await tester.pumpAndSettle();

    expect(printer.printed, hasLength(1));
    // The newly chosen printer replaces the dead one in storage.
    expect(store.load(), equals(replacement));
  });

  testWidgets('remembers the printer chosen from the picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = PrinterStore(await SharedPreferences.getInstance());

    const device = PrinterDevice(id: 'AB:CD', name: 'Phomemo M2');
    final printer = FakeLabelPrinter(devices: const [device]);
    await _pump(tester, printer: printer, printerStore: store);

    await tester.tap(find.byKey(const Key('print_tag')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phomemo M2'));
    await tester.pumpAndSettle();

    expect(store.load(), equals(device));
    expect(printer.printed, hasLength(1));
  });
}
