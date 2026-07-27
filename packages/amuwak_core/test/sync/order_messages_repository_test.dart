import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderMessage.fromSupabase', () {
    test('maps a row and derives sender/read flags', () {
      final m = OrderMessage.fromSupabase({
        'id': 'm1',
        'order_id': 'o1',
        'sender_kind': 'staff',
        'sender_id': 's1',
        'body': 'On our way',
        'created_at': DateTime.utc(2026, 7, 18, 9).toIso8601String(),
        'read_at': null,
      });
      expect(m.orderId, 'o1');
      expect(m.isFromStaff, isTrue);
      expect(m.isFromCustomer, isFalse);
      expect(m.isRead, isFalse);
    });

    test('parses read_at when present', () {
      final m = OrderMessage.fromSupabase({
        'id': 'm2',
        'order_id': 'o1',
        'sender_kind': 'customer',
        'sender_id': 'c1',
        'body': 'thanks',
        'created_at': DateTime.utc(2026, 7, 18, 9).toIso8601String(),
        'read_at': DateTime.utc(2026, 7, 18, 10).toIso8601String(),
      });
      expect(m.isFromCustomer, isTrue);
      expect(m.isRead, isTrue);
      expect(m.readAt, DateTime.utc(2026, 7, 18, 10));
    });
  });

  group('send', () {
    test('inserts a self-attributed message row', () async {
      Map<String, dynamic>? sent;
      final repo = OrderMessagesRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 9),
        insertRow: (values) async {
          sent = values;
          return [
            {'id': 'm1'}
          ];
        },
      );

      await repo.send(
        orderId: 'o1',
        senderKind: 'customer',
        senderId: 'c1',
        body: 'Is it ready?',
      );

      expect(sent, {
        'order_id': 'o1',
        'sender_kind': 'customer',
        'sender_id': 'c1',
        'body': 'Is it ready?',
      });
      // created_at is left to the server default — never sent by the client.
      expect(sent!.containsKey('created_at'), isFalse);
    });

    test('throws when the insert persists no row (RLS drop)', () async {
      final repo = OrderMessagesRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 9),
        insertRow: (values) async => const [],
      );
      expect(
        () => repo.send(
            orderId: 'o1', senderKind: 'customer', senderId: 'c1', body: 'hi'),
        throwsStateError,
      );
    });
  });

  group('markRead', () {
    test('stamps read_at for the given ids', () async {
      DateTime? readAt;
      List<String>? ids;
      final repo = OrderMessagesRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 11),
        markReadRows: (r, i) async {
          readAt = r;
          ids = i;
          return [
            {'id': 'm1'},
            {'id': 'm2'}
          ];
        },
      );

      await repo.markRead(['m1', 'm2']);

      expect(readAt, DateTime.utc(2026, 7, 18, 11));
      expect(ids, ['m1', 'm2']);
    });

    test('is a no-op for an empty id list (no update issued)', () async {
      var called = false;
      final repo = OrderMessagesRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 11),
        markReadRows: (r, i) async {
          called = true;
          return const [];
        },
      );
      await repo.markRead(const []);
      expect(called, isFalse);
    });
  });
}
