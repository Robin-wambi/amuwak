import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/sync_registry.dart';
import 'package:amuwak_staff/src/sync/valid_transitions_loader.dart';

/// Builds a row matching the `valid_transitions` schema. Only the columns
/// the loader's mapper reads matter — extras are harmless.
Map<String, dynamic> _row({
  required String id,
  required String intakeMethod,
  required String fulfillmentMethod,
  String? fromStatus,
  required String toStatus,
}) =>
    {
      'id': id,
      'intake_method': intakeMethod,
      'fulfillment_method': fulfillmentMethod,
      'from_status': fromStatus,
      'to_status': toStatus,
    };

/// The 12 canonical transitions seeded by Supabase migration 0003 for the
/// two non-phone-order flows. Enough variety to exercise null `from_status`
/// rows + multiple intake/fulfillment combos.
final List<Map<String, dynamic>> _twelveRows = [
  _row(id: 't-01', intakeMethod: 'walk_in', fulfillmentMethod: 'customer_collect', toStatus: 'received'),
  _row(id: 't-02', intakeMethod: 'walk_in', fulfillmentMethod: 'customer_collect', fromStatus: 'received', toStatus: 'in_progress'),
  _row(id: 't-03', intakeMethod: 'walk_in', fulfillmentMethod: 'customer_collect', fromStatus: 'in_progress', toStatus: 'ready'),
  _row(id: 't-04', intakeMethod: 'walk_in', fulfillmentMethod: 'customer_collect', fromStatus: 'ready', toStatus: 'completed'),
  _row(id: 't-05', intakeMethod: 'walk_in', fulfillmentMethod: 'delivery', toStatus: 'received'),
  _row(id: 't-06', intakeMethod: 'walk_in', fulfillmentMethod: 'delivery', fromStatus: 'received', toStatus: 'in_progress'),
  _row(id: 't-07', intakeMethod: 'walk_in', fulfillmentMethod: 'delivery', fromStatus: 'in_progress', toStatus: 'ready'),
  _row(id: 't-08', intakeMethod: 'walk_in', fulfillmentMethod: 'delivery', fromStatus: 'ready', toStatus: 'out_for_delivery'),
  _row(id: 't-09', intakeMethod: 'walk_in', fulfillmentMethod: 'delivery', fromStatus: 'out_for_delivery', toStatus: 'completed'),
  _row(id: 't-10', intakeMethod: 'driver_pickup', fulfillmentMethod: 'customer_collect', toStatus: 'pending_pickup'),
  _row(id: 't-11', intakeMethod: 'driver_pickup', fulfillmentMethod: 'customer_collect', fromStatus: 'pending_pickup', toStatus: 'received'),
  _row(id: 't-12', intakeMethod: 'driver_pickup', fulfillmentMethod: 'customer_collect', fromStatus: 'received', toStatus: 'in_progress'),
];

class _RecordingFetch {
  _RecordingFetch(this._rows);
  final List<Map<String, dynamic>> _rows;
  int callCount = 0;

  Future<List<Map<String, dynamic>>> call(SyncTable table, DateTime since) async {
    callCount++;
    return _rows;
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('loadOnce writes every fetched row into valid_transitions', () async {
    final fetch = _RecordingFetch(_twelveRows);
    final loader = ValidTransitionsLoader(db: db, fetch: fetch.call);

    await loader.loadOnce();

    expect(fetch.callCount, 1);
    final rows = await db.select(db.validTransitions).get();
    expect(rows, hasLength(12));
    // Verify the null-from_status rows landed correctly (initial states).
    final initialStates =
        rows.where((r) => r.fromStatus == null).map((r) => r.id).toSet();
    expect(initialStates, {'t-01', 't-05', 't-10'});
    // And a non-null from_status row maps faithfully.
    final t08 = rows.singleWhere((r) => r.id == 't-08');
    expect(t08.fromStatus, 'ready');
    expect(t08.toStatus, 'out_for_delivery');
    expect(t08.intakeMethod, 'walk_in');
    expect(t08.fulfillmentMethod, 'delivery');
  });

  test('loadOnce is idempotent — second call with same rows replaces cleanly', () async {
    final fetch = _RecordingFetch(_twelveRows);
    final loader = ValidTransitionsLoader(db: db, fetch: fetch.call);

    await loader.loadOnce();
    await loader.loadOnce();

    expect(fetch.callCount, 2);
    final rows = await db.select(db.validTransitions).get();
    // Still 12 — insertOrReplace, not insert-and-duplicate.
    expect(rows, hasLength(12));
  });

  test('loadOnce updates rows in place when their natural-key fields change', () async {
    // Seed with the 12 rows, then re-fetch where t-04's to_status was
    // (hypothetically) corrected. The same id wins, the new row replaces.
    await ValidTransitionsLoader(db: db, fetch: _RecordingFetch(_twelveRows).call)
        .loadOnce();

    final amended = [..._twelveRows];
    final idx = amended.indexWhere((r) => r['id'] == 't-04');
    amended[idx] = _row(
      id: 't-04',
      intakeMethod: 'walk_in',
      fulfillmentMethod: 'customer_collect',
      fromStatus: 'ready',
      toStatus: 'completed_corrected',
    );

    await ValidTransitionsLoader(db: db, fetch: _RecordingFetch(amended).call)
        .loadOnce();

    final rows = await db.select(db.validTransitions).get();
    expect(rows, hasLength(12));
    final t04 = rows.singleWhere((r) => r.id == 't-04');
    expect(t04.toStatus, 'completed_corrected');
  });

  test('loadOnce rethrows when the fetcher fails and leaves the DB unchanged',
      () async {
    final loader = ValidTransitionsLoader(
      db: db,
      fetch: (table, since) => throw const FormatException('boom'),
    );

    await expectLater(
      loader.loadOnce(),
      throwsA(isA<FormatException>()),
    );

    final rows = await db.select(db.validTransitions).get();
    expect(rows, isEmpty);
  });

  test('loadOnce does NOT write to sync_watermarks', () async {
    final loader = ValidTransitionsLoader(
      db: db,
      fetch: _RecordingFetch(_twelveRows).call,
    );

    await loader.loadOnce();

    final wm = await (db.select(db.syncWatermarks)
          ..where((t) => t.forTable.equals('valid_transitions')))
        .getSingleOrNull();
    expect(wm, isNull,
        reason: 'static seed loader must not produce a watermark row');
  });

  test('loadOnce treats an empty fetch as a successful no-op', () async {
    final loader = ValidTransitionsLoader(
      db: db,
      fetch: (table, since) async => const <Map<String, dynamic>>[],
    );

    await loader.loadOnce();

    final rows = await db.select(db.validTransitions).get();
    expect(rows, isEmpty);
  });
}
