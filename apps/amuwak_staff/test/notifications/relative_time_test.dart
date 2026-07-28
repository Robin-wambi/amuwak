import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/notifications/relative_time.dart';

void main() {
  final now = DateTime.utc(2026, 6, 5, 12, 0);

  String label(Duration ago) =>
      relativeTimeLabel(now.subtract(ago), now: now);

  test('under a minute reads "just now"', () {
    expect(label(const Duration(seconds: 30)), 'just now');
  });

  test('minutes', () {
    expect(label(const Duration(minutes: 1)), '1 min ago');
    expect(label(const Duration(minutes: 45)), '45 min ago');
  });

  test('hours', () {
    expect(label(const Duration(hours: 1)), '1 hr ago');
    expect(label(const Duration(hours: 5)), '5 hr ago');
  });

  test('days', () {
    expect(label(const Duration(hours: 24)), '1 day ago');
    expect(label(const Duration(hours: 47)), '1 day ago');
    expect(label(const Duration(days: 3)), '3 days ago');
  });

  test('a future timestamp collapses to "just now"', () {
    expect(relativeTimeLabel(now.add(const Duration(hours: 2)), now: now),
        'just now');
  });
}
