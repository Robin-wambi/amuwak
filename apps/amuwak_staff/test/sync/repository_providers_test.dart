import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/customers_repository.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';
import 'package:amuwak_staff/src/sync/staff_repository.dart';
import 'package:amuwak_staff/src/sync/outbox_repository.dart';
import 'package:amuwak_staff/src/sync/status_events_repository.dart';
import 'package:amuwak_staff/src/sync/sync_status.dart';

/// Online-only wiring: repositories resolve the Supabase client via
/// [supabaseClientProvider]. We override it with a mock so the test never
/// touches the uninitialised `Supabase.instance` singleton; the repo
/// constructors only store the client, so no stubbing is required.
class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      supabaseClientProvider.overrideWithValue(_MockSupabaseClient()),
      // outboxRepositoryProvider (offline, unused in online mode) still depends
      // on the DB; override it so its singleton test below doesn't open a file.
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('ordersRepositoryProvider resolves to an OrdersRepository singleton', () {
    final a = container.read(ordersRepositoryProvider);
    final b = container.read(ordersRepositoryProvider);
    expect(a, isA<OrdersRepository>());
    expect(identical(a, b), isTrue, reason: 'provider should cache the value');
  });

  test('customersRepositoryProvider resolves to a CustomersRepository singleton',
      () {
    final a = container.read(customersRepositoryProvider);
    final b = container.read(customersRepositoryProvider);
    expect(a, isA<CustomersRepository>());
    expect(identical(a, b), isTrue);
  });

  test('staffRepositoryProvider resolves to a StaffRepository singleton', () {
    final a = container.read(staffRepositoryProvider);
    final b = container.read(staffRepositoryProvider);
    expect(a, isA<StaffRepository>());
    expect(identical(a, b), isTrue);
  });

  test('proofEventsRepositoryProvider resolves to a ProofEventsRepository singleton',
      () {
    final a = container.read(proofEventsRepositoryProvider);
    final b = container.read(proofEventsRepositoryProvider);
    expect(a, isA<ProofEventsRepository>());
    expect(identical(a, b), isTrue);
  });

  test('statusEventsRepositoryProvider resolves to a StatusEventsRepository singleton',
      () {
    final a = container.read(statusEventsRepositoryProvider);
    final b = container.read(statusEventsRepositoryProvider);
    expect(a, isA<StatusEventsRepository>());
    expect(identical(a, b), isTrue);
  });

  test('outboxRepositoryProvider (offline, preserved) still resolves to a singleton',
      () {
    final a = container.read(outboxRepositoryProvider);
    final b = container.read(outboxRepositoryProvider);
    expect(a, isA<OutboxRepository>());
    expect(identical(a, b), isTrue);
  });
}
