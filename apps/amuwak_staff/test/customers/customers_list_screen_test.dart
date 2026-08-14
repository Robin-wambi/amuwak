import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/customers/customers_list_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart' show Customer;

Customer _customer(String id, String name, String phone, {String? address}) =>
    Customer(
      id: id,
      name: name,
      phone: phone,
      address: address,
      notes: null,
      customRatePerKgUgx: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      deletedAt: null,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('lists each customer with name and phone', (tester) async {
    await tester.pumpWidget(_host(CustomersListView(customers: [
      _customer('a', 'Ada Lovelace', '0700111222'),
      _customer('b', 'Grace Hopper', '0700333444'),
    ])));

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('0700111222'), findsOneWidget);
  });

  testWidgets('search filters by name, case-insensitively', (tester) async {
    await tester.pumpWidget(_host(CustomersListView(customers: [
      _customer('a', 'Ada Lovelace', '0700111222'),
      _customer('b', 'Grace Hopper', '0700333444'),
    ])));

    await tester.enterText(find.byKey(const Key('customer_search')), 'grace');
    await tester.pump();

    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('search filters by phone digits', (tester) async {
    await tester.pumpWidget(_host(CustomersListView(customers: [
      _customer('a', 'Ada Lovelace', '0700111222'),
      _customer('b', 'Grace Hopper', '0700333444'),
    ])));

    await tester.enterText(find.byKey(const Key('customer_search')), '333');
    await tester.pump();

    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('empty list shows the empty state with Add and Import CTAs',
      (tester) async {
    var add = 0, imp = 0;
    await tester.pumpWidget(_host(CustomersListView(
      customers: const [],
      onAddCustomer: () => add++,
      onImport: () => imp++,
    )));

    expect(find.text('Your customer list is empty'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customers_empty_add')));
    await tester.tap(find.byKey(const Key('customers_empty_import')));
    await tester.pump();
    expect(add, 1);
    expect(imp, 1);
  });

  testWidgets('tapping a customer fires onCustomerTap', (tester) async {
    Customer? tapped;
    await tester.pumpWidget(_host(CustomersListView(
      customers: [_customer('a', 'Ada Lovelace', '0700111222')],
      onCustomerTap: (c) => tapped = c,
    )));

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pump();

    expect(tapped?.id, 'a');
  });

  testWidgets('hides Add and Import when not manageable', (tester) async {
    await tester.pumpWidget(_host(CustomersListView(
      customers: const [],
      onAddCustomer: () {},
      onImport: () {},
      canManage: false,
    )));

    expect(find.byKey(const Key('customers_add')), findsNothing);
    expect(find.byKey(const Key('customers_import')), findsNothing);
    expect(find.byKey(const Key('customers_empty_add')), findsNothing);
    expect(find.byKey(const Key('customers_empty_import')), findsNothing);
  });
}
