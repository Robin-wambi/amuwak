import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/expenses/expense.dart';
import 'package:amuwak_staff/src/expenses/expense_entry_screen.dart';

void main() {
  testWidgets('saving records the chosen category, amount and note',
      (tester) async {
    Expense? saved;

    await tester.pumpWidget(MaterialApp(
      home: ExpenseEntryScreen(
        save: (e) async => saved = e,
        idGenerator: () => 'fixed-id',
        clock: () => DateTime.utc(2026, 6, 17, 12),
      ),
    ));

    await tester.tap(find.text(ExpenseCategory.fuel.label));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('expense_amount')), '15000');
    await tester.enterText(find.byKey(const Key('expense_note')), 'boda');
    await tester.tap(find.byKey(const Key('expense_save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.category, ExpenseCategory.fuel);
    expect(saved!.amountUgx, 15000);
    expect(saved!.note, 'boda');
    expect(saved!.id, 'fixed-id');
    expect(saved!.spentAt, DateTime.utc(2026, 6, 17, 12));
  });

  testWidgets('defaults to the first category when none is tapped',
      (tester) async {
    Expense? saved;

    await tester.pumpWidget(MaterialApp(
      home: ExpenseEntryScreen(save: (e) async => saved = e),
    ));

    await tester.enterText(find.byKey(const Key('expense_amount')), '8000');
    await tester.tap(find.byKey(const Key('expense_save')));
    await tester.pumpAndSettle();

    expect(saved!.category, ExpenseCategory.detergent);
    expect(saved!.amountUgx, 8000);
  });

  testWidgets('rejects a non-positive amount and does not save',
      (tester) async {
    var calls = 0;

    await tester.pumpWidget(MaterialApp(
      home: ExpenseEntryScreen(save: (e) async => calls++),
    ));

    await tester.enterText(find.byKey(const Key('expense_amount')), '0');
    await tester.tap(find.byKey(const Key('expense_save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Enter an amount greater than 0.'), findsOneWidget);
  });

  testWidgets(
    'a successful save pops true when pushed onto a navigator',
    (tester) async {
      // Covers the Navigator.canPop()/pop(true) branch: when the form sits on a
      // route that can pop, a successful save returns true to the caller.
      bool? popped;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ExpenseEntryScreen(
                          save: (e) async {},
                          idGenerator: () => 'fixed-id',
                          clock: () => DateTime.utc(2026, 6, 17, 12),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense_amount')), '15000');
      await tester.tap(find.byKey(const Key('expense_save')));
      await tester.pumpAndSettle();

      // Popped back to the launcher with `true`.
      expect(find.text('Open'), findsOneWidget);
      expect(popped, isTrue);
    },
  );

  testWidgets(
    'a failing save surfaces a retry SnackBar and stays on the form',
    (tester) async {
      // Covers the catch block: save throws → friendly SnackBar, no pop, and the
      // Save button is re-enabled (the finally clears _saving).
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseEntryScreen(
            save: (e) async => throw Exception('network down'),
            idGenerator: () => 'fixed-id',
            clock: () => DateTime.utc(2026, 6, 17, 12),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('expense_amount')), '15000');
      await tester.tap(find.byKey(const Key('expense_save')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ExpenseEntryScreen), findsOneWidget);
      expect(find.text('Could not save — please retry.'), findsOneWidget);
      expect(find.textContaining('network down'), findsNothing);

      // Re-enabled after the failure (back to the 'Save' label, not a spinner).
      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('expense_save')),
      );
      expect(saveButton.onPressed, isNotNull);
    },
  );
}
