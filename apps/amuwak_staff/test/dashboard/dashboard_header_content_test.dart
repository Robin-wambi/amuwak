import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/dashboard/dashboard_header_content.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';

LaundryOrder _order(String id, OrderStatus status) => LaundryOrder(
      orderId: id,
      customerName: 'Cust $id',
      serviceType: ServiceType.washOnly,
      status: status,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
    );

void main() {
  group('greetingForHour', () {
    test('morning before noon', () {
      expect(greetingForHour(0), 'Good morning');
      expect(greetingForHour(11), 'Good morning');
    });
    test('afternoon from noon to 16:59', () {
      expect(greetingForHour(12), 'Good afternoon');
      expect(greetingForHour(16), 'Good afternoon');
    });
    test('evening from 17:00', () {
      expect(greetingForHour(17), 'Good evening');
      expect(greetingForHour(23), 'Good evening');
    });
  });

  group('firstName', () {
    test('takes the first token', () {
      expect(firstName('John Achol'), 'John');
      expect(firstName('John'), 'John');
    });
    test('handles extra whitespace and empties', () {
      expect(firstName('  Mary   Jane '), 'Mary');
      expect(firstName(''), '');
      expect(firstName('   '), '');
    });
  });

  group('roleLabel', () {
    test('maps known roles', () {
      expect(roleLabel('rider'), 'Rider');
      expect(roleLabel('manager'), 'Manager');
      expect(roleLabel('in_shop'), 'In-shop');
      expect(roleLabel('staff'), 'Staff');
    });
    test('title-cases an unknown role rather than dropping it', () {
      expect(roleLabel('driver'), 'Driver');
    });
    test('returns null when absent', () {
      expect(roleLabel(null), isNull);
      expect(roleLabel(''), isNull);
    });
  });

  group('headerStatusLine', () {
    test('null while orders are still loading', () {
      expect(headerStatusLine(null), isNull);
    });
    test('all caught up when nothing is outstanding', () {
      expect(headerStatusLine(const []), 'All caught up');
      expect(
        headerStatusLine([_order('a', OrderStatus.completed)]),
        'All caught up',
      );
    });
    test('pickups only, singular vs plural', () {
      expect(
        headerStatusLine([_order('a', OrderStatus.pendingPickup)]),
        '1 pickup due',
      );
      expect(
        headerStatusLine([
          _order('a', OrderStatus.pendingPickup),
          _order('b', OrderStatus.pendingPickup),
        ]),
        '2 pickups due',
      );
    });
    test('in progress only', () {
      expect(
        headerStatusLine([_order('a', OrderStatus.inProgress)]),
        '1 in progress',
      );
    });
    test('joins both with a middot', () {
      expect(
        headerStatusLine([
          _order('a', OrderStatus.pendingPickup),
          _order('b', OrderStatus.pendingPickup),
          _order('c', OrderStatus.inProgress),
        ]),
        '2 pickups due · 1 in progress',
      );
    });
  });

  group('formatHeaderDate', () {
    test('formats as "Weekday, D Month"', () {
      // 2026-06-19 is a Friday.
      expect(formatHeaderDate(DateTime(2026, 6, 19)), 'Friday, 19 June');
      // 2026-01-01 is a Thursday.
      expect(formatHeaderDate(DateTime(2026, 1, 1)), 'Thursday, 1 January');
    });
  });
}
