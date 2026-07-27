import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/inbox/inbox_provider.dart';
import 'package:flutter_test/flutter_test.dart';

OrderMessage _m({
  required String id,
  required String orderId,
  required String kind,
  required String body,
  bool read = false,
  int minute = 0,
}) =>
    OrderMessage(
      id: id,
      orderId: orderId,
      senderKind: kind,
      senderId: kind == 'staff' ? 's1' : 'c1',
      body: body,
      createdAt: DateTime.utc(2026, 7, 18, 9, minute),
      readAt: read ? DateTime.utc(2026, 7, 18, 10) : null,
    );

void main() {
  group('buildInbox', () {
    test('one row per order with unread staff messages, newest first', () {
      final items = buildInbox(
        [
          _m(id: 'm1', orderId: 'o1', kind: 'staff', body: 'Ready!', minute: 5),
          _m(id: 'm2', orderId: 'o1', kind: 'staff', body: 'Older', minute: 1),
          _m(id: 'm3', orderId: 'o2', kind: 'staff', body: 'Picked up', minute: 9),
        ],
        {'o1': 'AMW-1', 'o2': 'AMW-2'},
      );

      expect(items, hasLength(2));
      // o2's message (minute 9) is newer than o1's latest (minute 5).
      expect(items.first.orderCode, 'AMW-2');
      expect(items[1].orderCode, 'AMW-1');
      // o1 groups its two unread; snippet is the newest.
      expect(items[1].unreadCount, 2);
      expect(items[1].snippet, 'Ready!');
    });

    test('ignores own messages and already-read staff messages', () {
      final items = buildInbox(
        [
          _m(id: 'm1', orderId: 'o1', kind: 'customer', body: 'mine'),
          _m(id: 'm2', orderId: 'o1', kind: 'staff', body: 'seen', read: true),
        ],
        {'o1': 'AMW-1'},
      );
      expect(items, isEmpty);
    });

    test('falls back to the order id when the code is unknown', () {
      final items = buildInbox(
        [_m(id: 'm1', orderId: 'o9', kind: 'staff', body: 'hi')],
        const {},
      );
      expect(items.single.orderCode, 'o9');
    });
  });
}
