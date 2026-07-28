import 'package:amuwak_core/amuwak_core.dart';

import '../data/app_database.dart';
import '../sync/sync_orchestrator.dart';

/// Cleanly tears down the per-user sync state and signs the user out.
///
/// Ordering matters:
/// 1. `orchestrator.stop()` — cancels the periodic pull, stops the
///    outbox worker, disposes the connectivity watcher, AND awaits any
///    in-flight pullAll (the orchestrator tracks it via `_inFlightPull`).
///    Truncating Drift while a pull is mid-write would corrupt the
///    next pull's watermark math.
/// 2. Truncate every locally-cached table. The list is explicit so a
///    future schema addition can't be silently skipped or, worse,
///    silently wiped on every sign-out before anyone notices.
/// 3. `AuthService.signOut()` — drops the Supabase session last so the
///    truncate above isn't running against an already-revoked JWT.
///
/// Takes dependencies directly rather than a [Ref] / [ProviderContainer],
/// which keeps the function pure-Dart and lets tests mock with mocktail.
Future<void> signOutAndReset({
  required AuthService auth,
  required SyncOrchestrator orchestrator,
  required AppDatabase db,
}) async {
  await orchestrator.stop();
  await _truncateAllTables(db);
  await auth.signOut();
}

/// Explicit table list — do NOT swap for db.allTables introspection. A future
/// "diagnostics" table that shouldn't be wiped on sign-out would silently
/// disappear under the introspection variant.
Future<void> _truncateAllTables(AppDatabase db) async {
  await db.transaction(() async {
    await db.delete(db.outbox).go();
    await db.delete(db.syncWatermarks).go();
    await db.delete(db.proofPhotos).go();
    await db.delete(db.proofEvents).go();
    await db.delete(db.orderStatusEvents).go();
    await db.delete(db.orders).go();
    await db.delete(db.customers).go();
    await db.delete(db.staff).go();
    await db.delete(db.issues).go();
    await db.delete(db.shifts).go();
    await db.delete(db.validTransitions).go();
    await db.delete(db.pullDeadLetter).go();
  });
}
