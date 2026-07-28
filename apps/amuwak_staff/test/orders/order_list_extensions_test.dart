import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_list_extensions.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';

LaundryOrder _orderWith(OrderStatus status, {int items = 1, int totalUgx = 0}) {
  return LaundryOrder(
    orderId: 'X',
    customerName: 'X',
    serviceType: ServiceType.washOnly,
    status: status,
    timeLabel: 'X',
    itemCount: items,
    phone: 'X',
    address: 'X',
    notes: 'X',
    totalUgx: totalUgx,
  );
}

LaundryOrder _scheduled(String code, DateTime when) => LaundryOrder(
      orderId: code,
      orderCode: code,
      customerName: 'X',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
      scheduledFor: when,
    );

LaundryOrder _immediate(String code) => LaundryOrder(
      orderId: code,
      orderCode: code,
      customerName: 'X',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
    );

LaundryOrder _deliveredAt(String code, DateTime when) => LaundryOrder(
      orderId: code,
      orderCode: code,
      customerName: 'X',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.completed,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
      proofEvents: [
        ProofEvent(
          id: 'd-$code',
          type: ProofEventType.delivery,
          capturedAt: when,
          count: 1,
          photoPaths: const [],
        ),
      ],
    );

const _searchBase = LaundryOrder(
  orderId: 'AMW-2026-0042',
  customerName: 'Jane Smith',
  serviceType: ServiceType.washOnly,
  status: OrderStatus.pendingPickup,
  timeLabel: 't',
  itemCount: 1,
  phone: '0700123456',
  address: '12 Kololo Road',
  notes: '',
);

void main() {
  group('OrderListStats', () {
    test('countByStatus returns the count for the given status', () {
      final orders = [
        _orderWith(OrderStatus.pendingPickup),
        _orderWith(OrderStatus.pendingPickup),
        _orderWith(OrderStatus.completed),
      ];

      expect(orders.countByStatus(OrderStatus.pendingPickup), 2);
      expect(orders.countByStatus(OrderStatus.inProgress), 0);
      expect(orders.countByStatus(OrderStatus.completed), 1);
    });

    test('totalItems sums itemCount across all orders', () {
      final orders = [
        _orderWith(OrderStatus.pendingPickup, items: 3),
        _orderWith(OrderStatus.completed, items: 5),
      ];

      expect(orders.totalItems, 8);
    });

    test('totalItems is 0 for an empty list', () {
      expect(<LaundryOrder>[].totalItems, 0);
    });

    test('earnedRevenueUgx sums totalUgx of completed orders only', () {
      final orders = [
        _orderWith(OrderStatus.completed, totalUgx: 8000),
        _orderWith(OrderStatus.completed, totalUgx: 12000),
        _orderWith(OrderStatus.inProgress, totalUgx: 5000),
        _orderWith(OrderStatus.pendingPickup, totalUgx: 3000),
      ];

      expect(orders.earnedRevenueUgx, 20000);
    });

    test('expectedRevenueUgx sums totalUgx of non-completed orders only', () {
      final orders = [
        _orderWith(OrderStatus.completed, totalUgx: 8000),
        _orderWith(OrderStatus.inProgress, totalUgx: 5000),
        _orderWith(OrderStatus.pendingPickup, totalUgx: 3000),
        _orderWith(OrderStatus.readyForDelivery, totalUgx: 2000),
      ];

      expect(orders.expectedRevenueUgx, 10000);
    });

    test('totalRevenueUgx equals earned plus expected', () {
      final orders = [
        _orderWith(OrderStatus.completed, totalUgx: 8000),
        _orderWith(OrderStatus.inProgress, totalUgx: 5000),
        _orderWith(OrderStatus.pendingPickup, totalUgx: 3000),
      ];

      expect(orders.totalRevenueUgx, 16000);
      expect(
        orders.totalRevenueUgx,
        orders.earnedRevenueUgx + orders.expectedRevenueUgx,
      );
    });

    test('revenue aggregates are 0 for an empty list', () {
      expect(<LaundryOrder>[].earnedRevenueUgx, 0);
      expect(<LaundryOrder>[].expectedRevenueUgx, 0);
      expect(<LaundryOrder>[].totalRevenueUgx, 0);
    });
  });

  group('OrderListSearch.searchBy', () {
    final other = _searchBase.copyWith(
      orderId: 'AMW-2026-0099',
      orderCode: 'AMW-2026-0099',
      customerName: 'Bob Jones',
      phone: '0788999000',
      address: '5 Entebbe Lane',
    );
    final orders = [_searchBase, other];

    test('empty / whitespace query returns the full list unchanged', () {
      expect(orders.searchBy(''), orders);
      expect(orders.searchBy('   '), orders);
    });

    test('matches on order code: by number, or case-insensitive substring', () {
      // '0042' is a bare number → matched by counter; the full code is matched
      // as a case-insensitive substring.
      expect(orders.searchBy('0042'), [_searchBase]);
      expect(orders.searchBy('amw-2026-0042'), [_searchBase]);
    });

    test('a bare number matches the exact order number, not a digit anywhere',
        () {
      // Typing "4" should find order #4 only — NOT #40, #14, or a code whose
      // year digits happen to contain a 4. Leading zeros are irrelevant.
      // Phones here are digit-"4"-free so this isolates code matching from the
      // (intentionally unchanged) phone search.
      final base = _searchBase.copyWith(phone: '0700000000');
      final four = base.copyWith(orderCode: 'AMW-2026-0004');
      final forty = base.copyWith(orderCode: 'AMW-2026-0040');
      final fourteen = base.copyWith(orderCode: 'AMW-2026-0014');
      final yearHasFour = base.copyWith(orderCode: 'AMW-2024-0099');
      final list = [four, forty, fourteen, yearHasFour];

      expect(list.searchBy('4'), [four]);
      expect(list.searchBy('0004'), [four]);
    });

    test('a bare number matches the same order number across years', () {
      final base = _searchBase.copyWith(phone: '0700000000');
      final y2025 = base.copyWith(orderCode: 'AMW-2025-0006');
      final y2026 = base.copyWith(orderCode: 'AMW-2026-0006');
      expect([y2025, y2026].searchBy('6'), [y2025, y2026]);
    });

    test('a bare number does not match names or addresses containing the digit',
        () {
      // Typing "4" must not surface a "4th Avenue" address or a name with a 4 —
      // a bare number is an order # (or a phone), never a name/address.
      final noise = _searchBase.copyWith(
        orderCode: 'AMW-2026-0070',
        phone: '0700000000',
        address: '4th Avenue',
        customerName: 'Plot 4 Holdings',
      );
      final four = _searchBase.copyWith(
        orderCode: 'AMW-2026-0004',
        phone: '0700000000',
        address: 'No digits here',
        customerName: 'Jane',
      );
      expect([noise, four].searchBy('4'), [four]);
    });

    test('a bare number still matches a phone (phone search is unchanged)', () {
      // A typed phone number is digits-only too; it must keep matching by phone
      // even though it is a "bare number".
      final order = _searchBase.copyWith(
        orderCode: 'AMW-2026-0001',
        phone: '0788123456',
      );
      expect([order].searchBy('788123456'), [order]);
    });

    test('matches on customer name (partial, case-insensitive)', () {
      expect(orders.searchBy('jane'), [_searchBase]);
      expect(orders.searchBy('JONES'), [other]);
    });

    test('matches on phone', () {
      expect(orders.searchBy('0700'), [_searchBase]);
    });

    test('matches phone ignoring formatting (spaces, +, country code)', () {
      // Orders created via the pickup form store the raw, formatted phone the
      // rider typed. A rider searching types digits without the spacing, so the
      // match must compare digit-only forms, not raw substrings.
      final formatted = _searchBase.copyWith(phone: '+256 700 123 456');
      expect([formatted].searchBy('700123456'), [formatted]);
      expect([formatted].searchBy('256 700 123'), [formatted]);
    });

    test('cross-matches a local-format query against an international number',
        () {
      // Stored international (+256), rider searches with the local 0-prefixed
      // form a customer would read out — must still match.
      final intl = _searchBase.copyWith(phone: '+256 700 123 456');
      expect([intl].searchBy('0700123456'), [intl]);
      expect([intl].searchBy('0700 123 456'), [intl]);
    });

    test('matches on address (partial, case-insensitive)', () {
      expect(orders.searchBy('kololo'), [_searchBase]);
      expect(orders.searchBy('entebbe'), [other]);
    });

    test('returns empty when nothing matches', () {
      expect(orders.searchBy('zzz-no-match'), isEmpty);
    });
  });

  group('OrderListGrouping.groupByDay', () {
    // 11 Jun 2026, mid-morning.
    DateTime now() => DateTime(2026, 6, 11, 10);

    test('empty list yields no groups', () {
      expect(<LaundryOrder>[].groupByDay(newestFirst: false, now: now), isEmpty);
    });

    test('immediate orders form a "Now" group placed first', () {
      final groups = [
        _scheduled('s1', DateTime(2026, 6, 11, 14)),
        _immediate('i1'),
      ].groupByDay(newestFirst: false, now: now);

      expect(groups.first.label, 'Now');
      expect(groups.first.day, isNull);
      expect(groups.first.orders.map((o) => o.orderCode), ['i1']);
    });

    test('ascending: Now, then Today, then Tomorrow, soonest-first within day',
        () {
      final groups = [
        _scheduled('tomorrow', DateTime(2026, 6, 12, 9)),
        _scheduled('today-pm', DateTime(2026, 6, 11, 16)),
        _scheduled('today-am', DateTime(2026, 6, 11, 8)),
        _immediate('now'),
      ].groupByDay(newestFirst: false, now: now);

      expect(groups.map((g) => g.label), ['Now', 'Today', 'Tomorrow']);
      expect(
        groups[1].orders.map((o) => o.orderCode),
        ['today-am', 'today-pm'],
      );
    });

    test('newestFirst: most-recent day and order first', () {
      final groups = [
        _deliveredAt('yest', DateTime(2026, 6, 10, 9)),
        _deliveredAt('today-early', DateTime(2026, 6, 11, 9)),
        _deliveredAt('today-late', DateTime(2026, 6, 11, 17)),
      ].groupByDay(newestFirst: true, now: now);

      expect(groups.map((g) => g.label), ['Today', 'Yesterday']);
      expect(
        groups.first.orders.map((o) => o.orderCode),
        ['today-late', 'today-early'],
      );
    });

    test('orderCode breaks ties within the same instant', () {
      final at = DateTime(2026, 6, 11, 9);
      final groups = [
        _scheduled('b', at),
        _scheduled('a', at),
      ].groupByDay(newestFirst: false, now: now);

      expect(groups.single.orders.map((o) => o.orderCode), ['a', 'b']);
    });
  });
}
