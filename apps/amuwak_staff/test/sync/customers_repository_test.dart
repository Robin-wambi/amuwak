import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/customers_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit-tests [CustomersRepository.upsertCustomer] through the
/// [CustomersRepository.forTest] seam: the dispatched column map and the
/// write-did-not-persist [StateError] guard, without a live SupabaseClient.
/// Mirrors orders_repository_mutations_test.dart — a customer write that an RLS
/// policy silently drops must surface as an error, never a false "saved".
void main() {
  final clock = DateTime.utc(2026, 6, 24, 10, 30);

  Customer customer({String id = 'c1'}) => Customer(
        id: id,
        name: 'Ada',
        phone: '0700',
        address: '12 Kira Rd',
        notes: 'gate code 4',
        createdAt: DateTime.utc(2026, 6, 1, 8),
        updatedAt: DateTime.utc(2026, 6, 1, 8),
        deletedAt: null,
      );

  /// A repo whose upsert dispatch records the column map and reports whether the
  /// write persisted (empty rows ⇒ nothing written ⇒ StateError).
  CustomersRepository repoThatUpserts({
    required void Function(Map<String, dynamic> values) record,
    bool persisted = true,
  }) =>
      CustomersRepository.forTest(
        clock: () => clock,
        upsertRow: (values) async {
          record(values);
          return persisted ? [<String, dynamic>{'id': values['id']}] : const [];
        },
      );

  group('upsertCustomer', () {
    test('dispatches the customer upsert payload', () async {
      late Map<String, dynamic> values;
      final repo = repoThatUpserts(record: (v) => values = v);

      await repo.upsertCustomer(customer());

      expect(values['id'], 'c1');
      expect(values['name'], 'Ada');
      expect(values['phone'], '0700');
      expect(values['updated_at'], '2026-06-24T10:30:00.000Z');
    });

    test('throws StateError when the write did not persist', () async {
      final repo = repoThatUpserts(record: (_) {}, persisted: false);
      expect(
        () => repo.upsertCustomer(customer()),
        throwsStateError,
      );
    });

    test('a forTest instance without upsertRow trips a descriptive assert',
        () async {
      final repo = CustomersRepository.forTest(clock: () => clock);
      expect(
        () => repo.upsertCustomer(customer()),
        throwsA(isA<AssertionError>()
            .having((e) => e.message, 'message', contains('upsertRow'))),
      );
    });
  });
}
