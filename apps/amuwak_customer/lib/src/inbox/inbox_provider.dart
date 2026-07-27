import 'package:amuwak_core/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/providers.dart';
import '../auth/customer_session.dart';

/// One inbox row: an order that has unread staff messages.
class InboxItem {
  const InboxItem({
    required this.orderId,
    required this.orderCode,
    required this.snippet,
    required this.unreadCount,
    required this.latestAt,
  });

  final String orderId;
  final String orderCode;
  final String snippet;
  final int unreadCount;
  final DateTime latestAt;
}

/// Pure: fold all visible messages into one inbox row per order that has unread
/// *staff* messages, newest activity first. [orderCodeById] supplies the human
/// code (falls back to the id if the order isn't in the map yet).
List<InboxItem> buildInbox(
  List<OrderMessage> messages,
  Map<String, String> orderCodeById,
) {
  final byOrder = <String, List<OrderMessage>>{};
  for (final m in messages) {
    if (m.isFromStaff && !m.isRead) {
      (byOrder[m.orderId] ??= <OrderMessage>[]).add(m);
    }
  }
  final items = byOrder.entries.map((e) {
    final msgs = e.value
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = msgs.first;
    return InboxItem(
      orderId: e.key,
      orderCode: orderCodeById[e.key] ?? e.key,
      snippet: latest.body,
      unreadCount: msgs.length,
      latestAt: latest.createdAt,
    );
  }).toList()
    ..sort((a, b) => b.latestAt.compareTo(a.latestAt));
  return items;
}

/// All messages across the customer's orders, live (RLS-scoped). Empty until the
/// customer id resolves.
final inboxMessagesProvider =
    StreamProvider.autoDispose<List<OrderMessage>>((ref) {
  final customerId = ref.watch(currentCustomerIdProvider);
  if (customerId == null) return Stream.value(const <OrderMessage>[]);
  return ref.watch(orderMessagesRepositoryProvider).watchVisible();
});
