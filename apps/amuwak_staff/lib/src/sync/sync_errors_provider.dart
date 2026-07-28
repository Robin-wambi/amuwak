import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import 'repository_providers.dart';

/// Live list of outbox rows currently in `dead_letter` status — surfaced by
/// the dashboard's sync-errors badge and the SyncErrorsScreen.
final outboxDeadLetteredProvider = StreamProvider<List<OutboxData>>(
  (ref) => ref.watch(outboxRepositoryProvider).watchDeadLettered(),
);

/// Live list of server rows the puller's mapper couldn't ingest.
final pullDeadLetteredProvider = StreamProvider<List<PullDeadLetterData>>(
  (ref) => ref.watch(pullDeadLetterRepositoryProvider).watchAll(),
);

/// Combined count of outbox dead-letters + pull-side dead-letters. Reads
/// `valueOrNull` so the badge shows `0` while either stream is loading
/// rather than hiding the chrome.
final syncErrorCountProvider = Provider<int>((ref) {
  final outbox = ref.watch(outboxDeadLetteredProvider).valueOrNull ?? const [];
  final pull = ref.watch(pullDeadLetteredProvider).valueOrNull ?? const [];
  return outbox.length + pull.length;
});
