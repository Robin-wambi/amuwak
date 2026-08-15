import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/customers_repository.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';

/// The repo constructor only stores the client (no calls), so a bare mock is
/// enough to satisfy `super(...)` on the fake below.
class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// A repository whose customer stream we drive, so the test can assert
/// [customersStreamProvider] surfaces exactly what `watchAll()` emits.
class _FakeCustomersRepository extends CustomersRepository {
  _FakeCustomersRepository(this._stream) : super(_MockSupabaseClient());

  final Stream<List<Customer>> _stream;

  @override
  Stream<List<Customer>> watchAll() => _stream;
}

void main() {
  test('customersStreamProvider surfaces the repository watchAll stream',
      () async {
    final now = DateTime.utc(2026, 8, 13);
    final ada = Customer(
      id: 'c1',
      name: 'Ada',
      phone: '0700000000',
      address: null,
      notes: null,
      customRatePerKgUgx: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    final controller = StreamController<List<Customer>>();
    addTearDown(controller.close);

    final container = ProviderContainer(overrides: [
      customersRepositoryProvider
          .overrideWithValue(_FakeCustomersRepository(controller.stream)),
    ]);
    addTearDown(container.dispose);

    // Read once to start the subscription, then feed a value through the repo.
    container.read(customersStreamProvider);
    controller.add([ada]);

    final value = await container.read(customersStreamProvider.future);
    expect(value, [ada]);
  });
}
