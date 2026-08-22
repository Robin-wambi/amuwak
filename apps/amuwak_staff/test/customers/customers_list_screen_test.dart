import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/customers/customers_list_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart' show Customer;

Customer _customer(
  String id,
  String name,
  String phone, {
  String? address,
  String? notes,
  double? customRatePerKgUgx,
}) =>
    Customer(
      id: id,
      name: name,
      phone: phone,
      address: address,
      notes: notes,
      customRatePerKgUgx: customRatePerKgUgx,
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

  testWidgets('shows a standing-rate chip when customRatePerKgUgx is set',
      (tester) async {
    await tester.pumpWidget(_host(CustomersListView(customers: [
      _customer('a', 'Ada Lovelace', '0700111222',
          customRatePerKgUgx: 3500.6),
    ])));

    // Rounds like customer_form_screen.dart's rate field does (.round()),
    // and reuses formatUgx as-is rather than re-prefixing "USh " (formatUgx
    // already includes it).
    expect(find.text('${formatUgx(3501)}/kg'), findsOneWidget);
    expect(find.byKey(const Key('customer_rate_chip_a')), findsOneWidget);
  });

  testWidgets('hides the standing-rate chip when customRatePerKgUgx is null',
      (tester) async {
    await tester.pumpWidget(_host(CustomersListView(customers: [
      _customer('a', 'Ada Lovelace', '0700111222'),
    ])));

    expect(find.byKey(const Key('customer_rate_chip_a')), findsNothing);
  });

  testWidgets('shows a notes indicator when notes is non-blank',
      (tester) async {
    await tester.pumpWidget(_host(CustomersListView(customers: [
      _customer('a', 'Ada Lovelace', '0700111222', notes: 'Fragile items'),
    ])));

    expect(
        find.byKey(const Key('customer_notes_indicator_a')), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    // Progressive disclosure: the icon appears, but not the note text itself.
    expect(find.text('Fragile items'), findsNothing);
  });

  testWidgets('hides the notes indicator when notes is null or blank',
      (tester) async {
    await tester.pumpWidget(_host(CustomersListView(customers: [
      _customer('a', 'Ada Lovelace', '0700111222'),
      _customer('b', 'Grace Hopper', '0700333444', notes: '   '),
    ])));

    expect(find.byKey(const Key('customer_notes_indicator_a')), findsNothing);
    expect(find.byKey(const Key('customer_notes_indicator_b')), findsNothing);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
  });
}
