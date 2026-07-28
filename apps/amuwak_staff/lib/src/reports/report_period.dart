import '../expenses/expense.dart';
import '../orders/order.dart';

/// A half-open time window `[start, end)`.
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  /// Includes [start], excludes [end] — so adjacent windows never double-count
  /// a boundary instant.
  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

/// The reporting period the Daily Report is scoped to. The report shows the
/// *current* period (the one containing "now"); past periods are out of scope.
enum ReportPeriod {
  daily(label: 'Daily'),
  weekly(label: 'Weekly'),
  monthly(label: 'Monthly');

  const ReportPeriod({required this.label});

  final String label;

  /// Header noun for the current window, e.g. "This week".
  String get headingLabel => switch (this) {
        ReportPeriod.daily => 'Today',
        ReportPeriod.weekly => 'This week',
        ReportPeriod.monthly => 'This month',
      };

  /// The `[start, end)` window — in [now]'s local zone — for the current period
  /// containing [now]. Weeks start on Monday. Calendar arithmetic uses
  /// `DateTime(y, m, d±n)` (which normalises overflow) rather than `Duration`,
  /// so month/year boundaries roll over correctly.
  DateRange currentWindow(DateTime now) {
    final n = now.toLocal();
    switch (this) {
      case ReportPeriod.daily:
        return DateRange(
          DateTime(n.year, n.month, n.day),
          DateTime(n.year, n.month, n.day + 1),
        );
      case ReportPeriod.weekly:
        final monday = DateTime(n.year, n.month, n.day - (n.weekday - 1));
        return DateRange(
          monday,
          DateTime(monday.year, monday.month, monday.day + 7),
        );
      case ReportPeriod.monthly:
        return DateRange(
          DateTime(n.year, n.month, 1),
          DateTime(n.year, n.month + 1, 1),
        );
    }
  }

  /// The comparable window immediately before [currentWindow] — yesterday, last
  /// week, or last month — used for the report's period-over-period trends. It
  /// ends exactly where the current window starts, so the two are adjacent and
  /// never overlap. Same `DateTime(y, m, d±n)` normalisation, so month/year
  /// boundaries (e.g. January → prior December) roll over correctly.
  DateRange previousWindow(DateTime now) {
    final start = currentWindow(now).start;
    switch (this) {
      case ReportPeriod.daily:
        return DateRange(
          DateTime(start.year, start.month, start.day - 1),
          start,
        );
      case ReportPeriod.weekly:
        return DateRange(
          DateTime(start.year, start.month, start.day - 7),
          start,
        );
      case ReportPeriod.monthly:
        return DateRange(
          DateTime(start.year, start.month - 1, 1),
          start,
        );
    }
  }
}

extension OrderPeriodFilter on List<LaundryOrder> {
  /// Orders whose [LaundryOrder.relevantDate] falls in [window]. An order with
  /// no relevant date (an immediate "now" order with neither a schedule nor any
  /// proof) is always kept — the current period always contains now.
  List<LaundryOrder> inPeriod(DateRange window) => where((o) {
        final d = o.relevantDate;
        return d == null || window.contains(d.toLocal());
      }).toList(growable: false);

  /// Orders in a *past* [window] for trend comparison. Unlike [inPeriod], an
  /// order with no relevant date (an immediate "now" order) is EXCLUDED — those
  /// belong only to the current period and must not inflate the previous-period
  /// figures the current period is compared against.
  List<LaundryOrder> inPastPeriod(DateRange window) => where((o) {
        final d = o.relevantDate;
        return d != null && window.contains(d.toLocal());
      }).toList(growable: false);
}

extension ExpensePeriodFilter on List<Expense> {
  /// Expenses whose `spent_at` falls in [window].
  List<Expense> inPeriod(DateRange window) =>
      where((e) => window.contains(e.spentAt.toLocal())).toList(growable: false);
}
