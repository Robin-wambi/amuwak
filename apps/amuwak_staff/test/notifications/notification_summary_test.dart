import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/notifications/notification_summary.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';

LaundryOrder _order({
  required String code,
  required OrderStatus status,
  DateTime? scheduledFor,
  DateTime? deliveredAt,
}) {
  return LaundryOrder(
    orderId: 'id-$code',
    orderCode: code,
    customerName: 'Cust $code',
    serviceType: ServiceType.washAndIron,
    status: status,
    timeLabel: 'Today',
    itemCount: 1,
    phone: '0700000000',
    address: 'Somewhere',
    notes: '',
    scheduledFor: scheduledFor,
    proofEvents: [
      if (deliveredAt != null)
        ProofEvent(
          id: 'pe-$code',
          type: ProofEventType.delivery,
          capturedAt: deliveredAt,
          count: 1,
          photoPaths: const [],
        ),
    ],
  );
}

void main() {
  final now = DateTime.utc(2026, 6, 5, 12, 0);

  test('new pickups are orders with pendingPickup status', () {
    final summary = NotificationSummary.fromOrders([
      _order(code: 'P1', status: OrderStatus.pendingPickup),
      _order(code: 'I1', status: OrderStatus.inProgress),
    ], now: now);

    expect(summary.newPickups.map((o) => o.orderCode), ['P1']);
  });

  test('delivered includes orders with a delivery proof inside the 48h window', () {
    final summary = NotificationSummary.fromOrders([
      _order(
        code: 'D1',
        status: OrderStatus.completed,
        deliveredAt: now.subtract(const Duration(hours: 1)),
      ),
    ], now: now);

    expect(summary.delivered.map((o) => o.orderCode), ['D1']);
  });

  test('delivered excludes a delivery proof older than the 48h window', () {
    final summary = NotificationSummary.fromOrders([
      _order(
        code: 'OLD',
        status: OrderStatus.completed,
        deliveredAt: now.subtract(const Duration(hours: 49)),
      ),
    ], now: now);

    expect(summary.delivered, isEmpty);
  });

  test('delivered excludes an order delivered at exactly the 48h boundary', () {
    final summary = NotificationSummary.fromOrders([
      _order(
        code: 'EXACT',
        status: OrderStatus.completed,
        deliveredAt: now.subtract(kDeliveredWindow), // exactly 48h ago
      ),
    ], now: now);

    expect(summary.delivered, isEmpty);
  });

  test('a pendingPickup order with a stray delivery proof is not delivered', () {
    final summary = NotificationSummary.fromOrders([
      _order(
        code: 'WEIRD',
        status: OrderStatus.pendingPickup,
        deliveredAt: now.subtract(const Duration(hours: 1)),
      ),
    ], now: now);

    // Appears only as a new pickup, never double-listed under delivered.
    expect(summary.delivered, isEmpty);
    expect(summary.newPickups.map((o) => o.orderCode), ['WEIRD']);
  });

  test('a non-completed order with a delivery proof is not delivered', () {
    // Reachable via the non-atomic proof-insert + status-update in
    // delivery_capture_screen: if the status write fails, the order keeps a
    // delivery proof while still readyForDelivery. It must not show as
    // delivered until the status actually flips to completed.
    final summary = NotificationSummary.fromOrders([
      _order(
        code: 'LAG',
        status: OrderStatus.readyForDelivery,
        deliveredAt: now.subtract(const Duration(hours: 1)),
      ),
    ], now: now);

    expect(summary.delivered, isEmpty);
  });

  test('delivered is sorted most-recent first', () {
    final summary = NotificationSummary.fromOrders([
      _order(
        code: 'OLDER',
        status: OrderStatus.completed,
        deliveredAt: now.subtract(const Duration(hours: 10)),
      ),
      _order(
        code: 'NEWER',
        status: OrderStatus.completed,
        deliveredAt: now.subtract(const Duration(hours: 2)),
      ),
    ], now: now);

    expect(summary.delivered.map((o) => o.orderCode), ['NEWER', 'OLDER']);
  });

  test('new pickups are sorted by scheduledFor ascending, nulls last', () {
    final summary = NotificationSummary.fromOrders([
      _order(code: 'LATER', status: OrderStatus.pendingPickup,
          scheduledFor: now.add(const Duration(hours: 3))),
      _order(code: 'NONE', status: OrderStatus.pendingPickup),
      _order(code: 'SOON', status: OrderStatus.pendingPickup,
          scheduledFor: now.add(const Duration(hours: 1))),
    ], now: now);

    expect(summary.newPickups.map((o) => o.orderCode), ['SOON', 'LATER', 'NONE']);
  });

  test('recent feed is pickups first then delivered', () {
    final summary = NotificationSummary.fromOrders([
      _order(
        code: 'D1',
        status: OrderStatus.completed,
        deliveredAt: now.subtract(const Duration(hours: 1)),
      ),
      _order(code: 'P1', status: OrderStatus.pendingPickup,
          scheduledFor: now.add(const Duration(hours: 1))),
    ], now: now);

    expect(
      summary.recent.map((i) => '${i.kind.name}:${i.order.orderCode}'),
      ['newPickup:P1', 'delivered:D1'],
    );
  });

  test('isEmpty is true when there are no pickups and nothing delivered', () {
    final summary = NotificationSummary.fromOrders([
      _order(code: 'I1', status: OrderStatus.inProgress),
    ], now: now);

    expect(summary.isEmpty, isTrue);
  });

  test('isEmpty is true for an empty order list', () {
    expect(NotificationSummary.fromOrders([], now: now).isEmpty, isTrue);
  });

  test('pendingPickupCount matches the newPickups derived by fromOrders', () {
    final orders = [
      _order(code: 'P1', status: OrderStatus.pendingPickup),
      _order(code: 'P2', status: OrderStatus.pendingPickup),
      _order(code: 'I1', status: OrderStatus.inProgress),
      _order(
        code: 'D1',
        status: OrderStatus.completed,
        deliveredAt: now.subtract(const Duration(hours: 1)),
      ),
    ];

    expect(NotificationSummary.pendingPickupCount(orders), 2);
    expect(
      NotificationSummary.pendingPickupCount(orders),
      NotificationSummary.fromOrders(orders, now: now).newPickups.length,
    );
  });
}
