import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_staff/src/orders/chat/order_chat_screen.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OrderMessage _msg({required String id, required String kind, required String body}) =>
    OrderMessage(
      id: id,
      orderId: 'ord-1',
      senderKind: kind,
      senderId: kind == 'staff' ? 'staff-1' : 'cust-1',
      body: body,
      createdAt: DateTime.utc(2026, 7, 18, 9),
      readAt: null,
    );

void main() {
  testWidgets('staff reply is attributed senderKind=staff with the auth uid',
      (tester) async {
    Map<String, dynamic>? sent;
    final repo = OrderMessagesRepository.forTest(
      clock: () => DateTime.utc(2026, 7, 18),
      insertRow: (values) async {
        sent = values;
        return [
          {'id': 'm9'}
        ];
      },
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('staff-1'),
        orderMessagesRepositoryProvider.overrideWithValue(repo),
        orderMessagesProvider('ord-1')
            .overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: OrderChatScreen(orderId: 'ord-1')),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'On our way');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(sent!['sender_kind'], 'staff');
    expect(sent!['sender_id'], 'staff-1');
    expect(sent!['body'], 'On our way');
  });

  testWidgets('own (staff) messages sit right of the customer\'s',
      (tester) async {
    final repo = OrderMessagesRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('staff-1'),
        orderMessagesRepositoryProvider.overrideWithValue(repo),
        orderMessagesProvider('ord-1').overrideWith((ref) => Stream.value([
              _msg(id: 'm1', kind: 'customer', body: 'Is it ready?'),
              _msg(id: 'm2', kind: 'staff', body: 'Almost!'),
            ])),
      ],
      child: const MaterialApp(home: OrderChatScreen(orderId: 'ord-1')),
    ));
    await tester.pumpAndSettle();

    final customerX = tester.getCenter(find.text('Is it ready?')).dx;
    final staffX = tester.getCenter(find.text('Almost!')).dx;
    expect(staffX, greaterThan(customerX));
  });
}
