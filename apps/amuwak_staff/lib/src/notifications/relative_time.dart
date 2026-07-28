/// Short, scannable relative-time label for a past instant ("4 min ago").
///
/// Pure: [now] is injected so callers (and tests) stay deterministic.
String relativeTimeLabel(DateTime time, {required DateTime now}) {
  final diff = now.difference(time);
  // Fold the future-timestamp case (negative diff from clock skew / bad data)
  // in with the sub-minute case — both read as "just now".
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  final days = diff.inDays;
  return '$days day${days == 1 ? '' : 's'} ago';
}
