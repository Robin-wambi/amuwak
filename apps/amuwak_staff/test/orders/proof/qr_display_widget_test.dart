import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:amuwak_staff/src/orders/proof/qr_display_widget.dart';

void main() {
  testWidgets('QrDisplayWidget renders a QrImageView with the given data',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(data: 'AMW-0421', size: 200),
        ),
      ),
    );

    final qrFinder = find.byType(QrImageView);
    expect(qrFinder, findsOneWidget);

    final qr = tester.widget<QrImageView>(qrFinder);
    expect(qr.size, equals(200));
  });

  testWidgets(
      'defaults to high error correction, a quiet-zone padding, and gapless '
      'rendering so printed bag tags stay scannable when scuffed or damp',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(data: 'AMW-2026-0042'),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.errorCorrectionLevel, equals(QrErrorCorrectLevel.H));
    expect(qr.padding, equals(const EdgeInsets.all(16)));
    expect(qr.gapless, isTrue);
  });

  testWidgets(
      'lets callers override the error correction level for denser symbols',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(
            data: 'AMW-2026-0042',
            errorCorrectionLevel: QrErrorCorrectLevel.Q,
          ),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.errorCorrectionLevel, equals(QrErrorCorrectLevel.Q));
  });

  testWidgets('exposes a semantics label referencing the order code',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(data: 'AMW-2026-0042'),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, contains('AMW-2026-0042'));
  });

  testWidgets(
      'errorStateBuilder falls back to the raw code as text so staff can still '
      'read it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(data: 'AMW-2026-0042', size: 180),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));

    // Render the fallback in isolation and confirm it surfaces the code.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: qr.errorStateBuilder!(
            tester.element(find.byType(QrImageView)),
            'boom',
          ),
        ),
      ),
    );
    expect(find.text('AMW-2026-0042'), findsOneWidget);
  });

  testWidgets(
      'fallback centers the code and scales it down so a long order code never '
      'overflows the tag box', (tester) async {
    const longCode = 'AMW-2026-0042-REPRINT-BATCH-7-OVERSIZED-CODE-1234567890';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(data: longCode, size: 120),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: qr.errorStateBuilder!(
            tester.element(find.byType(QrImageView)),
            'boom',
          ),
        ),
      ),
    );

    // No layout overflow should be reported for an oversized code.
    expect(tester.takeException(), isNull);

    final text = tester.widget<Text>(find.text(longCode));
    expect(text.textAlign, equals(TextAlign.center));
  });

  testWidgets(
      'fallback paints a white background so the code stays readable on any '
      'scaffold', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(data: 'AMW-2026-0042'),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: qr.errorStateBuilder!(
            tester.element(find.byType(QrImageView)),
            'boom',
          ),
        ),
      ),
    );

    final coloredBox = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: find.text('AMW-2026-0042'),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(coloredBox.color, equals(Colors.white));
  });

  testWidgets(
      'fallback logs the render error and order code so failures are not '
      'silently swallowed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayWidget(data: 'AMW-2026-0042'),
        ),
      ),
    );

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));

    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {int? wrapWidth}) => logs.add(message ?? '');
    try {
      qr.errorStateBuilder!(
        tester.element(find.byType(QrImageView)),
        'boom',
      );
    } finally {
      debugPrint = originalDebugPrint;
    }

    expect(
      logs.any((line) => line.contains('boom') && line.contains('AMW-2026-0042')),
      isTrue,
    );
  });
}
