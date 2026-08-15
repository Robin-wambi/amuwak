import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/dashboard/business_glance.dart';
import 'package:amuwak_staff/src/data/app_database.dart' show Customer;
import 'package:amuwak_staff/src/orders/order.dart';

LaundryOrder _order({DateTime? scheduledFor, int paid = 0}) => LaundryOrder(
      orderId: 'o',
      customerName: 'x',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
      scheduledFor: scheduledFor,
      paymentAmountUgx: paid,
      totalUgx: paid,
    );

Customer _customer(String id, DateTime createdAt) => Customer(
      id: id,
      name: 'n',
      phone: 'p',
      address: null,
      notes: null,
      customRatePerKgUgx: null,
      createdAt: createdAt,
      updatedAt: createdAt,
      deletedAt: null,
    );

void main() {
  final now = DateTime(2026, 8, 14, 10);

  test('sums collected on today\'s orders and counts today\'s new customers',
      () {
    final glance = BusinessGlance.forToday(
      [
        // For a non-completed order relevantDate == scheduledFor.
        _order(scheduledFor: DateTime(2026, 8, 14, 9), paid: 5000), // today
        _order(scheduledFor: DateTime(2026, 8, 14, 16), paid: 3000), // today
        _order(scheduledFor: DateTime(2026, 8, 13, 9), paid: 9000), // yesterday
        _order(scheduledFor: null, paid: 1000), // no relevant date
      ],
      [
        _customer('c1', DateTime(2026, 8, 14, 8)), // today
        _customer('c2', DateTime(2026, 8, 10, 8)), // older
      ],
      now: now,
    );

    expect(glance.revenueUgx, 8000);
    expect(glance.newCustomers, 1);
  });

  test('is all-zero when nothing falls on today', () {
    final glance = BusinessGlance.forToday(
      [_order(scheduledFor: DateTime(2026, 8, 13), paid: 5000)],
      [_customer('c1', DateTime(2026, 8, 1))],
      now: now,
    );

    expect(glance.revenueUgx, 0);
    expect(glance.newCustomers, 0);
  });
}
