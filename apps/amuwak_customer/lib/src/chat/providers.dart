import 'package:amuwak_core/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/customer_session.dart';

final orderMessagesRepositoryProvider = Provider<OrderMessagesRepository>(
  (ref) => OrderMessagesRepository(ref.watch(supabaseClientProvider)),
);

/// Live chat for one order, oldest-first. Scoped to the single order's realtime
/// channel and auto-disposed when the chat screen leaves.
final orderMessagesProvider =
    StreamProvider.autoDispose.family<List<OrderMessage>, String>(
  (ref, orderId) =>
      ref.watch(orderMessagesRepositoryProvider).watchByOrder(orderId),
);
