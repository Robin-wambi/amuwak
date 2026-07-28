import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_database.dart';

class SyncStatus {
  const SyncStatus({
    required this.pendingCount,
    required this.lastSyncedAt,
    required this.online,
  });
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final bool online;
}

/// Singleton AppDatabase shared by repositories, the OutboxWorker, the
/// SyncPuller, and the banner widget. Tests override this with an
/// in-memory instance so the rest of the sync graph picks it up.
final appDatabaseProvider = Provider<AppDatabase>((_) => AppDatabase());

/// Live count of pending + failed outbox rows. Watched via Drift's stream
/// API so the banner updates immediately when a row is enqueued, sent, or
/// marked failed.
final pendingOutboxCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final countExpr = db.outbox.id.count();
  final query = db.selectOnly(db.outbox)
    ..addColumns([countExpr])
    ..where(db.outbox.status.isIn(<String>['pending', 'failed']));
  return query.watch().map((rows) => rows.first.read(countExpr) ?? 0);
});

/// Newest watermark across every synced table — the most useful "last
/// time we heard from the server" signal for the banner. Emits `null`
/// when the local DB has no watermark rows yet (i.e. the very first
/// sync hasn't completed).
final lastSyncedAtProvider = StreamProvider<DateTime?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final maxExpr = db.syncWatermarks.lastSyncedAt.max();
  final query = db.selectOnly(db.syncWatermarks)..addColumns([maxExpr]);
  return query.watchSingle().map((row) => row.read(maxExpr));
});

/// Set by ConnectivityWatcher via SyncOrchestrator at app bootstrap. Reflects
/// network-interface presence — good enough for the (optional) banner, but NOT
/// a reliable "can we reach the server" signal.
final onlineProvider = StateProvider<bool>((_) => true);

/// Whether the server is actually *reachable*, published by SyncOrchestrator
/// from whether the last `pullAll` completed (a confirmed round-trip) — unlike
/// [onlineProvider], which only tracks interface presence. The OutboxWorker
/// reads this to tell a device-wide transport blip (retry forever) apart from a
/// row-specific hang (dead-letter). Defaults to `false` (fail-safe: assume
/// unreachable until a pull proves otherwise, so a transient failure is never
/// dead-lettered on a hunch).
final serverReachableProvider = StateProvider<bool>((_) => false);

/// Combined sync-status snapshot for the banner widget to consume.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final pending = ref.watch(pendingOutboxCountProvider).valueOrNull ?? 0;
  final lastSynced = ref.watch(lastSyncedAtProvider).valueOrNull;
  final online = ref.watch(onlineProvider);
  return SyncStatus(
    pendingCount: pending,
    lastSyncedAt: lastSynced,
    online: online,
  );
});
