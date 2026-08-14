import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart' show Customer;
import 'package:amuwak_staff/src/sync/customers_repository.dart';

Customer _customer(String id, String name, String phone) => Customer(
      id: id,
      name: name,
      phone: phone,
      address: null,
      notes: null,
      customRatePerKgUgx: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      deletedAt: null,
    );

void main() {
  test('importCustomers upserts one payload per customer and returns the count',
      () async {
    List<Map<String, dynamic>>? captured;
    final repo = CustomersRepository.forTest(
      clock: () => DateTime.utc(2026, 8, 14),
      bulkUpsertRows: (values) async {
        captured = values;
        // Mimic Supabase returning the written ids.
        return values
            .map((v) => <String, dynamic>{'id': v['id']})
            .toList();
      },
    );

    final written = await repo.importCustomers([
      _customer('a', 'Ada', '0700111222'),
      _customer('b', 'Grace', '0700333444'),
    ]);

    expect(written, 2);
    expect(captured, isNotNull);
    expect(captured!.length, 2);
    expect(captured![0]['id'], 'a');
    expect(captured![0]['name'], 'Ada');
    expect(captured![1]['phone'], '0700333444');
  });

  test('importCustomers on an empty list writes nothing', () async {
    var calls = 0;
    final repo = CustomersRepository.forTest(
      clock: () => DateTime.utc(2026, 8, 14),
      bulkUpsertRows: (values) async {
        calls++;
        return const [];
      },
    );

    final written = await repo.importCustomers(const []);

    expect(written, 0);
    expect(calls, 0);
  });
}
