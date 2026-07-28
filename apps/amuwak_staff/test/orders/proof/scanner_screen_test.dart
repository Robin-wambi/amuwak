import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/proof/barcode_reader.dart';
import 'package:amuwak_staff/src/orders/proof/scanner_screen.dart';

import '../../helpers/fake_camera_view.dart';

Future<bool?> _pumpAndPushScanner(
  WidgetTester tester, {
  required String expectedOrderCode,
  required String scannedValue,
}) async {
  bool? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ScannerScreen(
                        expectedOrderCode: expectedOrderCode,
                        cameraViewBuilder: (ctx, onDetected) {
                          return FakeCameraView(
                            scannedValue: scannedValue,
                            onDetected: onDetected,
                          );
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Open scanner'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open scanner'));
  await tester.pumpAndSettle();
  return Future.value(result);
}

void main() {
  testWidgets('matching scanned value pops the screen with true',
      (tester) async {
    await _pumpAndPushScanner(
      tester,
      expectedOrderCode: 'AMW-1',
      scannedValue: 'AMW-1',
    );

    await tester.tap(find.text('Simulate scan'));
    await tester.pumpAndSettle();

    expect(find.byType(ScannerScreen), findsNothing);
  });

  testWidgets('wrong scanned value shows an error and stays on screen',
      (tester) async {
    await _pumpAndPushScanner(
      tester,
      expectedOrderCode: 'AMW-1',
      scannedValue: 'AMW-9',
    );

    await tester.tap(find.text('Simulate scan'));
    await tester.pump();

    expect(find.byType(ScannerScreen), findsOneWidget);
    expect(find.textContaining('AMW-9'), findsOneWidget);
    expect(find.textContaining('AMW-1'), findsOneWidget);
  });

  testWidgets(
      'a new-format code is recognised as an order tag, not a generic value',
      (tester) async {
    await _pumpAndPushScanner(
      tester,
      expectedOrderCode: 'AMW-2026-0099',
      scannedValue: 'AMW-2026-0042',
    );

    await tester.tap(find.text('Simulate scan'));
    await tester.pump();

    expect(find.byType(ScannerScreen), findsOneWidget);
    // The year-dash-counter form must trip the "belongs to order #..."
    // wording, not the generic "does not match" fallback.
    expect(
      find.textContaining('belongs to order #AMW-2026-0042'),
      findsOneWidget,
    );
  });

  testWidgets('manual entry path: matching id pops with true', (tester) async {
    await _pumpAndPushScanner(
      tester,
      expectedOrderCode: 'AMW-1',
      scannedValue: 'unused',
    );

    await tester.tap(find.text('Enter order code instead'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'AMW-1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(ScannerScreen), findsNothing);
  });

  testWidgets('manual entry path: wrong id shows error', (tester) async {
    await _pumpAndPushScanner(
      tester,
      expectedOrderCode: 'AMW-1',
      scannedValue: 'unused',
    );

    await tester.tap(find.text('Enter order code instead'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'AMW-9');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
    await tester.pump();

    expect(find.byType(ScannerScreen), findsOneWidget);
    expect(find.textContaining('AMW-9'), findsOneWidget);
  });

  testWidgets(
    'scanning a non-order-id value shows a generic mismatch error',
    (tester) async {
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-1',
        scannedValue: 'https://example.com',
      );

      await tester.tap(find.text('Simulate scan'));
      await tester.pump();

      expect(find.byType(ScannerScreen), findsOneWidget);
      // Must NOT use the "belongs to order #..." phrasing for a random value.
      expect(find.textContaining('belongs to order'), findsNothing);
      expect(find.textContaining('https://example.com'), findsNothing);
      // Generic mismatch references only the expected order.
      expect(
        find.textContaining('does not match order #AMW-1'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'empty manual submit shows a generic mismatch error',
    (tester) async {
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-1',
        scannedValue: 'unused',
      );

      await tester.tap(find.text('Enter order code instead'));
      await tester.pumpAndSettle();

      // Submit with the field still empty.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pump();

      expect(find.byType(ScannerScreen), findsOneWidget);
      expect(find.textContaining('belongs to order'), findsNothing);
      expect(
        find.textContaining('does not match order #AMW-1'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manual entry path: lowercase id for an uppercase order matches',
    (tester) async {
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-1024',
        scannedValue: 'unused',
      );

      await tester.tap(find.text('Enter order code instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'amw-1024');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(ScannerScreen), findsNothing);
    },
  );

  testWidgets(
    'manual entry path: a bare number matches the expected code by counter',
    (tester) async {
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-2026-0042',
        scannedValue: 'unused',
      );

      await tester.tap(find.text('Enter order code instead'));
      await tester.pumpAndSettle();

      // The rider types just the number off the bag, not the full code.
      await tester.enterText(find.byType(TextFormField), '42');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(ScannerScreen), findsNothing);
    },
  );

  testWidgets(
    'manual entry path: a zero-padded bare number matches too',
    (tester) async {
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-2026-0042',
        scannedValue: 'unused',
      );

      await tester.tap(find.text('Enter order code instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '0042');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(ScannerScreen), findsNothing);
    },
  );

  testWidgets(
    'manual entry path: a bare number for a different order fails',
    (tester) async {
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-2026-0042',
        scannedValue: 'unused',
      );

      await tester.tap(find.text('Enter order code instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '43');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pump();

      expect(find.byType(ScannerScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a full code with the same counter but a different year is rejected',
    (tester) async {
      // Cross-year safety: scanning another year's QR that shares the counter
      // must NOT verify. Only a BARE number is matched by counter; a formatted
      // code is compared in full, year included.
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-2026-0042',
        scannedValue: 'AMW-2025-0042',
      );

      await tester.tap(find.text('Simulate scan'));
      await tester.pump();

      expect(find.byType(ScannerScreen), findsOneWidget);
      expect(
        find.textContaining('belongs to order #AMW-2025-0042'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manual-entry affordances are labelled "order code", not "order ID"',
    (tester) async {
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-2026-0042',
        scannedValue: 'unused',
      );

      // The toggle names the order code — that is what is printed on the bag.
      expect(find.text('Enter order code instead'), findsOneWidget);
      await tester.tap(find.text('Enter order code instead'));
      await tester.pumpAndSettle();

      expect(find.text('Order code written on the bag'), findsOneWidget);
      // The old "order ID" wording (which pointed riders at the UUID) is gone.
      expect(find.textContaining('order ID'), findsNothing);
      expect(find.textContaining('Order ID'), findsNothing);
    },
  );

  testWidgets(
    'an empty scan never matches, even when the expected code is empty',
    (tester) async {
      // Defensive: a blank/unreadable scan emits '' and must never be accepted
      // as a match — not even against a (malformed) empty expected code, which
      // would otherwise satisfy the `'' == ''` comparison and pop success.
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: '',
        scannedValue: '',
      );

      await tester.tap(find.text('Simulate scan'));
      await tester.pumpAndSettle();

      // Stayed on the scanner — the empty scan was not treated as a match.
      // (pumpAndSettle, not pump: a successful pop would otherwise still be
      // mid-transition in the tree and falsely look "present".)
      expect(find.byType(ScannerScreen), findsOneWidget);
    },
  );

  testWidgets(
    'repeated detections after a match do not pop the screen twice',
    (tester) async {
      bool? result;
      var pushCount = 0;
      late OnBarcodeDetected captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      pushCount++;
                      result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => ScannerScreen(
                            expectedOrderCode: 'AMW-1',
                            cameraViewBuilder: (ctx, onDetected) {
                              captured = onDetected;
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text('Open scanner'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();

      // MobileScanner fires onDetect continuously while a QR code is in the
      // camera frame, including after the first matching detection has been
      // forwarded. Simulate two calls in rapid succession.
      captured('AMW-1');
      captured('AMW-1');
      await tester.pumpAndSettle();

      expect(result, isTrue);
      // Wrapper screen with the launch button must still be present — i.e. the
      // second pop must have been suppressed.
      expect(find.text('Open scanner'), findsOneWidget);
      expect(pushCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the AppBar close button pops the screen with false',
      (tester) async {
    // Covers BarcodeScannerScaffold's onClose wiring (Navigator.pop false).
    // Capture the pop result locally — the shared helper snapshots its result
    // before the route resolves, so it can't observe a post-pop value.
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ScannerScreen(
                        expectedOrderCode: 'AMW-1',
                        cameraViewBuilder: (ctx, onDetected) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                child: const Text('Open scanner'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(find.byType(ScannerScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ScannerScreen), findsNothing);
    expect(result, isFalse);
  });

  testWidgets(
    'manual entry path: submitting via the keyboard action matches',
    (tester) async {
      // Covers TextFormField.onFieldSubmitted in _ManualEntryView — a rider can
      // press the keyboard's submit action instead of tapping the Submit button.
      await _pumpAndPushScanner(
        tester,
        expectedOrderCode: 'AMW-1',
        scannedValue: 'unused',
      );

      await tester.tap(find.text('Enter order code instead'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'AMW-1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(ScannerScreen), findsNothing);
    },
  );
}
