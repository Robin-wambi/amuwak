import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/proof/barcode_scanner_scaffold.dart';

void main() {
  testWidgets('renders the "Scan order tag" chrome around the given child',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BarcodeScannerScaffold(
        onClose: () {},
        child: const Text('CAMERA-BODY'),
      ),
    ));

    expect(find.text('Scan order tag'), findsOneWidget);
    expect(find.text('CAMERA-BODY'), findsOneWidget);
  });

  testWidgets('the close button invokes onClose', (tester) async {
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: BarcodeScannerScaffold(
        onClose: () => closed = true,
        child: const SizedBox(),
      ),
    ));

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });
}
