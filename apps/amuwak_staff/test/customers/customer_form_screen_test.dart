import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/customers/customer_form_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart' show Customer;

Customer _customer({
  required String id,
  required String name,
  required String phone,
  DateTime? createdAt,
}) =>
    Customer(
      id: id,
      name: name,
      phone: phone,
      address: null,
      notes: null,
      customRatePerKgUgx: null,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      updatedAt: createdAt ?? DateTime.utc(2026, 1, 1),
      deletedAt: null,
    );

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
}
