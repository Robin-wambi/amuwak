import 'package:amuwak_core/models.dart' show OrderMessagesRepository;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../expenses/expense.dart';
import '../expenses/expenses_repository.dart';
import '../orders/order.dart';
import '../staff/invite_staff_service.dart';
import '../staff/reset_staff_mfa_service.dart';
import 'customers_repository.dart';
import 'orders_repository.dart';
import 'outbox_repository.dart';
import 'proof_events_repository.dart';
import 'pull_dead_letter_repository.dart';
import 'staff_repository.dart';
import 'status_events_repository.dart';
import 'sync_status.dart';

/// Riverpod providers for the repositories.
///
/// OFFLINE-FIRST for orders + proof: [ordersRepositoryProvider] and
/// [proofEventsRepositoryProvider] read from the local Drift DB and queue writes
/// on [outboxRepositoryProvider]. The [SyncOrchestrator] (started from main.dart
/// via `syncLifecycleProvider`) drains the outbox and pulls server changes in
/// the background, so the local Drift database is opened (lazily, on first use)
/// once a session is active. Customers/staff/status repos still read directly
/// from Supabase via [supabaseClientProvider] — flipping those to local reads is
/// a follow-up.

/// Singleton Supabase client. Tests override this with a mock/fake client.
///
/// OPS DEPENDENCY — Realtime publication: the read repos use Supabase
/// `.stream(...)`, which only pushes *live* changes for tables in the
/// `supabase_realtime` publication. Without it, lists load the initial
/// snapshot but never update after a write in the same session (and the
/// new-pickup → capture auto-advance won't fire). Every environment must run:
///
///   alter publication supabase_realtime add table
///     public.orders, public.customers, public.proof_events,
///     public.staff, public.order_status_events, public.expenses;
///
/// See docs/online-only-mode.md for the full ops checklist.
final supabaseClientProvider =
    Provider<SupabaseClient>((_) => Supabase.instance.client);

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(
    ref.watch(appDatabaseProvider),
    outbox: ref.watch(outboxRepositoryProvider),
  ),
);

final customersRepositoryProvider = Provider<CustomersRepository>(
  (ref) => CustomersRepository(ref.watch(supabaseClientProvider)),
);

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.watch(supabaseClientProvider)),
);

final proofEventsRepositoryProvider = Provider<ProofEventsRepository>(
  (ref) => ProofEventsRepository(
    ref.watch(appDatabaseProvider),
    outbox: ref.watch(outboxRepositoryProvider),
  ),
);

final statusEventsRepositoryProvider = Provider<StatusEventsRepository>(
  (ref) => StatusEventsRepository(ref.watch(supabaseClientProvider)),
);

/// Per-order chat (staff side). The shared repository from amuwak_core; staff
/// send with senderKind='staff', senderId = their auth uid.
final orderMessagesRepositoryProvider = Provider<OrderMessagesRepository>(
  (ref) => OrderMessagesRepository(ref.watch(supabaseClientProvider)),
);

// Outbox + pull-dead-letter repos backing the offline write path. Watched by
// the orders/proof providers above and the SyncOrchestrator, so the local Drift
// DB is opened (lazily, on first use) once a session is active.
final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(ref.watch(appDatabaseProvider)),
);

final pullDeadLetterRepositoryProvider =
    Provider<PullDeadLetterRepository>(
  (ref) => PullDeadLetterRepository(ref.watch(appDatabaseProvider)),
);

final ordersStreamProvider = StreamProvider<List<LaundryOrder>>(
  (ref) => ref.watch(ordersRepositoryProvider).watchAll(),
);

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(supabaseClientProvider)),
);

final expensesStreamProvider = StreamProvider<List<Expense>>(
  (ref) => ref.watch(expensesRepositoryProvider).watchAll(),
);

final inviteStaffServiceProvider = Provider<InviteStaffService>(
  (ref) => InviteStaffService(ref.watch(supabaseClientProvider)),
);

final resetStaffMfaServiceProvider = Provider<ResetStaffMfaService>(
  (ref) => ResetStaffMfaService(ref.watch(supabaseClientProvider)),
);
