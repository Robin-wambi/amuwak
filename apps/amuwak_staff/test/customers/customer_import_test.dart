import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/customers/customer_import.dart';
import 'package:amuwak_staff/src/data/app_database.dart' show Customer;

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
  group('parseCustomersCsv', () {
    test('parses a header row and maps name/phone/address columns', () {
      final r = parseCustomersCsv(
          'name,phone,address\nAda,0700111222,Ntinda\nGrace,0700333444,Kira');
      expect(r.errors, isEmpty);
      expect(r.rows.length, 2);
      expect(r.rows[0].name, 'Ada');
      expect(r.rows[0].phone, '0700111222');
      expect(r.rows[0].address, 'Ntinda');
      expect(r.rows[1].name, 'Grace');
    });

    test('parses positional columns when there is no header', () {
      final r = parseCustomersCsv('Ada,0700111222,Ntinda');
      expect(r.rows.single.name, 'Ada');
      expect(r.rows.single.phone, '0700111222');
      expect(r.rows.single.address, 'Ntinda');
    });

    test('handles quoted fields containing commas', () {
      final r = parseCustomersCsv(
          'name,phone,address\n"Doe, Jane",0700111222,"Plot 5, Ntinda"');
      expect(r.rows.single.name, 'Doe, Jane');
      expect(r.rows.single.address, 'Plot 5, Ntinda');
    });

    test('reports an invalid phone row and keeps the valid ones', () {
      final r = parseCustomersCsv('name,phone\nAda,0700111222\nBad,123');
      expect(r.rows.single.name, 'Ada');
      expect(r.errors.length, 1);
      expect(r.errors.single, contains('3')); // 1-based line number
    });

    test('reports a row missing a name', () {
      final r = parseCustomersCsv('name,phone\n,0700111222');
      expect(r.rows, isEmpty);
      expect(r.errors.single.toLowerCase(), contains('name'));
    });

    test('skips fully blank lines', () {
      final r = parseCustomersCsv('name,phone\nAda,0700111222\n\n');
      expect(r.rows.length, 1);
      expect(r.errors, isEmpty);
    });
  });

  group('planCustomerImport', () {
    test('dedupes against existing customers by national number', () {
      final rows = parseCustomersCsv(
              'name,phone\nAda,0700111222\nGrace,0700333444')
          .rows;
      final plan = planCustomerImport(
        rows,
        [_existing('e1', '+256700111222')], // same national number as Ada
        idGenerator: () => 'gen',
        now: () => DateTime.utc(2026, 8, 14),
      );
      expect(plan.duplicatesExisting, 1);
      expect(plan.toImport.length, 1);
      expect(plan.toImport.single.name, 'Grace');
      expect(plan.toImport.single.createdAt, DateTime.utc(2026, 8, 14));
    });

    test('dedupes repeats within the same file', () {
      final rows =
          parseCustomersCsv('name,phone\nAda,0700111222\nAda2,+256700111222')
              .rows;
      final plan = planCustomerImport(
        rows,
        const [],
        idGenerator: () => 'gen',
        now: () => DateTime.utc(2026, 8, 14),
      );
      expect(plan.toImport.length, 1);
      expect(plan.duplicatesInFile, 1);
    });
  });
}
