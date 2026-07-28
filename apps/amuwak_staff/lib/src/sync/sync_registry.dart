/// Declarative list of which Postgres tables to pull and how. The SyncPuller
/// loops over this list every sync cycle.
class SyncTable {
  const SyncTable({
    required this.name,
    this.pkColumn = 'id',
    this.watermarkColumn = 'updated_at',
  });
  final String name;
  final String pkColumn;

  /// JSON / Postgres column the puller compares against the per-table
  /// watermark in `sync_watermarks.last_synced_at`. Defaults to
  /// `updated_at`; override per table for append-only or static-seed
  /// tables (e.g. `changed_at` for `order_status_events`, `created_at`
  /// for `proof_photos`).
  final String watermarkColumn;
}

/// Tables the SyncPuller pulls incrementally on every cycle. Each entry
/// pairs the Postgres table name with the column its watermark advances
/// against — `updated_at` by default for tables that carry the standard
/// BEFORE UPDATE trigger from Supabase migrations 0002–0006, and a
/// custom column for the few append-only / mostly-immutable tables.
///
/// Deliberately excluded:
///   - `issues` and `shifts` — currently have no `updated_at` column. A
///     follow-up Postgres migration will add one (plus the existing
///     `set_updated_at` trigger); only then can they join this list. The
///     puller mappers for both tables already exist in
///     [SyncPuller._upsertRow] so the activation will be a one-line change.
///   - `valid_transitions` — static seed data. It is loaded once at app
///     bootstrap via `ValidTransitionsLoader` (Plan 3a Task 9) rather than
///     polled on every cycle. The mapper exists but the table stays off
///     this list on purpose.
///   - `outbox`, `sync_watermarks` — local-only, never round-tripped.
const List<SyncTable> kSyncTables = [
  SyncTable(name: 'staff'),
  SyncTable(name: 'customers'),
  SyncTable(name: 'orders'),
  SyncTable(name: 'proof_events'),
  // Append-only; uses `changed_at` per the order_status_events schema.
  SyncTable(name: 'order_status_events', watermarkColumn: 'changed_at'),
  // Photo metadata is effectively immutable post-insert; watermark on
  // `created_at`. The binaries themselves go through Plan 4's upload
  // outbox — only the row is pulled here.
  SyncTable(name: 'proof_photos', watermarkColumn: 'created_at'),
];
