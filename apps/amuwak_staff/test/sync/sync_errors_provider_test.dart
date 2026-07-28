import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';
import 'package:amuwak_staff/src/sync/sync_errors_provider.dart';
import 'package:amuwak_staff/src/sync/sync_status.dart';

void main() {
  test(
    'syncErrorCountProvider sums outbox dead-letters + pull dead-letters',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      // Seed 2 outbox dead-letters.
      final outbox = container.read(outboxRepositoryProvider);
      for (final id in ['a', 'b']) {
        await outbox.enqueue(
          id: id, forTable: 'orders', op: 'update', rowId: id,
          payload: const {},
        );
        for (var i = 0; i < 6; i++) {
          await outbox.markFailed(id, 'boom');
        }
      }
      // Seed 3 pull dead-letters.
      final dlq = container.read(pullDeadLetterRepositoryProvider);
      for (var i = 0; i < 3; i++) {
        await dlq.insert(
          forTable: 'orders',
          rowPayload: <String, dynamic>{'id': 'p-$i'},
          errorText: 'mapper boom',
        );
      }

      // Subscribe to both underlying streams first so the derived provider
      // resolves to a concrete value rather than its `?? const []` fallback.
      await container.read(outboxDeadLetteredProvider.future);
      await container.read(pullDeadLetteredProvider.future);

      expect(container.read(syncErrorCountProvider), 5);
    },
  );

  test(
    'syncErrorCountProvider returns 0 while underlying streams are loading',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      // Don't await the futures — the streams haven't emitted yet.
      expect(container.read(syncErrorCountProvider), 0);
    },
  );
}
