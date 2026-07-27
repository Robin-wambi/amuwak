import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/customer_session.dart';
import 'providers.dart';

/// Per-order chat with the shop. Customer messages sit on the right, staff on
/// the left. Inbound (staff) messages are marked read as they arrive.
class OrderChatScreen extends ConsumerStatefulWidget {
  const OrderChatScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
  final _input = TextEditingController();
  final _marked = <String>{};
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _markInboundRead(List<OrderMessage> messages) async {
    final ids = messages
        .where((m) => m.isFromStaff && !m.isRead && !_marked.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (ids.isEmpty) return;
    _marked.addAll(ids);
    try {
      await ref.read(orderMessagesRepositoryProvider).markRead(ids);
    } catch (_) {
      // A failed mark-read is non-critical; drop the guard so a later emit
      // retries it.
      _marked.removeAll(ids);
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    final customerId = ref.read(currentCustomerIdProvider);
    if (body.isEmpty || customerId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(orderMessagesRepositoryProvider).send(
            orderId: widget.orderId,
            senderKind: 'customer',
            senderId: customerId,
            body: body,
          );
      _input.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderMessagesProvider(widget.orderId));
    ref.listen(orderMessagesProvider(widget.orderId), (_, next) {
      final msgs = next.valueOrNull;
      if (msgs != null) _markInboundRead(msgs);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Chat with the shop')),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text("Couldn't load messages.")),
              data: (messages) {
                if (messages.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    headline: 'No messages yet',
                    subtitle: 'Send us a message about this order.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(message: messages[i]),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final OrderMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.isFromCustomer;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Text(
          message.body,
          style: TextStyle(
            color: mine ? colors.onPrimary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}
