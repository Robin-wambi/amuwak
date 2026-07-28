import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/auth/sign_out.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator.dart';

class _MockOrchestrator extends Mock implements SyncOrchestrator {}

class _MockAuthService extends Mock implements AuthService {}

Future<void> _seedAllTables(AppDatabase db) async {
  final now = DateTime.utc(2026, 5, 19, 10, 0);
  await db.into(db.staff).insert(StaffCompanion.insert(
        id: 's-1',
        username: 'alice',
        displayName: 'Alice',
        role: 'driver',
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.customers).insert(CustomersCompanion.insert(
        id: 'c-1',
        name: 'Sarah',
        phone: '+256',
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.orders).insert(OrdersCompanion.insert(
        id: 'AMW-A',
        orderCode: 'AMW-A',
        customerName: 'Sarah',
        phone: '+256',
        address: 'addr',
        serviceType: ServiceType.washOnly.toDbString(),
        status: 'in_progress',
        intakeMethod: 'driver_pickup',
        fulfillmentMethod: 'delivery',
        itemCount: 3,
        intakeRecordedBy: 's-1',
        createdBy: 's-1',
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
  await db.into(db.orderStatusEvents).insert(OrderStatusEventsCompanion.insert(
        id: 'se-1',
        orderId: 'AMW-A',
        toStatus: 'in_progress',
        changedBy: 's-1',
        changedAt: now,
        source: 'mobile',
      ));
  await db.into(db.proofEvents).insert(ProofEventsCompanion.insert(
        id: 'pe-1',
        orderId: 'AMW-A',
        type: 'pickup',
        capturedAt: now,
        itemCount: 3,
        capturedBy: 's-1',
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.proofPhotos).insert(ProofPhotosCompanion.insert(
        id: 'pp-1',
        proofEventId: 'pe-1',
        storagePath: 'proofs/pp-1.jpg',
        createdAt: now,
      ));
  await db.into(db.issues).insert(IssuesCompanion.insert(
        id: 'iss-1',
        kind: 'missing_item',
        description: 'one sock',
        reportedBy: 's-1',
        reportedAt: now,
      ));
  await db.into(db.shifts).insert(ShiftsCompanion.insert(
        id: 'sh-1',
        staffId: 's-1',
        startedAt: now,
      ));
  await db.into(db.validTransitions).insert(ValidTransitionsCompanion.insert(
        id: 'vt-1',
        intakeMethod: 'walk_in',
        fulfillmentMethod: 'customer_collect',
        toStatus: 'received',
      ));
  await db.into(db.outbox).insert(OutboxCompanion.insert(
        id: 'ob-1',
        forTable: 'customers',
        op: 'insert',
        rowId: 'c-1',
        payloadJson: '{}',
        createdAt: Value(now),
      ));
  await db.into(db.syncWatermarks).insert(SyncWatermarksCompanion.insert(
        forTable: 'customers',
        lastSyncedAt: now,
      ));
  await db.into(db.pullDeadLetter).insert(PullDeadLetterCompanion.insert(
        id: 'orders:bad-row:1',
        forTable: 'orders',
        rowPayloadJson: '{"id":"bad-row"}',
        errorText: 'null value in non-null column',
      ));
}

Future<List<int>> _rowCounts(AppDatabase db) async => Future.wait([
      db.select(db.staff).get().then((r) => r.length),
      db.select(db.customers).get().then((r) => r.length),
      db.select(db.orders).get().then((r) => r.length),
      db.select(db.orderStatusEvents).get().then((r) => r.length),
      db.select(db.proofEvents).get().then((r) => r.length),
      db.select(db.proofPhotos).get().then((r) => r.length),
      db.select(db.issues).get().then((r) => r.length),
      db.select(db.shifts).get().then((r) => r.length),
      db.select(db.validTransitions).get().then((r) => r.length),
      db.select(db.outbox).get().then((r) => r.length),
      db.select(db.syncWatermarks).get().then((r) => r.length),
      db.select(db.pullDeadLetter).get().then((r) => r.length),
    ]);

void main() {
  late AppDatabase db;
  late _MockOrchestrator orchestrator;
  late _MockAuthService authService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    orchestrator = _MockOrchestrator();
    authService = _MockAuthService();
    when(() => orchestrator.stop()).thenAnswer((_) async {});
    when(() => authService.signOut()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  test('truncates every tracked Drift table', () async {
    await _seedAllTables(db);
    final beforeCounts = await _rowCounts(db);
    expect(beforeCounts.every((c) => c == 1), isTrue,
        reason: 'seeded one row per table');

    await signOutAndReset(
      orchestrator: orchestrator,
      db: db,
      auth: authService,
    );

    final afterCounts = await _rowCounts(db);
    expect(afterCounts.every((c) => c == 0), isTrue,
        reason: 'every tracked table should be empty after sign out');
  });

  test('calls orchestrator.stop() and AuthService.signOut() exactly once',
      () async {
    await signOutAndReset(
      orchestrator: orchestrator,
      db: db,
      auth: authService,
    );

    verify(() => orchestrator.stop()).called(1);
    verify(() => authService.signOut()).called(1);
  });

  test('ordering: orchestrator.stop runs before truncate, truncate before '
      'signOut', () async {
    final calls = <String>[];
    when(() => orchestrator.stop()).thenAnswer((_) async {
      calls.add('stop');
    });
    when(() => authService.signOut()).thenAnswer((_) async {
      calls.add('signOut');
      // Capture row counts at the moment signOut is invoked to verify
      // truncate already ran.
      final counts = await _rowCounts(db);
      calls.add('truncated=${counts.every((c) => c == 0)}');
    });
    await _seedAllTables(db);

    await signOutAndReset(
      orchestrator: orchestrator,
      db: db,
      auth: authService,
    );

    expect(calls, ['stop', 'signOut', 'truncated=true']);
  });

  test('completes even when there is nothing to truncate', () async {
    // No seeding — every table is already empty.
    await expectLater(
      signOutAndReset(orchestrator: orchestrator, db: db, auth: authService),
      completes,
    );
    verify(() => orchestrator.stop()).called(1);
    verify(() => authService.signOut()).called(1);
  });
}
