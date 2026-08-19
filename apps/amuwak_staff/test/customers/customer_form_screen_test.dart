import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/customers/customer_form_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart' show Customer;

Customer _customer({
  required String id,
  required String name,
  required String phone,
  DateTime? createdAt,
  double? customRatePerKgUgx,
}) =>
    Customer(
      id: id,
      name: name,
      phone: phone,
      address: null,
      notes: null,
      customRatePerKgUgx: customRatePerKgUgx,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      updatedAt: createdAt ?? DateTime.utc(2026, 1, 1),
      deletedAt: null,
    );

/// A tall viewport for the tests that render the standing-rate field. The form
/// is a lazy ListView: the extra field pushes the save button past the default
/// 600px viewport, so it is never built and the finder reports "found 0"
/// rather than an off-screen hit-test failure. Mirrors `useTallViewport` in
/// new_pickup_rate_test.dart.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('add saves a customer with a generated id and trimmed fields',
      (tester) async {
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        idGenerator: () => 'new-id',
        clock: () => DateTime.utc(2026, 8, 14),
      ),
    ));

    await tester.enterText(
        find.byKey(const Key('customer_name')), '  Ada Lovelace ');
    await tester.enterText(
        find.byKey(const Key('customer_phone')), '0700123456');
    await tester.enterText(
        find.byKey(const Key('customer_address')), ' Ntinda ');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.id, 'new-id');
    expect(saved!.name, 'Ada Lovelace');
    expect(saved!.phone, '0700123456');
    expect(saved!.address, 'Ntinda');
  });

  testWidgets('rejects an empty name and does not save', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(save: (c) async => calls++),
    ));

    await tester.enterText(
        find.byKey(const Key('customer_phone')), '0700123456');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Enter the customer name.'), findsOneWidget);
  });

  testWidgets('rejects a phone that is not a valid number', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(save: (c) async => calls++),
    ));

    await tester.enterText(find.byKey(const Key('customer_name')), 'Ada');
    await tester.enterText(find.byKey(const Key('customer_phone')), '123');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Enter a valid phone number.'), findsOneWidget);
  });

  testWidgets('rejects a phone that duplicates an existing customer',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => calls++,
        // Same national number, different formatting (+256 vs leading 0).
        existingCustomers: [
          _customer(id: 'x', name: 'Existing', phone: '+256700123456'),
        ],
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_name')), 'Ada');
    await tester.enterText(
        find.byKey(const Key('customer_phone')), '0700123456');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.textContaining('already exists'), findsOneWidget);
  });

  testWidgets('edit prefills and preserves id and created date',
      (tester) async {
    Customer? saved;
    final existing = _customer(
      id: 'keep-id',
      name: 'Ada',
      phone: '0700123456',
      createdAt: DateTime.utc(2025, 3, 3),
    );
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: existing,
        clock: () => DateTime.utc(2026, 8, 14),
      ),
    ));

    expect(find.text('Ada'), findsOneWidget); // prefilled name
    await tester.enterText(find.byKey(const Key('customer_name')), 'Ada B');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.id, 'keep-id');
    expect(saved!.name, 'Ada B');
    expect(saved!.createdAt, DateTime.utc(2025, 3, 3));
    expect(saved!.updatedAt, DateTime.utc(2026, 8, 14));
  });

  testWidgets('hides the rate field when the user cannot edit rates',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(save: (c) async {}),
    ));

    expect(find.byKey(const Key('customer_rate')), findsNothing);
  });

  testWidgets('a non-manager save leaves an existing standing rate untouched',
      (tester) async {
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: _customer(
            id: 'keep-id',
            name: 'Ada',
            phone: '0700123456',
            customRatePerKgUgx: 4000),
      ),
    ));

    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.customRatePerKgUgx, 4000.0,
        reason: 'a user who cannot edit rates must not clear one by saving');
  });

  testWidgets('a manager can set a standing rate on an existing customer',
      (tester) async {
    useTallViewport(tester);
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: _customer(id: 'keep-id', name: 'Ada', phone: '0700123456'),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
        clock: () => DateTime.utc(2026, 8, 17),
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '4000');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.customRatePerKgUgx, 4000.0,
        reason: 'this is the gap S0 closes — the rate was previously '
            'unreachable once the customer existed');
  });

  testWidgets('a manager can clear a standing rate back to the default',
      (tester) async {
    useTallViewport(tester);
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: _customer(
            id: 'keep-id',
            name: 'Ada',
            phone: '0700123456',
            customRatePerKgUgx: 4000),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.customRatePerKgUgx, isNull,
        reason: 'an emptied field clears the override rather than keeping the '
            'old value');
  });

  testWidgets('a fractional rate is rounded to whole shillings',
      (tester) async {
    useTallViewport(tester);
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: _customer(id: 'keep-id', name: 'Ada', phone: '0700123456'),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '4000.7');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.customRatePerKgUgx, 4001.0);
  });

  testWidgets('refuses a rate that is not a usable number', (tester) async {
    useTallViewport(tester);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => calls++,
        existing: _customer(id: 'keep-id', name: 'Ada', phone: '0700123456'),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
      ),
    ));

    // Distinct from an empty field, which clears the override: a typed value
    // that cannot become a positive rate is a mistake, not an instruction.
    await tester.enterText(find.byKey(const Key('customer_rate')), '0');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.textContaining('greater than 0'), findsOneWidget);
  });

  testWidgets('refuses a rate below the configured floor', (tester) async {
    useTallViewport(tester);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => calls++,
        existing: _customer(id: 'keep-id', name: 'Ada', phone: '0700123456'),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
        minRatePctOfDefault: 60, // floor = 3000
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '2000');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.textContaining('below the minimum'), findsOneWidget);
  });
}
