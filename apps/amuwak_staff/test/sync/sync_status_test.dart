import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/sync_status.dart';

Future<void> _writeWatermark(
  AppDatabase db, {
  required String table,
  required DateTime at,
}) async {
  await db.into(db.syncWatermarks).insertOnConflictUpdate(
        SyncWatermarksCompanion.insert(forTable: table, lastSyncedAt: at),
      );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('lastSyncedAtProvider', () {
    test('emits null when sync_watermarks is empty', () async {
      final value = await container.read(lastSyncedAtProvider.future);
      expect(value, isNull);
    });

    test('emits the maximum lastSyncedAt across all watermark rows',
        () async {
      await _writeWatermark(db,
          table: 'customers', at: DateTime.utc(2026, 5, 19, 10, 0));
      await _writeWatermark(db,
          table: 'orders', at: DateTime.utc(2026, 5, 19, 14, 30));
      await _writeWatermark(db,
          table: 'staff', at: DateTime.utc(2026, 5, 19, 12, 0));

      final value = await container.read(lastSyncedAtProvider.future);
      expect(value, isNotNull);
      expect(value!.toUtc().toIso8601String(), '2026-05-19T14:30:00.000Z');
    });

    test('re-emits when a newer watermark is written', () async {
      await _writeWatermark(db,
          table: 'customers', at: DateTime.utc(2026, 5, 19, 10, 0));

      final emissions = <DateTime?>[];
      final sub = container.listen<AsyncValue<DateTime?>>(
        lastSyncedAtProvider,
        (_, next) {
          final v = next.valueOrNull;
          if (next.hasValue) emissions.add(v);
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Wait for the initial emission.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions, isNotEmpty);
      expect(emissions.last!.toUtc().toIso8601String(),
          '2026-05-19T10:00:00.000Z');

      await _writeWatermark(db,
          table: 'orders', at: DateTime.utc(2026, 5, 19, 16, 0));

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(emissions.last!.toUtc().toIso8601String(),
          '2026-05-19T16:00:00.000Z');
    });
  });

  group('syncStatusProvider', () {
    test('reads lastSyncedAt from lastSyncedAtProvider, not from null',
        () async {
      await _writeWatermark(db,
          table: 'customers', at: DateTime.utc(2026, 5, 19, 11, 15));

      // Wait for the underlying stream provider to populate.
      await container.read(lastSyncedAtProvider.future);
      final status = container.read(syncStatusProvider);

      expect(status.lastSyncedAt, isNotNull);
      expect(status.lastSyncedAt!.toUtc().toIso8601String(),
          '2026-05-19T11:15:00.000Z');
    });

    test('lastSyncedAt is null on an empty DB', () async {
      await container.read(lastSyncedAtProvider.future);
      final status = container.read(syncStatusProvider);
      expect(status.lastSyncedAt, isNull);
    });
  });
}
