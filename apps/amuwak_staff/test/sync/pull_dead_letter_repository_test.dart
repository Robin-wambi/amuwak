import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/pull_dead_letter_repository.dart';

void main() {
  late AppDatabase db;
  late PullDeadLetterRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PullDeadLetterRepository(db);
  });
  tearDown(() async => db.close());

  test('insert + watchAll round-trip', () async {
    await repo.insert(
      forTable: 'orders',
      rowPayload: <String, dynamic>{'id': 'AMW-X', 'status': null},
      errorText: 'TypeError: null is not a String',
      recordedAt: DateTime.utc(2026, 5, 23, 12, 0),
    );

    final rows = await repo.watchAll().first;
    expect(rows, hasLength(1));
    expect(rows.single.forTable, 'orders');
    expect(rows.single.errorText, contains('TypeError'));
  });

  test(
    'two inserts with same forTable + rowId but different recordedAt land both',
    () async {
      await repo.insert(
        forTable: 'orders',
        rowPayload: <String, dynamic>{'id': 'AMW-X'},
        errorText: 'err 1',
        recordedAt: DateTime.utc(2026, 5, 23, 12, 0),
      );
      await repo.insert(
        forTable: 'orders',
        rowPayload: <String, dynamic>{'id': 'AMW-X'},
        errorText: 'err 2',
        recordedAt: DateTime.utc(2026, 5, 23, 12, 0, 0, 1),
      );

      final rows = await repo.watchAll().first;
      expect(rows, hasLength(2));
    },
  );

  test(
    'watchAll orders newest-first by recordedAt',
    () async {
      await repo.insert(
        forTable: 'orders',
        rowPayload: <String, dynamic>{'id': 'AMW-OLD'},
        errorText: 'old',
        recordedAt: DateTime.utc(2026, 5, 22),
      );
      await repo.insert(
        forTable: 'orders',
        rowPayload: <String, dynamic>{'id': 'AMW-NEW'},
        errorText: 'new',
        recordedAt: DateTime.utc(2026, 5, 23),
      );

      final rows = await repo.watchAll().first;
      expect(rows.map((r) => r.errorText).toList(), ['new', 'old']);
    },
  );

  test('delete removes a quarantined row by id', () async {
    await repo.insert(
      forTable: 'orders',
      rowPayload: <String, dynamic>{'id': 'AMW-X'},
      errorText: 'err',
      recordedAt: DateTime.utc(2026, 5, 23, 12, 0),
    );
    await repo.insert(
      forTable: 'orders',
      rowPayload: <String, dynamic>{'id': 'AMW-Y'},
      errorText: 'other err',
      recordedAt: DateTime.utc(2026, 5, 23, 12, 1),
    );

    final before = await repo.watchAll().first;
    expect(before, hasLength(2));
    final toDelete =
        before.firstWhere((r) => r.errorText == 'err').id;

    await repo.delete(toDelete);

    final after = await repo.watchAll().first;
    expect(after, hasLength(1));
    expect(after.single.errorText, 'other err');
  });

  test('delete on an unknown id is a no-op', () async {
    await repo.insert(
      forTable: 'orders',
      rowPayload: <String, dynamic>{'id': 'AMW-X'},
      errorText: 'err',
      recordedAt: DateTime.utc(2026, 5, 23, 12, 0),
    );

    await repo.delete('does-not-exist');

    final after = await repo.watchAll().first;
    expect(after, hasLength(1));
  });
}
