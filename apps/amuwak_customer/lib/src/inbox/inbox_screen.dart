import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../orders/providers.dart';
import 'inbox_provider.dart';

/// In-app notifications: orders with unread messages from the shop. Tapping an
/// item opens that order's chat.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(inboxMessagesProvider);
    final orders =
        ref.watch(myOrdersProvider).valueOrNull ?? const <LaundryOrder>[];
    final codes = {for (final o in orders) o.orderId: o.orderCode};

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: messagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text("Couldn't load your inbox.")),
        data: (messages) {
          final items = buildInbox(messages, codes);
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              headline: 'You’re all caught up',
              subtitle: 'Messages from the shop will appear here.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = items[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text('${item.unreadCount}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary)),
                ),
                title: Text(item.orderCode,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(item.snippet,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/orders/${item.orderId}/chat'),
              );
            },
          );
        },
      ),
    );
  }
}
