import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/repository_providers.dart';

/// Staff side of per-order chat with the order's customer. Mirrors the customer
/// app's chat, but own (staff) messages sit on the right and the customer's on
/// the left, and sends are attributed senderKind='staff', senderId = auth uid.
final orderMessagesProvider =
    StreamProvider.autoDispose.family<List<OrderMessage>, String>(
  (ref, orderId) =>
      ref.watch(orderMessagesRepositoryProvider).watchByOrder(orderId),
);

class OrderChatScreen extends ConsumerStatefulWidget {
  const OrderChatScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    final staffId = ref.read(currentUserIdProvider);
    if (body.isEmpty || staffId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(orderMessagesRepositoryProvider).send(
            orderId: widget.orderId,
            senderKind: 'staff',
            senderId: staffId,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with customer')),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text("Couldn't load messages.")),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
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
                      decoration: const InputDecoration(hintText: 'Reply…'),
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
    final mine = message.isFromStaff;
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
          style:
              TextStyle(color: mine ? colors.onPrimary : colors.onSurface),
        ),
      ),
    );
  }
}
