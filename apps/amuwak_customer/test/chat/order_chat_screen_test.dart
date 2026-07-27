import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/auth/customer_session.dart';
import 'package:amuwak_customer/src/chat/order_chat_screen.dart';
import 'package:amuwak_customer/src/chat/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OrderMessage _msg({
  required String id,
  required String kind,
  required String body,
  bool read = true,
}) =>
    OrderMessage(
      id: id,
      orderId: 'ord-1',
      senderKind: kind,
      senderId: kind == 'customer' ? 'cust-1' : 'staff-1',
      body: body,
      createdAt: DateTime.utc(2026, 7, 18, 9),
      readAt: read ? DateTime.utc(2026, 7, 18, 10) : null,
    );

void main() {
  testWidgets('renders staff on the left and own messages on the right',
      (tester) async {
    final repo = OrderMessagesRepository.forTest(
      clock: () => DateTime.utc(2026, 7, 18),
      markReadRows: (_, __) async => const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentCustomerIdProvider.overrideWithValue('cust-1'),
        orderMessagesRepositoryProvider.overrideWithValue(repo),
        orderMessagesProvider('ord-1').overrideWith((ref) => Stream.value([
              _msg(id: 'm1', kind: 'staff', body: 'Hi from the shop'),
              _msg(id: 'm2', kind: 'customer', body: 'My message'),
            ])),
      ],
      child: const MaterialApp(home: OrderChatScreen(orderId: 'ord-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hi from the shop'), findsOneWidget);
    expect(find.text('My message'), findsOneWidget);

    // Own message sits further right than the staff message.
    final staffX = tester.getCenter(find.text('Hi from the shop')).dx;
    final mineX = tester.getCenter(find.text('My message')).dx;
    expect(mineX, greaterThan(staffX));
  });

  testWidgets('sending posts a customer-attributed message', (tester) async {
    Map<String, dynamic>? sent;
    final repo = OrderMessagesRepository.forTest(
      clock: () => DateTime.utc(2026, 7, 18),
      insertRow: (values) async {
        sent = values;
        return [
          {'id': 'm9'}
        ];
      },
      markReadRows: (_, __) async => const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentCustomerIdProvider.overrideWithValue('cust-1'),
        orderMessagesRepositoryProvider.overrideWithValue(repo),
        orderMessagesProvider('ord-1')
            .overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: OrderChatScreen(orderId: 'ord-1')),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Is it ready?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!['sender_kind'], 'customer');
    expect(sent!['sender_id'], 'cust-1');
    expect(sent!['body'], 'Is it ready?');
  });
}
