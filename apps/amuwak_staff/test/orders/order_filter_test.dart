import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_filter.dart';
import 'package:amuwak_staff/src/orders/order_list_extensions.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';

LaundryOrder _order(
  OrderStatus status, {
  String id = 'X',
  DateTime? deliveredAt,
}) {
  return LaundryOrder(
    orderId: id,
    customerName: 'X',
    serviceType: ServiceType.washOnly,
    status: status,
    timeLabel: 't',
    itemCount: 1,
    phone: 'p',
    address: 'a',
    notes: '',
    proofEvents: deliveredAt == null
        ? const []
        : [
            ProofEvent(
              id: 'd-$id',
              type: ProofEventType.delivery,
              capturedAt: deliveredAt,
              count: 1,
              photoPaths: const [],
            ),
          ],
  );
}

void main() {
  // 11 Jun 2026, mid-morning.
  DateTime now() => DateTime(2026, 6, 11, 10);

  group('OrderFilter.apply', () {
    final orders = [
      _order(OrderStatus.pendingPickup),
      _order(OrderStatus.pendingPickup),
      _order(OrderStatus.inProgress),
      _order(OrderStatus.readyForDelivery),
      _order(OrderStatus.completed, deliveredAt: DateTime(2026, 6, 11, 9)),
    ];

    test('all returns every order (parity with list.length)', () {
      expect(OrderFilter.all.apply(orders, now: now).length, orders.length);
    });

    test('status filters match countByStatus', () {
      expect(
        OrderFilter.pendingPickup.apply(orders, now: now).length,
        orders.countByStatus(OrderStatus.pendingPickup),
      );
      expect(
        OrderFilter.inProgress.apply(orders, now: now).length,
        orders.countByStatus(OrderStatus.inProgress),
      );
      expect(
        OrderFilter.readyForDelivery.apply(orders, now: now).length,
        orders.countByStatus(OrderStatus.readyForDelivery),
      );
    });

    test('count() equals apply().length for every filter', () {
      for (final f in OrderFilter.values) {
        expect(f.count(orders, now: now), f.apply(orders, now: now).length,
            reason: '$f');
      }
    });
  });

  group('OrderFilter.completedToday', () {
    test('includes an order delivered late today', () {
      final o = _order(OrderStatus.completed,
          deliveredAt: DateTime(2026, 6, 11, 23, 59));
      expect(OrderFilter.completedToday.matches(o, now: now()), isTrue);
    });

    test('excludes an order delivered just before midnight yesterday', () {
      final o = _order(OrderStatus.completed,
          deliveredAt: DateTime(2026, 6, 10, 23, 59));
      expect(OrderFilter.completedToday.matches(o, now: now()), isFalse);
    });

    test('excludes a completed order with no delivery proof', () {
      final o = _order(OrderStatus.completed);
      expect(OrderFilter.completedToday.matches(o, now: now()), isFalse);
    });

    test('excludes a non-completed order even with a delivery proof today', () {
      final o = _order(OrderStatus.readyForDelivery,
          deliveredAt: DateTime(2026, 6, 11, 9));
      expect(OrderFilter.completedToday.matches(o, now: now()), isFalse);
    });

    test('classification is independent of UTC-vs-local capturedAt', () {
      // capturedAt arrives from Supabase as UTC; the same instant expressed as
      // UTC vs local must classify identically. Without toLocal() these diverge
      // for an instant whose UTC and local calendar days differ (the EAT
      // 00:00–03:00 window) — this fails on any non-UTC machine if the
      // normalization regresses, and never false-fails on a UTC machine.
      final instantUtc = DateTime.utc(2026, 6, 10, 21, 30); // 00:30 EAT Jun 11
      final asUtc = _order(OrderStatus.completed, deliveredAt: instantUtc);
      final asLocal =
          _order(OrderStatus.completed, deliveredAt: instantUtc.toLocal());
      final reference = DateTime(2026, 6, 11, 10);
      expect(
        OrderFilter.completedToday.matches(asUtc, now: reference),
        OrderFilter.completedToday.matches(asLocal, now: reference),
      );
    });
  });

  group('OrderFilter labels and sort direction', () {
    test('labels', () {
      expect(OrderFilter.all.label, 'Assigned');
      expect(OrderFilter.pendingPickup.label, OrderStatus.pendingPickup.label);
      expect(OrderFilter.inProgress.label, OrderStatus.inProgress.label);
      expect(
        OrderFilter.readyForDelivery.label,
        OrderStatus.readyForDelivery.label,
      );
      expect(OrderFilter.completedToday.label, 'Completed today');
    });

    test('newestFirst is false for the non-completed filters', () {
      expect(OrderFilter.completedToday.newestFirst, isTrue);
      expect(OrderFilter.all.newestFirst, isFalse);
      expect(OrderFilter.pendingPickup.newestFirst, isFalse);
      expect(OrderFilter.inProgress.newestFirst, isFalse);
      expect(OrderFilter.readyForDelivery.newestFirst, isFalse);
    });
  });

  group('OrderFilter.completed (all-time)', () {
    final orders = [
      _order(OrderStatus.pendingPickup),
      _order(OrderStatus.inProgress),
      _order(OrderStatus.completed, deliveredAt: DateTime(2026, 6, 11, 9)),
      _order(OrderStatus.completed), // completed, no delivery proof
    ];

    test('matches every completed order regardless of delivery date', () {
      expect(OrderFilter.completed.apply(orders, now: now).length, 2);
    });

    test('count equals countByStatus(completed)', () {
      expect(
        OrderFilter.completed.count(orders, now: now),
        orders.countByStatus(OrderStatus.completed),
      );
    });

    test('label and newestFirst', () {
      expect(OrderFilter.completed.label, 'Completed');
      expect(OrderFilter.completed.newestFirst, isTrue);
    });
  });

  group('OrderFilter.pendingWork', () {
    final orders = [
      _order(OrderStatus.pendingPickup),
      _order(OrderStatus.inProgress),
      _order(OrderStatus.readyForDelivery),
      _order(OrderStatus.completed, deliveredAt: DateTime(2026, 6, 11, 9)),
    ];

    test('matches every not-completed order', () {
      expect(OrderFilter.pendingWork.apply(orders, now: now).length, 3);
    });

    test('count equals total minus completed', () {
      expect(
        OrderFilter.pendingWork.count(orders, now: now),
        orders.length - orders.countByStatus(OrderStatus.completed),
      );
    });

    test('label and newestFirst', () {
      expect(OrderFilter.pendingWork.label, 'Pending work');
      expect(OrderFilter.pendingWork.newestFirst, isFalse);
    });
  });
}
