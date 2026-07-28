import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/expenses/expense.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/reports/report_period.dart';

LaundryOrder _order({DateTime? scheduledFor}) => LaundryOrder(
      orderId: 'o',
      customerName: 'X',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'a',
      notes: '',
      scheduledFor: scheduledFor,
    );

Expense _expense(DateTime spentAt) => Expense(
      id: 'e',
      category: ExpenseCategory.detergent,
      amountUgx: 1000,
      note: '',
      spentAt: spentAt,
    );

void main() {
  // Wednesday 2026-06-17, 14:30 local.
  final now = DateTime(2026, 6, 17, 14, 30);

  group('ReportPeriod.currentWindow', () {
    test('daily spans the calendar day containing now', () {
      final w = ReportPeriod.daily.currentWindow(now);
      expect(w.start, DateTime(2026, 6, 17));
      expect(w.end, DateTime(2026, 6, 18));
    });

    test('weekly spans Monday..next Monday (week containing now)', () {
      // 2026-06-17 is a Wednesday; its week starts Monday 2026-06-15.
      final w = ReportPeriod.weekly.currentWindow(now);
      expect(w.start, DateTime(2026, 6, 15));
      expect(w.end, DateTime(2026, 6, 22));
    });

    test('monthly spans first..first-of-next-month', () {
      final w = ReportPeriod.monthly.currentWindow(now);
      expect(w.start, DateTime(2026, 6, 1));
      expect(w.end, DateTime(2026, 7, 1));
    });

    test('monthly rolls December over into next January', () {
      final w = ReportPeriod.monthly.currentWindow(DateTime(2026, 12, 9));
      expect(w.start, DateTime(2026, 12, 1));
      expect(w.end, DateTime(2027, 1, 1));
    });
  });

  group('ReportPeriod.previousWindow', () {
    test('daily is the calendar day before the current one', () {
      final w = ReportPeriod.daily.previousWindow(now);
      expect(w.start, DateTime(2026, 6, 16));
      expect(w.end, DateTime(2026, 6, 17));
    });

    test('weekly is the Monday..Monday week before the current one', () {
      final w = ReportPeriod.weekly.previousWindow(now);
      expect(w.start, DateTime(2026, 6, 8));
      expect(w.end, DateTime(2026, 6, 15));
    });

    test('monthly is the month before the current one', () {
      final w = ReportPeriod.monthly.previousWindow(now);
      expect(w.start, DateTime(2026, 5, 1));
      expect(w.end, DateTime(2026, 6, 1));
    });

    test('monthly rolls January back into the prior December', () {
      final w = ReportPeriod.monthly.previousWindow(DateTime(2026, 1, 9));
      expect(w.start, DateTime(2025, 12, 1));
      expect(w.end, DateTime(2026, 1, 1));
    });

    test('previous window ends exactly where the current window starts', () {
      for (final p in ReportPeriod.values) {
        expect(p.previousWindow(now).end, p.currentWindow(now).start);
      }
    });
  });

  group('OrderPeriodFilter.inPastPeriod', () {
    final lastWeek = ReportPeriod.weekly.previousWindow(now);

    test('keeps orders whose relevant date is inside the past window', () {
      final inside = _order(scheduledFor: DateTime(2026, 6, 9, 9));
      expect([inside].inPastPeriod(lastWeek), [inside]);
    });

    test('drops orders outside the past window', () {
      final thisWeek = _order(scheduledFor: DateTime(2026, 6, 16, 9));
      expect([thisWeek].inPastPeriod(lastWeek), isEmpty);
    });

    test('EXCLUDES a no-relevant-date order (unlike inPeriod)', () {
      // "Now" orders belong only to the current period; they must never leak
      // into the previous-period comparison.
      final immediate = _order(scheduledFor: null);
      expect([immediate].inPastPeriod(lastWeek), isEmpty);
    });
  });

  group('ReportPeriod labels', () {
    test('label is the enum display name', () {
      expect(ReportPeriod.daily.label, 'Daily');
      expect(ReportPeriod.weekly.label, 'Weekly');
      expect(ReportPeriod.monthly.label, 'Monthly');
    });

    test('headingLabel is the current-window noun for each period', () {
      expect(ReportPeriod.daily.headingLabel, 'Today');
      expect(ReportPeriod.weekly.headingLabel, 'This week');
      expect(ReportPeriod.monthly.headingLabel, 'This month');
    });
  });

  group('DateRange.contains', () {
    test('is half-open: includes start, excludes end', () {
      final w = ReportPeriod.daily.currentWindow(now);
      expect(w.contains(DateTime(2026, 6, 17, 0, 0)), isTrue);
      expect(w.contains(DateTime(2026, 6, 17, 23, 59)), isTrue);
      expect(w.contains(DateTime(2026, 6, 18, 0, 0)), isFalse);
      expect(w.contains(DateTime(2026, 6, 16, 23, 59)), isFalse);
    });
  });

  group('OrderPeriodFilter.inPeriod', () {
    final week = ReportPeriod.weekly.currentWindow(now);

    test('keeps orders whose relevant date is inside the window', () {
      final inside = _order(scheduledFor: DateTime(2026, 6, 16, 9));
      expect([inside].inPeriod(week), [inside]);
    });

    test('drops orders whose relevant date is outside the window', () {
      final lastWeek = _order(scheduledFor: DateTime(2026, 6, 8, 9));
      expect([lastWeek].inPeriod(week), isEmpty);
    });

    test('always keeps an order with no relevant date (a "now" order)', () {
      final immediate = _order(scheduledFor: null);
      expect([immediate].inPeriod(week), [immediate]);
    });
  });

  group('ExpensePeriodFilter.inPeriod', () {
    final month = ReportPeriod.monthly.currentWindow(now);

    test('keeps expenses spent inside the window, drops those outside', () {
      final thisMonth = _expense(DateTime(2026, 6, 3, 8));
      final lastMonth = _expense(DateTime(2026, 5, 30, 8));
      expect([thisMonth, lastMonth].inPeriod(month), [thisMonth]);
    });
  });
}
