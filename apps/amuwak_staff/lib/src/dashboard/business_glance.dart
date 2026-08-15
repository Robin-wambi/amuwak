import '../data/app_database.dart' show Customer;
import '../orders/order.dart';
import '../orders/order_list_extensions.dart';

/// The Home "Business at a glance" headline numbers, scoped to today: cash
/// collected on orders relevant to today, and customers added today. Pure so it
/// is unit-testable with an injected `now`.
class BusinessGlance {
  const BusinessGlance({required this.revenueUgx, required this.newCustomers});

  final int revenueUgx;
  final int newCustomers;

  factory BusinessGlance.forToday(
    List<LaundryOrder> orders,
    List<Customer> customers, {
    required DateTime now,
  }) {
    final today = now.toLocal();
    bool isToday(DateTime d) {
      final local = d.toLocal();
      return local.year == today.year &&
          local.month == today.month &&
          local.day == today.day;
    }

    // Revenue is attributed to an order's relevant day (delivery/pickup/
    // scheduled), mirroring how the report scopes collected cash to a period.
    final todaysOrders = orders
        .where((o) => o.relevantDate != null && isToday(o.relevantDate!))
        .toList(growable: false);

    return BusinessGlance(
      revenueUgx: todaysOrders.collectedUgx,
      newCustomers: customers.where((c) => isToday(c.createdAt)).length,
    );
  }
}
