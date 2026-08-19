import 'dart:convert';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/sync/pull_dead_letter_repository.dart';
import 'package:amuwak_staff/src/sync/sync_puller.dart';
import 'package:amuwak_staff/src/sync/sync_registry.dart';

class _FakeFetch {
  /// Map of (table name) -> sequence of result batches. Each call to fetch
  /// consumes one batch from the head of the list.
  final Map<String, List<List<Map<String, dynamic>>>> queued = {};

  /// Records the `since` value the puller passed for each call.
  final List<MapEntry<String, DateTime>> sinceCalls = [];

  Future<List<Map<String, dynamic>>> call(SyncTable table, DateTime since) async {
    sinceCalls.add(MapEntry(table.name, since));
    final q = queued[table.name];
    if (q == null || q.isEmpty) return const [];
    return q.removeAt(0);
  }
}

const _customers = SyncTable(name: 'customers');

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('pullTable upserts returned rows and advances the watermark', () async {
    final fake = _FakeFetch();
    fake.queued['customers'] = [
      [
        {
          'id': 'c-1', 'name': 'Alice', 'phone': '+254700',
          'address': null, 'notes': null,
          'created_at': '2026-05-19T10:00:00Z',
          'updated_at': '2026-05-19T10:00:00Z',
          'deleted_at': null,
        },
        {
          'id': 'c-2', 'name': 'Bob', 'phone': '+254701',
          'address': null, 'notes': null,
          'created_at': '2026-05-19T11:00:00Z',
          'updated_at': '2026-05-19T11:00:00Z',
          'deleted_at': null,
        },
      ],
    ];

    final puller = SyncPuller(db: db, fetch: fake.call);
    final pulled = await puller.pullTable(_customers);

    expect(pulled, 2);

    final localRows = await db.select(db.customers).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    expect(localRows, hasLength(2));
    expect(localRows.first.name, 'Alice');
    expect(localRows[1].name, 'Bob');

    // Watermark advanced to the max updated_at it saw
    final wm = await (db.select(db.syncWatermarks)
          ..where((t) => t.forTable.equals('customers')))
        .getSingle();
    expect(wm.lastSyncedAt.toUtc().toIso8601String(),
        '2026-05-19T11:00:00.000Z');

    // First call asked since-epoch
    expect(fake.sinceCalls.first.value.year, 1970);
  });

  test('pullTable passes the existing watermark on the next call', () async {
    final fake = _FakeFetch();
    fake.queued['customers'] = [
      [
        {
          'id': 'c-1', 'name': 'Alice', 'phone': '+254',
          'address': null, 'notes': null,
          'created_at': '2026-05-19T10:00:00Z',
          'updated_at': '2026-05-19T10:00:00Z',
          'deleted_at': null,
        },
      ],
      const [],
    ];

    final puller = SyncPuller(db: db, fetch: fake.call);

    await puller.pullTable(_customers);
    final pulled2 = await puller.pullTable(_customers);

    expect(pulled2, 0);
    expect(fake.sinceCalls, hasLength(2));
    expect(fake.sinceCalls[1].value.toUtc().toIso8601String(),
        '2026-05-19T10:00:00.000Z');
  });

  test('pullTable advances the watermark from the configured column', () async {
    // Plan 3a Task 6: prove the puller uses `SyncTable.watermarkColumn`
    // instead of hard-coding `updated_at`. The fixture row deliberately
    // sets `created_at` later than `updated_at` — if the puller reads
    // the right column, the watermark lands on the `created_at` value.
    final fake = _FakeFetch();
    fake.queued['customers'] = [
      [
        {
          'id': 'c-1', 'name': 'Alice', 'phone': '+254',
          'address': null, 'notes': null,
          'created_at': '2026-05-19T12:00:00Z',
          'updated_at': '2026-05-19T08:00:00Z',
          'deleted_at': null,
        },
      ],
    ];

    final puller = SyncPuller(db: db, fetch: fake.call);
    await puller.pullTable(
      const SyncTable(name: 'customers', watermarkColumn: 'created_at'),
    );

    final wm = await (db.select(db.syncWatermarks)
          ..where((t) => t.forTable.equals('customers')))
        .getSingle();
    expect(wm.lastSyncedAt.toUtc().toIso8601String(),
        '2026-05-19T12:00:00.000Z');
  });

  test(
      'a placeholder order_code is backfilled by the real AMW code on the next '
      'pull (offline-create reconciliation)', () async {
    const orderId = '019e9147-608b-72b7-9e2c-0baa04e85094';
    Map<String, dynamic> orderRow(String code, String updatedAt) => {
          'id': orderId,
          'order_code': code,
          'customer_name': 'Jane',
          'phone': '+256',
          'address': 'addr',
          'service_type': 'wash',
          'status': 'pending_pickup',
          'intake_method': 'driver_pickup',
          'fulfillment_method': 'delivery',
          'item_count': 1,
          'intake_recorded_by': 's-1',
          'created_by': 's-1',
          'created_at': '2026-05-23T10:00:00Z',
          'updated_at': updatedAt,
        };

    final fake = _FakeFetch();
    fake.queued['orders'] = [
      // Mirrors the local row right after an offline create: order_code is the
      // UUID placeholder (== id) because create_pickup hasn't minted a code yet.
      [orderRow(orderId, '2026-05-23T10:00:00Z')],
      // The synced server row now carries the real minted AMW code.
      [orderRow('AMW-2026-0042', '2026-05-23T10:05:00Z')],
    ];

    const orders = SyncTable(name: 'orders', watermarkColumn: 'updated_at');
    final puller = SyncPuller(db: db, fetch: fake.call);

    await puller.pullTable(orders);
    final before = await (db.select(db.orders)
          ..where((t) => t.id.equals(orderId)))
        .getSingle();
    expect(before.orderCode, orderId, reason: 'placeholder present before sync');

    await puller.pullTable(orders);
    final after = await (db.select(db.orders)
          ..where((t) => t.id.equals(orderId)))
        .getSingle();
    expect(after.orderCode, 'AMW-2026-0042',
        reason: 'the id-keyed insertOrReplace overwrote the placeholder code');
  });

  group('Plan 3a Task 7 mappers — additional tables', () {
    test('pullTable upserts order_status_events rows '
        '(including null from_status and null device_event_id)', () async {
      final fake = _FakeFetch();
      fake.queued['order_status_events'] = [
        [
          {
            'id': 'se-1',
            'order_id': 'AMW-A',
            'from_status': null,
            'to_status': 'pending_pickup',
            'changed_by': 's-1',
            'changed_at': '2026-05-19T09:00:00Z',
            'source': 'mobile',
            'device_event_id': null,
          },
          {
            'id': 'se-2',
            'order_id': 'AMW-A',
            'from_status': 'pending_pickup',
            'to_status': 'received',
            'changed_by': 's-1',
            'changed_at': '2026-05-19T11:00:00Z',
            'source': 'mobile',
            'device_event_id': 'dev-evt-1',
          },
        ],
      ];

      final puller = SyncPuller(db: db, fetch: fake.call);
      final pulled = await puller.pullTable(const SyncTable(
        name: 'order_status_events',
        watermarkColumn: 'changed_at',
      ));

      expect(pulled, 2);
      final rows = await (db.select(db.orderStatusEvents)
            ..orderBy([(t) => OrderingTerm(expression: t.changedAt)]))
          .get();
      expect(rows.map((r) => r.id).toList(), ['se-1', 'se-2']);
      expect(rows[0].fromStatus, isNull);
      expect(rows[0].deviceEventId, isNull);
      expect(rows[1].fromStatus, 'pending_pickup');
      expect(rows[1].deviceEventId, 'dev-evt-1');
    });

    test('pullTable upserts proof_photos rows '
        '(including null width/height/bytes/uploaded_at)', () async {
      final fake = _FakeFetch();
      fake.queued['proof_photos'] = [
        [
          {
            'id': 'pp-1',
            'proof_event_id': 'pe-1',
            'storage_path': 'proofs/pp-1.jpg',
            'width': null,
            'height': null,
            'bytes': null,
            'uploaded_at': null,
            'created_at': '2026-05-19T10:30:00Z',
          },
          {
            'id': 'pp-2',
            'proof_event_id': 'pe-1',
            'storage_path': 'proofs/pp-2.jpg',
            'width': 1024,
            'height': 768,
            'bytes': 102400,
            'uploaded_at': '2026-05-19T10:35:00Z',
            'created_at': '2026-05-19T10:31:00Z',
          },
        ],
      ];

      final puller = SyncPuller(db: db, fetch: fake.call);
      final pulled = await puller.pullTable(const SyncTable(
        name: 'proof_photos',
        watermarkColumn: 'created_at',
      ));

      expect(pulled, 2);
      final rows = await (db.select(db.proofPhotos)
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();
      expect(rows.map((r) => r.id).toList(), ['pp-1', 'pp-2']);
      expect(rows[0].width, isNull);
      expect(rows[0].uploadedAt, isNull);
      expect(rows[1].width, 1024);
      expect(rows[1].height, 768);
      expect(rows[1].bytes, 102400);
      expect(rows[1].uploadedAt, isNotNull);
    });

    test('pullTable upserts issues rows '
        '(including null order_id / resolved_at / resolved_by)', () async {
      final fake = _FakeFetch();
      // Synthetic `updated_at` (not present in the live Postgres schema until
      // a future migration adds it) keeps the watermark math happy; the
      // mapper ignores it.
      fake.queued['issues'] = [
        [
          {
            'id': 'iss-1',
            'order_id': null,
            'kind': 'missing_item',
            'description': 'Missing one sock',
            'reported_by': 's-1',
            'reported_at': '2026-05-19T12:00:00Z',
            'resolved_at': null,
            'resolved_by': null,
            'updated_at': '2026-05-19T12:00:00Z',
          },
          {
            'id': 'iss-2',
            'order_id': 'AMW-A',
            'kind': 'damaged',
            'description': 'Stain found after wash',
            'reported_by': 's-1',
            'reported_at': '2026-05-19T13:00:00Z',
            'resolved_at': '2026-05-19T15:00:00Z',
            'resolved_by': 's-2',
            'updated_at': '2026-05-19T15:00:00Z',
          },
        ],
      ];

      final puller = SyncPuller(db: db, fetch: fake.call);
      final pulled = await puller.pullTable(const SyncTable(name: 'issues'));

      expect(pulled, 2);
      final rows = await (db.select(db.issues)
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();
      expect(rows.map((r) => r.id).toList(), ['iss-1', 'iss-2']);
      expect(rows[0].orderId, isNull);
      expect(rows[0].resolvedAt, isNull);
      expect(rows[0].resolvedBy, isNull);
      expect(rows[1].orderId, 'AMW-A');
      expect(rows[1].resolvedAt, isNotNull);
      expect(rows[1].resolvedBy, 's-2');
    });

    test('pullTable upserts shifts rows '
        '(including null lat/lng/ended_at)', () async {
      final fake = _FakeFetch();
      fake.queued['shifts'] = [
        [
          {
            'id': 'sh-1',
            'staff_id': 's-1',
            'started_at': '2026-05-19T08:00:00Z',
            'started_lat': null,
            'started_lng': null,
            'ended_at': null,
            'ended_lat': null,
            'ended_lng': null,
            'updated_at': '2026-05-19T08:00:00Z',
          },
          {
            'id': 'sh-2',
            'staff_id': 's-2',
            'started_at': '2026-05-19T09:00:00Z',
            'started_lat': 0.3476,
            'started_lng': 32.5825,
            'ended_at': '2026-05-19T17:00:00Z',
            'ended_lat': 0.3500,
            'ended_lng': 32.5800,
            'updated_at': '2026-05-19T17:00:00Z',
          },
        ],
      ];

      final puller = SyncPuller(db: db, fetch: fake.call);
      final pulled = await puller.pullTable(const SyncTable(name: 'shifts'));

      expect(pulled, 2);
      final rows = await (db.select(db.shifts)
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();
      expect(rows.map((r) => r.id).toList(), ['sh-1', 'sh-2']);
      expect(rows[0].startedLat, isNull);
      expect(rows[0].endedAt, isNull);
      expect(rows[1].startedLat, closeTo(0.3476, 1e-6));
      expect(rows[1].endedLng, closeTo(32.5800, 1e-6));
      expect(rows[1].endedAt, isNotNull);
    });

    test('pullAll iterates every kSyncTables entry and writes per-table '
        'watermarks (Plan 3a Task 8 activation)', () async {
      // Sanity check that the registry now includes order_status_events
      // and proof_photos. If a future maintainer drops them from the
      // const list, this assertion catches it before the test that
      // depends on the puller calling them.
      expect(
        kSyncTables.map((t) => t.name).toList(),
        containsAll(<String>[
          'staff',
          'customers',
          'orders',
          'proof_events',
          'order_status_events',
          'proof_photos',
        ]),
      );
      // Negative check: tables intentionally NOT in the periodic
      // registry stay out.
      expect(
        kSyncTables.map((t) => t.name).toList(),
        isNot(anyOf(contains('valid_transitions'),
            contains('issues'), contains('shifts'))),
      );

      final fake = _FakeFetch();
      fake.queued['staff'] = [const <Map<String, dynamic>>[]];
      fake.queued['customers'] = [const <Map<String, dynamic>>[]];
      fake.queued['orders'] = [const <Map<String, dynamic>>[]];
      fake.queued['proof_events'] = [const <Map<String, dynamic>>[]];
      fake.queued['order_status_events'] = [
        [
          {
            'id': 'se-1',
            'order_id': 'AMW-A',
            'from_status': null,
            'to_status': 'pending_pickup',
            'changed_by': 's-1',
            'changed_at': '2026-05-19T09:00:00Z',
            'source': 'mobile',
            'device_event_id': null,
          },
        ],
      ];
      fake.queued['proof_photos'] = [
        [
          {
            'id': 'pp-1',
            'proof_event_id': 'pe-1',
            'storage_path': 'proofs/pp-1.jpg',
            'width': null,
            'height': null,
            'bytes': null,
            'uploaded_at': null,
            'created_at': '2026-05-19T10:30:00Z',
          },
        ],
      ];

      final puller = SyncPuller(db: db, fetch: fake.call);
      final total = await puller.pullAll();

      expect(total, 2);
      // Watermark rows exist for both newly-activated tables, with the
      // right per-table column values.
      final eventsWm = await (db.select(db.syncWatermarks)
            ..where((t) => t.forTable.equals('order_status_events')))
          .getSingle();
      expect(eventsWm.lastSyncedAt.toUtc().toIso8601String(),
          '2026-05-19T09:00:00.000Z');
      final photosWm = await (db.select(db.syncWatermarks)
            ..where((t) => t.forTable.equals('proof_photos')))
          .getSingle();
      expect(photosWm.lastSyncedAt.toUtc().toIso8601String(),
          '2026-05-19T10:30:00.000Z');

      // Sanity: each kSyncTables entry was queried.
      final queriedTables = fake.sinceCalls.map((c) => c.key).toSet();
      expect(queriedTables, containsAll(<String>[
        'staff', 'customers', 'orders', 'proof_events',
        'order_status_events', 'proof_photos',
      ]));
    });

    test('pullTable upserts valid_transitions rows '
        '(including null from_status for initial states)', () async {
      // valid_transitions is static seed; ValidTransitionsLoader (Task 9)
      // is the production caller. This test exercises the same mapper
      // through pullTable with a synthetic watermark column so we can
      // verify the upsert path works.
      final fake = _FakeFetch();
      fake.queued['valid_transitions'] = [
        [
          {
            'id': 'vt-1',
            'intake_method': 'walk_in',
            'fulfillment_method': 'customer_collect',
            'from_status': null,
            'to_status': 'received',
            'created_at': '2026-05-19T08:00:00Z',
          },
          {
            'id': 'vt-2',
            'intake_method': 'driver_pickup',
            'fulfillment_method': 'delivery',
            'from_status': 'ready',
            'to_status': 'out_for_delivery',
            'created_at': '2026-05-19T08:00:00Z',
          },
        ],
      ];

      final puller = SyncPuller(db: db, fetch: fake.call);
      final pulled = await puller.pullTable(const SyncTable(
        name: 'valid_transitions',
        watermarkColumn: 'created_at',
      ));

      expect(pulled, 2);
      final rows = await (db.select(db.validTransitions)
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();
      expect(rows.map((r) => r.id).toList(), ['vt-1', 'vt-2']);
      expect(rows[0].fromStatus, isNull);
      expect(rows[0].toStatus, 'received');
      expect(rows[1].fromStatus, 'ready');
      expect(rows[1].toStatus, 'out_for_delivery');
    });
  });

  group('Plan 4 Task 3 — per-row dead-letter', () {
    test(
      'a row whose mapper throws is dead-lettered; good rows still upsert; '
      'watermark advances past the bad row',
      () async {
        final fake = _FakeFetch();
        fake.queued['orders'] = [
          [
            // Good row — full payload.
            {
              'id': 'AMW-OK',
              'order_code': 'AMW-OK',
              'customer_name': 'OK Person',
              'phone': '+256', 'address': 'addr', 'service_type': 'wash',
              'status': 'pending_pickup',
              'intake_method': 'driver_pickup',
              'fulfillment_method': 'delivery',
              'item_count': 1,
              'intake_recorded_by': 's-1', 'created_by': 's-1',
              'created_at': '2026-05-23T10:00:00Z',
              'updated_at': '2026-05-23T10:00:00Z',
            },
            // Bad row — `status` is null, mapper throws on `as String`.
            {
              'id': 'AMW-BAD',
              'order_code': 'AMW-BAD',
              'customer_name': 'Bad Person',
              'phone': '+256', 'address': 'addr', 'service_type': 'wash',
              'status': null,
              'intake_method': 'driver_pickup',
              'fulfillment_method': 'delivery',
              'item_count': 1,
              'intake_recorded_by': 's-1', 'created_by': 's-1',
              'created_at': '2026-05-23T10:01:00Z',
              'updated_at': '2026-05-23T10:01:00Z',
            },
          ],
        ];

        final dlq = PullDeadLetterRepository(db);
        final puller =
            SyncPuller(db: db, fetch: fake.call, deadLetter: dlq);
        final written = await puller.pullTable(
            const SyncTable(name: 'orders', watermarkColumn: 'updated_at'));

        // Good row upserted; bad row not.
        expect(written, 1);
        final ok = await (db.select(db.orders)
              ..where((t) => t.id.equals('AMW-OK')))
            .getSingle();
        expect(ok.customerName, 'OK Person');
        final bad = await (db.select(db.orders)
              ..where((t) => t.id.equals('AMW-BAD')))
            .getSingleOrNull();
        expect(bad, isNull);

        // Bad row was quarantined.
        final dead = await dlq.watchAll().first;
        expect(dead, hasLength(1));
        expect(dead.single.forTable, 'orders');
        expect(dead.single.rowPayloadJson, contains('AMW-BAD'));

        // Watermark advanced past the bad row's updated_at so next cycle
        // doesn't re-fetch and re-dead-letter the same poison row forever.
        final wm = await (db.select(db.syncWatermarks)
              ..where((t) => t.forTable.equals('orders')))
            .getSingle();
        expect(
          wm.lastSyncedAt.toUtc().toIso8601String(),
          '2026-05-23T10:01:00.000Z',
        );
      },
    );

    test(
      'dead-letter errorText is the error message only — no Dart stack frames',
      () async {
        // A row whose mapper throws (status is null where the mapper does
        // `as String`). We assert the stored errorText does not include
        // stack-frame markers that would leak file paths to a rider.
        final fake = _FakeFetch();
        fake.queued['orders'] = [
          [
            {
              'id': 'AMW-BAD',
              'order_code': 'AMW-BAD',
              'customer_name': 'X',
              'phone': '+', 'address': 'a', 'service_type': 'wash',
              'status': null,
              'intake_method': 'driver_pickup',
              'fulfillment_method': 'delivery',
              'item_count': 1,
              'intake_recorded_by': 's-1', 'created_by': 's-1',
              'created_at': '2026-05-23T10:00:00Z',
              'updated_at': '2026-05-23T10:00:00Z',
            },
          ],
        ];

        final dlq = PullDeadLetterRepository(db);
        final puller =
            SyncPuller(db: db, fetch: fake.call, deadLetter: dlq);
        await puller.pullTable(
            const SyncTable(name: 'orders', watermarkColumn: 'updated_at'));

        final dead = await dlq.watchAll().first;
        expect(dead, hasLength(1));
        expect(
          dead.single.errorText,
          isNot(contains('package:')),
          reason: 'errorText must not include file paths from a stack frame',
        );
        expect(
          dead.single.errorText,
          isNot(contains('#0')),
          reason: 'errorText must not include numbered stack frames',
        );
        expect(dead.single.errorText, isNotEmpty);
      },
    );

    test(
      'without a deadLetter wired, legacy all-or-nothing behaviour is preserved',
      () async {
        final fake = _FakeFetch();
        fake.queued['orders'] = [
          [
            {
              'id': 'AMW-BAD',
              // Missing required columns — mapper throws.
              'status': null,
              'updated_at': '2026-05-23T10:00:00Z',
            },
          ],
        ];

        final puller = SyncPuller(db: db, fetch: fake.call);
        final written = await puller.pullTable(
            const SyncTable(name: 'orders', watermarkColumn: 'updated_at'));

        expect(written, 0);
        // Watermark NOT advanced — legacy aborts the whole batch.
        final wm = await (db.select(db.syncWatermarks)
              ..where((t) => t.forTable.equals('orders')))
            .getSingleOrNull();
        expect(wm, isNull);
      },
    );
  });

  group("a customer order's cart snapshot", () {
    Map<String, dynamic> orderRow({Object? cartItems}) => {
          'id': 'AMW-CART',
          'order_code': 'AMW-CART',
          'customer_name': 'Jane',
          'phone': '+256',
          'address': 'addr',
          'service_type': 'wash',
          'status': 'pending_pickup',
          'intake_method': 'customer_app',
          'fulfillment_method': 'delivery',
          'item_count': 3,
          'intake_recorded_by': 's-1',
          'created_by': 's-1',
          'created_at': '2026-07-27T10:00:00Z',
          'updated_at': '2026-07-27T10:00:00Z',
          if (cartItems != null) 'cart_items': cartItems,
        };

    Future<String> pull(Map<String, dynamic> row) async {
      final fake = _FakeFetch();
      fake.queued['orders'] = [
        [row]
      ];
      await SyncPuller(db: db, fetch: fake.call).pullTable(
          const SyncTable(name: 'orders', watermarkColumn: 'updated_at'));
      final stored = await (db.select(db.orders)
            ..where((t) => t.id.equals('AMW-CART')))
          .getSingle();
      return stored.cartItems;
    }

    test('reaches the device, so staff see it without a round-trip', () async {
      final stored = await pull(orderRow(cartItems: [
        {'kind': 'weight', 'name': 'Wash & Iron', 'est_kg': 6, 'qty': 1},
        {
          'kind': 'piece',
          'name': 'Jacket',
          'qty': 2,
          'photo_key': 'customer/c1/cart/p1.jpg',
        },
      ]));

      final items = parseCartSnapshot(jsonDecode(stored));
      expect(items.map((i) => i.name), ['Wash & Iron', 'Jacket']);
      expect(items.last.photoKey, 'customer/c1/cart/p1.jpg');
    });

    test('a rider order (no cart_items at all) stores an empty snapshot',
        () async {
      expect(parseCartSnapshot(jsonDecode(await pull(orderRow()))), isEmpty);
    });
  });

  group('pulled pricing and payment', () {
    // This mapper is the only server→local path for orders, so a column it
    // drops reads as 0 on the device — and a customer-app order's price is
    // frozen server-side at checkout, never re-derived locally.
    Map<String, dynamic> pricedRow({Map<String, dynamic> overrides = const {}}) =>
        {
          'id': 'AMW-PRICED',
          'order_code': 'AMW-PRICED',
          'customer_name': 'Jane',
          'phone': '+256',
          'address': 'addr',
          // The db stores the service LABEL; ServiceType.fromDbString throws on
          // anything else, and this row is hydrated through fromDriftRow below.
          'service_type': 'Wash & Iron',
          'status': 'in_progress',
          'intake_method': 'customer_app',
          'fulfillment_method': 'delivery',
          'item_count': 3,
          'intake_recorded_by': 's-1',
          'created_by': 's-1',
          'created_at': '2026-07-27T10:00:00Z',
          'updated_at': '2026-07-27T10:00:00Z',
          'rate_per_kg_snapshot_ugx': 5000,
          'estimated_weight_kg': 6.5,
          'final_weight_kg': 7,
          'line_items': [
            {'name': 'Jacket', 'amount_ugx': 8000},
          ],
          'manual_adjustment_ugx': -500,
          'total_ugx': 47500,
          'delivery_fee_snapshot_ugx': 3000,
          'is_express': true,
          'express_flat_snapshot_ugx': 2000,
          'express_pct_snapshot': 0.15,
          'payment_amount_ugx': 20000,
          ...overrides,
        };

    Future<Order> pullOrder(Map<String, dynamic> row) async {
      final fake = _FakeFetch();
      fake.queued['orders'] = [
        [row]
      ];
      await SyncPuller(db: db, fetch: fake.call).pullTable(
          const SyncTable(name: 'orders', watermarkColumn: 'updated_at'));
      return (db.select(db.orders)..where((t) => t.id.equals(row['id'] as String)))
          .getSingle();
    }

    test('survives the trip to the device instead of reading as zero',
        () async {
      final stored = await pullOrder(pricedRow());

      expect(stored.totalUgx, 47500);
      expect(stored.ratePerKgSnapshotUgx, 5000);
      expect(stored.estimatedWeightKg, 6.5);
      expect(stored.finalWeightKg, 7);
      expect(stored.manualAdjustmentUgx, -500);
      expect(stored.deliveryFeeSnapshotUgx, 3000);
      expect(stored.isExpress, isTrue);
      expect(stored.expressFlatSnapshotUgx, 2000);
      expect(stored.expressPctSnapshot, 0.15);
      expect(stored.paymentAmountUgx, 20000);
      expect(jsonDecode(stored.lineItems), [
        {'name': 'Jacket', 'amount_ugx': 8000},
      ]);
    });

    test('hydrates into a LaundryOrder staff can act on', () async {
      final order =
          LaundryOrderDriftX.fromDriftRow(await pullOrder(pricedRow()), const []);

      expect(order.totalUgx, 47500);
      expect(order.outstandingUgx, 27500, reason: '47500 total less 20000 paid');
      expect(order.lineItems.single.name, 'Jacket');
    });

    test('a row predating these columns degrades to 0, not an error', () async {
      final bare = pricedRow()
        ..removeWhere((key, _) => const {
              'rate_per_kg_snapshot_ugx',
              'estimated_weight_kg',
              'final_weight_kg',
              'line_items',
              'manual_adjustment_ugx',
              'total_ugx',
              'delivery_fee_snapshot_ugx',
              'is_express',
              'express_flat_snapshot_ugx',
              'express_pct_snapshot',
              'payment_amount_ugx',
            }.contains(key));

      final stored = await pullOrder(bare);

      expect(stored.totalUgx, 0);
      expect(stored.ratePerKgSnapshotUgx, 0);
      expect(stored.estimatedWeightKg, isNull);
      expect(stored.isExpress, isFalse);
      expect(stored.lineItems, '[]');
    });

    test('a later pull of the same order overwrites the stale price', () async {
      await pullOrder(pricedRow());
      final restated = await pullOrder(pricedRow(overrides: {
        'total_ugx': 51000,
        'final_weight_kg': 8,
        'updated_at': '2026-07-27T11:00:00Z',
      }));

      expect(restated.totalUgx, 51000, reason: 'insertOrReplace, not ignore');
      expect(restated.finalWeightKg, 8);
    });

    test('carries the rate-override audit so staff can see why a price differs',
        () async {
      final stored = await pullOrder(pricedRow(overrides: {
        'rate_override_reason': 'Bulk hostel deal',
        'rate_override_from_ugx': 6000,
      }));

      expect(stored.rateOverrideReason, 'Bulk hostel deal');
      expect(stored.rateOverrideFromUgx, 6000);
    });

    test('an ordinary pulled order has no override recorded', () async {
      final stored = await pullOrder(pricedRow());

      expect(stored.rateOverrideReason, isNull);
      expect(stored.rateOverrideFromUgx, isNull);
    });

    test('carries the promised collection date (migration 0058)', () async {
      // Regression: the mapper carried scheduled_for but never
      // expected_collection_at, so a collection date promised in the shop (or
      // edited on another device) was dropped on the way back to this one and
      // the order read as having no promise at all.
      final stored = await pullOrder(pricedRow(overrides: {
        'expected_collection_at': '2026-07-30T00:00:00Z',
      }));

      expect(stored.expectedCollectionAt, DateTime.utc(2026, 7, 30));
    });

    test('an order with no promised collection date stays null', () async {
      expect((await pullOrder(pricedRow())).expectedCollectionAt, isNull);
    });
  });
}
