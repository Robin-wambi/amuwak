import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/payment/record_payment_sheet.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int amountDueUgx,
  required RecordPaymentFn onConfirm,
}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: RecordPaymentSheet(
        amountDueUgx: amountDueUgx,
        onConfirm: onConfirm,
      ),
    ),
  ));
}

void main() {
  group('RecordPaymentSheet', () {
    testWidgets('shows the amount due', (tester) async {
      await _pump(tester, amountDueUgx: 10000, onConfirm: (_) async {});
      expect(find.text('USh 10,000'), findsWidgets);
    });

    testWidgets('overpayment shows change due', (tester) async {
      await _pump(tester, amountDueUgx: 10000, onConfirm: (_) async {});
      await tester.enterText(find.byKey(const Key('cash_tendered')), '12000');
      await tester.pump();
      expect(find.byKey(const Key('change_due')), findsOneWidget);
      expect(find.text('USh 2,000'), findsWidgets);
      expect(find.byKey(const Key('remaining_balance')), findsNothing);
    });

    testWidgets('underpayment shows remaining balance + partial notice',
        (tester) async {
      await _pump(tester, amountDueUgx: 10000, onConfirm: (_) async {});
      await tester.enterText(find.byKey(const Key('cash_tendered')), '4000');
      await tester.pump();
      expect(find.byKey(const Key('remaining_balance')), findsOneWidget);
      expect(find.text('USh 6,000'), findsWidgets);
      expect(find.textContaining('Partial'), findsOneWidget);
      expect(find.byKey(const Key('change_due')), findsNothing);
    });

    testWidgets('a quick-tender note fills the tendered field', (tester) async {
      await _pump(tester, amountDueUgx: 10000, onConfirm: (_) async {});
      await tester.tap(find.byKey(const Key('quick_tender_5000')));
      await tester.pump();
      // 5,000 tendered against 10,000 due → 5,000 still owed.
      expect(find.byKey(const Key('remaining_balance')), findsOneWidget);
      expect(find.text('USh 5,000'), findsWidgets);
    });

    testWidgets('Confirm reports the applied amount (capped at due)',
        (tester) async {
      int? applied;
      await _pump(
        tester,
        amountDueUgx: 10000,
        onConfirm: (a) async => applied = a,
      );
      await tester.enterText(find.byKey(const Key('cash_tendered')), '12000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('record_payment_confirm')));
      await tester.pump();
      expect(applied, 10000);
    });

    testWidgets('Confirm is disabled until something would be applied',
        (tester) async {
      await _pump(tester, amountDueUgx: 10000, onConfirm: (_) async {});
      final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('record_payment_confirm')));
      expect(button.onPressed, isNull);
    });
  });
}
