import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/customers/customer_import_screen.dart';
import 'package:amuwak_staff/src/data/app_database.dart' show Customer;

String Function() _counter() {
  var i = 0;
  return () => 'id-${i++}';
}

Customer _existing(String id, String phone) => Customer(
      id: id,
      name: 'Existing',
      phone: phone,
      address: null,
      notes: null,
      customRatePerKgUgx: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      deletedAt: null,
    );

void main() {
  testWidgets('picks a CSV, previews the count, and imports the parsed rows',
      (tester) async {
    List<Customer>? imported;
    await tester.pumpWidget(MaterialApp(
      home: CustomerImportScreen(
        pickCsvText: () async => 'name,phone\nAda,0700111222\nGrace,0700333444',
        loadExisting: () async => const [],
        importCustomers: (list) async {
          imported = list;
          return list.length;
        },
        idGenerator: _counter(),
        clock: () => DateTime.utc(2026, 8, 14),
      ),
    ));

    await tester.tap(find.byKey(const Key('import_choose_file')));
    await tester.pumpAndSettle();

    expect(find.text('2 ready to import'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import_confirm')));
    await tester.pumpAndSettle();

    expect(imported, isNotNull);
    expect(imported!.length, 2);
  });

  testWidgets('excludes duplicates of existing customers and reports them',
      (tester) async {
    List<Customer>? imported;
    await tester.pumpWidget(MaterialApp(
      home: CustomerImportScreen(
        pickCsvText: () async => 'name,phone\nAda,0700111222\nGrace,0700333444',
        loadExisting: () async => [_existing('e', '+256700111222')],
        importCustomers: (list) async {
          imported = list;
          return list.length;
        },
        idGenerator: _counter(),
        clock: () => DateTime.utc(2026, 8, 14),
      ),
    ));

    await tester.tap(find.byKey(const Key('import_choose_file')));
    await tester.pumpAndSettle();

    expect(find.text('1 ready to import'), findsOneWidget);
    expect(find.textContaining('duplicate'), findsWidgets);

    await tester.tap(find.byKey(const Key('import_confirm')));
    await tester.pumpAndSettle();

    expect(imported!.length, 1);
    expect(imported!.single.name, 'Grace');
  });

  testWidgets('reports invalid rows and imports only the valid ones',
      (tester) async {
    List<Customer>? imported;
    await tester.pumpWidget(MaterialApp(
      home: CustomerImportScreen(
        pickCsvText: () async => 'name,phone\nAda,0700111222\nBad,123',
        loadExisting: () async => const [],
        importCustomers: (list) async {
          imported = list;
          return list.length;
        },
        idGenerator: _counter(),
        clock: () => DateTime.utc(2026, 8, 14),
      ),
    ));

    await tester.tap(find.byKey(const Key('import_choose_file')));
    await tester.pumpAndSettle();

    expect(find.text('1 ready to import'), findsOneWidget);
    expect(find.textContaining('invalid phone'), findsWidgets);

    await tester.tap(find.byKey(const Key('import_confirm')));
    await tester.pumpAndSettle();

    expect(imported!.length, 1);
  });

  testWidgets('offers nothing to import when no row is valid', (tester) async {
    var importCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: CustomerImportScreen(
        pickCsvText: () async => 'name,phone\n,123',
        loadExisting: () async => const [],
        importCustomers: (list) async {
          importCalls++;
          return 0;
        },
      ),
    ));

    await tester.tap(find.byKey(const Key('import_choose_file')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import_confirm')), findsNothing);
    expect(find.text('0 ready to import'), findsOneWidget);
    expect(importCalls, 0);
  });
}
