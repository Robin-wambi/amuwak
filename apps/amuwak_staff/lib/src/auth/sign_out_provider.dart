import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_orchestrator_provider.dart';
import '../sync/sync_status.dart';
import 'sign_out.dart';

/// Riverpod wiring for [signOutAndReset] — the single sign-out path for the
/// whole app.
///
/// [signOutAndReset] itself stays dependency-injected and pure-Dart (see its
/// doc) so it can be tested with mocktail; this is the one place that knows
/// which providers supply it.
///
/// Every sign-out control must come through here. Calling
/// `AuthService.signOut()` on its own revokes the session but leaves the sync
/// engine running and the whole local cache — orders, customers, proofs, the
/// outbox — on disk for whoever signs in next. On a shared rider device that is
/// the leak `signOutAndReset` exists to prevent.
Future<void> signOutAndResetFromRef(WidgetRef ref) => signOutAndReset(
      auth: ref.read(authServiceProvider),
      orchestrator: ref.read(syncOrchestratorProvider),
      db: ref.read(appDatabaseProvider),
    );
