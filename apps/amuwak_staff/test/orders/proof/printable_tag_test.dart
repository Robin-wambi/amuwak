import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:amuwak_staff/src/orders/proof/printable_tag.dart';
import 'package:amuwak_staff/src/orders/proof/qr_display_widget.dart';

void main() {
  testWidgets('renders the order code and customer name on a white tag',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrintableTag(
            orderCode: 'AMW-2026-0042',
            customerName: 'Jane Doe',
          ),
        ),
      ),
    );

    expect(find.text('AMW-2026-0042'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byType(QrDisplayWidget), findsOneWidget);
  });

  testWidgets('uses High error correction so a scuffed label still scans',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrintableTag(orderCode: 'AMW-2026-0042'),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.errorCorrectionLevel, equals(QrErrorCorrectLevel.H));
  });

  testWidgets('omits the customer line when no name is given', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrintableTag(orderCode: 'AMW-2026-0042'),
        ),
      ),
    );

    // Only the order code text is present, no stray empty customer label.
    expect(find.text('AMW-2026-0042'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captureTagPng returns non-empty PNG bytes for the boundary',
      (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PrintableTag(
              orderCode: 'AMW-2026-0042',
              customerName: 'Jane Doe',
              boundaryKey: boundaryKey,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    late Uint8List bytes;
    await tester.runAsync(() async {
      bytes = await captureTagPng(boundaryKey, pixelRatio: 2);
    });

    expect(bytes, isNotEmpty);
    // PNG magic number: 0x89 'P' 'N' 'G'.
    expect(bytes.sublist(0, 4), equals(<int>[0x89, 0x50, 0x4E, 0x47]));
  });

  testWidgets(
      'captureTagPng throws a clean TagCaptureException when the boundary is '
      'not mounted, not a null-check crash', (tester) async {
    final unattachedKey = GlobalKey(); // never put in the tree

    await expectLater(
      captureTagPng(unattachedKey),
      throwsA(isA<TagCaptureException>()),
    );
  });
}
