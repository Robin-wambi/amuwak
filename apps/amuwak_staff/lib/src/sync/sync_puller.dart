import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/app_database.dart';
import 'pull_dead_letter_repository.dart';
import 'sync_registry.dart';

/// Fetches Postgres rows for [table] whose configured `watermarkColumn`
/// is strictly newer than [since]. Implementations throw on failure; the
/// puller stops the affected table for this cycle and tries again next
/// cycle.
typedef SyncFetch = Future<List<Map<String, dynamic>>> Function(
  SyncTable table,
  DateTime since,
);

/// Pulls Postgres rows that changed since a per-table watermark and upserts
/// them into the local Drift database. Used by the periodic puller and on
/// reconnect.
class SyncPuller {
  SyncPuller({required this.db, required this.fetch, this.deadLetter});

  final AppDatabase db;
  final SyncFetch fetch;

  /// Optional sink for rows the mapper couldn't ingest.  When supplied, the
  /// puller per-row try/catches around `_upsertRow` and quarantines failures
  /// here, letting good rows in the same batch land and the watermark
  /// advance.  When null (legacy behaviour, no Plan-4 wiring), a single bad
  /// row still aborts the whole batch — preserved for tests that don't care.
  final PullDeadLetterRepository? deadLetter;

  static final DateTime _epoch = DateTime.utc(1970);

  /// Default fetcher backed by the real Supabase client. Uses each
  /// table's configured [SyncTable.watermarkColumn] for the `.gt(...)`
  /// comparison and the result ordering.
  static SyncFetch supabaseFetcher(SupabaseClient client) {
    return (table, since) async {
      final List<dynamic> rows = await client
          .from(table.name)
          .select()
          .gt(table.watermarkColumn, since.toIso8601String())
          .order(table.watermarkColumn);
      return rows.cast<Map<String, dynamic>>().toList();
    };
  }

  Future<DateTime> _readWatermark(String forTable) async {
    final row = await (db.select(db.syncWatermarks)
          ..where((t) => t.forTable.equals(forTable)))
        .getSingleOrNull();
    return row?.lastSyncedAt ?? _epoch;
  }

  Future<void> _writeWatermark(String forTable, DateTime at) {
    return db.into(db.syncWatermarks).insertOnConflictUpdate(
          SyncWatermarksCompanion.insert(
            forTable: forTable,
            lastSyncedAt: at,
          ),
        );
  }

  /// Pull a single table. Returns the number of rows successfully upserted.
  ///
  /// With a [deadLetter] wired, each row is upserted independently inside a
  /// transaction; mapper failures are quarantined in `pull_dead_letter` and
  /// the watermark advances past every row we SAW (good or bad) so the next
  /// cycle doesn't re-fetch the poison row forever.
  ///
  /// Without [deadLetter], legacy behaviour applies: any row's failure
  /// aborts the whole batch and leaves the watermark put.
  Future<int> pullTable(SyncTable table) async {
    final since = await _readWatermark(table.name);
    final rows = await fetch(table, since);
    if (rows.isEmpty) return 0;

    // Capture the nullable field into a local so Dart's flow analysis can
    // narrow it across the guard below — the per-row path then uses `dl`
    // directly instead of a `deadLetter!` bang.
    final dl = deadLetter;
    if (dl == null) {
      // Legacy all-or-nothing path.
      DateTime maxWatermark = since;
      try {
        await db.batch((batch) {
          for (final row in rows) {
            _upsertRow(batch, table.name, row);
            final u = DateTime.parse(row[table.watermarkColumn] as String);
            if (u.isAfter(maxWatermark)) maxWatermark = u;
          }
        });
      } catch (e, st) {
        developer.log(
          'batch for "${table.name}" failed; watermark not advanced.',
          name: 'SyncPuller',
          error: e,
          stackTrace: st,
        );
        return 0;
      }
      await _writeWatermark(table.name, maxWatermark);
      return rows.length;
    }

    // Per-row path with dead-letter quarantine.
    //
    // Watermark advances past EVERY row we saw, including the bad ones —
    // otherwise next cycle re-fetches the poison row and re-dead-letters it
    // forever.  A single bad row can't roll back successful upserts because
    // each row's failure is caught per-row (the upsert never throws out of the
    // loop).  The dead-letter inserts and the watermark write live INSIDE the
    // same transaction as the upserts, so the whole cycle commits atomically:
    // a crash mid-cycle leaves the watermark un-advanced and the batch is
    // simply re-pulled next time, with no lost or duplicated quarantine rows.
    DateTime maxWatermark = since;
    final failed = <_FailedRow>[];
    var written = 0;

    await db.transaction(() async {
      for (final row in rows) {
        try {
          await _upsertRowSingle(table.name, row);
          written += 1;
        } catch (e, st) {
          failed.add(_FailedRow(table.name, row, e, st));
        }
        // Advance watermark for both successful and dead-lettered rows.
        final ts = _parseTimestampOrNull(row[table.watermarkColumn]);
        if (ts != null && ts.isAfter(maxWatermark)) maxWatermark = ts;
      }

      for (final f in failed) {
        // Stack stays in dev logs (debugger, `flutter logs`); the rider-visible
        // errorText is the message only so file paths and frame numbers don't
        // leak through the SyncErrorsScreen.
        developer.log(
          'pull dead-letter: ${f.tableName}',
          name: 'SyncPuller',
          error: f.error,
          stackTrace: f.stack,
        );
        await dl.insert(
          forTable: f.tableName,
          rowPayload: f.row,
          errorText: f.error.toString(),
        );
      }
      if (maxWatermark.isAfter(since)) {
        await _writeWatermark(table.name, maxWatermark);
      }
    });
    return written;
  }

  DateTime? _parseTimestampOrNull(Object? v) {
    if (v is! String) return null;
    return DateTime.tryParse(v);
  }

  /// Upserts ONE row so per-row failures can be caught and dead-lettered
  /// individually. Delegates to [_upsertRow] via a one-row `batch` so the
  /// table dispatch lives in exactly one place — adding a synced table only
  /// touches [_upsertRow]. A mapper exception (the failure mode the per-row
  /// path quarantines) is thrown while building the companion, before any DB
  /// write, so it still surfaces to the caller's try/catch unchanged.
  Future<void> _upsertRowSingle(String table, Map<String, dynamic> row) {
    return db.batch((batch) => _upsertRow(batch, table, row));
  }

  Future<int> pullAll() async {
    var total = 0;
    for (final t in kSyncTables) {
      total += await pullTable(t);
    }
    return total;
  }

  /// Exhaustive switch over every table in the Drift schema. Anything that
  /// reaches the default is a typo or a newly-added table without a mapper —
  /// fail fast so it surfaces in dev rather than silently dropping rows.
  void _upsertRow(Batch batch, String table, Map<String, dynamic> row) {
    switch (table) {
      case 'staff':
        batch.insert(db.staff, _staffFromJson(row), mode: InsertMode.insertOrReplace);
        break;
      case 'customers':
        batch.insert(db.customers, _customersFromJson(row), mode: InsertMode.insertOrReplace);
        break;
      case 'orders':
        batch.insert(db.orders, _ordersFromJson(row), mode: InsertMode.insertOrReplace);
        break;
      case 'proof_events':
        batch.insert(db.proofEvents, _proofEventsFromJson(row), mode: InsertMode.insertOrReplace);
        break;
      case 'order_status_events':
        batch.insert(db.orderStatusEvents, _orderStatusEventsFromJson(row),
            mode: InsertMode.insertOrReplace);
        break;
      case 'proof_photos':
        batch.insert(db.proofPhotos, _proofPhotosFromJson(row),
            mode: InsertMode.insertOrReplace);
        break;
      case 'issues':
        batch.insert(db.issues, _issuesFromJson(row),
            mode: InsertMode.insertOrReplace);
        break;
      case 'shifts':
        batch.insert(db.shifts, _shiftsFromJson(row),
            mode: InsertMode.insertOrReplace);
        break;
      case 'valid_transitions':
        batch.insert(db.validTransitions, _validTransitionsFromJson(row),
            mode: InsertMode.insertOrReplace);
        break;
      default:
        throw StateError('SyncPuller has no upsert mapper for table "$table"');
    }
  }

  // ------------- per-table JSON → Drift Companion mappers -------------

  DateTime _dt(Object? v) => DateTime.parse(v as String);
  DateTime? _dtNullable(Object? v) => v == null ? null : DateTime.parse(v as String);

  StaffCompanion _staffFromJson(Map<String, dynamic> r) => StaffCompanion.insert(
        id: r['id'] as String,
        username: r['username'] as String,
        displayName: r['display_name'] as String,
        phone: Value(r['phone'] as String?),
        role: r['role'] as String,
        active: Value(r['active'] as bool? ?? true),
        mustChangePin: Value(r['must_change_pin'] as bool? ?? false),
        createdAt: _dt(r['created_at']),
        updatedAt: _dt(r['updated_at']),
        deletedAt: Value(_dtNullable(r['deleted_at'])),
      );

  CustomersCompanion _customersFromJson(Map<String, dynamic> r) => CustomersCompanion.insert(
        id: r['id'] as String,
        name: r['name'] as String,
        phone: r['phone'] as String,
        address: Value(r['address'] as String?),
        notes: Value(r['notes'] as String?),
        createdAt: _dt(r['created_at']),
        updatedAt: _dt(r['updated_at']),
        deletedAt: Value(_dtNullable(r['deleted_at'])),
      );

  OrdersCompanion _ordersFromJson(Map<String, dynamic> r) => OrdersCompanion.insert(
        id: r['id'] as String,
        orderCode: r['order_code'] as String,
        customerId: Value(r['customer_id'] as String?),
        customerName: r['customer_name'] as String,
        phone: r['phone'] as String,
        address: r['address'] as String,
        serviceType: r['service_type'] as String,
        status: r['status'] as String,
        intakeMethod: r['intake_method'] as String,
        fulfillmentMethod: r['fulfillment_method'] as String,
        itemCount: r['item_count'] as int,
        notes: Value(r['notes'] as String? ?? ''),
        scheduledFor: Value(_dtNullable(r['scheduled_for'])),
        assignedDriver: Value(r['assigned_driver'] as String?),
        intakeRecordedBy: r['intake_recorded_by'] as String,
        createdBy: r['created_by'] as String,
        updatedBy: Value(r['updated_by'] as String?),
        deletedBy: Value(r['deleted_by'] as String?),
        createdAt: Value(_dt(r['created_at'])),
        updatedAt: Value(_dt(r['updated_at'])),
        deletedAt: Value(_dtNullable(r['deleted_at'])),
        // Pricing + payment. These MUST be carried: this mapper is the only
        // server→local path for orders (staff screens read Drift, never
        // Supabase), so anything omitted here reads as 0 on the device. That
        // bites every customer-app order, whose price is frozen server-side at
        // checkout and never re-derived locally. Degrade-to-0 on a null or a
        // row predating a column, matching `LaundryOrder.fromSupabase`.
        ratePerKgSnapshotUgx:
            Value((r['rate_per_kg_snapshot_ugx'] as num?)?.toDouble() ?? 0),
        // The rate-override audit (migration 0059). Null for an ordinary order
        // and for any row predating the columns.
        rateOverrideReason: Value(r['rate_override_reason'] as String?),
        rateOverrideFromUgx:
            Value((r['rate_override_from_ugx'] as num?)?.toDouble()),
        estimatedWeightKg: Value((r['estimated_weight_kg'] as num?)?.toDouble()),
        finalWeightKg: Value((r['final_weight_kg'] as num?)?.toDouble()),
        lineItems: Value(jsonEncode(r['line_items'] ?? const [])),
        manualAdjustmentUgx:
            Value((r['manual_adjustment_ugx'] as num?)?.toInt() ?? 0),
        totalUgx: Value((r['total_ugx'] as num?)?.toInt() ?? 0),
        deliveryFeeSnapshotUgx:
            Value((r['delivery_fee_snapshot_ugx'] as num?)?.toInt() ?? 0),
        isExpress: Value((r['is_express'] as bool?) ?? false),
        expressFlatSnapshotUgx:
            Value((r['express_flat_snapshot_ugx'] as num?)?.toInt() ?? 0),
        expressPctSnapshot:
            Value((r['express_pct_snapshot'] as num?)?.toDouble() ?? 0),
        paymentAmountUgx:
            Value((r['payment_amount_ugx'] as num?)?.toInt() ?? 0),
        // The customer's itemized cart (jsonb → the JSON text column). Kept so
        // staff can see what a customer-app order contains, and which garments
        // they flagged, without a network round-trip. Absent/null for rider and
        // in-shop orders.
        cartItems: Value(jsonEncode(r['cart_items'] ?? const [])),
      );

  ProofEventsCompanion _proofEventsFromJson(Map<String, dynamic> r) =>
      ProofEventsCompanion.insert(
        id: r['id'] as String,
        orderId: r['order_id'] as String,
        type: r['type'] as String,
        capturedAt: _dt(r['captured_at']),
        itemCount: r['item_count'] as int,
        notes: Value(r['notes'] as String?),
        capturedBy: r['captured_by'] as String,
        createdAt: _dt(r['created_at']),
        updatedAt: _dt(r['updated_at']),
        deletedAt: Value(_dtNullable(r['deleted_at'])),
      );

  OrderStatusEventsCompanion _orderStatusEventsFromJson(
          Map<String, dynamic> r) =>
      OrderStatusEventsCompanion.insert(
        id: r['id'] as String,
        orderId: r['order_id'] as String,
        fromStatus: Value(r['from_status'] as String?),
        toStatus: r['to_status'] as String,
        changedBy: r['changed_by'] as String,
        changedAt: _dt(r['changed_at']),
        source: r['source'] as String,
        deviceEventId: Value(r['device_event_id'] as String?),
      );

  ProofPhotosCompanion _proofPhotosFromJson(Map<String, dynamic> r) =>
      ProofPhotosCompanion.insert(
        id: r['id'] as String,
        proofEventId: r['proof_event_id'] as String,
        storagePath: r['storage_path'] as String,
        width: Value(r['width'] as int?),
        height: Value(r['height'] as int?),
        bytes: Value(r['bytes'] as int?),
        uploadedAt: Value(_dtNullable(r['uploaded_at'])),
        createdAt: _dt(r['created_at']),
      );

  IssuesCompanion _issuesFromJson(Map<String, dynamic> r) =>
      IssuesCompanion.insert(
        id: r['id'] as String,
        orderId: Value(r['order_id'] as String?),
        kind: r['kind'] as String,
        description: r['description'] as String,
        reportedBy: r['reported_by'] as String,
        reportedAt: _dt(r['reported_at']),
        resolvedAt: Value(_dtNullable(r['resolved_at'])),
        resolvedBy: Value(r['resolved_by'] as String?),
      );

  ShiftsCompanion _shiftsFromJson(Map<String, dynamic> r) =>
      ShiftsCompanion.insert(
        id: r['id'] as String,
        staffId: r['staff_id'] as String,
        startedAt: _dt(r['started_at']),
        startedLat: Value((r['started_lat'] as num?)?.toDouble()),
        startedLng: Value((r['started_lng'] as num?)?.toDouble()),
        endedAt: Value(_dtNullable(r['ended_at'])),
        endedLat: Value((r['ended_lat'] as num?)?.toDouble()),
        endedLng: Value((r['ended_lng'] as num?)?.toDouble()),
      );

  ValidTransitionsCompanion _validTransitionsFromJson(
          Map<String, dynamic> r) =>
      ValidTransitionsCompanion.insert(
        id: r['id'] as String,
        intakeMethod: r['intake_method'] as String,
        fulfillmentMethod: r['fulfillment_method'] as String,
        fromStatus: Value(r['from_status'] as String?),
        toStatus: r['to_status'] as String,
      );
}

class _FailedRow {
  _FailedRow(this.tableName, this.row, this.error, this.stack);
  final String tableName;
  final Map<String, dynamic> row;
  final Object error;
  final StackTrace stack;
}
