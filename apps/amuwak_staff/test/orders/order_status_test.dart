import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_core/amuwak_core.dart';

void main() {
  group('OrderStatus', () {
    test('exposes a human-readable label for each status', () {
      expect(OrderStatus.pendingPickup.label, 'Pending pickup');
      expect(OrderStatus.inProgress.label, 'In progress');
      expect(OrderStatus.readyForDelivery.label, 'Ready for delivery');
      expect(OrderStatus.completed.label, 'Completed');
    });

    test('nextStatus advances through the laundry pipeline', () {
      expect(OrderStatus.pendingPickup.nextStatus, OrderStatus.inProgress);
      expect(OrderStatus.inProgress.nextStatus, OrderStatus.readyForDelivery);
      expect(OrderStatus.readyForDelivery.nextStatus, OrderStatus.completed);
    });

    test('completed is terminal — nextStatus is null', () {
      expect(OrderStatus.completed.nextStatus, isNull);
    });

    test('toDbString returns the Postgres canonical name', () {
      expect(OrderStatus.pendingPickup.toDbString(), 'pending_pickup');
      expect(OrderStatus.inProgress.toDbString(), 'in_progress');
      expect(OrderStatus.readyForDelivery.toDbString(), 'ready');
      expect(OrderStatus.completed.toDbString(), 'completed');
    });

    test('fromDbString maps every Postgres status, including aliases', () {
      // received → inProgress and out_for_delivery → readyForDelivery are the
      // intentional six-to-four aliases (see mapper TODO).
      expect(OrderStatus.fromDbString('pending_pickup'),
          OrderStatus.pendingPickup);
      expect(OrderStatus.fromDbString('received'), OrderStatus.inProgress);
      expect(OrderStatus.fromDbString('in_progress'), OrderStatus.inProgress);
      expect(OrderStatus.fromDbString('ready'), OrderStatus.readyForDelivery);
      expect(OrderStatus.fromDbString('out_for_delivery'),
          OrderStatus.readyForDelivery);
      expect(OrderStatus.fromDbString('completed'), OrderStatus.completed);
    });

    test('fromDbString degrades an unknown status to pendingPickup', () {
      // Must not throw — a status added server-side before an app update would
      // otherwise crash the whole orders stream.
      expect(OrderStatus.fromDbString('banana'), OrderStatus.pendingPickup);
    });

    test('toDbString round-trips through fromDbString', () {
      for (final s in OrderStatus.values) {
        expect(OrderStatus.fromDbString(s.toDbString()), s,
            reason: 'for ${s.name}');
      }
    });
  });
}
