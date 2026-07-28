import '../orders/order.dart';
import '../orders/order_filter.dart';

/// Pure text helpers for the dashboard header. Kept widget-free so the wording
/// and edge cases are unit-tested without pumping a widget.

/// Time-of-day greeting: morning before noon, afternoon until 17:00, then
/// evening.
String greetingForHour(int hour) => hour < 12
    ? 'Good morning'
    : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

/// First whitespace-delimited token of a display name
/// (e.g. "John Achol" -> "John"). Empty in, empty out.
String firstName(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Human label for a staff `user_role` claim, or `null` when absent — so the
/// header can hide the role chip entirely. Unknown-but-present roles are
/// title-cased rather than dropped.
String? roleLabel(String? role) {
  if (role == null || role.isEmpty) return null;
  return switch (role) {
    'rider' => 'Rider',
    'manager' => 'Manager',
    'in_shop' => 'In-shop',
    'staff' => 'Staff',
    // Title-case via runes so a multi-byte first character (surrogate pair)
    // isn't split — role[0] indexes UTF-16 code units, runes are code points.
    _ => '${String.fromCharCodes(role.runes.take(1)).toUpperCase()}'
        '${String.fromCharCodes(role.runes.skip(1))}',
  };
}

/// The live, at-a-glance work line beneath the greeting. Returns `null` while
/// [orders] is still loading (the header shows the date instead). Once loaded it
/// joins the non-zero of "pickups due" / "in progress"; when there is nothing
/// outstanding it reads "All caught up".
String? headerStatusLine(List<LaundryOrder>? orders, {DateTime Function()? now}) {
  if (orders == null) return null;
  final pickups = OrderFilter.pendingPickup.count(orders, now: now);
  final inProgress = OrderFilter.inProgress.count(orders, now: now);
  final parts = <String>[
    if (pickups > 0) '$pickups ${pickups == 1 ? 'pickup' : 'pickups'} due',
    if (inProgress > 0) '$inProgress in progress',
  ];
  return parts.isEmpty ? 'All caught up' : parts.join(' · ');
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// e.g. "Friday, 20 June". Hand-built because the project has no `intl`
/// dependency. Uses the local calendar day.
String formatHeaderDate(DateTime date) {
  final local = date.toLocal();
  return '${_weekdays[local.weekday - 1]}, '
      '${local.day} ${_months[local.month - 1]}';
}
